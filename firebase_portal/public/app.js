const $=s=>document.querySelector(s),make=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;};
const labels={id:'المعرف',seq:'التسلسل',name:'الاسم',date:'التاريخ',beneficiary:'المستفيد',accountCode:'رمز الحساب',code:'رمز الحساب',product:'المنتج',profile:'البروفايل',email:'الإيميل',totalEarnings:'إجمالي الأرباح',netProfit:'صافي الربح',roi:'العائد ROI',conversionRate:'نسبة التحويل',baseCapital:'رأس المال',capital:'رأس المال',cost:'التكلفة',clicks:'النقرات',orderedItems:'الطلبات',orderedRevenue:'قيمة الطلبات',shippedItems:'المشحون',returnedItems:'المرتجع',totalRevenue:'إجمالي المبيعات',commission:'العمولة',bonus:'المكافآت',isPending:'قيد التشغيل',storeId:'Store ID',country:'الدولة',status:'الحالة',product1:'المنتج الأول',promoStatus1:'حالة الترويج الأول',product2:'المنتج الثاني',promoStatus2:'حالة الترويج الثاني',gologin:'جو لوجن',phone:'الهاتف',platform:'المنصة',profile1:'البروفايل الأول',profile2:'البروفايل الثاني',profile3:'البروفايل الثالث',host:'الخادم',port:'المنفذ',protocol:'البروتوكول',isUsed:'مستخدم',portType:'نوع المنفذ',bankName:'البنك',beneficiaryName:'صاحب الحساب',amazonEmail:'إيميل أمازون',amazonAccountName:'اسم حساب أمازون',category:'الفئة',accountName:'الحساب',linkType:'نوع الرابط',url:'الرابط',windowName:'الفترة',syriaTime:'توقيت سوريا',usTime:'توقيت أمريكا',stepNumber:'الخطوة',title:'العنوان',details:'التفاصيل',stage:'المرحلة',isCompleted:'مكتملة'};
const metricLabels={capital:'رأس المال',spend:'المصروف',earnings:'الأرباح',netProfit:'صافي الأرباح',remainingCapital:'رأس المال المتبقي',roi:'العائد ROI'};
const errorMessages={ACCESS_DENIED:'الوصول إلى هذا الحساب موقوف. تواصل مع المدير.',SIGN_IN_REQUIRED:'انتهت الجلسة. سجّل الدخول مجددًا.',ADMIN_REQUIRED:'هذه العملية متاحة للمدير فقط.',REVISION_CONFLICT:'تغيرت البيانات أثناء التعديل. تم تحديث العرض؛ راجعها ثم أعد المحاولة.',FIELD_DENIED:'لم تعد لديك صلاحية لتعديل هذه الحقول.',BENEFICIARY_NOT_FOUND:'لم تُرفع بيانات المستفيد بعد. تواصل مع المدير.',EMAIL_ALREADY_EXISTS:'البريد مستخدم في Firebase. أدخل UID لربط الحساب الموجود بدل إنشاء حساب جديد.',MEMBER_EXISTS:'المستخدم مضاف مسبقًا.',REQUEST_FAILED:'تعذر إتمام الطلب. تحقق من المدخلات والصلاحيات.',INVALID_BENEFICIARY:'اختر مستفيدًا موجودًا في البيانات المنشورة.',CONFIGURATION_REQUIRED:'لم يتم ضبط إعدادات Firebase بعد.'};
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
function clearData(){if($('#edit-dialog').open)$('#edit-dialog').close();$('#edit-fields').replaceChildren();editRow=null;view=null;$('#metrics').replaceChildren();$('#table-head').replaceChildren();$('#table-body').replaceChildren();$('#members').replaceChildren();}
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
 fillAssignments();$('#last-update').textContent=new Date().toLocaleString('ar');
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
try{config=await(await fetch('firebase-config.json',{cache:'no-store'})).json();if(!config.apiKey)$('#login-error').textContent=errorMessages.CONFIGURATION_REQUIRED;else if(sessionStorage.getItem('erp-refresh'))await enter();}catch(e){logout(message(e));}
