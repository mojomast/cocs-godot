// Explicit read-only current catalog review. Retain capability metadata, never
// credentials, account ownership records, signed URLs or raw private errors.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {loadTool} from './tool.mjs';
const {sanitizeEngineContract,createContractSnapshot}=await loadTool('engine-contracts.mjs');
const root=new URL('./engine-review/',import.meta.url);
fs.mkdirSync(root,{recursive:true});
const key=process.env.MOTH_API_KEY;if(!key)throw new Error('Missing child-environment key');
const get=async route=>{const r=await fetch('https://api.mothquantum.com'+route,{headers:{Authorization:`Bearer ${key}`},signal:AbortSignal.timeout(30000),redirect:'error'});if(!r.ok)return {status:r.status};return {status:r.status,data:await r.json()};};
const catalog=await get('/api/v1/engines');if(catalog.status!==200)throw new Error(`Catalog HTTP ${catalog.status}`);
const summaries=catalog.data.engines.map(e=>({id:e.engine_id,name:e.name,description:e.description,enabled:e.enabled,version:e.version??null,creditsPerRun:e.credits_per_run,inputType:e.input_type,outputType:e.output_type}));
fs.writeFileSync(new URL('catalog.json',root),JSON.stringify({retrievedAt:new Date().toISOString(),http:200,engines:summaries},null,2)+'\n');
const contracts=[],probes=[];
for(const e of catalog.data.engines){
  const r=await get(`/api/v1/engines/${e.engine_id}`);
  probes.push({id:e.engine_id,http:r.status});
  if(r.status===200){contracts.push(r.data);const c=sanitizeEngineContract(r.data);fs.writeFileSync(new URL(`${e.engine_id}.json`,root),JSON.stringify(c,null,2)+'\n');}
  await new Promise(resolve=>setTimeout(resolve,350));
}
const snapshot=createContractSnapshot(contracts,{apiVersion:'v0.41.0'}),bytes=JSON.stringify(snapshot,null,2)+'\n';
fs.writeFileSync(new URL('contracts.json',root),bytes);
fs.writeFileSync(new URL('receipt.json',root),JSON.stringify({requests:1+probes.length,probes,snapshotSha256:createHash('sha256').update(bytes).digest('hex')},null,2)+'\n');
console.log(JSON.stringify({catalog:summaries.length,contracts:contracts.length,statuses:probes}));
