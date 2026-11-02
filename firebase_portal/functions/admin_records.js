'use strict';
const {randomBytes}=require('node:crypto'),P=require('./policy');
const numbers=new Set(['id','seq','baseCapital','capital','cost','clicks','orderedItems','orderedRevenue','shippedItems','returnedItems','totalRevenue','commission','bonus','port','stepNumber']);
const integers=new Set(['id','seq','clicks','orderedItems','shippedItems','returnedItems','port','stepNumber']);
const booleans=new Set(['isPending','isUsed','isCompleted']);
const computed=new Set(['totalEarnings','netProfit','roi','conversionRate']);
const opaque=new Set(['campaigns','proxies','bank_accounts']);
function schema(){return Object.fromEntries(Object.entries(P.tables).map(([t,d])=>[t,d.keys.filter(k=>!computed.has(k)).map(key=>({key,type:booleans.has(key)?'boolean':numbers.has(key)?'number':key==='date'?'date':'string',locked:!opaque.has(t)&&(P.identities[t]||[]).includes(key),auto:['id','seq'].includes(key)}))]));}
function mutate(data,{table,action,rowId,values}){
 if(!P.tables[table]||!['create','update','delete'].includes(action))throw Error('INVALID_VALUE');
 const out=structuredClone(data);out[table]??=[];const rs=out[table];const i=action==='create'?-1:rs.findIndex(r=>P.rowId(table,r)===rowId);if(action!=='create'&&i<0)throw Error('RECORD_NOT_FOUND');
 if(action==='delete'){
  if(table==='beneficiaries'&&Object.entries(out).some(([t,rows])=>t!=='beneficiaries'&&rows.some(r=>P.norm(r.beneficiary)===P.norm(rs[i].name)||P.norm(r.beneficiaryName)===P.norm(rs[i].name))))throw Error('RECORD_IN_USE');
  rs.splice(i,1);return P.validateData(out);
 }
 if(!values||typeof values!=='object'||Array.isArray(values))throw Error('INVALID_VALUE');
 const defs=schema()[table],allowed=defs.map(f=>f.key);if(Object.keys(values).some(k=>!allowed.includes(k)))throw Error('FIELD_DENIED');
 const row=action==='create'?Object.fromEntries(defs.map(f=>[f.key,f.type==='boolean'?false:f.type==='number'?0:''])):{...rs[i]};
 for(const [k,v]of Object.entries(values)){
  const f=defs.find(f=>f.key===k);if(action==='update'&&f.locked&&v!==row[k])throw Error('IDENTITY_LOCKED');
  if(typeof v!==(f.type==='date'?'string':f.type==='string'?'string':f.type)||typeof v==='string'&&v.length>3000||typeof v==='number'&&(!Number.isFinite(v)||integers.has(k)&&!Number.isSafeInteger(v)))throw Error('INVALID_VALUE');
  if(['cost','capital','baseCapital','clicks','orderedItems','shippedItems','returnedItems','port'].includes(k)&&v<0)throw Error('INVALID_VALUE');
  if(k==='date'&&(!/^\d{4}-\d{2}-\d{2}$/.test(v)||!Number.isFinite(Date.parse(v))||new Date(v).toISOString().slice(0,10)!==v))throw Error('INVALID_VALUE');
  row[k]=v;
 }
 if(action==='create'){
  for(const key of ['id','seq'])if(allowed.includes(key))row[key]=Math.max(0,...rs.map(r=>Number(r[key])||0))+1;
  if(opaque.has(table))row._portalRecordId=randomBytes(32).toString('hex');
  for(const k of P.identities[table]||[])if(!opaque.has(table)&&String(row[k]??'').trim()==='')throw Error('INVALID_VALUE');
 }
 if(['campaigns','products_catalog','amazon_accounts','historical_links'].includes(table)&&!out.beneficiaries.some(b=>P.norm(b.name)===P.norm(row.beneficiary)))throw Error('INVALID_BENEFICIARY');
 if(table==='proxies'&&(!String(row.host).trim()||row.port<1||row.port>65535))throw Error('INVALID_VALUE');
 if(table==='bank_accounts'&&(!row.bankName||!row.beneficiaryName))throw Error('INVALID_VALUE');
 if(table==='emails'&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(row.email))throw Error('INVALID_VALUE');
 if(table==='campaigns'&&(!row.date||!row.accountCode||!row.product))throw Error('INVALID_VALUE');
 if(table==='beneficiaries'&&action==='update'&&row.name!==rs[i].name){const old=rs[i].name;for(const [t,rows]of Object.entries(out))if(t!=='beneficiaries')for(const r of rows){if(r.beneficiary===old)r.beneficiary=row.name;if(r.beneficiaryName===old)r.beneficiaryName=row.name;}}
 if(action==='create')rs.push(row);else rs[i]=row;
 return P.validateData(out);
}
module.exports={schema,mutate};
