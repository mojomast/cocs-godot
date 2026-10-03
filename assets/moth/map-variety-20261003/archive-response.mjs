// Explicit authorized read-only retrieval. Never submits jobs. Preserve exact
// provider HTTP body bytes in addition to mothbake's canonical inline archive.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
const root=new URL('./',import.meta.url);
const key=process.env.MOTH_API_KEY;
if(!key)throw new Error('MOTH_API_KEY must be in the child environment');
const sha=b=>createHash('sha256').update(b).digest('hex');
const jobs=['live.json','supplemental.json','refined.json'].filter(p=>fs.existsSync(new URL(p,root))).flatMap(p=>JSON.parse(fs.readFileSync(new URL(p,root))).jobs);
const records=[];
fs.mkdirSync(new URL('provider/http/',root),{recursive:true});
for(const job of jobs){
  const archive=JSON.parse(fs.readFileSync(new URL(`provider/raw/${job.id}/.mothbake-archive.json`,root)));
  const file=`provider/http/${job.id}.json`, url=new URL(file,root);
  let bytes;
  if(fs.existsSync(url))bytes=fs.readFileSync(url);
  else {
    const r=await fetch(`https://api.mothquantum.com/api/v1/jobs/${archive.jobId}/result`,{headers:{Authorization:`Bearer ${key}`},signal:AbortSignal.timeout(30000),redirect:'error'});
    if(!r.ok)throw new Error(`${job.id}: result HTTP ${r.status}; no response details logged`);
    bytes=Buffer.from(await r.arrayBuffer());
    if(bytes.length>2_000_000)throw new Error('Response exceeds pack bound');
    const j=JSON.parse(bytes);
    if(/https?:\/\//i.test(JSON.stringify({...j,$schema:undefined})))throw new Error('Refusing an envelope containing transport URLs');
    if(!Array.isArray(j.result?.output))throw new Error('Unexpected inline output shape');
    fs.writeFileSync(url,bytes,{flag:'wx'});
    await new Promise(resolve=>setTimeout(resolve,350));
  }
  records.push({id:job.id,jobId:archive.jobId,path:file,bytes:bytes.length,sha256:sha(bytes)});
}
fs.writeFileSync(new URL('provider/http-manifest.json',root),JSON.stringify({version:1,operation:'GET completed job results, no submissions',records},null,2)+'\n');
console.log(`Verified ${records.length} exact HTTP response bodies; no transport URLs retained.`);
