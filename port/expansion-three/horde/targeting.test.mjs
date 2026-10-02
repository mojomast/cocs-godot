import test from 'node:test';
import assert from 'node:assert/strict';
import {JourneyController} from './controller.mjs';
import {visible} from '../../../game/core.mjs';
import {readBlackwater} from '../../native-horde/blackwater-schema.mjs';

// Exact coordinates from unmodified-input deterministic replay tick 33126.
// Synthetic read-only snapshots here are regression fixtures, not completion.
const player={id:0,x:-185.613847556862,y:0,z:-64.17147040363324,health:100,weapon:0,ammo:['∞']};
const mender={id:75,x:-148.75055402387315,y:0,z:60.379256372326964,health:55,isNpc:true};
const husk={id:67,x:109.00962070728008,y:0,z:-60.00019293027138,health:30,isNpc:true};
const arena=readBlackwater().arena; // gate mask 3 = base geometry, both gates open
const sight=a=>visible({...player,y:player.y+1.45},{...a,y:a.y+1.2},arena);
const snapshot=enemies=>({time:552.0999999998265,actors:[structuredClone(player),...structuredClone(enemies)],
 singleplayer:{stage:{stageId:'C',gateMask:3},upgrades:[]},blackwater:{active:null,completed:['north-feeder','south-feeder','switch-pump','relief-valve'],stations:[]}});

test('retained wave-nine geometry: visible 294.65m enemy must not displace the nearer navigation target',()=>{
 assert.equal(sight(mender),false);assert.equal(sight(husk),true);
 const state=snapshot([mender,husk]),before=structuredClone(state);
 const command=new JourneyController().sample(state);
 assert.equal(command.route,'combat-75','the old controller selects combat-67 across the map and cannot fire');
 assert.equal(command.input.fire,false);
 assert(Math.hypot(command.input.x,command.input.z)>0,'ordinary movement pursues the nearer enemy');
 assert.deepEqual(state,before,'controller only reads the snapshot');
});

test('a sole distant visible enemy remains a valid navigation destination',()=>{
 const command=new JourneyController().sample(snapshot([husk]));
 assert.equal(command.route,'combat-67');assert.equal(command.input.fire,false);
 assert(Math.hypot(command.input.x,command.input.z)>0);
});

test('visible enemy inside the existing fire window still wins target selection',()=>{
 const nearby={...husk,x:player.x+3,z:player.z};assert.equal(sight(nearby),true);
 const command=new JourneyController().sample(snapshot([mender,nearby]));
 assert.equal(command.route,'combat-67');assert.equal(command.input.fire,true);
});

test('source close-combat contract aims at visibility height and releases sprint while approaching',()=>{
  const nearby={...husk,x:player.x+25,z:player.z};
  const state=snapshot([nearby]),before=structuredClone(state);
  const command=new JourneyController().sample(state);
  assert.equal(Object.hasOwn(command.input,'sprint'),false,'source omits inactive sprint');
  assert.equal(command.keys.includes('ShiftLeft'),false);
  assert.equal(command.mouse.pitch,Math.atan2(1.2-1.45,25));
  assert.notEqual(command.mouse.pitch,Math.atan2(.9-1.45,25));
  assert.deepEqual(state,before);
});
