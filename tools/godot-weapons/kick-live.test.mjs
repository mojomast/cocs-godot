// Source-only construction/input contracts. Does not listen on sockets or run Godot.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Match, obstructed} from '../../game/core.mjs';
import {setup} from './kick-live-server.mjs';

function fixture(scenario = 'chain') {
  const match = new Match('chatgpt','openclaw',()=>.5,'meridian-exchange',
    {mode:'deathmatch',botCount:1,humanCount:1,timeLimit:60,fragLimit:20});
  const initial = setup(match, scenario);
  const [local,target] = match.actors;
  const input = (value = {}, ticks = 1) => {
    for(let i=0;i<ticks;i++)match.step(1/60,{inputs:{[local.id]:{yaw:0,pitch:0,...value}}});
  };
  const events = () => match.events.filter(e=>e.type==='melee' && e.actor===local.id);
  return {match,initial,local,target,input,events};
}

test('live placement is clear on actual shipped map; ordinary inputs produce 55,10,0 health',()=>{
  const {match,initial,local,target,input,events} = fixture();
  assert.equal(initial.sourceTime,0);
  assert.equal(target.bot,false);
  for(const actor of [local,target])assert.equal(obstructed(actor.x,actor.y,actor.z,.4,match.arena),false);
  assert.equal(match.visible({x:local.x,y:1,z:local.z},{x:target.x,y:1,z:target.z}),true);
  const health = [];
  for(let strike=0;strike<3;strike++) {
    input({melee:true});
    health.push(target.health);
    input({},21);
    // Same feedback-controlled approach as native W: ordinary movement only.
    for(let n=0;Math.hypot(local.x-target.x,local.z-target.z)>=1.45 && n<36;n++)input({z:-1});
    input({});
  }
  assert.equal(events().length,3);
  assert.deepEqual(events().map(e=>e.outcome),['hit','hit','hit']);
  assert.deepEqual(health,[55,10,0]);
  assert.ok(events().slice(1).every((e,i)=>e.time-events()[i].time>=.3 && e.time-events()[i].time<=.85));
});

test('early press remains consumed past cooldown; blocked fixture never changes health',()=>{
  const {target,input,events} = fixture('blocked');
  input({melee:true});input({},2);input({melee:true},25);
  assert.equal(events().length,1);
  input({});input({melee:true});
  assert.equal(events().length,2);
  assert.deepEqual(events().map(e=>e.outcome),['blocked','blocked']);
  assert.equal(target.health,100);
  input({},20);input({yaw:Math.PI,melee:true});
  assert.equal(events().at(-1).outcome,'miss');
});

test('live observer cannot stage events, poses, authority actions or actor state',()=>{
  const source=readFileSync(new URL('../../godot/tests/first_person/kick_live.gd',import.meta.url),'utf8');
  for(const forbidden of [/\.apply_events\(/,/\.apply_actor\(/,/\.advance\(/,/\.apply_pose\(/,/\.send_frame\(/,/\.kick_motion\b/,/\.local_actor\s*=/,/\.yaw\s*=/,/\.pitch\s*=/])assert.doesNotMatch(source,forbidden);
  assert.match(source,/Input\.parse_input_event/);
  assert.match(source,/RenderingServer\.frame_post_draw/);
  assert.match(source,/40000/);
});
