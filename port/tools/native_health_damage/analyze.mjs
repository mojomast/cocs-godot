// Correlation patterns from native_death_respawn 1d5a3dd and
// native_trace_correlation fbc8345: adjacent synchronous observer seq association,
// fresh-round successful queue ordinal inference. No completion inference.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {pathToFileURL} from 'node:url';
const controls=['x','z','yaw','pitch','fire','jump','reload','sprint','crouch','interact','mobility'];
const near=(a,b,tolerance=1e-5)=>Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=tolerance;
const target=p=>p.kind==='health'&&p.x===-6&&p.z===22;
const distance=(a,p)=>Math.hypot(a.x-p.x,a.y-p.y,a.z-p.z);
export function analyze(stdout,wire,{hudMode='current'}={}){
 assert.ok(['current','legacy'].includes(hudMode));
 const records=[],associated=[],observations=[];let monotonic=-1,previous=null,latestSnapshot=null,latestDamageId=-1;
 for(const [i,line] of stdout.split('\n').entries()){
  if(line.startsWith('PORT_NATIVE_TRACE ')){
   const r=JSON.parse(line.slice(18));assert.equal(r.schema,1);assert.equal(r.sequence,records.length,'trace sequence gap/limit');
   assert.ok(Number.isSafeInteger(r.monotonic_usec)&&r.monotonic_usec>=monotonic);monotonic=r.monotonic_usec;
   assert.ok(['round_start','snapshot','input_queue'].includes(r.event),'error/limit/unknown native trace');
   assert.equal(r.round,1);assert.equal(r.actor_id,wire.actor);assert.equal(r.phase,3);
   previous={...r,line:i+1};records.push(previous);
  }else if(line.startsWith('HEALTH_CORRELATE ')){
   const o=JSON.parse(line.slice(17));assert.equal(previous?.line,i,'observer must immediately follow runtime handler');
   assert.equal(previous.event,o.event==='start'?'round_start':'snapshot');associated.push({...o,nativeSequence:previous.sequence,line:i+1});
   if(o.event==='snapshot')latestSnapshot=associated.at(-1);
  }else if(line.startsWith('HEALTH_OBSERVE ')){
   const o=JSON.parse(line.slice(15));
   if(o.event==='events')for(const e of o.items)if(e.type==='damage'&&e.actor===wire.actor&&e.amount>0)latestDamageId=e.id;
   if(o.event==='hud_render'){
    assert.equal(o.seq,latestSnapshot?.seq,'HUD observation must associate with latest snapshot at rendered frame');
    assert.equal(o.native_sequence,latestSnapshot?.nativeSequence,'HUD native trace association');
    assert.equal(o.damage_event_id,latestDamageId,'HUD damage event association');
   }
   observations.push(o);
  }
 }
 assert.equal(wire.connections,2);assert.equal(wire.joins,1);assert.equal(wire.mappingChanges,0);assert.equal(wire.unexpected.length,0);assert.equal(wire.results,0);
 assert.ok(Number.isSafeInteger(wire.actor)&&wire.actor>=0);assert.ok(Number.isSafeInteger(wire.attackerActor)&&wire.actor!==wire.attackerActor);
 assert.equal(wire.starts.length,1);assert.equal(records[0]?.event,'round_start');assert.equal(records.filter(r=>r.event==='round_start').length,1);assert.equal(records[0].complete,false);
 const start=associated.filter(o=>o.event==='start');assert.equal(start.length,1);assert.equal(start[0].actor_id,wire.actor);assert.equal(start[0].mapId,'meridian-exchange');assert.equal(start[0].roundRevision,wire.starts[0].roundRevision);
 const cfg=wire.config;assert.equal(cfg.mode,'deathmatch');assert.equal(cfg.botCount,0);assert.equal(cfg.damage,1);assert.equal(cfg.speed,1);assert.equal(cfg.gravity,1);assert.deepEqual(cfg.mutators,[]);
 for(const key of ['oneShot','instagib','lifeSteal','randomLoadout','berserk','bounty'])assert.equal(cfg[key],false,`unsupported config ${key}`);
 const natives=records.filter(r=>r.event==='snapshot'),obs=associated.filter(o=>o.event==='snapshot'),index=new Map(wire.snapshots.map(w=>[w.seq,w]));
 assert.equal(natives.length,obs.length);assert.ok(natives.length>=30);let seq=-1,time=-1,ack=0,marker=null,pickupId=null;
 const matched=natives.map((r,i)=>{
  const o=obs[i],w=index.get(o.seq);assert.ok(w,'server snapshot association missing');assert.equal(o.nativeSequence,r.sequence);
  assert.ok(o.seq>seq&&o.time>=time);seq=o.seq;time=o.time;assert.equal(o.time,w.time);assert.equal(o.over,false);assert.equal(w.over,false);
  assert.equal(o.actor_id,wire.actor);assert.deepEqual(o.actor,w.actor);assert.ok(w.actor.health>0&&w.actor.dead===0,'native victim must remain alive');
  assert.equal(r.health,w.actor.health);assert.equal(r.dead,0);assert.equal(r.lifecycle,'alive');assert.equal(r.pose_present,true);
  ack=Math.max(ack,w.ack);assert.equal(r.ack,ack);assert.equal(o.ack,ack);
  const p=w.pickups.find(target);assert.ok(p);assert.deepEqual(o.pickup,p);
  pickupId??=p.id;assert.equal(p.id,pickupId,'same health pickup ID');marker??=o.marker_instance;assert.ok(marker>0);assert.equal(o.marker_instance,marker,'same native marker instance');
  assert.deepEqual(o.marker_position,[-6,p.y+1,22]);assert.equal(o.marker_visible,p.wait<=0,'marker agrees with authoritative wait');
   const hp=/\| HP ([\d.eE+-]+) \| Armor ([\d.eE+-]+)/.exec(o.hud);assert.ok(hp,'native diagnostic HUD format');assert.ok(near(Number(hp[1]),w.actor.health));assert.ok(near(Number(hp[2]),w.actor.armor));assert.ok(o.label.includes(o.hud),'legacy diagnostic text contains authoritative HUD (visibility not inferred)');
  return {r,o,w,p};
 });
 const queues=records.filter(r=>r.event==='input_queue');assert.equal(queues.length,wire.inputs.length,'unmatched/inflight receipt tail');
 queues.forEach((r,i)=>{const w=wire.inputs[i];assert.equal(w.seq,i+1);assert.equal(r.queued,true);assert.equal(r.queue_result,0);for(const k of controls)assert.equal(r.controls[k],w.input[k],`input receipt seq ${i+1} ${k}`);assert.equal(r.controls.fire,false,'native victim never fires');});
 const events=wire.events,damage=events.filter(e=>e.type==='damage'&&e.actor===wire.actor&&e.amount>0);
 assert.ok(damage.length>0,'positive authoritative damage');assert.ok(damage.every(e=>e.source===wire.attackerActor));assert.ok(!events.some(e=>e.type==='death'&&e.actor===wire.actor));
 const nativeEvents=observations.filter(o=>o.event==='events');
 for(const e of damage){const batch=nativeEvents.find(o=>o.items.some(n=>n.id===e.id));assert.ok(batch,'native received positive damage event');assert.deepEqual(batch.items.find(n=>n.id===e.id),e);assert.ok(batch.hurts>0&&batch.hurt_remaining>0&&batch.combat_text.includes('TAKING DAMAGE'),'combat.apply_events/text produced hurt feedback');}
  const hudFrames=observations.filter(o=>o.event==='hud_render');
  let hurtUI;
  if(hudMode==='current'){
   assert.ok(hudFrames.length>=30,'missing current rendered HUD observations');
   let renderFrame=-1;
   for(const h of hudFrames){
    const w=index.get(h.seq);assert.ok(w,'HUD snapshot missing');assert.deepEqual(h.actor,w.actor,'HUD actor authority association');assert.equal(h.time,w.time);
    assert.equal(h.schema,1);assert.equal(h.mode,'compact-default');assert.equal(h.post_draw,true,'HUD must be observed after render');
    assert.ok(Number.isSafeInteger(h.render_frame)&&h.render_frame>renderFrame,'HUD rendered frame order');renderFrame=h.render_frame;
    for(const k of ['layer_visible','root_visible','vitals_visible'])assert.equal(h[k],true,`HUD ${k}`);
    assert.equal(h.legacy_label_visible,false);assert.equal(h.legacy_combat_visible,false);
    for(const k of ['health_label','armor_label','health_bar','armor_bar']){
     assert.equal(h[k]?.visible,true,`HUD ${k} visible`);assert.equal(h[k].in_viewport,true,`HUD ${k} in viewport`);
     assert.ok(h[k].rect?.length===4&&h[k].rect.every(Number.isFinite)&&h[k].rect[2]>0&&h[k].rect[3]>0,`HUD ${k} nonempty geometry`);
    }
    assert.equal(h.health_label.text,`HEALTH  ${Math.trunc(w.actor.health)}`,'HUD health integer value');
    assert.equal(h.armor_label.text,`ARMOR  ${Math.trunc(w.actor.armor)}`,'HUD armor integer value');
    assert.equal(h.health_bar.max,Math.max(1,w.actor.maxHealth??100),'HUD health maximum');assert.equal(h.armor_bar.max,100,'HUD armor reference maximum');
    // Godot Range's stock 0.01 step rounds gauges, not authoritative actors.
    // Bound the half-step tolerance explicitly; evidence cannot widen it.
    for(const k of ['health_bar','armor_bar'])assert.ok(h[k].step===0||h[k].step===0.01,`HUD ${k} supported precision`);
    assert.ok(near(h.health_bar.value,Math.min(h.health_bar.max,Math.max(0,w.actor.health)),h.health_bar.step/2+1e-5), 'HUD health bar authority');
    assert.ok(near(h.armor_bar.value,Math.min(100,Math.max(0,w.actor.armor)),h.armor_bar.step/2+1e-5), 'HUD armor bar authority');
    if(h.image){assert.ok(['baseline.png','hurt.png','collected.png'].includes(h.image));assert.equal(h.image_result,0,'HUD image save');}
   }
   hurtUI=hudFrames.find(h=>h.overlay?.visible===true&&h.overlay.in_viewport===true&&h.overlay.rect[2]>0&&h.overlay.rect[3]>0&&h.hurts>0&&h.hurt_remaining>0&&h.hurt_strength>0&&h.hurt_strength<=1&&near(h.overlay_draw_hurt,h.hurt_strength)&&h.overlay_draw_frame===h.render_frame&&damage.some(e=>e.id===h.damage_event_id)&&h.image==='hurt.png');
   assert.ok(hurtUI,'actual combat overlay hurt must be visible and drawn in captured rendered frame');
  }else{
   assert.equal(hudFrames.length,0,'current HUD evidence cannot be downgraded to legacy');
   hurtUI=observations.find(o=>o.event==='frame'&&o.hurts>0&&o.hurt_remaining>0&&o.combat_text.includes('TAKING DAMAGE')&&o.ui_text.includes('TAKING DAMAGE'));
   assert.ok(hurtUI,'legacy actual combat Label text evidence (visibility not recorded)');
  }
 assert.ok(wire.attackStop&&wire.attackStop.health>0&&wire.attackStop.health<wire.attackStop.maxHealth);
 const attackTail=wire.attackerInputs.filter(i=>i.seq>=wire.attackStop.nextInputSeq);assert.ok(attackTail.length>20&&attackTail.every(i=>!i.input.fire),'incoming fire stopped');
 const approach=wire.routes.find(r=>r.stage==='approach'),leave=wire.routes.find(r=>r.stage==='leave');assert.ok(approach&&leave,'both physical movement routes issued');
 assert.ok(approach.time-wire.attackStop.time>=1,'nonlethal stabilization before movement');
 assert.ok(damage.every(e=>e.time<approach.time),'no new incoming damage during pickup route');
 const before=matched.find(x=>x.w.time<damage[0].time),injured=matched.find(x=>x.w.time>=approach.time);
 assert.ok(before&&injured&&injured.w.actor.health<before.w.actor.health);
 // Default chatgpt/adaptive has no armor regeneration or review absorb pool.
 // Refuse to apply this narrow accounting model to other modifier/config cases.
 const combatWindow=matched.filter(x=>x.w.time>=before.w.time&&x.w.time<=injured.w.time);
 for(const x of combatWindow){
  for(const a of [x.w.actor,x.w.attacker]){
   assert.equal(a.character,'chatgpt');assert.equal(a.harness,'openclaw');assert.equal(a.verbState?.verb,'adaptive');
   assert.equal(a.active,0);assert.equal(a.braceTimer,0);assert.equal(a.damageMultiplier,1);assert.equal(a.gearDamage,1);assert.equal(a.cocsArrival,null);assert.equal(a.npcShield,null);
  }
  assert.equal(x.w.actor.temporaryShield,0);assert.equal(x.w.actor.juggernautShield,0);
 }
 const b=before.w.actor,a=injured.w.actor,healthLoss=b.health-a.health,armorLoss=b.armor-a.armor;
 const total=damage.reduce((n,e)=>n+e.amount,0),tolerance=.002*(damage.length+1);
 assert.ok(healthLoss>0&&armorLoss>=0);assert.ok(damage.every(e=>e.shield===0));assert.ok(near(total,healthLoss+armorLoss,tolerance),'damage event total reconciles HP plus armor loss, not HP alone');
 const collectedIndex=matched.findIndex(x=>x.p.wait>0);assert.ok(collectedIndex>0,'target pickup wait transitioned');
 const prior=matched[collectedIndex-1],collected=matched[collectedIndex],returned=matched.slice(collectedIndex+1).find(x=>x.p.wait===0);
 assert.ok(returned,'authoritative health return observed');assert.equal(prior.p.wait,0);
 assert.ok(prior.w.actor.health<prior.w.actor.maxHealth);assert.ok(near(collected.w.actor.health,Math.min(prior.w.actor.maxHealth,prior.w.actor.health+35),.002),'source health +35 capped at maxHealth');
 assert.equal(collected.w.actor.armor,prior.w.actor.armor);assert.ok(distance(collected.w.actor,collected.p)<1.5,'exclusive target proximity at collection');
 const pickupEvents=events.filter(e=>e.type==='pickup'&&e.actor===wire.actor&&e.kind==='health');assert.equal(pickupEvents.length,1,'exactly one local health pickup');
 const pickupEvent=pickupEvents[0];assert.ok(pickupEvent.time>prior.w.time&&pickupEvent.time<=collected.w.time);
 const otherHealthChanges=prior.w.pickups.filter(p=>p.kind==='health'&&p.id!==pickupId&&collected.w.pickups.find(q=>q.id===p.id)?.wait!==p.wait);assert.equal(otherHealthChanges.length,0,'no ambiguous other-health transition');
 const nativePickupEvent=nativeEvents.find(o=>o.items.some(e=>e.id===pickupEvent.id));assert.ok(nativePickupEvent);assert.deepEqual(nativePickupEvent.items.find(e=>e.id===pickupEvent.id),pickupEvent);
 const hidden=matched.filter(x=>x.w.seq>=collected.w.seq&&x.w.seq<returned.w.seq);assert.ok(hidden.every(x=>x.p.wait>0&&!x.o.marker_visible));
 assert.ok(collected.p.wait>=11.9&&collected.p.wait<=12);
 for(const x of hidden)assert.ok(near(x.w.time+x.p.wait,pickupEvent.time+12,.035),'authority countdown follows simulation time');
 const returnDuration=returned.w.time-pickupEvent.time;assert.ok(returnDuration>=11.998&&returnDuration<=12.067,'12 simulation second authority return');
 const left=observations.find(o=>o.event==='left_radius');assert.ok(left&&left.seq>collected.w.seq&&left.seq<returned.w.seq);
 const outside=matched.filter(x=>x.w.seq>=left.seq&&x.w.seq<=returned.w.seq);assert.ok(outside.length>=100&&outside.every(x=>distance(x.w.actor,x.p)>1.05),'remained outside collection radius until return');
  assert.ok(returned.o.marker_visible);assert.equal(returned.p.id,pickupId);
  if(hudMode==='current'){
   for(const [name,select] of [
    ['baseline',h=>h.time<damage[0].time],
    ['injured',h=>h.time>=approach.time&&h.seq<collected.w.seq],
    ['collected',h=>h.seq>=collected.w.seq&&h.seq<returned.w.seq],
    ['returned',h=>h.seq>=returned.w.seq],
   ])assert.ok(hudFrames.some(select),`missing ${name} rendered HUD observation`);
  }
 const collectionTrace=collected.r.sequence,routeQueues=queues.filter(q=>q.sequence<collectionTrace&&q.controls.x*q.controls.x+q.controls.z*q.controls.z>.01);
 assert.ok(routeQueues.length>20,'real native movement packets');assert.ok(Math.hypot(collected.w.actor.x-b.x,collected.w.actor.z-b.z)>2,'authoritative native displacement');
 assert.ok(observations.some(o=>o.event==='physical_key'&&o.key==='W'&&o.pressed&&o.engine_held));assert.ok(observations.some(o=>o.event==='mouse_motion'));
 const end=observations.filter(o=>o.event==='harness_end');assert.equal(end.length,1);assert.equal(end[0].stage,'returned');assert.equal(end[0].reason,'return_window');assert.equal(end[0].completionProven,false);
 const witness=x=>({snapshotSeq:x.w.seq,nativeTraceSequence:x.r.sequence,time:x.w.time,health:x.w.actor.health,maxHealth:x.w.actor.maxHealth,armor:x.w.actor.armor,position:[x.w.actor.x,x.w.actor.y,x.w.actor.z],pickupId:x.p.id,wait:x.p.wait,markerVisible:x.o.marker_visible,markerInstance:x.o.marker_instance,hud:x.o.hud});
  return {status:'PASS',hudAcceptance:{mode:hudMode==='current'?'compact-default-rendered':'historical-legacy-text-only',currentHUDProven:hudMode==='current',legacyVisibilityProven:false,renderedObservations:hudFrames.length,images:hudFrames.filter(h=>h.image)},actor:wire.actor,attacker:wire.attackerActor,roundRevision:wire.starts[0].roundRevision,completionProven:false,
  counts:{nativeRecords:records.length,correlatedSnapshots:matched.length,receivedInputs:queues.length,damageEvents:damage.length,nativeMovementInputsBeforeCollection:routeQueues.length,hiddenPickupSnapshots:hidden.length,outsideRadiusSnapshots:outside.length},
   damage:{firstEventId:damage[0].id,lastEventId:damage.at(-1).id,eventAmountTotal:total,healthLoss,armorLoss,temporaryShieldLoss:0,juggernautShieldLoss:0,reviewPoolLoss:0,quantizationTolerance:tolerance,attackerStoppedAt:wire.attackStop,hurtUI,baseline:witness(before),injured:witness(injured),modifierScope:'deathmatch damage=1; chatgpt/adaptive + openclaw; active=0, brace=0, gearDamage=1, damageMultiplier=1; no temporary/juggernaut/review pool, NPC shield, arrival modifier or mutators; actual emitted damage already includes weapon falloff/handling'},
  healthPickup:{id:pickupId,eventId:pickupEvent.id,eventTime:pickupEvent.time,expectedGain:Math.min(prior.w.actor.maxHealth,prior.w.actor.health+35)-prior.w.actor.health,observedGain:collected.w.actor.health-prior.w.actor.health,returnSimulationSeconds:returnDuration,before:witness(prior),collected:witness(collected),returned:witness(returned)},
  ackHighWater:ack,receiptNotIndividualApplication:true,nativeGraphicalFocusAcceptance:false,harnessBoundary:end[0]};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  try{const dir=process.argv[2],result=analyze(gunzipSync(readFileSync(`${dir}/native.stdout.log.gz`)).toString(),JSON.parse(gunzipSync(readFileSync(`${dir}/wire.json.gz`))),{hudMode:process.argv.includes('--legacy-hud')?'legacy':'current'});console.log(JSON.stringify(result,null,2));}
 catch(e){console.error(e.stack);process.exitCode=1;}
}
