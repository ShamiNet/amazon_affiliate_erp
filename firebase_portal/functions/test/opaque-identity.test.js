const {test}=require('node:test');const assert=require('node:assert/strict');const P=require('../policy');
test('different proxy accounts on the same gateway keep independent opaque identities',()=>{
 const proxies=[{host:'gateway.example',port:8000,_portalRecordId:'a'.repeat(64)},{host:'gateway.example',port:8000,_portalRecordId:'b'.repeat(64)}];
 const data=P.validateData({beneficiaries:[{id:1,name:'A'}],proxies});
 assert.equal(data.proxies.length,2);assert.notEqual(P.rowId('proxies',proxies[0]),P.rowId('proxies',proxies[1]));
 const permissions={sections:{proxies:{fields:['host','port','_portalRecordId']}}};
 const assignments={['proxies:'+P.rowId('proxies',proxies[1])]:'1'};
 const view=P.project(data,{enabled:true,role:'beneficiary',beneficiaryId:'1',permissions},assignments);
 assert.equal(view.sections.proxies.rows.length,1);assert(!Object.hasOwn(view.sections.proxies.rows[0].values,'_portalRecordId'));
});
