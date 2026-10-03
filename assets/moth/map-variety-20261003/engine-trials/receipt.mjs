// Offline evidence aggregation, including pre-submit and local-bake failures.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
const main=JSON.parse(fs.readFileSync(path.join(root,'live.json'))),intensity=JSON.parse(fs.readFileSync(path.join(root,'intensity.json'))),concurrency=JSON.parse(fs.readFileSync(path.join(root,'concurrency/plan.json')));
const records=[];
for(const [jobs,dir]of [[main.jobs,'provider'],[intensity.jobs,'intensity-provider'],[concurrency.definitions,'concurrency']]){
  const journal=dir==='concurrency'?null:JSON.parse(fs.readFileSync(path.join(root,dir,'run-journal.json')));
  for(const job of jobs){const af=path.join(root,dir,'raw',job.raw??job.id,'.mothbake-archive.json'),archive=fs.existsSync(af)?JSON.parse(fs.readFileSync(af)):null,state=journal?.jobs[job.id]??JSON.parse(fs.readFileSync(path.join(root,dir,`${job.id}.json`)));records.push({id:job.id,engine:job.engine,jobId:archive?.jobId??state.jobId??null,remoteCompleted:!!archive,initialLocalState:state.state,rawArchive:archive?path.relative(root,af):null,localRepair:job.engine==='qpixl-v1'&&archive?'explicit 64x64 reshape, provider/qpixl-repaired.json; no resubmission':null});}
}
const perEngine={};for(const r of records){const v=perEngine[r.engine]??={attempted:0,accepted:0,remoteCompleted:0,preSubmissionFailures:0};v.attempted++;if(r.jobId)v.accepted++;else v.preSubmissionFailures++;if(r.remoteCompleted)v.remoteCompleted++;}
const concurrencyReport=JSON.parse(fs.readFileSync(path.join(root,'concurrency/report.json')));
const receipt={version:1,attempted:records.length,accepted:records.filter(r=>r.jobId).length,remoteCompleted:records.filter(r=>r.remoteCompleted).length,preSubmissionFailures:records.filter(r=>!r.jobId).length,remoteFailures:records.filter(r=>r.jobId&&!r.remoteCompleted).length,perEngine,estimatedCreditsForAcceptedJobs:records.filter(r=>r.jobId).length,actualChargedCredits:null,totalCampaignAcceptedJobsIncludingOriginal45:45+records.filter(r=>r.jobId).length,requestAccounting:{authenticatedCatalogAndDefinitions:33,assetInspectionGETs:4,concurrencyJobHistoryGETs:6,extraExactScalarResultGETs:2,confirmedJobPOSTs:records.filter(r=>r.jobId).length,exactTotal:null,note:'Upload requests, unchanged polling and retries are not fully instrumented; no exact overall HTTP count claimed'},concurrency:concurrencyReport.results,records};
fs.writeFileSync(path.join(root,'receipt.json'),JSON.stringify(receipt,null,2)+'\n');
for(const [name,source]of [['serial','/tmp/opencode/moth-engine-trials.log'],['intensity','/tmp/opencode/moth-intensity.log']]){const text=fs.readFileSync(source,'utf8');if(/https?:\/\/|Bearer\s+moth_|X-Amz-/i.test(text))throw new Error('Refusing unsanitized log');fs.writeFileSync(path.join(root,`${name}.log`),text);}
console.log(JSON.stringify({attempted:receipt.attempted,accepted:receipt.accepted,remoteCompleted:receipt.remoteCompleted,preSubmissionFailures:receipt.preSubmissionFailures,perEngine}));
