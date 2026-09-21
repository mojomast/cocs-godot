// Offline validation of genuine stdout; synthetic examples exist only in test.mjs.
export class EvidenceError extends Error {
 constructor(kind,message,location) { super(`${kind}: ${message}${location ? ` (${location.source}:${location.line})` : ''}`); this.kind=kind; this.location=location; }
}
const invalid=(m,l)=>{throw new EvidenceError('invalid',m,l);};
const missing=m=>{throw new EvidenceError('missing',m);};
const object=v=>v!==null && typeof v==='object' && !Array.isArray(v);
const integer=v=>Number.isSafeInteger(v);
const finite=v=>typeof v==='number' && Number.isFinite(v);
export const controlKeys=['x','z','yaw','pitch','fire','jump','reload','sprint','crouch','interact','mobility'];
export function parseTrace(text,source='stdout') {
 const records=[];let seq=0,time=-1,limited=false;
 for(const [index,line] of text.split('\n').entries()) {
  if(!line.startsWith('PORT_NATIVE_TRACE'))continue;
  const location={source,line:index+1,column:1};
  if(!line.startsWith('PORT_NATIVE_TRACE '))invalid('bad trace prefix',location);
  let r;try {r=JSON.parse(line.slice(18));}catch {invalid('malformed JSON',location);}
  const check=(ok,msg)=>{if(!ok)invalid(msg,location);};
  check(object(r)&&r.schema===1,'schema/object');
  check(!limited,'record after limit');
  if(r.event==='limit') {check(r.complete===false && seq===10000 && Object.keys(r).sort().join(',')==='complete,event,schema','limit shape/count');limited=true;records.push({record:r,location});continue;}
  check(['snapshot','input_queue','round_start','session_error'].includes(r.event),'unknown event');
  check(seq<10000&&integer(r.sequence)&&r.sequence===seq++,'sequence gap/order/limit');
  check(integer(r.monotonic_usec)&&r.monotonic_usec>=0&&r.monotonic_usec>=time,'monotonic time');time=r.monotonic_usec;
  for(const k of ['round','actor_id','phase'])check(integer(r[k]),k);
  check(r.round>=0 && r.actor_id>=-1,'round/actor bounds');
  const bool=k=>check(typeof r[k]==='boolean',k);
  if(['snapshot','input_queue'].includes(r.event))check(integer(r.ack)&&r.ack>=0,'ack');
  if(r.event==='snapshot') {
   for(const k of ['pose_present','camera_reseeded','pointer_captured','control_eligible','focused'])bool(k);
   check(r.health===null||finite(r.health),'health');check(r.dead===null||(finite(r.dead)&&r.dead>=0),'dead');
   check(['waiting','alive','dead','results'].includes(r.lifecycle),'lifecycle');
   check(finite(r.yaw)&&finite(r.pitch),'angles');check(Array.isArray(r.camera_position)&&r.camera_position.length===3&&r.camera_position.every(finite),'camera_position');
  } else if(r.event==='input_queue') {
   check(integer(r.queue_result)&&r.queue_result>=0,'queue_result');bool('queued');check(r.queued===(r.queue_result===0),'queue success consistency');
   check(object(r.controls),'controls');
   for(const k of controlKeys)check(k in r.controls && (r.controls[k]===null || (['x','z','yaw','pitch'].includes(k)?finite(r.controls[k]):typeof r.controls[k]==='boolean')),`controls.${k}`);
  } else {check(r.complete===false,'boundary complete');bool('pose_present');bool('pointer_captured');}
  records.push({record:r,location});
 }
 return records;
}
const eq=(a,b,m,l)=>{if(JSON.stringify(a)!==JSON.stringify(b))invalid(m,l);};
export function parseObservations(text,records,source='stdout') {
 const byLine=new Map(records.map(x=>[x.location.line,x.record]));
 return text.split('\n').flatMap((line,i)=>{
  if(!line.startsWith('CORRELATION_OBSERVE '))return [];
  const location={source,line:i+1,column:1};let o;
  try{o=JSON.parse(line.slice('CORRELATION_OBSERVE '.length));}catch{invalid('observer JSON',location);}
  if(!object(o)||!['start','snapshot'].includes(o.event)||!integer(o.actor))invalid('observer shape',location);
  const r=byLine.get(i); // immediately preceding stdout line, same synchronous signal emission
  if(records.length && (!r||r.event!==(o.event==='start'?'round_start':'snapshot')))invalid('observer not adjacent to corresponding native handler',location);
  return [{...o,location,nativeSequence:r?.sequence??null}];
 });
}
// Observation must cover a fresh connection before START, with no reconnect or lost stdout.
export function correlate(records,wire,observations) {
 const rs=records.map(x=>x.record), starts=rs.filter(r=>r.event==='round_start');
 if(!starts.length)missing('round_start trace');
 if(!wire.starts.length||!observations.some(x=>x.event==='start'))missing('observed start');
 if(starts.length!==1||wire.starts.length!==1)invalid('requires exactly one fresh round');
 if(rs[0].event!=='round_start')invalid('capture does not begin at round start');
 const actor=wire.actor;
 if(!integer(actor)||actor<0)missing('WELCOME/LOBBY actor assignment');
 const startObs=observations.filter(x=>x.event==='start');
 eq(startObs.length,1,'start observation count');eq(startObs[0].actor,actor,'start actor');
 eq(startObs[0].nativeSequence,starts[0].sequence,'start signal association');
 eq(startObs[0].roundRevision,wire.starts[0].roundRevision,'start round revision');eq(startObs[0].mapId,wire.starts[0].mapId,'start map');
 eq(starts[0].round,1,'native fresh round');eq(starts[0].phase,3,'start phase');eq(starts[0].pose_present,false,'start pose reset');
 for(const x of records.filter(x=>['snapshot','input_queue','round_start'].includes(x.record.event))) {eq(x.record.actor_id,actor,'actor mismatch',x.location);eq(x.record.round,1,'round mismatch',x.location);}
 if(rs.some(r=>r.event==='session_error'||r.event==='limit'))invalid('error or truncated native capture');
 const snapshots=records.filter(x=>x.record.event==='snapshot'), observed=observations.filter(x=>x.event==='snapshot');
 if(!snapshots.length||!observed.length||!wire.snapshots.length)missing('snapshots');
 if(snapshots.length!==observed.length)missing('trace/observer snapshot count differs');
 let previous=-1,ack=0;
 const snapshotMatches=[];
 for(let i=0;i<snapshots.length;i++) {
  const {record:r,location:l}=snapshots[i],o=observed[i];
  eq(o.nativeSequence,r.sequence,'snapshot signal association',l);
  if(!integer(o.seq)||o.seq<=previous)invalid('observer snapshot order');previous=o.seq;
  const w=wire.snapshots.find(s=>s.seq===o.seq);if(!w)missing(`server snapshot ${o.seq}`);
  eq(o.actor,actor,'observer actor');eq(w.actor,actor,'wire actor');ack=Math.max(ack,w.ack);
  for(const k of ['health','dead']){eq(o[k],w[k],`wire/observer ${k}`);eq(r[k],o[k],`native ${k}`,l);}
  eq(r.ack,ack,'native ack',l);eq(o.ack,ack,'observer ack');eq(r.pose_present,true,'pose',l);
  snapshotMatches.push({traceLine:l.line,traceSequence:r.sequence,serverSnapshotSeq:o.seq,actor,health:r.health,dead:r.dead,ack});
 }
 const queued=records.filter(x=>x.record.event==='input_queue'&&x.record.queued);
 if(!queued.length)missing('successful native input queue records');
 const inputMatches=[];
 for(let i=0;i<wire.inputs.length;i++) {
  const w=wire.inputs[i];eq(w.seq,i+1,'wire input sequence');
  if(!queued[i])missing(`native queued input for received seq ${w.seq}`);
  for(const k of controlKeys)eq(queued[i].record.controls[k],w.input[k],`input seq ${w.seq} ${k}`,queued[i].location);
  inputMatches.push({traceLine:queued[i].location.line,traceSequence:queued[i].record.sequence,inferredInputSeq:i+1,receivedSeq:w.seq});
 }
 // No positive receipt claim for unmatched queue records (including a trailing in-flight suffix).
 const unobserved=queued.slice(wire.inputs.length).map((x,i)=>({traceLine:x.location.line,inferredInputSeq:wire.inputs.length+i+1}));
 return {status:unobserved.length?'MISSING_RECEIPT':'PASS',actor,roundStarts:1,snapshotMatches,inputMatches,unobservedQueue:unobserved,serverReceiptOnly:true,applicationClaim:false,ackHighWater:ack,completionProven:false};
}
