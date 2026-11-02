// Usage: node firebase_portal/configure.mjs --project PROJECT --api-key PUBLIC_WEB_KEY --portal-url https://SITE.web.app
// Public Firebase Web configuration only. Never pass service-account keys here.
import fs from 'node:fs/promises';
const args=Object.fromEntries(process.argv.slice(2).reduce((a,v,i,all)=>{if(i%2===0)a.push([v.replace(/^--/,''),all[i+1]]);return a;},[]));
const project=args.project,key=args['api-key'],url=args['portal-url'];
if(!/^[a-z][a-z0-9-]{4,62}$/.test(project||'')||!key||!url)throw Error('Specify --project, --api-key and --portal-url.');
const parsed=new URL(url);if(parsed.protocol!=='https:'||!parsed.hostname.endsWith('.web.app'))throw Error('Use the Firebase Hosting .web.app URL for the dedicated portal site.');
const site=parsed.hostname.slice(0,-8);
const apiBase=`https://us-central1-${project}.cloudfunctions.net/erpPortalApi`;
const config={apiKey:key,projectId:project,apiBase:'/api',portalUrl:parsed.origin};
await fs.writeFile('firebase_portal/public/firebase-config.json',JSON.stringify(config,null,2)+'\n');
await fs.writeFile('lib/portal_config.dart',`// Public Firebase Web configuration; never store administrative secrets here.\nconst portalFirebaseApiKey = ${JSON.stringify(key)};\nconst portalProjectId = ${JSON.stringify(project)};\nconst portalApiBase = ${JSON.stringify(apiBase)};\nconst portalWebUrl = ${JSON.stringify(parsed.origin)};\n`);
await fs.writeFile('.firebaserc',JSON.stringify({projects:{default:project},targets:{[project]:{hosting:{'erp-portal':[site]}}}},null,2)+'\n');
await fs.writeFile(`firebase_portal/functions/.env.${project}`,`ERP_DATABASE_ID=erp-portal\nERP_ALLOWED_ORIGINS=${parsed.origin}\n`);
console.log('Configured the isolated ERP portal for project '+project+'. No deployment performed.');
