'use strict';
// Run only against the demo Firebase emulators. Never reads production credentials.
process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099';
const {initializeApp}=require('firebase-admin/app');const {getFirestore}=require('firebase-admin/firestore');const {getAuth}=require('firebase-admin/auth');const assert=require('node:assert/strict');const P=require('../policy');
initializeApp({projectId:'demo-erp-portal'});const db=getFirestore('erp-portal');const base='http://127.0.0.1:5001/demo-erp-portal/us-central1/erpPortalApi';
async function login(email,password){const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});const d=await r.json();assert(r.ok,JSON.stringify(d));return d.idToken;}
async function api(token,path,method='GET',body){const r=await fetch(base+path,{method,headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});return {status:r.status,data:await r.json()};}
async function nextEvent(reader,kind,predicate=()=>true){const decoder=new TextDecoder();let buffer='';const timeout=setTimeout(()=>reader.cancel(),15000);try{while(true){const {value,done}=await reader.read();if(done)throw Error('event stream ended before '+kind);buffer+=decoder.decode(value,{stream:true});let index;while((index=buffer.indexOf('\n\n'))>=0){const block=buffer.slice(0,index);buffer=buffer.slice(index+2);const line=block.split('\n').find(l=>l.startsWith('data: '));if(line){const event=JSON.parse(line.slice(6));if(event.kind===kind&&predicate(event.data))return event.data;}}}}finally{clearTimeout(timeout);}}
async function main(){
 const auth=getAuth();for(const [uid,email] of [['admin-test','admin@example.test'],['member-a','a@example.test'],['member-b','b@example.test']]){
  try{await auth.createUser({uid,email,password:'Demo-only-test-123!'});}catch(e){if(e.code!=='auth/uid-already-exists'&&e.code!=='auth/email-already-exists')throw e;}
 }
 await db.doc('members/admin-test').set({role:'admin',enabled:true,email:'admin@example.test',policyRevision:1});
 const admin=await login('admin@example.test','Demo-only-test-123!'),a=await login('a@example.test','Demo-only-test-123!'),b=await login('b@example.test','Demo-only-test-123!');
 const data={beneficiaries:[{id:1,name:'شامي',baseCapital:100},{id:2,name:'أبو مخلص',baseCapital:270}],campaigns:[{seq:1,date:'2026-11-02',beneficiary:'شامي',accountCode:'SH-01',product:'منتج المدير',cost:10,clicks:1,commission:999,bonus:0},{seq:2,date:'2026-11-02',beneficiary:'أبو مخلص',accountCode:'MK-01',product:'حملة أبو مخلص',cost:20,clicks:10,commission:35,bonus:5}],emails:[{email:'abu@example.test',status:'نشط',password:'DO_NOT_UPLOAD'}],products_catalog:[{id:1,beneficiary:'أبو مخلص',accountCode:'MK-01',email:'abu@example.test'}]};
 let state=(await api(admin,'/admin/state')).data;
 let published=await api(admin,'/admin/publish','POST',{expectedRevision:state.revision,data});assert.equal(published.status,200);
 for(const [uid,id] of [['member-a','1'],['member-b','2']])await db.doc('members/'+uid).set({role:'beneficiary',enabled:true,beneficiaryId:id,displayName:id==='1'?'شامي':'أبو مخلص',permissions:P.defaultPermissions(),policyRevision:1});
 assert.equal((await api(b,'/admin/state')).status,403);
 assert.equal((await fetch(base+'/view')).status,401);
 const view=(await api(b,'/view')).data;assert.equal(view.metrics.capital,270);assert.equal(view.metrics.netProfit,20);assert.equal(view.sections.campaigns.rows.length,1);assert(!JSON.stringify(view).includes('999'));assert(!JSON.stringify(view).includes('DO_NOT_UPLOAD'));
 const response=await fetch(base+'/events',{headers:{Authorization:'Bearer '+b}});const reader=response.body.getReader();await nextEvent(reader,'view');
 data.campaigns[1].commission=50;state=(await api(admin,'/admin/state')).data;await api(admin,'/admin/publish','POST',{expectedRevision:state.revision,data});const update=await nextEvent(reader,'view',v=>v.metrics.netProfit===35);assert.equal(update.metrics.earnings,55);
 const limited={metrics:['capital'],sections:{campaigns:{fields:['product','clicks'],editableFields:['clicks']}},export:false};
 await api(admin,'/admin/users/member-b','PATCH',{permissions:limited});const limitedView=await nextEvent(reader,'view',v=>Object.keys(v.metrics).length===1);assert(!Object.hasOwn(limitedView.sections.campaigns.rows[0].values,'commission'));
 const row=limitedView.sections.campaigns.rows[0];assert.equal((await api(b,'/records/campaigns/'+row.rowId,'PATCH',{expectedRevision:limitedView.revision,changes:{commission:999}})).status,403);
 const ownUpdate=await api(b,'/records/campaigns/'+row.rowId,'PATCH',{expectedRevision:limitedView.revision,changes:{clicks:12}});assert.equal(ownUpdate.status,200);
 assert.equal((await api(admin,'/admin/publish','POST',{expectedRevision:limitedView.revision,data})).status,409);
 const other=(await api(a,'/view')).data.sections.campaigns.rows[0].rowId;assert.equal((await api(b,'/records/campaigns/'+other,'PATCH',{expectedRevision:ownUpdate.data.revision,changes:{clicks:88}})).status,403);
 await api(admin,'/admin/users/member-b','PATCH',{enabled:false});await nextEvent(reader,'revoked');assert.equal((await api(b,'/view')).status,403);await reader.cancel();
 // Password changes are admin-only and restricted to beneficiary members.
 const created=await api(admin,'/admin/users','POST',{email:'new-'+Date.now()+'@example.test',password:'Initial-test-password-123!',displayName:'test',beneficiaryId:'2',enabled:false});assert.equal(created.status,201);assert.equal(created.data.enabled,false);
 const target=created.data.uid;
 assert.equal((await api(admin,'/admin/users/'+target+'/password','POST',{password:'short'})).data.error,'INVALID_PASSWORD');
 assert.equal((await api(admin,'/admin/users/admin-test/password','POST',{password:'New-test-password-123!'})).status,404);
 assert.equal((await api(a,'/admin/users/'+target+'/password','POST',{password:'New-test-password-123!'})).status,403);
 await api(admin,'/admin/users/'+target,'PATCH',{enabled:true});
 const oldLogin=await login(created.data.email,'Initial-test-password-123!');assert.equal((await api(oldLogin,'/view')).status,200);
 await new Promise(r=>setTimeout(r,1100));
 assert.equal((await api(admin,'/admin/users/'+target+'/password','POST',{password:'New-test-password-123!'})).status,200);
 assert.equal((await api(oldLogin,'/view')).status,401);
 await assert.rejects(()=>login(created.data.email,'Initial-test-password-123!'));
 const newLogin=await login(created.data.email,'New-test-password-123!');assert.equal((await api(newLogin,'/view')).status,200);
 // Direct database reads cannot bypass the API's field projection.
 const direct=await fetch('http://127.0.0.1:8080/v1/projects/demo-erp-portal/databases/erp-portal/documents/workspaces/main',{headers:{Authorization:'Bearer '+b}});assert.equal(direct.status,403);
 console.log('PASS: Auth, owner isolation, hidden fields, live publish, permission changes, edits, conflicts, revocation and direct database denial.');
}
main().then(()=>process.exit(0)).catch(e=>{console.error(e.message);process.exit(1);});
