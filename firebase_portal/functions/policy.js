'use strict';
const {createHash} = require('node:crypto');
const tables = {
 beneficiaries:{label:'المستفيدون',keys:['id','name','baseCapital','accountCodeRange']},
 products_catalog:{label:'المنتجات',keys:['id','product','beneficiary','accountCode','profile','capital','email']},
 campaigns:{label:'الحملات والأرباح',keys:['seq','date','beneficiary','accountCode','product','profile','email','cost','clicks','orderedItems','orderedRevenue','shippedItems','returnedItems','totalRevenue','commission','bonus','isPending','totalEarnings','netProfit','roi','conversionRate']},
 amazon_accounts:{label:'حسابات أمازون',keys:['beneficiary','code','name','storeId','country','status','product1','promoStatus1','product2','promoStatus2','email']},
 historical_links:{label:'روابط الأرشيف',keys:['beneficiary','accountName','product','linkType','url']},
 emails:{label:'الإيميلات',keys:['email','gologin','status','country','phone']},
 gologin:{label:'بروفايلات جو لوجن',keys:['email','platform','profile1','profile2','profile3','country']},
 proxies:{label:'البروكسي',keys:['country','isUsed','portType','protocol','host','port']},
 bank_accounts:{label:'الحسابات البنكية',keys:['beneficiaryName','bankName','status','amazonEmail','amazonAccountName']},
 platforms:{label:'المنصات',keys:['category','name']},
 promo_times:{label:'أوقات الترويج',keys:['windowName','syriaTime','usTime']},
 workflow_steps:{label:'خطوات العمل',keys:['stepNumber','title','details','stage','isCompleted']},
};
const identities={beneficiaries:['id'],products_catalog:['id'],campaigns:['seq'],amazon_accounts:['code'],historical_links:['beneficiary','accountName','product','linkType','url'],emails:['email'],gologin:['email','platform'],proxies:['host','port'],bank_accounts:['amazonEmail','bankName','beneficiaryName'],platforms:['category','name'],promo_times:['windowName'],workflow_steps:['stepNumber']};
const computed=new Set(['totalEarnings','netProfit','roi','conversionRate']);
const immutable=new Set([...computed,'id','seq','beneficiary','accountCode','code','email','profile','profile1','profile2','profile3','storeId','amazonEmail','amazonAccountName','name','beneficiaryName','host','port','stepNumber','category','platform','windowName','accountName','product','linkType','url']);
const metrics={capital:'رأس المال',spend:'المصروف',earnings:'الأرباح',netProfit:'صافي الأرباح',remainingCapital:'المتبقي من رأس المال',roi:'نسبة العائد'};
function displayRow(t,r){if(t!=='campaigns')return r;const cost=Number(r.cost)||0,earnings=r.isPending?0:(Number(r.commission)||0)+(Number(r.bonus)||0),netProfit=r.isPending?0:earnings-cost;return {...r,totalEarnings:earnings,netProfit,roi:r.isPending?null:cost>0?netProfit/cost:0,conversionRate:Number(r.clicks)>0?(Number(r.orderedItems)||0)/Number(r.clicks):0};}
const norm=v=>String(v??'').normalize('NFKC').trim().replace(/\s+/g,' ').toLowerCase();
const rows=(data,t)=>Array.isArray(data[t])?data[t]:[];
const rowId=(t,row)=>createHash('sha256').update(JSON.stringify([t,...(['campaigns','proxies','bank_accounts'].includes(t)&&row._portalRecordId?[row._portalRecordId]:identities[t].map(k=>row[k]??''))])).digest('hex').slice(0,32);
function sanitizeData(input){
 const out={};
 for(const [t,def] of Object.entries(tables)) out[t]=rows(input,t).map(row=>Object.fromEntries(def.keys.filter(k=>!computed.has(k)&&Object.hasOwn(row,k)).map(k=>[k,row[k]])));
 for(const t of ['campaigns','proxies','bank_accounts'])out[t].forEach((row,i)=>{const id=rows(input,t)[i]._portalRecordId;if(id!==undefined){if(!/^[a-f0-9]{64}$/.test(id))throw new Error('INVALID_RECORD_ID');row._portalRecordId=id;}});
 return out;
}
function validateData(input){
 if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('INVALID_DATA');
 const safe=sanitizeData(input);
 for(const [t,rs] of Object.entries(safe)){
  const used=new Set();
  for(const r of rs){
   if(!r||typeof r!=='object'||Array.isArray(r))throw new Error('INVALID_RECORD');
   const id=rowId(t,r);if(used.has(id))throw new Error('DUPLICATE_RECORD:'+t);used.add(id);
   for(const value of Object.values(r))if(value!==null&&!['string','number','boolean'].includes(typeof value))throw new Error('INVALID_FIELD');
  }
 }
 const names=safe.beneficiaries.map(r=>norm(r.name));
 if(names.some(n=>!n)||new Set(names).size!==names.length)throw new Error('DUPLICATE_BENEFICIARY');
 return safe;
}
function defaultPermissions(){return {metrics:Object.keys(metrics),export:false,sections:Object.fromEntries(['campaigns','products_catalog','amazon_accounts','emails'].map(t=>[t,{fields:tables[t].keys.filter(k=>!['id','seq','beneficiary'].includes(k)),editableFields:[]}]))};}
function normalizePermissions(p){
 const sections={};
 for(const [t,section] of Object.entries(p?.sections??{})){
  if(!tables[t])continue;
  const fields=[...new Set((section.fields??[]).filter(k=>tables[t].keys.includes(k)))];
  const editableFields=[...new Set((section.editableFields??[]).filter(k=>fields.includes(k)&&!immutable.has(k)))];
  if(fields.length)sections[t]={fields,editableFields};
 }
 return {sections,metrics:[...new Set((p?.metrics??[]).filter(k=>Object.hasOwn(metrics,k)))],export:p?.export===true};
}
function ownership(data,assignments={}){
 const bs=rows(data,'beneficiaries');
 const byName=new Map(bs.map(b=>[norm(b.name),String(b.id)]));
 const codeOwners=new Map(),emailOwners=new Map(),profileOwners=new Map();
 const add=(map,key,owner)=>{key=norm(key);if(!key||!owner)return;if(!map.has(key))map.set(key,new Set());map.get(key).add(owner);};
 const explicit=r=>byName.get(norm(r.beneficiary));
 for(const t of ['products_catalog','campaigns','amazon_accounts'])for(const r of rows(data,t)){
  const owner=explicit(r);add(codeOwners,r.accountCode??r.code,owner);
  add(emailOwners,r.email,owner);add(emailOwners,norm(r.email).split('@')[0],owner);
  add(profileOwners,r.profile??r.name,owner);
 }
 const unique=(map,key)=>{const set=map.get(norm(key));return set?.size===1?[...set][0]:undefined;};
 const mailOwner=email=>unique(emailOwners,email)??(!norm(email).includes('@')?unique(emailOwners,norm(email).split('@')[0]):undefined);
 return (t,r)=>{
  const assigned=assignments[t+':'+rowId(t,r)];
  if(assigned!==undefined)return bs.some(b=>String(b.id)===String(assigned))?String(assigned):undefined;
  if(t==='beneficiaries')return String(r.id);
  if(Object.hasOwn(r,'beneficiary'))return explicit(r);
  if(t==='emails')return mailOwner(r.email);
  if(t==='gologin'){
   const profiles=[r.profile1,r.profile2,r.profile3].filter(v=>norm(v));
   if(profiles.length){const owners=profiles.map(v=>unique(profileOwners,v));return owners.every(v=>v&&v===owners[0])?owners[0]:undefined;}
   return mailOwner(r.email);
  }
  if(t==='bank_accounts')return unique(profileOwners,r.amazonAccountName)??mailOwner(r.amazonEmail);
  return undefined;
 };
}
function project(data,access,assignments={}){
 if(!access?.enabled||access.role!=='beneficiary')throw new Error('ACCESS_DENIED');
 const beneficiary=rows(data,'beneficiaries').find(b=>String(b.id)===String(access.beneficiaryId));
 if(!beneficiary)throw new Error('BENEFICIARY_NOT_FOUND');
 const own=ownership(data,assignments);const id=String(beneficiary.id),permissions=normalizePermissions(access.permissions);
 const sections={};
 for(const [t,p] of Object.entries(permissions.sections))sections[t]={label:tables[t].label,fields:p.fields,editableFields:p.editableFields,rows:rows(data,t).filter(r=>own(t,r)===id).map(r=>({rowId:rowId(t,r),values:Object.fromEntries(p.fields.map(k=>[k,displayRow(t,r)[k]??'']))}))};
 const cs=rows(data,'campaigns').filter(r=>own('campaigns',r)===id);
 const sum=k=>cs.reduce((s,r)=>s+(Number(r[k])||0),0);
 const capital=Number(beneficiary.baseCapital)||0,spend=sum('cost'),earnings=cs.reduce((s,r)=>s+displayRow('campaigns',r).totalEarnings,0),netProfit=cs.reduce((s,r)=>s+displayRow('campaigns',r).netProfit,0);
 const values={capital,spend,earnings,netProfit,remainingCapital:capital-spend,roi:spend>0?netProfit/spend:0};
 return {displayName:access.displayName||beneficiary.name,beneficiaryName:beneficiary.name,metrics:Object.fromEntries(permissions.metrics.map(k=>[k,values[k]])),sections,canExport:permissions.export};
}
function applyEdit(data,access,assignments,t,id,changes){
 const view=project(data,access,assignments),section=view.sections[t];
 if(!section||!section.rows.some(r=>r.rowId===id))throw new Error('ACCESS_DENIED');
 const keys=Object.keys(changes??{});
 if(!keys.length||keys.some(k=>!section.editableFields.includes(k)))throw new Error('FIELD_DENIED');
 const out=structuredClone(data),r=out[t].find(r=>rowId(t,r)===id);
 for(const k of keys){
  const v=changes[k];if(typeof v!==typeof r[k]||typeof v==='number'&&(!Number.isFinite(v)||(['cost','capital','baseCapital','clicks','orderedItems','shippedItems','returnedItems'].includes(k)&&v<0)||(['clicks','orderedItems','shippedItems','returnedItems'].includes(k)&&!Number.isSafeInteger(v)))||typeof v==='string'&&v.length>3000)throw new Error('INVALID_VALUE');
  if(k==='date'&&(!/^\d{4}-\d{2}-\d{2}$/.test(v)||!Number.isFinite(Date.parse(v))||new Date(v).toISOString().slice(0,10)!==v))throw new Error('INVALID_VALUE');
  r[k]=v;
 }
 return out;
}
module.exports={tables,metrics,identities,immutable,norm,rowId,rows,sanitizeData,validateData,defaultPermissions,normalizePermissions,ownership,project,applyEdit};
