import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {parseTrace,parseObservations,correlate,controlKeys} from './validate.mjs';
import {until,stopChild} from './guest_helpers.mjs';
// ALL fixtures below are synthetic, not live native output.
function fixture(){
 const base={schema:1,actor_id:1,round:1,phase:3};
 const controls=Object.fromEntries(controlKeys.map(k=>[k,['x','z','yaw','pitch'].includes(k)?0:false]));
 const rows=[{...base,event:'round_start',complete:false,pose_present:false,pointer_captured:false},
 {...base,event:'snapshot',ack:0,pose_present:true,health:100,dead:0,lifecycle:'alive',camera_reseeded:true,yaw:0,pitch:0,camera_position:[0,0,0],pointer_captured:false,control_eligible:true,focused:true},
 {...base,event:'input_queue',ack:0,queue_result:0,queued:true,controls}].map((r,i)=>({...r,sequence:i,monotonic_usec:i}));
 const wire={actor:1,starts:[{mapId:'meridian-exchange',roundRevision:1}],snapshots:[{seq:5,actor:1,ack:0,health:100,dead:0}],inputs:[{seq:1,input:controls}]};
 const obs=[{event:'start',actor:1,mapId:'meridian-exchange',roundRevision:1,nativeSequence:0},{event:'snapshot',seq:5,actor:1,ack:0,health:100,dead:0,nativeSequence:1}];
 return {rows,wire,obs};
}
const text=rows=>'engine banner\n'+rows.map(r=>'PORT_NATIVE_TRACE '+JSON.stringify(r)).join('\n')+'\n';
const run=f=>correlate(parseTrace(text(f.rows),'synthetic.log'),f.wire,f.obs);
test('synthetic: valid order, source locations and correlation',()=>{const f=fixture(),p=parseTrace(text(f.rows),'synthetic.log');assert.equal(p[0].location.line,2);assert.equal(p[0].location.source,'synthetic.log');assert.equal(run(f).status,'PASS');});
test('synthetic: malformed JSON, schema, fields and queue result rejected',()=>{
 assert.throws(()=>parseTrace('PORT_NATIVE_TRACE {'),/invalid/);
 for(const [index,key,value] of [[0,'schema',2],[1,'health','100'],[1,'dead',false],[1,'camera_position',[0,0]],[2,'queued',false],[2,'controls',{}],[0,'sequence',1],[0,'monotonic_usec',-1]]) {const f=fixture();f.rows[index][key]=value;assert.throws(()=>run(f),/invalid/);}
});
test('synthetic: actor mismatch rejected',()=>{const f=fixture();f.rows[1].actor_id=7;assert.throws(()=>run(f),/actor mismatch/);});
test('synthetic: health/dead and input mismatches rejected',()=>{for(const k of ['health','dead']){const f=fixture();f.rows[1][k]=k==='health'?99:2;assert.throws(()=>run(f),/native/);}const f=fixture();f.wire.inputs[0].input={...f.wire.inputs[0].input,fire:true};assert.throws(()=>run(f),/input seq/);});
test('synthetic: absent evidence differs from invalid evidence',()=>{const f=fixture();assert.throws(()=>correlate([],f.wire,f.obs),e=>e.kind==='missing');f.wire.snapshots=[];assert.throws(()=>run(f),e=>e.kind==='missing');});
test('synthetic: successful queue without receipt is NOT delivery',()=>{const f=fixture();f.wire.inputs=[];const r=run(f);assert.equal(r.status,'MISSING_RECEIPT');assert.equal(r.inputMatches.length,0);assert.equal(r.unobservedQueue.length,1);assert.equal(r.applicationClaim,false);});
test('synthetic: sequence gap, out-of-order snapshot and malformed limit rejected',()=>{let f=fixture();f.rows[2].sequence=3;assert.throws(()=>run(f),/sequence/);assert.throws(()=>parseTrace('PORT_NATIVE_TRACE {"schema":1,"event":"limit","complete":false}'),/limit/);f=fixture();f.wire.inputs[0].seq=2;assert.throws(()=>run(f),/wire input sequence/);});
test('synthetic: limit after exactly 10000 records is truncation, not completion',()=>{const first=fixture().rows[0];const rows=Array.from({length:10000},(_,i)=>({...first,sequence:i,monotonic_usec:i}));rows.push({schema:1,event:'limit',complete:false});const p=parseTrace(text(rows));assert.equal(p.at(-1).record.complete,false);rows.push(first);assert.throws(()=>parseTrace(text(rows)),/after limit/);});
test('synthetic: observer association rejects unrelated adjacent records',()=>{const f=fixture();const log=text(f.rows)+'CORRELATION_OBSERVE '+JSON.stringify(f.obs[1]);assert.throws(()=>parseObservations(log,parseTrace(log)),/not adjacent/);f.obs[1].nativeSequence=2;assert.throws(()=>run(f),/signal association/);});
test('synthetic: error boundary parses without sensitive message',()=>{const r={...fixture().rows[0],event:'session_error',actor_id:-1,phase:-1};assert.equal(parseTrace(text([r]))[0].record.event,'session_error');});
test('synthetic: disabled output contains no trace',()=>assert.deepEqual(parseTrace('Godot engine\nGUEST_SAMPLE {}\n'),[]));
test('real owned subprocess: failure finally reaps',async()=>{const c=spawn(process.execPath,['-e','setInterval(()=>{},1000)']);try{await assert.rejects(until(()=>false,40,'injected failure'));}finally{assert.equal((await stopChild(c)).reaped,true);}});
test('real owned subprocess: timeout escalation reaps SIGTERM-resistant child',async()=>{const c=spawn(process.execPath,['-e','process.on("SIGTERM",()=>{});console.log("ready");setInterval(()=>{},1000)']);let ready=false;c.stdout.on('data',()=>ready=true);try{await until(()=>ready,2000,'ready');}finally{const r=await stopChild(c);assert.equal(r.reaped,true);assert.equal(r.signal,'SIGKILL');}});
