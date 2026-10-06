#!/usr/bin/env node
// Read-only accounting of retained input/events. No simulation or setup mutation.
import {readFileSync,mkdirSync,mkdtempSync,writeFileSync} from 'node:fs';
import {rayWorld} from '../../../game/core.mjs';
import {readBlackwater} from '../../native-horde/blackwater-schema.mjs';
import {shotActorContact} from '../../../game/shot-contact.mjs';
const attempt=process.argv[2];if(!attempt)throw Error('retained source attempt directory required');
const rows=readFileSync(`${attempt}/inputs-events.jsonl`,'utf8').trim().split('\n').map(JSON.parse);
const result=JSON.parse(readFileSync(`${attempt}/result.json`));
const recipe=readBlackwater().arena,arenas=new Map();
function arena(mask){if(!arenas.has(mask))arenas.set(mask,{...recipe,blocks:[...recipe.blocks,...recipe.hordeStagePlan.gates.filter((_,i)=>!(mask&(1<<i)))]});return arenas.get(mask);}
const waves={},targets={},summoners={};let wave=0,phase='intermission',mask=0,previous=null,lastTarget=null,window=[];
// A player shot counts as a hit shot on the authority's explicit contact, not on
// the `hit` candidate: a shot blocked before that candidate reports
// `contact:'blocked'` while still naming the candidate, so counting `hit` credits
// shots that hit cover. Producers with no classification (older cores, flak
// shrapnel) keep the legacy candidate test.
const hitShot=e=>{const actor=shotActorContact(e);return actor==null?e.hit!==false&&e.hit!==undefined:actor;};
const init=()=>({steps:0,movingFire:0,movingNoFire:0,stillFire:0,stillIdle:0,intermissionSteps:0,repairSteps:0,travelMetres:0,targetSwitches:0,shots:0,hitShots:0,geometryStoppedMisses:0,otherMisses:0,damage:0,kills:0,reloadPulses:0,reloadStarts:0,powerPulses:0,stuckWindows:[],summons:0,summonedActors:0,decisionSamples:0,occludedTargetSteps:0,outOfFireRangeSteps:0,emptyAmmoSteps:0});
for(const row of rows){
 for(const e of row.events){if(e.type==='horde-wave'){wave=e.wave;phase='wave';waves[wave]??=init();waves[wave].start=e.time;}if(e.type==='horde-wave-cleared'){(waves[e.wave]??=init()).clear=e.time;phase='intermission';}if(e.type==='mission-won'||e.type==='mission-lost')phase='terminal';if(e.type==='horde-gate-open'||e.type==='horde-gate-closed')mask=e.gateMask;}
 const w=waves[wave]??=init();w.steps++;
 const move=Math.hypot(row.input.x??0,row.input.z??0)>.01,fire=row.input.fire===true;
 w[move?(fire?'movingFire':'movingNoFire'):(fire?'stillFire':'stillIdle')]++;
 if(phase==='intermission')w.intermissionSteps++;
 if(row.route&&!row.route.startsWith('combat')&&!row.route.startsWith('transit'))w.repairSteps++;
 if(row.input.reload)w.reloadPulses++;if(row.input.power)w.powerPulses++;
 if(row.decision){w.decisionSamples++;if(row.decision.target!==null&&!row.decision.visible)w.occludedTargetSteps++;if(row.decision.distance>=65)w.outOfFireRangeSteps++;if(row.decision.ammo===0)w.emptyAmmoSteps++;}
 if(previous?.position&&row.position)w.travelMetres+=Math.hypot(row.position[0]-previous.position[0],row.position[2]-previous.position[2]);
 const target=row.route?.startsWith('combat-')?Number(row.route.slice(7)):null;
 if(target!==null){const t=targets[target]??={steps:0,fireSteps:0,movingSteps:0,first:row.sourceTime,last:row.sourceTime};t.steps++;t.fireSteps+=Number(fire);t.movingSteps+=Number(move);t.last=row.sourceTime;}
 if(target!==lastTarget&&target!==null)w.targetSwitches++;lastTarget=target;
 for(const e of row.events){
  if(e.type==='shot'&&e.actor===0){w.shots++;if(hitShot(e))w.hitShots++;else{
   const dx=e.to.x-e.from.x,dy=e.to.y-e.from.y,dz=e.to.z-e.from.z,d=Math.hypot(dx,dy,dz);
   const stop=d>0?rayWorld(e.from,{x:dx/d,y:dy/d,z:dz/d},d+.03,arena(mask)):Infinity;
   if(stop<=d+.02)w.geometryStoppedMisses++;else w.otherMisses++;
  }}
  if(e.type==='damage'&&e.source===0)w.damage+=e.amount;
  if(e.type==='death'&&e.killer===0)w.kills++;
  if(e.type==='reload'&&e.actor===0&&e.state==='start')w.reloadStarts++;
  if(e.type==='boss-summon'){w.summons++;w.summonedActors+=e.count;const s=summoners[e.actor]??={first:e.time,last:e.time,count:0,actors:0};s.last=e.time;s.count++;s.actors+=e.count;}
 }
 window.push({row,move,wave});
 if(window.length===60){const first=window[0],last=window.at(-1);if(first.wave===wave&&first.row.position&&last.row.position&&window.filter(r=>r.move).length>=45){
  const displacement=Math.hypot(last.row.position[0]-first.row.position[0],last.row.position[2]-first.row.position[2]);
  if(displacement<.25)w.stuckWindows.push({start:first.row.sourceTime,end:last.row.sourceTime,position:first.row.position,route:first.row.route,displacement});
 }window=[];}
 previous=row;
}
const report={attempt,definitions:{dt:1/60,moving:'nonzero requested movement',fireWindow:'input.fire true, not an actual shot',travel:'sum of successive source player X/Z positions',stuck:'disjoint 60-step windows: >=45 moving inputs and net displacement <0.25m; can include oscillation',geometryStoppedMiss:'player shot the authority did not classify as an actor/vehicle/sentry contact (contact world or blocked, or hit=false/absent on producers with no classification) with source ray geometry at its recorded endpoint within .02m; does not prove pre-shot target occlusion',unavailable:'old trace has no per-step enemy/ammo snapshots: exact target-LOS rejection and empty-ammo dwell cannot be reconstructed',moveBlocked:'source move-blocked reason=firing is grapple admission, NOT wall collision'},waves,targets,summoners,
 upgrades:result.events.filter(e=>e.type==='controller-upgrade'),weaponSwitches:result.events.filter(e=>e.type==='weapon-switch'&&e.actor===0),moveBlockedReasons:{}};
for(const e of result.events.filter(e=>e.type==='move-blocked'&&e.actor===0))report.moveBlockedReasons[e.reason]=(report.moveBlockedReasons[e.reason]??0)+1;
for(const [id,s] of Object.entries(summoners)){s.targeting=targets[id]??null;s.firstDamage=result.events.find(e=>e.type==='damage'&&e.actor===Number(id)&&e.source===0)?.time;s.death=result.events.find(e=>e.type==='death'&&e.actor===Number(id));}
const root='/home/mojo/.tmp-on-disk/cocs-expansion-three-horde-evidence-20261002';mkdirSync(root,{recursive:true});const out=mkdtempSync(`${root}/trace-analysis-`);
writeFileSync(`${out}/analysis.json`,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({out,waves:Object.fromEntries(Object.entries(waves).map(([id,w])=>[id,{...w,stuckWindows:w.stuckWindows.length}])),summoners,upgrades:report.upgrades,weaponSwitches:report.weaponSwitches},null,2));
