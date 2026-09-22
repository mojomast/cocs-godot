import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {pathToFileURL} from 'node:url';
export function validate(wire,stdout,scenario='startup') {
 const frames=wire.filter(r=>r.direction==='out'),rows=stdout.split('\n').filter(l=>l.startsWith('HORDE_NATIVE ')).map(l=>JSON.parse(l.slice(13)));
 assert(rows.length>0,'no native evidence');
 const snapshots=new Map(frames.filter(r=>r.frame.type==='snapshot').map(r=>[`${r.round}:${r.frame.seq}`,r.frame]));
 let correlated=0;
 for(const row of rows){
  if(row.seq<0)continue;
  const f=snapshots.get(`${row.round}:${row.seq}`);assert(f,'missing recipient snapshot');
  assert.equal(row.actor_id,0,'local actor zero');
  for(const k of ['wave','waveTarget','lives','enemiesAlive','enemiesTotal','phase','score','winner'])assert.equal(row.model[k],f.state.singleplayer[k],`HUD model ${k}`);
  assert(row.hud.includes(`WAVE ${f.state.singleplayer.wave} / ${f.state.singleplayer.waveTarget}`),'wave not visible');
  assert(row.hud.includes(`LIVES ${f.state.singleplayer.lives}`),'lives not visible');
  assert.deepEqual(Object.keys(row.rendered).sort(),f.state.actors.map(a=>String(a.id)).sort(),'rendered identity set');
  for(const a of f.state.actors){const r=row.rendered[a.id];assert(r,'missing rendered actor');for(const [i,v]of [a.x,a.y+0.9,a.z].entries())assert(Math.abs(r.position[i]-v)<0.001,'position mismatch');assert.equal(r.visible,a.id!==0&&a.health>0&&a.dead<=0,'visibility');}
  correlated++;
 }
 assert(correlated>10,'insufficient samples');
 const events=frames.filter(r=>r.frame.type==='events').flatMap(r=>r.frame.items);
 const state=frames.filter(r=>r.frame.type==='snapshot').map(r=>r.frame.state);
 assert(state.some(s=>s.singleplayer.wave>=1&&s.singleplayer.enemiesAlive>0),'no real wave');
 const receipts=wire.filter(r=>r.direction==='in'&&r.frame.type==='input');
 const done=stdout.split('\n').filter(l=>l.startsWith('HORDE_DONE ')).map(l=>JSON.parse(l.slice(11)));
 assert(done.length===1&&done[0].ok,'native completion missing/failed');
 const won=frames.some(r=>r.frame.type==='results'&&r.frame.state.singleplayer.phase==='won');
 const deaths=state.some(s=>s.singleplayer.lives<3);
 if(scenario==='combat'){
  assert(receipts.some(r=>r.frame.input.fire===true),'no fire receipt');
  assert(state.some(s=>s.singleplayer.kills>0),'no real kill');
  assert(won,'no genuine victory');
  assert(rows.some(r=>r.round===2&&!r.captured),'no released restart');
 }
 if(scenario==='death'){
  assert(deaths,'no life loss');
  assert(done[0].dead_seen&&done[0].respawn_seen&&done[0].blocked_seen,'missing respawn input gates');
  const gates=stdout.split('\n').filter(l=>l.startsWith('HORDE_GATE ')).map(l=>JSON.parse(l.slice(11)));
  assert(gates.some(g=>g.stage==='pause')&&gates.some(g=>g.stage==='resumed_holding_interact'),'no explicit pause/resume probe');
  const trace=stdout.split('\n').filter(l=>l.startsWith('PORT_NATIVE_TRACE ')).map(l=>JSON.parse(l.slice(18)));
  const firstDead=trace.findIndex(t=>t.event==='snapshot'&&t.dead>0);
  assert(firstDead>=0,'no native dead state');
  assert(trace.slice(0,firstDead).some(t=>t.event==='input_queue'&&t.controls.interact),'no pre-death held action');
  const after=trace.slice(firstDead);
  const recaptured=after.findIndex(t=>t.event==='snapshot'&&t.pointer_captured);
  const blocked=recaptured<0?after:after.slice(0,recaptured);
  const neutral=blocked.filter(t=>t.event==='input_queue');
  assert(neutral.length>10,'insufficient neutral death/respawn samples');
  for(const t of neutral){for(const key of ['x','z','fire','jump','reload','sprint','crouch','interact','mobility'])assert(!t.controls[key],`held action leaked: ${key}`);}
 }
 return {status:'PASS',scenario,correlated,receipts:receipts.length,ackHighWater:Math.max(...rows.map(r=>r.ack)),won,deaths,eventTypes:[...new Set(events.map(e=>e.type))],nativeTraceCompletionProven:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const dir=process.argv[2];const read=n=>gunzipSync(readFileSync(`${dir}/${n}.gz`)).toString();const summary=JSON.parse(readFileSync(`${dir}/summary.json`));const result=validate(read('wire.jsonl').trim().split('\n').map(JSON.parse),read('native.stdout.log'),summary.scenario);writeFileSync(`${dir}/validation.json`,JSON.stringify(result,null,2));console.log(JSON.stringify(result));}
