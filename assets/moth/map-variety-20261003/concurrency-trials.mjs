// User-authorized 2-then-4 genuine overlapping job POST experiment. Useful
// material trials only. Each accepted ID is journaled before any polling.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {loadTool} from './tool.mjs';
const {createApi}=await loadTool('api.mjs');
const {archiveResponse}=await loadTool('archive.mjs');
const {writeFileAtomic}=await loadTool('publish.mjs');
const {validateJobsAgainstContracts}=await loadTool('engine-contracts.mjs');
const root=path.join(path.dirname(fileURLToPath(import.meta.url)),'engine-trials');
const out=path.join(root,'concurrency');fs.mkdirSync(out,{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex');
const key=process.env.MOTH_API_KEY;if(!key)throw new Error('Missing child-environment API key');
const api=createApi({key,maxDownloadBytes:8*1024*1024,log:()=>{}});
const definitions=[
  {id:'copper-patina-image-global',batch:2,engine:'blur-v1',params:{style:'rx',strength:.22,reach:0,size:64},inputs:{image:'sources/copper-patina-source.png'}},
  {id:'copper-patina-kernel-global',batch:2,engine:'deep-fryer-v1',params:{gates:[['rx',.1]],tile_size:2},inputs:{image:'sources/copper-patina-source.png'}},
  {id:'copper-patina-tele-global',batch:4,engine:'telablur-v1',params:{strength:.3,direction:'full',size:64},inputs:{image1:'sources/copper-patina-source.png',image2:'sources/copper-patina-target.png'}},
  {id:'copper-patina-kernel-four',batch:4,engine:'deep-fryer-v1',params:{gates:[['rx',.1]],tile_size:4},inputs:{image:'sources/copper-patina-source.png'}},
  {id:'quay-waterline-tele-strong',batch:4,engine:'telablur-v1',params:{strength:.55,direction:'horizontal',size:64},inputs:{image1:'sources/quay-waterline-source.png',image2:'sources/quay-waterline-target.png'}},
  {id:'prismatic-etch-image-reach',batch:4,engine:'blur-v1',params:{strength:.18,reach:.08,style:'rx',size:64},inputs:{image:'sources/prismatic-etch-source.png'}},
];
const validation=validateJobsAgainstContracts({jobs:definitions},JSON.parse(fs.readFileSync(path.join(root,'../engine-review/contracts.json'))),root);
if(validation.errors.length)throw new Error(JSON.stringify(validation));
const plan={definitions:definitions.map(d=>({...d,inputHashes:Object.fromEntries(Object.entries(d.inputs).map(([slot,p])=>[slot,sha(fs.readFileSync(path.join(root,p)))]))})),estimatedCredits:6,concurrencyStages:[2,4]};
writeFileAtomic(path.join(out,'plan.json'),JSON.stringify({...plan,fingerprint:sha(JSON.stringify(plan))},null,2)+'\n');
const uploadsFile=path.join(out,'uploads.json'),uploads=fs.existsSync(uploadsFile)?JSON.parse(fs.readFileSync(uploadsFile)):{};
for(const p of new Set(definitions.flatMap(d=>Object.values(d.inputs))))if(!uploads[p]){
  try {uploads[p]={assetId:await api.uploadAsset(path.join(root,p)),sha256:sha(fs.readFileSync(path.join(root,p)))};writeFileAtomic(uploadsFile,JSON.stringify(uploads,null,2)+'\n');}
  catch(e){writeFileAtomic(path.join(out,'upload-blocker.json'),JSON.stringify({path:p,http:e.status??null,assetId:e.assetId??null,action:'stop; no automatic ambiguous retry'},null,2));throw new Error(`Input upload blocked, HTTP ${e.status??'unknown'}; redacted`);}
}
const clock=()=>performance.timeOrigin+performance.now();
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const records=new Map();
const save=r=>writeFileAtomic(path.join(out,`${r.id}.json`),JSON.stringify(r,null,2)+'\n');
async function submit(d){
  const file=path.join(out,`${d.id}.json`);
  if(fs.existsSync(file)){const old=JSON.parse(fs.readFileSync(file));if(old.jobId){records.set(d.id,old);return old;}throw new Error('Unconfirmed existing intent: reconcile instead of repeating POST');}
  const body={params:d.params,input_files:Object.fromEntries(Object.entries(d.inputs).map(([slot,p])=>[slot,uploads[p].assetId]))};
  const r={...d,recipeFingerprint:sha(JSON.stringify({definition:d,inputs:Object.fromEntries(Object.values(d.inputs).map(p=>[p,uploads[p].sha256]))})),state:'submitting',jobId:null,attempts:[],observations:[]};records.set(d.id,r);save(r);
  for(let attempt=0;attempt<3;attempt++){
    const timing={startMonotonicMs:clock(),startUTC:new Date().toISOString()};r.attempts.push(timing);save(r);
    try {
      const res=await fetch(`https://api.mothquantum.com/api/v1/engines/${d.engine}/process`,{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(60000)});
      timing.endMonotonicMs=clock();timing.http=res.status;timing.durationMs=timing.endMonotonicMs-timing.startMonotonicMs;
      if(res.status===429){const header=res.headers.get('retry-after');const seconds=Number(header);const delay=header?(Number.isFinite(seconds)?seconds*1000:Date.parse(header)-Date.now()):1000*2**attempt;timing.retryAfterMs=Math.max(1000,Math.min(120000,Number.isFinite(delay)?delay:1000));save(r);await res.body?.cancel();await sleep(timing.retryAfterMs);continue;}
      if(!res.ok){r.state=res.status>=500?'unknown-submission':'rejected';save(r);await res.body?.cancel();return r;}
      const data=await res.json();if(!data.job_id){r.state='unknown-submission';save(r);return r;}
      r.jobId=data.job_id;r.submittedAt=data.submitted_at??null;r.state='accepted';save(r);return r;
    }catch{timing.endMonotonicMs=clock();r.state='unknown-submission';save(r);return r;}
  }
  r.state='rate-limited';save(r);return r;
}
async function pollGroup(group){
  const began=clock();let interval=1500;
  while(group.some(r=>['accepted','pending','queued','processing','fetching'].includes(r.state))){
    const active=group.filter(r=>['accepted','pending','queued','processing','fetching'].includes(r.state));
    // Central GET concurrency capped at two, independent of POST batch size.
    for(let i=0;i<active.length;i+=2)await Promise.all(active.slice(i,i+2).map(async r=>{
      const status=await api.jobStatus(r.jobId);
      r.observations.push({atUTC:new Date().toISOString(),monotonicMs:clock(),status:status.status,step:status.progress?.step??null,startedAt:status.started_at??null,completedAt:status.completed_at??null});
      r.state=status.status;save(r);
      if(status.status==='completed'){
        const response=await api.jobResult(r.jobId);
        await archiveResponse({response,api,outDir:out,rawName:r.id,recipeFingerprint:r.recipeFingerprint,generationFingerprint:sha(r.recipeFingerprint+r.jobId),jobId:r.jobId,engine:r.engine,verification:'concurrent-new-request'});
        r.archived=true;save(r);
      }
    }));
    if(clock()-began>15*60*1000)throw new Error('Polling deadline; accepted job IDs remain recoverable');
    if(group.some(r=>['accepted','pending','queued','processing','fetching'].includes(r.state))){await sleep(interval);interval=Math.min(5000,interval*1.3);}
  }
}
const results=[];
for(const batch of [2,4]){
  const started=clock();
  const group=await Promise.all(definitions.filter(d=>d.batch===batch).map(submit));
  await pollGroup(group);
  const posts=group.map(r=>r.attempts[0]),overlapMs=Math.min(...posts.map(p=>p.endMonotonicMs))-Math.max(...posts.map(p=>p.startMonotonicMs));
  const processing=group.map(r=>({id:r.id,observations:r.observations.filter(o=>o.status==='processing')}));
  const entry={batch,accepted:group.filter(r=>r.jobId).length,completed:group.filter(r=>r.state==='completed'&&r.archived).length,jobIds:group.map(r=>r.jobId),postOverlapMs:Math.max(0,overlapMs),postDurationsMs:posts.map(p=>p.durationMs),http429:group.reduce((s,r)=>s+r.attempts.filter(a=>a.http===429).length,0),elapsedMs:clock()-started,processingObservations:processing,executionOverlap:'Only status observations supplied; POST overlap alone does not prove worker execution overlap'};
  results.push(entry);writeFileAtomic(path.join(out,'report.json'),JSON.stringify({version:1,results},null,2)+'\n');
  console.log(JSON.stringify({...entry,processingObservations:processing.map(p=>({id:p.id,count:p.observations.length}))}));
  if(entry.completed!==batch)break;
}
