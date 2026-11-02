// One-time setup of the application administrator using Google ADC credentials.
// This modifies only the members document in the dedicated erp-portal database.
'use strict';
const {initializeApp,applicationDefault}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');const {getFirestore}=require('firebase-admin/firestore');
async function main(){
 const [project,uid]=process.argv.slice(2);
 if(!project||!uid)throw Error('Usage: node firebase_portal/functions/bootstrap-admin.cjs PROJECT FIREBASE_AUTH_UID');
 if(process.env.FIRESTORE_EMULATOR_HOST||process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('Unset emulator variables before production bootstrap.');
 initializeApp({projectId:project,credential:applicationDefault()});
 const user=await getAuth().getUser(uid),ref=getFirestore('erp-portal').doc('members/'+uid);
 if(user.disabled)throw Error('The Firebase Auth user is disabled.');
 const old=await ref.get();if(old.exists)throw Error('Member already exists; refusing to overwrite an existing role.');
 await ref.create({role:'admin',enabled:true,email:user.email||'',displayName:user.displayName||'مدير النظام',policyRevision:1});
 console.log('ERP administrator configured. No other Firebase application data was modified.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
