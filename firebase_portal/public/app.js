const $=s=>document.querySelector(s),make=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;};
const labels={id:'المعرف',seq:'التسلسل',name:'الاسم',date:'التاريخ',beneficiary:'المستفيد',accountCode:'رمز الحساب',code:'رمز الحساب',product:'المنتج',profile:'البروفايل',email:'الإيميل',totalEarnings:'إجمالي الأرباح',netProfit:'صافي الربح',roi:'العائد ROI',conversionRate:'نسبة التحويل',baseCapital:'رأس المال',capital:'رأس المال',cost:'التكلفة',clicks:'النقرات',orderedItems:'الطلبات',orderedRevenue:'قيمة الطلبات',shippedItems:'المشحون',returnedItems:'المرتجع',totalRevenue:'إجمالي المبيعات',commission:'العمولة',bonus:'المكافآت',isPending:'قيد التشغيل',storeId:'Store ID',country:'الدولة',status:'الحالة',product1:'المنتج الأول',promoStatus1:'حالة الترويج الأول',product2:'المنتج الثاني',promoStatus2:'حالة الترويج الثاني',gologin:'جو لوجن',phone:'الهاتف',platform:'المنصة',profile1:'البروفايل الأول',profile2:'البروفايل الثاني',profile3:'البروفايل الثالث',host:'الخادم',port:'المنفذ',protocol:'البروتوكول',isUsed:'مستخدم',portType:'نوع المنفذ',bankName:'البنك',beneficiaryName:'صاحب الحساب',amazonEmail:'إيميل أمازون',amazonAccountName:'اسم حساب أمازون',category:'الفئة',accountName:'الحساب',linkType:'نوع الرابط',url:'الرابط',windowName:'الفترة',syriaTime:'توقيت سوريا',usTime:'توقيت أمريكا',stepNumber:'الخطوة',title:'العنوان',details:'التفاصيل',stage:'المرحلة',isCompleted:'مكتملة'};
const metricLabels={capital:'رأس المال',spend:'المصروف',earnings:'الأرباح',netProfit:'صافي الأرباح',remainingCapital:'رأس المال المتبقي',roi:'العائد ROI'};
const errorMessages={IDENTITY_LOCKED:'هذا المعرّف مرتبط بسجلات محلية ولا يمكن تغييره من الويب.',RECORD_IN_USE:'هذا المستفيد مرتبط بسجلات أو مستخدمين. انقل ارتباطاتهم أولًا قبل الحذف.',DUPLICATE_RECORD:'يوجد سجل بالمعرّف نفسه. استخدم معرّفًا مختلفًا.',INVALID_VALUE:'تحقق من الحقول المطلوبة وأنواع القيم والتاريخ.',INVALID_REVISION:'حدّث الصفحة ثم أعد المحاولة.',ACCESS_DENIED:'الوصول إلى هذا الحساب موقوف. تواصل مع المدير.',SIGN_IN_REQUIRED:'انتهت الجلسة. سجّل الدخول مجددًا.',ADMIN_REQUIRED:'هذه العملية متاحة للمدير فقط.',REVISION_CONFLICT:'تغيرت البيانات أثناء التعديل. تم تحديث العرض؛ راجعها ثم أعد المحاولة.',FIELD_DENIED:'لم تعد لديك صلاحية لتعديل هذه الحقول.',BENEFICIARY_NOT_FOUND:'لم تُرفع بيانات المستفيد بعد. تواصل مع المدير.',EMAIL_ALREADY_EXISTS:'البريد مستخدم في Firebase. أدخل UID لربط الحساب الموجود بدل إنشاء حساب جديد.',MEMBER_EXISTS:'المستخدم مضاف مسبقًا.',REQUEST_FAILED:'تعذر إتمام الطلب. تحقق من المدخلات والصلاحيات.',INVALID_BENEFICIARY:'اختر مستفيدًا موجودًا في البيانات المنشورة.',CONFIGURATION_REQUIRED:'لم يتم ضبط إعدادات Firebase بعد.'};
let config,auth=null,access=null,view=null,section='',catalog=null,members=[],streamAbort=null,reconnect=null,editRow=null,editingUid=null,epoch=0;
const money=v=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:2}).format(v||0);
const message=e=>errorMessages[e.code]||'تعذر الاتصال. تحقق من الشبكة وأعد المحاولة.';
function problem(code){return Object.assign(new Error(code),{code});}
async function identity(action,body){
 if(!config.apiKey)throw problem('CONFIGURATION_REQUIRED');
 const authBase=['localhost','127.0.0.1'].includes(location.hostname)&&config.authEmulator?config.authEmulator+'/identitytoolkit.googleapis.com':'https://identitytoolkit.googleapis.com';
 const response=await fetch(authBase+'/v1/accounts:'+action+'?key='+encodeURIComponent(config.apiKey),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
 const data=await response.json();if(!response.ok)throw problem('SIGN_IN_REQUIRED');return data;
}
async function token(){
 if(auth&&auth.expiresAt>Date.now()+60000)return auth.idToken;
 const refreshToken=auth?.refreshToken||sessionStorage.getItem('erp-refresh');if(!refreshToken)throw problem('SIGN_IN_REQUIRED');
 const refreshBase=['localhost','127.0.0.1'].includes(location.hostname)&&config.authEmulator?config.authEmulator+'/securetoken.googleapis.com':'https://securetoken.googleapis.com';
 const res=await fetch(refreshBase+'/v1/token?key='+encodeURIComponent(config.apiKey),{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',refresh_token:refreshToken})});
 if(!res.ok)throw problem('SIGN_IN_REQUIRED');const value=await res.json();auth={idToken:value.id_token,refreshToken:value.refresh_token,expiresAt:Date.now()+Number(value.expires_in)*1000};sessionStorage.setItem('erp-refresh',auth.refreshToken);return auth.idToken;
}
async function api(path,method='GET',body){
 const response=await fetch((config.apiBase||'/api')+path,{method,headers:{Authorization:'Bearer '+await token(),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,cache:'no-store'});
 const data=await response.json();if(!response.ok)throw problem(data.error||'REQUEST_FAILED');return data;
}
function clearData(){document.querySelectorAll('dialog.admin-record-dialog').forEach(d=>d.close());document.body.classList.remove('admin-mode');$('#admin-dashboard')?.remove();if($('#edit-dialog').open)$('#edit-dialog').close();$('#edit-fields').replaceChildren();editRow=null;view=null;$('#metrics').replaceChildren();$('#table-head').replaceChildren();$('#table-body').replaceChildren();$('#members').replaceChildren();}
function logout(text=''){
 epoch++;streamAbort?.abort();clearTimeout(reconnect);auth=null;access=null;catalog=null;members=[];sessionStorage.removeItem('erp-refresh');clearData();$('#app').hidden=true;$('#login').hidden=false;$('#login-error').textContent=text;$('#password').value='';
}
async function enter(){
 access=await api('/access');$('#login').hidden=true;$('#app').hidden=false;$('#greeting').textContent=access.role==='admin'?'إدارة المستخدمين':access.displayName||'حسابي';
 $('#member-view').hidden=access.role==='admin';$('#admin-view').hidden=access.role!=='admin';
 if(access.role==='admin')await loadAdmin();else await refreshView();
 void subscribe(epoch);
}
async function refreshView(){view=await api('/view');renderView();}
function renderView(){
 if(!view)return;
 $('#notice').textContent='';$('#greeting').textContent=view.displayName||view.beneficiaryName;
 $('#metrics').replaceChildren(...Object.entries(view.metrics).map(([key,value])=>{
  const box=make('article',undefined,'metric');box.append(make('div',metricLabels[key]||key,'label'),make('div',key==='roi'?(value*100).toFixed(1)+'%':money(value),'value'));return box;
 }));
 const sections=Object.entries(view.sections);if(!view.sections[section])section=sections[0]?.[0]||'';
 $('#tabs').replaceChildren(...sections.map(([id,s])=>{const button=make('button',s.label,id===section?'active':'');button.onclick=()=>{section=id;renderView();};return button;}));
 $('#export').hidden=!view.canExport;renderTable();$('#last-update').textContent=new Date().toLocaleString('ar');
}
function renderTable(){
 const s=view?.sections[section];$('#section-title').textContent=s?.label||'لا توجد أقسام مسموحة';
 const needle=$('#search').value.trim().toLowerCase();const rows=(s?.rows||[]).filter(r=>Object.values(r.values).some(v=>String(v).toLowerCase().includes(needle)));
 const heading=make('tr');for(const field of s?.fields||[])heading.append(make('th',labels[field]||field));if(s?.editableFields.length)heading.append(make('th','تعديل'));$('#table-head').replaceChildren(heading);
 $('#table-body').replaceChildren(...rows.map(row=>{const tr=make('tr');for(const field of s.fields){const value=row.values[field];const td=make('td',value===''||value===null?'—':typeof value==='boolean'?(value?'نعم':'لا'):['cost','capital','baseCapital','orderedRevenue','totalRevenue','commission','bonus','totalEarnings','netProfit'].includes(field)?money(value):['roi','conversionRate'].includes(field)?(Number(value)*100).toFixed(1)+'%':String(value??''));if(typeof value==='number')td.className='money'+(['netProfit','roi'].includes(field)?(value<0?' negative':' positive'):'');tr.append(td);}if(s.editableFields.length){const td=make('td'),button=make('button','تعديل','quiet');button.onclick=()=>openEdit(row);td.append(button);tr.append(td);}return tr;}));
 $('#empty').hidden=rows.length>0;
}
$('#search').oninput=renderTable;
async function subscribe(myEpoch){
 streamAbort?.abort();streamAbort=new AbortController();
 try{
  const response=await fetch((config.apiBase||'/api')+'/events',{headers:{Authorization:'Bearer '+await token()},signal:streamAbort.signal,cache:'no-store'});
  if(!response.ok){const d=await response.json();throw problem(d.error||'REQUEST_FAILED');}
  $('#connection').textContent='متصل • تحديث مباشر';
  const reader=response.body.getReader(),decoder=new TextDecoder();let buffered='';
  while(myEpoch===epoch){const {value,done}=await reader.read();if(done)break;buffered+=decoder.decode(value,{stream:true});let end;while((end=buffered.indexOf('\n\n'))>=0){const event=buffered.slice(0,end);buffered=buffered.slice(end+2);const line=event.split('\n').find(l=>l.startsWith('data: '));if(!line)continue;const item=JSON.parse(line.slice(6));if(item.kind==='revoked'){logout('تم سحب صلاحية الوصول. تواصل مع المدير.');return;}if(item.kind==='clear'){clearData();}if(item.kind==='view'){view=item.data;renderView();}if(item.kind==='revision'&&access?.role==='admin')await loadAdmin();if(item.kind==='error')$('#notice').textContent='تأخر التحديث. جارٍ إعادة الاتصال.';}}
 }catch(e){if(e.name==='AbortError')return;if(e.code==='ACCESS_DENIED'||e.code==='SIGN_IN_REQUIRED'){logout(message(e));return;}$('#connection').textContent='انقطع الاتصال';$('#notice').textContent='البيانات المعروضة قديمة؛ ستُحدّث تلقائيًا عند عودة الاتصال.';}
 if(myEpoch===epoch&&access)reconnect=setTimeout(()=>subscribe(myEpoch),2000);
}
$('#login-form').onsubmit=async event=>{
 event.preventDefault();$('#login-submit').disabled=true;$('#login-error').textContent='';
 try{const result=await identity('signInWithPassword',{email:$('#email').value.trim(),password:$('#password').value,returnSecureToken:true});auth={idToken:result.idToken,refreshToken:result.refreshToken,expiresAt:Date.now()+Number(result.expiresIn)*1000};sessionStorage.setItem('erp-refresh',auth.refreshToken);$('#password').value='';await enter();}catch(e){logout(message(e));}finally{$('#login-submit').disabled=false;}
};
$('#logout').onclick=()=>logout();
function openEdit(row){
 editRow={section,row,revision:view.revision};$('#edit-error').textContent='';
 $('#edit-fields').replaceChildren(...view.sections[section].editableFields.map(field=>{
  const label=make('label',labels[field]||field),value=row.values[field],input=make('input');input.dataset.field=field;input.dataset.kind=typeof value;
  if(typeof value==='boolean'){input.type='checkbox';input.checked=value;}else{input.value=String(value??'');if(typeof value==='number'){input.type='number';input.min='0';input.step='any';}else input.maxLength=3000;}label.append(input);return label;
 }));$('#edit-dialog').showModal();
}
$('#edit-close').onclick=()=>$('#edit-dialog').close();
$('#edit-form').onsubmit=async event=>{
 event.preventDefault();$('#edit-save').disabled=true;try{const changes=Object.fromEntries([...$('#edit-fields').querySelectorAll('input')].map(i=>[i.dataset.field,i.dataset.kind==='boolean'?i.checked:i.dataset.kind==='number'?Number(i.value):i.value]));await api('/records/'+encodeURIComponent(editRow.section)+'/'+editRow.row.rowId,'PATCH',{changes,expectedRevision:editRow.revision});$('#edit-dialog').close();await refreshView();}catch(e){$('#edit-error').textContent=message(e);if(e.code==='REVISION_CONFLICT')await refreshView();}finally{$('#edit-save').disabled=false;}
};
$('#export').onclick=()=>{
 if(!view?.canExport)return;const s=view.sections[section];if(!s)return;
 const csvCell=v=>'"'+String(v??'').replace(/^[=+@-]/,"'$&").replaceAll('"','""')+'"';
 const lines=[s.fields.map(f=>labels[f]||f),...s.rows.map(r=>s.fields.map(f=>r.values[f]))];const url=URL.createObjectURL(new Blob(['\uFEFF'+lines.map(row=>row.map(csvCell).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}));const a=make('a');a.href=url;a.download=section+'.csv';a.click();URL.revokeObjectURL(url);
};
async function loadAdmin(){
 const [cat,result]=await Promise.all([api('/admin/catalog'),api('/admin/users')]);catalog=cat;members=result.users;$('#tabs').replaceChildren();
 $('#members').replaceChildren(...members.map(member=>{const card=make('article',undefined,'member-card');card.append(make('h3',member.displayName||member.email),make('p',member.email),make('p',member.role==='admin'?'مدير النظام':catalog.beneficiaries.find(b=>String(b.id)===String(member.beneficiaryId))?.name||'المستفيد غير موجود'),make('span',member.enabled?'نشط':'الوصول مسحوب','pill'));if(member.role==='beneficiary'){const button=make('button','تعديل الصلاحيات','quiet');button.onclick=()=>openMember(member);card.append(make('br'),button);}return card;}));
 const previous=$('#assign-table').value;$('#assign-table').replaceChildren(...Object.entries(catalog.tables).map(([t,d])=>new Option(d.label,t)));if(catalog.tables[previous])$('#assign-table').value=previous;
 fillAssignments();renderAdminDashboard();$('#last-update').textContent=new Date().toLocaleString('ar');
}
function fillAssignments(){
 const t=$('#assign-table').value;$('#assign-record').replaceChildren(...(catalog?.records[t]||[]).map(r=>new Option(Object.entries(r.values).slice(0,5).map(([k,v])=>(labels[k]||k)+': '+v).join(' | '),r.rowId)));
 $('#assign-owner').replaceChildren(new Option('تلقائي / إزالة الربط اليدوي',''),...(catalog?.beneficiaries||[]).map(b=>new Option(b.name,String(b.id))));showAssignment();
}
function showAssignment(){const key=$('#assign-table').value+':'+$('#assign-record').value;$('#assign-owner').value=catalog?.assignments[key]??'';}
$('#assign-table').onchange=fillAssignments;$('#assign-record').onchange=showAssignment;
$('#assign-save').onclick=async()=>{try{await api('/admin/assign','POST',{table:$('#assign-table').value,rowId:$('#assign-record').value,beneficiaryId:$('#assign-owner').value||null});$('#notice').textContent='تم حفظ الربط وتحديث عرض المستفيد.';await loadAdmin();}catch(e){$('#notice').textContent=message(e);}};
function permissionDom(permissions){
 $('#permission-metrics').replaceChildren(...Object.entries(catalog.metrics).map(([key,label])=>{const box=make('label',undefined,'check'),input=make('input');input.type='checkbox';input.dataset.metric=key;input.checked=permissions.metrics.includes(key);box.append(input,document.createTextNode(label));return box;}));
 $('#permission-sections').replaceChildren(...Object.entries(catalog.tables).map(([table,def])=>{
  const details=make('details',undefined,'permission-group');details.append(make('summary',def.label));
  const heading=make('div',undefined,'permission-row');heading.append(make('span','الحقل'),make('span','عرض'),make('span','تعديل'));details.append(heading);
  for(const field of def.keys){const line=make('div',undefined,'permission-row');line.append(make('span',labels[field]||field));const visible=make('input'),edit=make('input');visible.type=edit.type='checkbox';visible.dataset.table=edit.dataset.table=table;visible.dataset.field=edit.dataset.field=field;visible.dataset.permission='view';edit.dataset.permission='edit';visible.checked=permissions.sections[table]?.fields.includes(field)||false;edit.checked=permissions.sections[table]?.editableFields.includes(field)||false;
   const locked=['totalEarnings','netProfit','roi','conversionRate','id','seq','beneficiary','accountCode','code','email','profile','profile1','profile2','profile3','storeId','amazonEmail','amazonAccountName','name','beneficiaryName','host','port','stepNumber','category','platform','windowName','accountName','product','linkType','url'].includes(field);edit.disabled=locked||!visible.checked;
   visible.onchange=()=>{if(!visible.checked)edit.checked=false;edit.disabled=locked||!visible.checked;};line.append(visible,edit);details.append(line);
  }return details;
 }));
}
function openMember(member){
 editingUid=member?.uid||null;$('#member-uid').value='';$('#member-uid-label').hidden=!!member;$('#member-title').textContent=member?'تعديل الصلاحيات':'إضافة مستخدم';$('#member-name').value=member?.displayName||'';$('#member-email').value=member?.email||'';$('#member-email').disabled=!!member;$('#member-password').value='';$('#member-password').required=!member;$('#member-email').required=!member;$('#member-password-label').hidden=!!member;$('#member-enabled').checked=member?.enabled??true;
 $('#member-beneficiary').replaceChildren(...catalog.beneficiaries.map(b=>new Option(b.name,String(b.id))));if(member)$('#member-beneficiary').value=String(member.beneficiaryId);const permissions=member?.permissions||catalog.defaultPermissions;permissionDom(permissions);$('#member-export').checked=permissions.export;$('#member-error').textContent='';$('#member-dialog').showModal();
}
$('#member-uid').oninput=()=>{$('#member-password').required=!$('#member-uid').value.trim();$('#member-email').required=!$('#member-uid').value.trim();};
$('#add-member').onclick=()=>{if(!catalog?.beneficiaries.length){$('#notice').textContent='ارفع بيانات المستفيدين من تطبيق المدير أولًا.';return;}openMember();};$('#member-close').onclick=()=>$('#member-dialog').close();
$('#member-form').onsubmit=async event=>{
 event.preventDefault();$('#member-save').disabled=true;
 try{const sections={};for(const input of $('#permission-sections').querySelectorAll('input'))if(input.checked){const t=input.dataset.table;sections[t]??={fields:[],editableFields:[]};sections[t][input.dataset.permission==='view'?'fields':'editableFields'].push(input.dataset.field);}
 const body={displayName:$('#member-name').value,beneficiaryId:$('#member-beneficiary').value,enabled:$('#member-enabled').checked,permissions:{sections,metrics:[...$('#permission-metrics').querySelectorAll('input:checked')].map(i=>i.dataset.metric),export:$('#member-export').checked}};
 if(editingUid)await api('/admin/users/'+encodeURIComponent(editingUid),'PATCH',body);else await api('/admin/users','POST',{...body,...($('#member-uid').value.trim()?{uid:$('#member-uid').value.trim()}:{email:$('#member-email').value,password:$('#member-password').value})});$('#member-password').value='';$('#member-dialog').close();await loadAdmin();
 }catch(e){$('#member-error').textContent=message(e);}finally{$('#member-save').disabled=false;}
};
/* Administrator analytics: only mounted after the server confirms admin access. */
let adminPage='overview',adminQuery='',adminOwner='',adminDate='',adminSort='',adminAscending=true;
const adminHidden={};
function campaignValues(r){const cost=Number(r.cost)||0,earned=r.isPending?0:(Number(r.commission)||0)+(Number(r.bonus)||0),net=r.isPending?0:earned-cost;return {...r,totalEarnings:earned,netProfit:net,roi:r.isPending?'':cost?net/cost:0,conversionRate:r.clicks?(Number(r.orderedItems)||0)/r.clicks:0};}
function adminStats(rows,capital){const spend=rows.reduce((a,r)=>a+(Number(r.cost)||0),0),earnings=rows.reduce((a,r)=>a+campaignValues(r).totalEarnings,0),net=rows.reduce((a,r)=>a+campaignValues(r).netProfit,0);return {capital,spend,earnings,netProfit:net,remainingCapital:capital-spend,roi:spend?net/spend:0};}
function adminRecords(t){return (catalog?.records[t]||[]).map(r=>({...r,values:{...(t==='campaigns'?campaignValues(r.values):r.values),__rowId:r.rowId}}));}
function adminOpen(page){adminPage=page;adminQuery='';adminOwner='';adminDate='';adminSort='';renderAdminDashboard();}
function renderAdminDashboard(){
 if(access?.role!=='admin'||!catalog)return;
 let root=$('#admin-dashboard');if(!root){root=make('section');root.id='admin-dashboard';$('#admin-view').before(root);}
 document.body.classList.add('admin-mode');$('#greeting').textContent='مركز قيادة الأعمال';
 $('#member-view').hidden=true;$('#admin-view').hidden=adminPage!=='users';root.hidden=adminPage==='users';
 const nav=[['overview','◈','التقرير التنفيذي'],...Object.entries(catalog.tables).map(([k,v])=>[k,'▦',v.label]),['users','⚙','المستخدمون والصلاحيات']];
 $('#tabs').replaceChildren(...nav.map(([id,icon,title])=>{const b=make('button',icon+'  '+title,id===adminPage?'active':'');b.onclick=()=>adminOpen(id);return b;}));
 root.replaceChildren();if(root.hidden)return;
 const banner=make('div',undefined,'executive-banner');const info=make('div');info.append(make('span','AMAZON • EXECUTIVE WORKSPACE','eyebrow'),make('h2',adminPage==='overview'?'صورة واضحة. قرارات أفضل.':catalog.tables[adminPage]?.label),make('p','بيانات أعمالك المتزامنة من التطبيق • تحديث مباشر عند حفظ التغييرات'));
 const refresh=make('button','↻ تحديث البيانات','quiet');refresh.onclick=async()=>{refresh.disabled=true;try{await loadAdmin();}catch(e){$('#notice').textContent=message(e);}finally{refresh.disabled=false;}};banner.append(info,refresh);root.append(banner);
 if(adminPage==='overview'){renderExecutive(root);return;}
 renderAdminDetails(root);
}
function renderExecutive(root){
 const campaigns=adminRecords('campaigns').map(r=>r.values),capital=catalog.beneficiaries.reduce((s,b)=>s+(Number(b.baseCapital)||0),0),stats=adminStats(campaigns,capital);
 const grid=make('div',undefined,'metric-grid');for(const [k,v]of Object.entries(stats)){const card=make('article',undefined,'metric');card.append(make('div',metricLabels[k],'label'),make('div',k==='roi'?(v*100).toFixed(1)+'%':money(v),'value'));grid.append(card);}root.append(grid);
 const counts=make('div',undefined,'asset-grid');for(const [key,title]of [['campaigns','حملة مسجلة'],['amazon_accounts','حساب أمازون'],['emails','حساب بريد'],['bank_accounts','حساب بنكي'],['proxies','بروكسي'],['workflow_steps','خطوة عمل']]){const b=make('button',undefined,'asset-card');b.append(make('strong',String(adminRecords(key).length)),make('span',title));b.onclick=()=>adminOpen(key);counts.append(b);}root.append(counts);
 const split=make('div',undefined,'overview-split'),trend=make('section',undefined,'dashboard-panel'),activity=make('section',undefined,'dashboard-panel');trend.append(make('h3','حركة الأرباح خلال آخر 14 يومًا'),make('p','إجمالي الأرباح والمصروف حسب تاريخ الحملات'));
 const days=new Map();for(const r of campaigns){if(!r.date)continue;const d=days.get(r.date)||{earned:0,cost:0};d.earned+=campaignValues(r).totalEarnings;d.cost+=Number(r.cost)||0;days.set(r.date,d);}
 const recent=[...days].sort(([a],[b])=>a.localeCompare(b)).slice(-14),max=Math.max(1,...recent.flatMap(([,v])=>[v.earned,v.cost]));const chart=make('div',undefined,'daily-chart');for(const [date,v]of recent){const col=make('div',undefined,'chart-column'),bars=make('div',undefined,'chart-bars');for(const [key,label]of [['earned','الأرباح'],['cost','المصروف']]){const bar=make('div',undefined,'bar '+key);bar.style.height=(v[key]/max*150)+'px';bar.title=label+' '+money(v[key]);bars.append(bar);}col.append(bars,make('small',date.slice(5)));chart.append(col);}if(!recent.length)chart.append(make('p','لا توجد حملات متزامنة بعد.'));trend.append(chart,make('p','● الأرباح باللون الأخضر   ● المصروف باللون الذهبي','chart-legend'));
 activity.append(make('h3','نبض العمليات'));for(const [title,value]of [['حملات بانتظار النتائج',campaigns.filter(r=>r.isPending).length],['حملات رابحة',campaigns.filter(r=>!r.isPending&&campaignValues(r).netProfit>0).length],['حملات بخسارة',campaigns.filter(r=>!r.isPending&&campaignValues(r).netProfit<0).length],['إجمالي النقرات',campaigns.reduce((s,r)=>s+(Number(r.clicks)||0),0)],['إجمالي الطلبات',campaigns.reduce((s,r)=>s+(Number(r.orderedItems)||0),0)]]){const line=make('div',undefined,'pulse-line');line.append(make('span',title),make('strong',Number(value).toLocaleString('en-US')));activity.append(line);}split.append(trend,activity);root.append(split);
 const panel=make('section',undefined,'dashboard-panel');panel.append(make('h3','أرصدة المستفيدين وأداء رؤوس الأموال'));
 const fields=['name','baseCapital','spend','remainingCapital','campaignCount','totalEarnings','netProfit','roi'];const rows=catalog.beneficiaries.map(b=>{const cs=campaigns.filter(r=>String(r.beneficiary||'').trim().toLowerCase()===String(b.name).trim().toLowerCase()),v=adminStats(cs,Number(b.baseCapital)||0);return {...b,...v,totalEarnings:v.earnings,campaignCount:cs.length};});panel.append(adminTable(fields,rows));root.append(panel);
 const note=make('p','الأرباح وصافي الربح للحملات المعلّقة ينتظران النتائج. تكلفتها تدخل ضمن المصروف ورأس المال المتبقي.','data-note');root.append(note);
}
function adminTable(fields,rows,actions=false){
 if(adminSort)rows=[...rows].sort((a,b)=>{const x=a[adminSort],y=b[adminSort];return (typeof x==='number'&&typeof y==='number'?x-y:String(x??'').localeCompare(String(y??''),'ar',{numeric:true}))*(adminAscending?1:-1);});const shell=make('div',undefined,'table-shell'),table=make('table'),head=make('thead'),tr=make('tr');for(const f of fields){const th=make('th',labels[f]||metricLabels[f]||({campaignCount:'الحملات'}[f])||f);th.tabIndex=0;th.title='ترتيب حسب هذا العمود';const sort=()=>{adminAscending=adminSort===f?!adminAscending:true;adminSort=f;renderAdminDashboard();};th.onclick=sort;th.onkeydown=e=>{if(e.key==='Enter')sort();};tr.append(th);}if(actions)tr.append(make('th','الإجراءات'));head.append(tr);table.append(head);const body=make('tbody');for(const r of rows){const line=make('tr');if(r.date){let hash=0;for(const c of r.date)hash=(hash*31+c.charCodeAt(0))>>>0;line.style.backgroundColor=['#f0f7f5','#f3f1fa','#fff8e9','#eef5fc'][hash%4];}for(const f of fields){const v=r[f];const td=make('td',v===null||v===undefined||v===''?'—':typeof v==='boolean'?(v?'نعم':'لا'):['roi','conversionRate'].includes(f)?(Number(v)*100).toFixed(1)+'%':['cost','capital','baseCapital','orderedRevenue','totalRevenue','commission','bonus','totalEarnings','netProfit','spend','remainingCapital'].includes(f)?money(v):String(v));if(['netProfit','roi','remainingCapital'].includes(f))td.classList.add(Number(v)<0?'negative':'positive');if(['beneficiary','accountCode','code'].includes(f)){const badge=make('span',td.textContent,'record-badge');td.replaceChildren(badge);}td.title=td.textContent;line.append(td);}if(actions){const cell=make('td'),record=adminRecords(adminPage).find(rec=>String(rec.rowId)===String(r.__rowId));for(const [label,action]of [['تعديل','update'],['حذف','delete']]){const b=make('button',label,'quiet');b.onclick=()=>openAdminRecord(adminPage,record,action);cell.append(b);}line.append(cell);}body.append(line);}if(!rows.length){const line=make('tr'),td=make('td','لا توجد سجلات مطابقة');td.colSpan=Math.max(1,fields.length);line.append(td);body.append(line);}table.append(body);shell.append(table);return shell;}
function renderAdminDetails(root){
 const t=adminPage,def=catalog.tables[t],fields=def.keys,records=adminRecords(t);const tools=make('div',undefined,'admin-filters');
 const search=make('input');search.placeholder='بحث في جميع الحقول…';search.value=adminQuery;search.setAttribute('aria-label','بحث');
 const owner=make('select');owner.setAttribute('aria-label','المستفيد');owner.append(new Option('كل المستفيدين',''),...catalog.beneficiaries.map(b=>new Option(b.name,b.name)));owner.value=adminOwner;
 const date=make('input');date.type='date';date.value=adminDate;date.setAttribute('aria-label','التاريخ');date.hidden=!fields.includes('date');
 const columns=make('details',undefined,'column-picker');columns.append(make('summary','الأعمدة الظاهرة'));const hidden=adminHidden[t]??=new Set();for(const f of fields){const label=make('label',undefined,'check'),c=make('input');c.type='checkbox';c.checked=!hidden.has(f);c.onchange=()=>{c.checked?hidden.delete(f):hidden.add(f);paint();};label.append(c,document.createTextNode(labels[f]||f));columns.append(label);}
 const add=make('button','＋ إضافة سجل');add.disabled=!catalog.recordSchema;add.onclick=()=>openAdminRecord(t,null,'create');tools.append(add);
 const reset=make('button','مسح الفلاتر','quiet');reset.onclick=()=>adminOpen(t);const exportButton=make('button','تصدير CSV');tools.append(search,owner,date,columns,reset,exportButton);root.append(tools);const summary=make('p'),tableSlot=make('div');root.append(summary,tableSlot);
 function selected(){let rows=records.map(r=>r.values).filter(r=>(!adminQuery||Object.values(r).some(v=>String(v).toLowerCase().includes(adminQuery.toLowerCase())))&&(!adminOwner||[r.beneficiary,r.beneficiaryName,r.name].some(v=>String(v||'').trim()===adminOwner))&&(!adminDate||r.date===adminDate));if(adminSort)rows.sort((a,b)=>{const x=a[adminSort],y=b[adminSort];return(typeof x==='number'&&typeof y==='number'?x-y:String(x??'').localeCompare(String(y??''),'ar',{numeric:true}))*(adminAscending?1:-1);});return rows;}
 function paint(){const rows=selected();summary.textContent=rows.length+' من '+records.length+' سجل'+(t==='campaigns'?' • الأرباح '+money(adminStats(rows,0).earnings)+' • الصافي '+money(adminStats(rows,0).netProfit):'');tableSlot.replaceChildren(adminTable(fields.filter(f=>!hidden.has(f)),rows,true));}
 search.oninput=()=>{adminQuery=search.value;paint();};owner.onchange=()=>{adminOwner=owner.value;paint();};date.onchange=()=>{adminDate=date.value;paint();};exportButton.onclick=()=>{const shown=fields.filter(f=>!hidden.has(f)),cell=v=>'"'+String(v??'').replace(/^[=+@-]/,"'$&").replaceAll('"','""')+'"';const lines=[shown.map(f=>labels[f]||f),...selected().map(r=>shown.map(f=>r[f]))];const u=URL.createObjectURL(new Blob(['\uFEFF'+lines.map(r=>r.map(cell).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}));const a=make('a');a.href=u;a.download=t+'.csv';a.click();URL.revokeObjectURL(u);};paint();
}


function openAdminRecord(table,record,action){
 const revision=catalog.revision,defs=catalog.recordSchema?.[table];if(!defs){$('#notice').textContent='حدّث الصفحة لتحميل أدوات التحرير.';return;}
 const dialog=make('dialog',undefined,'admin-record-dialog'),form=make('form'),title=make('h2',(action==='create'?'إضافة':action==='delete'?'حذف':'تعديل')+' • '+catalog.tables[table].label),error=make('p');error.setAttribute('role','alert');const inputs={};form.append(title);
 if(action==='delete')form.append(make('p','هل تريد حذف هذا السجل؟ سيُحذف من البيانات المتزامنة ويصل الحذف إلى التطبيق والمستفيدين.'));
 else{form.append(make('p','تصل التغييرات المحفوظة إلى التطبيق والمستفيدين حسب صلاحياتهم. المعرفات المرتبطة بالسجلات ثابتة عند التعديل.'));const grid=make('div',undefined,'record-editor-grid');
 for(const def of defs){const label=make('label',labels[def.key]||def.key),input=def.key==='beneficiary'?make('select'):make('input');
 if(def.key==='beneficiary'){input.append(new Option('اختر المستفيد',''),...catalog.beneficiaries.map(b=>new Option(b.name,b.name)));input.required=true;}else if(def.type==='boolean')input.type='checkbox';else if(def.type==='number'){input.type='number';input.step=['id','seq','clicks','orderedItems','shippedItems','returnedItems','port','stepNumber'].includes(def.key)?'1':'any';if(['cost','capital','baseCapital','clicks','orderedItems','shippedItems','returnedItems','port'].includes(def.key))input.min='0';}else if(def.type==='date')input.type='date';
 input.disabled=action==='create'?def.auto:def.locked;input.required=!input.disabled&&(def.locked||table==='campaigns'&&['date','product','accountCode'].includes(def.key)||table==='beneficiaries'&&def.key==='name');
 if(def.type==='boolean')input.checked=record?.values[def.key]??false;else input.value=record?.values[def.key]??(def.type==='number'?0:'');
 input.setAttribute('aria-label',labels[def.key]||def.key);inputs[def.key]={def,input};label.append(input);grid.append(label);}form.append(grid);}
 const actions=make('div',undefined,'dialog-actions'),save=make('button',action==='delete'?'تأكيد الحذف':'حفظ ومزامنة'),cancel=make('button','إلغاء','quiet');cancel.type='button';cancel.onclick=()=>dialog.close();actions.append(save,cancel);form.append(error,actions);dialog.append(form);document.body.append(dialog);dialog.addEventListener('close',()=>dialog.remove());
 form.onsubmit=async e=>{e.preventDefault();save.disabled=true;cancel.disabled=true;const values={};for(const [key,{def,input}]of Object.entries(inputs))if(!input.disabled)values[key]=def.type==='boolean'?input.checked:def.type==='number'?Number(input.value):input.value.trim();try{await api('/admin/records','POST',{table,action,rowId:record?.rowId,values,expectedRevision:revision});dialog.close();await loadAdmin();$('#notice').textContent='تم حفظ التغيير ومزامنته. يظهر للمستفيدين حسب صلاحياتهم.';}catch(e){error.textContent=message(e);if(e.code==='REVISION_CONFLICT')error.textContent+=' أغلق النافذة وحدّث البيانات ثم راجع التغيير قبل حفظه مجددًا.';}finally{save.disabled=false;cancel.disabled=false;}};
 dialog.showModal();
}
try{config=await(await fetch('firebase-config.json',{cache:'no-store'})).json();if(!config.apiKey)$('#login-error').textContent=errorMessages.CONFIGURATION_REQUIRED;else if(sessionStorage.getItem('erp-refresh'))await enter();}catch(e){logout(message(e));}
