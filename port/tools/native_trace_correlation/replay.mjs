// Usage: node replay.mjs CASE.stdout.log CASE.json
import {readFileSync} from 'node:fs';
import {parseTrace,parseObservations,correlate} from './validate.mjs';
const [log,evidence]=process.argv.slice(2);
if(!log||!evidence)throw Error('Usage: node replay.mjs CASE.stdout.log CASE.json');
try {
 const text=readFileSync(log,'utf8'),result=JSON.parse(readFileSync(evidence));
 const records=parseTrace(text,log),obs=parseObservations(text,records,log);
 const r=correlate(records,result.wire,obs);
 console.log(JSON.stringify({status:r.status,actor:r.actor,roundStarts:r.roundStarts,snapshots:r.snapshotMatches.length,receivedInputs:r.inputMatches.length,unobservedQueue:r.unobservedQueue,completionProven:r.completionProven}));
 if(r.status!=='PASS')process.exitCode=2;
}catch(e){console.error(JSON.stringify({status:e.kind??'error',message:e.message}));process.exitCode=e.kind==='missing'?2:1;}
