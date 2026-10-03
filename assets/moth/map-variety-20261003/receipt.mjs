// Summarize existing plans/logs; this command makes no network requests.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
const root=new URL('./',import.meta.url);
const batches=[['initial','/tmp/opencode/map-variety-plan.json','/tmp/opencode/map-variety-live.log'],['supplemental','/tmp/opencode/map-variety-supplemental-plan.json','/tmp/opencode/map-variety-supplemental-live.log'],['refined','/tmp/opencode/map-variety-refined-plan.json','/tmp/opencode/map-variety-refined-live.log']];
fs.mkdirSync(new URL('evidence/',root),{recursive:true});
const summaries=batches.map(([name,planFile,logFile])=>{
  const bytes=fs.readFileSync(planFile),plan=JSON.parse(bytes),log=fs.readFileSync(logFile,'utf8');
  if(/https?:\/\/|bearer|moth_[a-z0-9]{10}/i.test(log))throw new Error('Refusing unsanitized log');
  fs.writeFileSync(new URL(`evidence/${name}.log`,root),log);
  return {name,planFingerprint:plan.fingerprint,fullPlanSha256:createHash('sha256').update(bytes).digest('hex'),spending:plan.spending,confirmedSubmissions:[...log.matchAll(/submitted ([a-f0-9-]+)/g)].map(m=>m[1]),completedTransitions:(log.match(/^  completed/gm)??[]).length,statusRequestsLowerBound:(log.match(/^  (pending|processing|queued|completed|fetching)/gm)??[]).length,retryLogEntries:(log.match(/retrying/g)??[]).length};
});
const submitted=summaries.reduce((s,b)=>s+b.confirmedSubmissions.length,0),statusMin=summaries.reduce((s,b)=>s+b.statusRequestsLowerBound,0);
const receipt={date:'2026-10-03',api:'https://api.mothquantum.com',authenticatedCatalogHTTP:200,engineDefinitionHTTP:200,openapiHTTP:200,earlierUrllibOpenapiHTTP:403,submissions:submitted,completed:summaries.reduce((s,b)=>s+b.completedTransitions,0),estimatedCredits:45,actualChargedCredits:null,creditNote:'Catalog estimate only; response schemas do not expose actual billing',requests:{jobPOST:submitted,runnerResultGET:submitted,extraExactBodyResultGET:45,statusGETLowerBound:statusMin,discovery:4,totalLowerBound:submitted*2+45+statusMin+4,exactTotal:null,note:'Runner logs status transitions, not unchanged polls; total count is a lower bound, never an invented exact count'},selection:{baseFamilies:30,selectedJobResults:30,supersededXyResults:15,derivedVariants:6},batches:summaries};
fs.writeFileSync(new URL('evidence/api-receipt.json',root),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({submissions:receipt.submissions,completed:receipt.completed,estimatedCredits:45,requests:receipt.requests}));
