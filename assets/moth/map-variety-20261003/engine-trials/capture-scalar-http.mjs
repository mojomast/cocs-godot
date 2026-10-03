// Explicit read-only retrieval of exact completed scalar response bytes.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
const root=new URL('./',import.meta.url),key=process.env.MOTH_API_KEY;
if(!key)throw new Error('Missing child-environment key');
const sha=b=>createHash('sha256').update(b).digest('hex');
fs.mkdirSync(new URL('http-scalar/',root),{recursive:true});
const records=[];
for(const id of ['moss-lichen-qpixl','quay-waterline-qpixl']){
  const archive=JSON.parse(fs.readFileSync(new URL(`provider/raw/${id}/.mothbake-archive.json`,root))),file=new URL(`http-scalar/${id}.json`,root);let bytes;
  if(fs.existsSync(file))bytes=fs.readFileSync(file);else{const r=await fetch(`https://api.mothquantum.com/api/v1/jobs/${archive.jobId}/result`,{headers:{Authorization:`Bearer ${key}`},redirect:'error',signal:AbortSignal.timeout(30000)});if(!r.ok)throw new Error(`Scalar HTTP ${r.status}; details redacted`);bytes=Buffer.from(await r.arrayBuffer());if(bytes.length>2_000_000)throw new Error('Scalar response exceeds bound');const j=JSON.parse(bytes);if(/https?:\/\//i.test(JSON.stringify({...j,$schema:undefined})))throw new Error('Unexpected transport URL');fs.writeFileSync(file,bytes,{flag:'wx'});}
  const canonical=JSON.parse(fs.readFileSync(new URL(`provider/raw/${id}/inline-result.json`,root))),body=JSON.parse(bytes);
  if(JSON.stringify(body.result.output)!==JSON.stringify(canonical.output))throw new Error('Scalar response differs from archived measurement');
  records.push({id,jobId:archive.jobId,path:`http-scalar/${id}.json`,bytes:bytes.length,sha256:sha(bytes),canonicalSha256:archive.result.sha256});
}
fs.writeFileSync(new URL('http-scalar/manifest.json',root),JSON.stringify({records},null,2)+'\n');console.log(`Verified ${records.length} exact scalar HTTP responses.`);
