import assert from 'node:assert/strict';
const close=(a,b)=>typeof a==='number'&&typeof b==='number'&&Math.abs(a-b)<1e-5;
export function validate(wire,stdout,map,mode){
  const natives=stdout.split('\n').filter(l=>l.startsWith('ZONE_NATIVE ')).map(l=>JSON.parse(l.slice(12)));
  const queued=stdout.split('\n').filter(l=>l.startsWith('PORT_NATIVE_TRACE ')).map(l=>JSON.parse(l.slice(18))).filter(r=>r.event==='input_queue');
  const snapshots=wire.filter(f=>f.type==='snapshot'&&f.recipient===0), index=new Map(snapshots.map(f=>[`${f.round}:${f.seq}`,f]));
  let correlated=0;
  for(const native of natives){if(native.seq<0||!native.projection.zones)continue;const source=index.get(`${native.round}:${native.seq}`);assert.ok(source,'same recipient/round/sequence');assert.equal(source.state.mapId,map);assert.equal(source.state.config.mode,mode);
    assert.equal(native.rendered.length,source.state.objectives.zones.length);
    for(const zone of native.rendered){const z=source.state.objectives.zones.find(z=>z.id===zone.id);assert.ok(z);for(const key of ['x','y','z','radius','progress','captureSeconds'])assert.ok(close(zone[key],z[key]),key);for(const key of ['owner','captureTeam','contested'])assert.equal(zone[key],z[key]);}
    assert.ok(close(native.projection.time,source.state.time));for(let i=0;i<2;i++)assert.ok(close(native.projection.scores[i],source.state.teamScores[i]));
    assert.ok(source.state.actors.some(a=>a.id===native.actor_id));correlated++;
  }
  assert.ok(correlated>30,'rendered source correlation');
  const received=wire.filter(f=>f.type==='received'&&f.frame.type==='input');
  assert.ok(queued.some(q=>q.queued&&Math.hypot(q.controls.x,q.controls.z)>.5),'native movement queued');
  assert.ok(received.some(q=>Math.hypot(q.frame.input.x,q.frame.input.z)>.5),'movement received');
  const results=wire.filter(f=>f.type==='results'&&f.recipient===0);assert.equal(results.length,1);assert.ok(results[0].state.over);assert.ok(results[0].state.time>=60&&results[0].state.time<=76);
  assert.equal(wire.filter(f=>f.type==='start'&&f.recipient===0).length,2);
  assert.ok(stdout.includes('ZONE_LIVE_OK '));
  const state=snapshots.filter(f=>f.round===1).map(f=>f.state), end=results[0].state;
  const nativeCapture=end.actors[0].scoreStats.objectiveCaptures>0,nativeHeldScore=end.actors[0].scoreStats.objectiveTime>=1;
  // Transitions are authoritative objective/actor stats, never ACK-based claims.
  const captureTransition=state.some((s,i)=>i>0&&s.objectives.zones.some(z=>z.owner===0&&state[i-1].objectives.zones.some(p=>p.id===z.id&&p.owner===null)));
  const scoredInside=state.some((s,i)=>i>0&&s.teamScores[0]>state[i-1].teamScores[0]&&s.objectives.zones.some(z=>z.owner===0&&!z.contested&&Math.hypot(s.actors[0].x-z.x,s.actors[0].z-z.z)<=z.radius&&Math.abs(s.actors[0].y-z.y)<=5));
  if(nativeCapture)assert.ok(captureTransition);if(nativeHeldScore)assert.ok(scoredInside);
  const centers=[...new Set(state.flatMap(s=>s.objectives.zones.map(z=>`${z.id}:${z.x}:${z.y}:${z.z}`)))];
  if(mode==='koth')assert.ok(centers.length>=2,'source hill rotation reflected');
  return{recipient:0,map,mode,correlatedSnapshots:correlated,queuedInputs:queued.length,receivedInputs:received.length,ackHighwater:Math.max(...natives.map(n=>n.ack)),ackMeaning:'input receipt only',nativeCapture,nativeHeldScore,captureTransition,scoredInside,naturalResults:results.length,restartStarts:2,finalScore:end.teamScores,winner:end.winner,sourceTime:end.time,centers,contestedLive:state.some(s=>s.objectives.zones.some(z=>z.contested)),traceComplete:false};
}
