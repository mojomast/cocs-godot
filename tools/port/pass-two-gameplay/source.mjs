// Deterministic source-input oracles. No actor writes, teleports or native imports.
import assert from 'node:assert/strict';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {Match} from '../../../game/core.mjs';
export const operators = ['mistral','gemini','grok','deepseek','meta','claude','chatgpt'];
export const plans = Object.fromEntries(operators.map(operator => [operator, {
  operator, harness: operator === 'claude' ? 'claudecode' : 'codex', seconds: 4,
  changes: operator === 'grok' ? [[0,'crouch',true],[.7,'crouch',false]]
    : operator === 'meta' ? [[0,'crouch',true],[.1,'jump',true],[.35,'jump',false],[.35,'crouch',false]]
    : operator === 'chatgpt' ? [[0,'mobility',true],[3,'mobility',false]]
    : [[0,'jump',true],[.14,'jump',false],[.28,'jump',true],[1.85,'jump',false]],
  aim: operator === 'chatgpt' ? {yaw:-2.54,pitch:.4} : {yaw:0,pitch:0},
}]));
export function journey(operator, negative = false) {
  const plan = plans[operator];
  const match = new Match(operator, plan.harness, () => .5, 'meridian-exchange', {botCount:0,skipNav:true});
  const start = {...match.snapshot().actors[0]};
  const controls = {...plan.aim};
  const frames = [], events = new Map();
  let index = 0;
  for (let tick=0; tick<240; tick++) {
    while(index<plan.changes.length && plan.changes[index][0]<=tick/60) {
      const [,key,value]=plan.changes[index++]; controls[key]=value;
    }
    // Negative controls distinguish an early release from real charged/held use.
    const input = negative ? (operator==='grok' ? {crouch:tick<6} : operator==='chatgpt' ? {...plan.aim,mobility:tick===0} : {}) : controls;
    match.step(1/60, input);
    for(const event of match.events) if(event.actor===0) events.set(event.id,event);
    const actor=match.snapshot().actors[0];
    frames.push({tick, input:{...input}, actor});
  }
  const accepted=[...events.values()].filter(e=>e.type==='move-start');
  const end=frames.at(-1).actor;
  const result={operator,negative,start,accepted,events:[...events.values()].filter(e=>e.type!=='move-blocked'),
    maxRise:Math.max(...frames.map(f=>f.actor.y-start.y)),end,frames};
  if(negative) assert.equal(accepted.length,operator==='chatgpt'?1:0,operator+' negative activation');
  else {
    assert.ok(accepted.length>0,operator+' real input activation');
    assert.ok(result.maxRise>0,operator+' real vertical journey');
    if(operator==='grok') assert.ok(result.events.some(e=>e.type==='charge-release'));
    if(operator==='meta') assert.ok(result.events.some(e=>e.type==='slam-impact'));
    if(operator==='chatgpt') {
      assert.ok(result.events.some(e=>e.type==='grapple-release'&&['arrive','blocked'].includes(e.reason)));
      assert.ok(frames.some(f=>f.actor.movement.grappleLanding),'source resolved standable ledge');
      assert.ok(end.grounded && end.y>start.y+4,'upward mantle lands on source roof');
    }
  }
  return result;
}

export function sharedRope(negative=false) {
  const match=new Match('qwen','codex',()=>.5,'meridian-exchange',{botCount:0,skipNav:true,humanCount:2,loadouts:{1:{character:'mistral',harness:'codex'}}});
  const route=[{x:44,z:-34},{x:-44,z:-34}];
  let waypoint=0,ride=null;
  const frames=[];
  for(let tick=0;tick<2200;tick++) {
    const guest=match.actors[1], target=route[waypoint];
    let input={};
    if(target && !ride) {
      const dx=target.x-guest.x,dz=target.z-guest.z,d=Math.hypot(dx,dz);
      if(d<.4)waypoint++; else input={x:dx/d,z:dz/d};
    }
    match.step(1/60,{inputs:{0:{yaw:0,pitch:-.35,mobility:!negative&&tick===800},1:input}});
    if(guest.zipRide?.id?.startsWith('rope-')&&!ride)ride={tick,owner:match.ropeLines[0].owner,rider:guest.id,id:guest.zipRide.id};
    if(tick%6===0)frames.push({tick,actors:match.snapshot().actors,ropes:structuredClone(match.ropeLines??[])});
  }
  if(negative)assert.equal(ride,null,'without X no shared rope boarding');
  else {assert.ok(ride&&ride.owner!==ride.rider,'another player boarded');assert.equal(match.ropeLines.length,0,'source rope expires');assert.equal(match.actors[0].movement.anchor,null,'source anchor expires');}
  return {negative,ride,frames};
}

if(process.argv[1]===new URL(import.meta.url).pathname) {
  const out=resolve(process.env.EVIDENCE_DIR??'/home/mojo/.tmp-on-disk/cocs-pass-two-gameplay-evidence-20261002/source');
  mkdirSync(out,{recursive:true});
  const results=operators.map(operator=>{
    const positive=journey(operator),negative=journey(operator,true);
    writeFileSync(resolve(out,operator+'.json'),JSON.stringify({positive,negative}));
    const samples=[];
    const phases=new Set();
    for(const frame of positive.frames){const phase=frame.actor.movement.phase;if(!phases.has(phase)){samples.push(frame.actor);phases.add(phase);}}
    if(operator==='grok')samples.push(positive.frames[40].actor);
    return {operator,events:positive.events,maxRise:positive.maxRise,negativeRise:negative.maxRise,samples};
  });
  for(const negative of [false,true])writeFileSync(resolve(out,`shared-rope-${negative?'negative':'positive'}.json`),JSON.stringify(sharedRope(negative)));
  const fixture={label:'SOURCE INPUT ORACLE; NOT NATIVE ACCEPTANCE',plans,results};
  const path=new URL('../../../godot/tests/player_gameplay/second_pass_oracle.json',import.meta.url);
  const bytes=JSON.stringify(fixture,null,2)+'\n';
  if(process.argv.includes('--check'))assert.equal(readFileSync(path,'utf8'),bytes);else writeFileSync(path,bytes);
  writeFileSync(resolve(out,'summary.json'),JSON.stringify(results,null,2));
  console.log('SECOND_PASS_SOURCE_OK seven movement journeys + seven negative controls; shared guest rope + no-X control + expiration');
}
