import assert from 'node:assert/strict';
import {readFileSync,readdirSync,writeFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {validateRun} from '../../native-horde/validate.mjs';
const root=new URL('evidence/',import.meta.url),results=[];
const tagged=(text,prefix)=>text.split('\n').filter(l=>l.startsWith(prefix)).map(l=>JSON.parse(l.slice(prefix.length)));
for(const id of readdirSync(root)) {
 const dir=new URL(id+'/',root),json=name=>JSON.parse(readFileSync(new URL(name,dir)));
 const unzip=name=>gunzipSync(readFileSync(new URL(name+'.gz',dir))).toString();
 const wire=unzip('wire.jsonl').split('\n').map(JSON.parse),stdout=unzip('native.stdout.log'),stderr=unzip('native.stderr.log');
 const summary=json('summary.json'),launch=json('launch.json');
 const validation=validateRun({wire,stdout,stderr,summary,launch});
 const oracle=json('source-object-oracle.json'),objects=unzip('source-object-oracle.jsonl').split('\n').map(JSON.parse);
 assert(oracle.passed&&oracle.mismatches===0&&oracle.matchCount===2);
 assert(objects.every(r=>r.ok&&!r.lost));
 let sourceObjectCount=0;
 for(const round of [1,2]) {
  const expected=objects.filter(r=>r.match===round).flatMap(r=>r.expectedFromDistinctSourceObjects);
  const actual=wire.filter(r=>r.direction==='out'&&r.round===round&&r.frame.type==='events').flatMap(r=>r.frame.items);
  assert.deepEqual(actual,expected,'wire events do not correspond exactly to distinct source event objects');
  assert.deepEqual(actual.map(e=>e.id),actual.map((_,i)=>i+1),'per-round adapter ordinal not contiguous');
  sourceObjectCount+=expected.length;
 }
 assert.equal(sourceObjectCount,oracle.sourceObjects);
 const snapshots=wire.filter(r=>r.direction==='out'&&r.frame.type==='snapshot');
 const rows=tagged(stdout,'HORDE_NATIVE '),trace=tagged(stdout,'PORT_NATIVE_TRACE '),done=tagged(stdout,'HORDE_DONE ');
 const outputs=wire.filter(r=>r.direction==='out'&&r.frame.type==='results');
 assert.equal(outputs.length,1);
 const restarted=snapshots.find(r=>r.round===2).frame.state;
 assert(restarted.time<=.051&&restarted.singleplayer.kills===0&&restarted.singleplayer.score===0&&restarted.actors[0].shots===0);
 assert(rows.filter(r=>r.round===2).every(r=>!r.captured));
 assert.equal(done.length,1);assert(done[0].ok);
 assert.equal(trace.filter(t=>t.event==='recording_end'&&t.complete).length,1);
 const receipts=new Map(),steps=new Map();
 for(const r of wire) {
  if(r.direction==='in'&&r.frame.type==='input')receipts.set(`${r.round}:${r.frame.seq}`,r);
  if(r.direction==='step'&&r.inputSeq!==null) {
   const key=`${r.round}:${r.inputSeq}`;assert(receipts.has(key)&&!steps.has(key));steps.set(key,r);
  }
  if(r.direction==='out'&&r.frame.type==='snapshot'&&r.frame.acks[0])assert(steps.has(`${r.round}:${r.frame.acks[0]}`));
 }
 const queued=trace.filter(t=>t.event==='input_queue'&&t.queued),matched=queued.filter(t=>receipts.has(`${t.round}:${t.input_seq}`));
 assert(summary.wallSeconds<=180&&summary.attempt<=2);
 const detail={id,status:'BOUNDED_REPAIR_PASS; LEAD_INTEGRATION_HOLD',wallSeconds:summary.wallSeconds,
  observerComplete:done[0].ok,nativeTraceComplete:true,harnessExit:summary.exit,
  sourceObjectOracle:oracle,sourceObjectsEqualWire:sourceObjectCount,
  sourceModifierPreserved:objects.some(r=>r.actual.some(e=>e.type==='horde-modifier'&&e.sourceId==='swarm')),
  correlatedNativeSnapshots:validation.correlated,nativeQueued:queued.length,nativeQueuedWithReceipt:matched.length,
  wireReceipts:receipts.size,distinctStepped:steps.size,appliedAckHighWater:validation.ackHighWater,
  combatKills:validation.combatKills,restart:{sourceTime:restarted.time,kills:0,shots:0,score:0,released:true},
  engineAndRuntimeCommit:launch.base,validation};
 assert(detail.sourceModifierPreserved);
 writeFileSync(new URL('validation.json',dir),JSON.stringify(validation,null,2)+'\n');
 writeFileSync(new URL('audit.json',dir),JSON.stringify(detail,null,2)+'\n');results.push(detail);
}
writeFileSync(new URL('live-audits.json',import.meta.url),JSON.stringify(results,null,2)+'\n');
console.log(JSON.stringify(results,null,2));
