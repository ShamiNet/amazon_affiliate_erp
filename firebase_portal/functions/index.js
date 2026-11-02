'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore,FieldValue} = require('firebase-admin/firestore');
const {onRequest} = require('firebase-functions/v2/https');
const {createHash,randomUUID} = require('node:crypto');
const P=require('./policy');
initializeApp();
const db=getFirestore(process.env.ERP_DATABASE_ID||'erp-portal');
const root=db.doc('workspaces/main'),members=db.collection('members');
const fail=(code,status=400)=>Object.assign(new Error(code),{status});
async function access(req){
 const bearer=/^Bearer (\S+)$/.exec(req.headers.authorization||'');if(!bearer)throw fail('SIGN_IN_REQUIRED',401);
 let token;try{token=await getAuth().verifyIdToken(bearer[1],true);}catch{throw fail('SIGN_IN_REQUIRED',401);}
 const doc=await members.doc(token.uid).get(),profile=doc.data();
 if(!profile?.enabled)throw fail('ACCESS_DENIED',403);
 return {...profile,uid:token.uid,email:token.email||'',expires:token.exp*1000};
}
function admin(a){if(a.role!=='admin')throw fail('ADMIN_REQUIRED',403);}
async function state(){
 const meta=(await root.get()).data()||{revision:0};
 if(!meta.generation)return {data:{},meta};
 const docs=await root.collection('snapshots').doc(meta.generation).collection('chunks').orderBy('index').get();
 const bytes=Buffer.concat(docs.docs.map(d=>Buffer.from(d.data().encoded,'base64')));
 if(createHash('sha256').update(bytes).digest('hex')!==meta.hash)throw fail('SNAPSHOT_INTEGRITY',503);
 return {data:JSON.parse(bytes.toString('utf8')),meta};
}
async function commit(data,expectedRevision,actor,policyRevision){
 const safe=P.validateData(data),bytes=Buffer.from(JSON.stringify(safe),'utf8');
 if(bytes.length>8000000)throw fail('DATA_TOO_LARGE',413);
 const generation=randomUUID();
 const parent=root.collection('snapshots').doc(generation);
 const chunks=[];
 for(let offset=0;offset<bytes.length;offset+=150000)chunks.push(bytes.subarray(offset,offset+150000));
 const batch=db.batch();
 batch.set(parent,{createdAt:FieldValue.serverTimestamp()});
 chunks.forEach((chunk,i)=>batch.set(parent.collection('chunks').doc(String(i).padStart(5,'0')),{index:i,encoded:chunk.toString('base64')}));
 await batch.commit();
 try{
  await db.runTransaction(async tx=>{
   const old=(await tx.get(root)).data()||{revision:0};
   const profile=(await tx.get(members.doc(actor))).data();
   if(!profile?.enabled||profile.policyRevision!==policyRevision)throw fail('ACCESS_DENIED',403);
   if(old.revision!==expectedRevision)throw fail('REVISION_CONFLICT',409);
   tx.set(root,{...old,generation,hash:createHash('sha256').update(bytes).digest('hex'),revision:old.revision+1,updatedAt:FieldValue.serverTimestamp(),updatedBy:actor});
  });
 }catch(e){await db.recursiveDelete(parent);throw e;}
 return expectedRevision+1;
}
function publicAccess(a){return {uid:a.uid,email:a.email,displayName:a.displayName||'',role:a.role,enabled:a.enabled,beneficiaryId:a.beneficiaryId??null,permissions:P.normalizePermissions(a.permissions),policyRevision:a.policyRevision||0};}
async function viewFor(a){const s=await state();return {revision:s.meta.revision||0,policyRevision:a.policyRevision||0,...P.project(s.data,a,s.meta.assignments||{})};}
async function stream(req,res,a){
 res.status(200).set({'Content-Type':'text/event-stream','Cache-Control':'no-store','X-Accel-Buffering':'no','Connection':'keep-alive'});res.flushHeaders();
 let closed=false,running=false,rerun=false,last='';
 const send=(kind,data)=>{if(!closed)res.write('data: '+JSON.stringify({kind,data})+'\n\n');};
 const close=()=>{if(closed)return;closed=true;clearInterval(heartbeat);clearInterval(recheck);clearTimeout(expiry);unsubscribeMeta();unsubscribeUser();res.end();};
 const update=async()=>{
  if(closed)return;if(running){rerun=true;return;}running=true;
  try{
   const profile=(await members.doc(a.uid).get()).data();
   if(!profile?.enabled||profile.role!==a.role){send('revoked',{});close();return;}
   const current={...profile,uid:a.uid,email:a.email};
   const meta=(await root.get()).data()||{revision:0};
   const version=[meta.revision||0,profile.policyRevision||0].join(':');
   if(version!==last){
    if(a.role==='admin')send('revision',{revision:meta.revision||0});
    else {
     const projected=await viewFor(current);
     const [latestProfile,latestMeta]=await Promise.all([members.doc(a.uid).get(),root.get()]);
     if(!latestProfile.data()?.enabled||latestProfile.data()?.policyRevision!==current.policyRevision||latestMeta.data()?.revision!==projected.revision){rerun=true;return;}
     send('view',projected);
    }
    last=version;
   }
  }catch{send('error',{code:'SYNC_UNAVAILABLE'});}
  finally{running=false;if(rerun){rerun=false;void update();}}
 };
 const unsubscribeMeta=root.onSnapshot(update,()=>{send('error',{code:'SYNC_UNAVAILABLE'});close();});
 const unsubscribeUser=members.doc(a.uid).onSnapshot(()=>{if(a.role!=='admin')send('clear',{});void update();},()=>{send('revoked',{});close();});
 const heartbeat=setInterval(()=>{if(!closed)res.write(': heartbeat\n\n');},20000);
 const recheck=setInterval(async()=>{try{await getAuth().verifyIdToken(req.headers.authorization.slice(7),true);}catch{send('revoked',{});close();}},60000);
 const expiry=setTimeout(close,Math.max(1000,Math.min(25*60000,a.expires-Date.now())));
 res.on('close',close);
 await update();
}
exports.erpPortalApi=onRequest({region:'us-central1',timeoutSeconds:1800,memory:'512MiB',maxInstances:10,cors:false},async(req,res)=>{
 res.set({'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});
 const origin=req.headers.origin,allowed=process.env.ERP_ALLOWED_ORIGINS?.split(',')||[];
 // Hosting rewrites use the same origin; the direct endpoint only allows configured sites.
 if(origin){
  const project=process.env.GCLOUD_PROJECT||process.env.GCP_PROJECT;
  const defaults=[`https://${project}.web.app`,`https://${project}.firebaseapp.com`];
  if(![...allowed,...defaults].includes(origin)&&!(process.env.FUNCTIONS_EMULATOR==='true'&&/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)))return res.status(403).json({error:'ORIGIN_DENIED'});
  res.set('Access-Control-Allow-Origin',origin).set('Vary','Origin').set('Access-Control-Allow-Headers','Authorization, Content-Type').set('Access-Control-Allow-Methods','GET, POST, PATCH, OPTIONS');
 }
 if(req.method==='OPTIONS')return res.status(204).end();
 try{
  if((req.rawBody?.length||0)>9000000)throw fail('DATA_TOO_LARGE',413);
  const a=await access(req),path=req.path.replace(/^\/api/,'').replace(/\/$/,'')||'/',body=req.body||{};
  if(req.method==='GET'&&path==='/access')return res.json(publicAccess(a));
  if(req.method==='GET'&&path==='/events')return await stream(req,res,a);
  if(req.method==='GET'&&path==='/view'){if(a.role!=='beneficiary')throw fail('BENEFICIARY_REQUIRED',403);return res.json(await viewFor(a));}
  if(req.method==='PATCH'&&path.startsWith('/records/')){
   if(a.role!=='beneficiary')throw fail('BENEFICIARY_REQUIRED',403);
   const [, ,table,id]=path.split('/'),s=await state();
   if(body.expectedRevision!==s.meta.revision)throw fail('REVISION_CONFLICT',409);
   const edited=P.applyEdit(s.data,a,s.meta.assignments||{},table,id,body.changes);
   return res.json({revision:await commit(edited,s.meta.revision,a.uid,a.policyRevision)});
  }
  admin(a);
  if(req.method==='GET'&&path==='/admin/state'){const s=await state();return res.json({data:s.data,revision:s.meta.revision||0,assignments:s.meta.assignments||{}});}
  if(req.method==='POST'&&path==='/admin/publish'){
   if(!Number.isSafeInteger(body.expectedRevision)||body.expectedRevision<0)throw fail('INVALID_REVISION');
   return res.json({revision:await commit(body.data,body.expectedRevision,a.uid,a.policyRevision)});
  }
  if(req.method==='GET'&&path==='/admin/catalog'){
   const s=await state();return res.json({tables:P.tables,metrics:P.metrics,defaultPermissions:P.defaultPermissions(),beneficiaries:P.rows(s.data,'beneficiaries'),assignments:s.meta.assignments||{},records:Object.fromEntries(Object.entries(s.data).map(([t,rows])=>[t,rows.map(r=>({rowId:P.rowId(t,r),values:r}))]))});
  }
  if(req.method==='GET'&&path==='/admin/users')return res.json({users:(await members.get()).docs.map(d=>({uid:d.id,...d.data()}))});
  if(req.method==='POST'&&/^\/admin\/users\/[^/]+\/password$/.test(path)){
   const uid=path.split('/')[3],ref=members.doc(uid),member=(await ref.get()).data();
   if(!member||member.role!=='beneficiary')throw fail('MEMBER_NOT_FOUND',404);
   if(typeof body.password!=='string'||body.password.length<12||body.password.length>128)throw fail('INVALID_PASSWORD');
   await getAuth().updateUser(uid,{password:body.password});
   await getAuth().revokeRefreshTokens(uid);
   await ref.update({policyRevision:(member.policyRevision||0)+1});
   return res.json({ok:true});
  }
  if(req.method==='POST'&&path==='/admin/users'){
   const s=await state();
   if(!P.rows(s.data,'beneficiaries').some(b=>String(b.id)===String(body.beneficiaryId)))throw fail('INVALID_BENEFICIARY');
   if(!body.uid&&String(body.password||'').length<12)throw fail('INVALID_PASSWORD');
   const user=body.uid?await getAuth().getUser(body.uid):await getAuth().createUser({email:String(body.email||'').trim(),password:String(body.password||''),displayName:String(body.displayName||'')});
   if((await members.doc(user.uid).get()).exists)throw fail('MEMBER_EXISTS',409);
   const member={email:user.email||'',role:'beneficiary',enabled:body.enabled!==false,beneficiaryId:String(body.beneficiaryId),displayName:String(body.displayName||''),permissions:P.normalizePermissions(body.permissions||P.defaultPermissions()),policyRevision:1};
   await members.doc(user.uid).create(member);
   return res.status(201).json({uid:user.uid,...member});
  }
  if(req.method==='PATCH'&&path.startsWith('/admin/users/')){
   const uid=path.split('/').pop(),ref=members.doc(uid),old=(await ref.get()).data();
   if(!old||old.role!=='beneficiary')throw fail('MEMBER_NOT_FOUND',404);
   const s=await state();
   const beneficiaryId=String(body.beneficiaryId??old.beneficiaryId);
   if(!P.rows(s.data,'beneficiaries').some(b=>String(b.id)===beneficiaryId))throw fail('INVALID_BENEFICIARY');
   const member={...old,enabled:body.enabled===undefined?old.enabled:body.enabled===true,beneficiaryId,displayName:String(body.displayName??old.displayName),permissions:P.normalizePermissions(body.permissions??old.permissions),policyRevision:(old.policyRevision||0)+1};
   await ref.set(member);return res.json({uid,...member});
  }
  if(req.method==='POST'&&path==='/admin/assign'){
   const s=await state(),{table,rowId,beneficiaryId}=body;
   if(!P.tables[table]||!P.rows(s.data,table).some(r=>P.rowId(table,r)===rowId))throw fail('RECORD_NOT_FOUND',404);
   if(beneficiaryId!==null&&!P.rows(s.data,'beneficiaries').some(b=>String(b.id)===String(beneficiaryId)))throw fail('INVALID_BENEFICIARY');
   await db.runTransaction(async tx=>{const meta=(await tx.get(root)).data()||{revision:0};const assignments={...meta.assignments};if(beneficiaryId===null)delete assignments[table+':'+rowId];else assignments[table+':'+rowId]=String(beneficiaryId);tx.set(root,{...meta,assignments,revision:meta.revision+1});});
   return res.json({ok:true});
  }
  throw fail('NOT_FOUND',404);
 }catch(e){
  const denied=['ACCESS_DENIED','FIELD_DENIED','ADMIN_REQUIRED','BENEFICIARY_REQUIRED'].includes(e.message);
  const status=e.status||(denied?403:400);
  const known=['SIGN_IN_REQUIRED','ACCESS_DENIED','ADMIN_REQUIRED','BENEFICIARY_REQUIRED','BENEFICIARY_NOT_FOUND','FIELD_DENIED','REVISION_CONFLICT','INVALID_VALUE','INVALID_REVISION','INVALID_PASSWORD','INVALID_BENEFICIARY','RECORD_NOT_FOUND','MEMBER_EXISTS','MEMBER_NOT_FOUND','NOT_FOUND','DATA_TOO_LARGE','SNAPSHOT_INTEGRITY'];
  const code=known.includes(e.message)?e.message:e.code==='auth/email-already-exists'?'EMAIL_ALREADY_EXISTS':'REQUEST_FAILED';
  if(res.headersSent){res.end();return;}
  res.status(status).json({error:code});
 }
});
