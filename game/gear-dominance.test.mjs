// §4.8 gear: asymmetric but testable. This file is the automated gate for the
// item pool (declared power/cost axes, slot budget parity, in-slot
// non-dominance) and for the envelope caps resolveGear enforces on every
// caller. §10.1 S8 upgrades scope, heavy-barrel and servo and pins their stat
// vectors; the other five launch items keep their pre-overhaul raw modifiers,
// and the career-expansion items are pinned in the EXPECTED_CAREER table so a
// catalog diff stays deliberate and tested.
import test from 'node:test';
import assert from 'node:assert/strict';
import {Match} from './core.mjs';
import {GEAR,GEAR_AXES,GEAR_BUDGET,GEAR_CAPS,GEAR_SLOTS,MAX_LEVEL,gearBudget,gearById,resolveGear} from './progression.mjs';

// Ids present in the launch catalogue. These are pinned byte-for-byte by the
// tests below; the career-expansion items are appended and may be re-tuned as a
// deliberate catalog diff (this table must be updated when they are).
const LAUNCH_GEAR=['scope','heavy-barrel','light-frame','plating','reactive','stim','servo','mag'];
const EXPECTED_CAREER={
 'runner-frame':{slot:'primary',level:12,powerAxis:'mobility',costAxis:'offense',vector:{health:0,armor:0,speed:1.08,damage:.95,spread:1}},
 'match-trigger':{slot:'primary',level:15,powerAxis:'handling',costAxis:'offense',vector:{health:0,armor:0,speed:1,damage:.91,spread:.86}},
 'breacher-kit':{slot:'primary',level:23,powerAxis:'offense',costAxis:'mobility',vector:{health:0,armor:0,speed:.92,damage:1.12,spread:1.03}},
 'siege-kit':{slot:'primary',level:26,powerAxis:'offense',costAxis:'handling',vector:{health:0,armor:0,speed:1,damage:1.13,spread:1.10}},
 'marksman-kit':{slot:'primary',level:40,powerAxis:'handling',costAxis:'offense',vector:{health:0,armor:0,speed:1,damage:.90,spread:.85}},
 'command-kit':{slot:'primary',level:50,powerAxis:'offense',costAxis:'mobility',vector:{health:0,armor:0,speed:.95,damage:1.08,spread:.95}},
 'scout-plate':{slot:'armor',level:5,powerAxis:'mobility',costAxis:'offense',vector:{health:0,armor:4,speed:1.06,damage:.94,spread:1}},
 'gunner-harness':{slot:'armor',level:10,powerAxis:'handling',costAxis:'offense',vector:{health:0,armor:5,speed:1,damage:.91,spread:.88}},
 'assault-plate':{slot:'armor',level:18,powerAxis:'offense',costAxis:'mobility',vector:{health:0,armor:0,speed:.93,damage:1.1,spread:1}},
 'field-medic-rig':{slot:'utility',level:8,powerAxis:'ehp',costAxis:'handling',vector:{health:12,armor:3,speed:1,damage:1,spread:1.11}},
 'overcharge-cell':{slot:'utility',level:13,powerAxis:'offense',costAxis:'mobility',vector:{health:0,armor:0,speed:.94,damage:1.09,spread:1}},
  'route-servo':{slot:'utility',level:17,powerAxis:'mobility',costAxis:'handling',vector:{health:0,armor:0,speed:1.07,damage:1,spread:1.05}},
  'brace-satchel':{slot:'utility',level:21,powerAxis:'handling',costAxis:'offense',vector:{health:0,armor:0,speed:1,damage:.93,spread:.90}},
 'targeting-uplink':{slot:'utility',level:50,powerAxis:'handling',costAxis:'mobility',vector:{health:0,armor:0,speed:.92,damage:1,spread:.88}},
 'fortress-plate':{slot:'armor',level:35,powerAxis:'ehp',costAxis:'handling',vector:{health:11,armor:4,speed:1,damage:1,spread:1.09}},
};

const EPS=1e-9;
const AXES=['health','armor','speed','damage','spread'];
const statVector=item=>{
 const modifiers=item?.modifiers||{},read=(axis,fallback)=>Number.isFinite(modifiers[axis])?modifiers[axis]:fallback;
 return {health:read('health',0),armor:read('armor',0),speed:read('speed',1),damage:read('damage',1),spread:read('spread',1)};
};
// Spread is the one axis where lower is better; everything else is higher.
const atLeast=(a,b,axis)=>axis==='spread'?a[axis]<=b[axis]+EPS:a[axis]>=b[axis]-EPS;
const better=(a,b,axis)=>axis==='spread'?a[axis]<b[axis]-EPS:a[axis]>b[axis]+EPS;
const dominates=(a,b)=>AXES.every(axis=>atLeast(a,b,axis))&&AXES.some(axis=>better(a,b,axis));

test('every item declares a power axis, a different cost axis and its slot budget',()=>{
 for(const item of GEAR){
  assert.ok(GEAR_AXES.includes(item.powerAxis),`${item.id} has a power axis`);
  assert.ok(GEAR_AXES.includes(item.costAxis),`${item.id} has a cost axis`);
  assert.notEqual(item.powerAxis,item.costAxis,`${item.id} power and cost axes differ`);
  assert.equal(item.budget,GEAR_BUDGET[item.slot],`${item.id} declares its slot budget`);
 }
});

test('same-slot items share one net budget and none overspends it',()=>{
 assert.deepEqual({...GEAR_BUDGET},{primary:15,armor:25,utility:24});
 for(const slot of GEAR_SLOTS){
  const items=GEAR.filter(item=>item.slot===slot.id),budget=GEAR_BUDGET[slot.id];
  assert.ok(items.length>=2,`${slot.id} keeps competing items`);
  for(const item of items)assert.ok(gearBudget(item).net<=budget+EPS,`${item.id} net ${gearBudget(item).net} exceeds ${budget}`);
  assert.ok(items.some(item=>Math.abs(gearBudget(item).net-budget)<=EPS),`${slot.id} budget is reached`);
 }
});

test('the §10.1 S8 upgrades pay for their power (cost ≥60% of power)',()=>{
 for(const id of ['scope','heavy-barrel','servo']){
  const spend=gearBudget(gearById(id));
  assert.ok(spend.power>0,`${id} spends on its power axis`);
  assert.ok(spend.cost>=.6*spend.power-EPS,`${id} cost ${spend.cost} is under 60% of power ${spend.power}`);
 }
});

test('no item dominates any other on every axis',()=>{
 // §4.8's normative rule is in-slot (same-budget) dominance; checking the whole
 // pool is stricter and catches cross-slot god items too.
 for(const a of GEAR)for(const b of GEAR){
  if(a.id===b.id)continue;
  assert.ok(!dominates(statVector(a),statVector(b)),`${a.id} strictly dominates ${b.id}`);
 }
});

test('the three S8-upgraded stat vectors are pinned',()=>{
 assert.deepEqual(statVector(gearById('scope')),{health:0,armor:0,speed:.9,damage:1.1,spread:.85});
 assert.deepEqual(statVector(gearById('heavy-barrel')),{health:0,armor:0,speed:.97,damage:1.15,spread:1.1});
 assert.deepEqual(statVector(gearById('servo')),{health:0,armor:0,speed:1.1,damage:1,spread:1.07});
 const solo=id=>resolveGear([id]).modifiers;
 for(const id of ['scope','heavy-barrel','servo'])assert.deepEqual(statVector({modifiers:solo(id)}),statVector(gearById(id)),`${id} resolves exactly as declared`);
});

test('the five non-upgraded items keep their pre-overhaul raw modifiers',()=>{
 assert.deepEqual(gearById('light-frame').modifiers,{damage:1.08,spread:.9,armor:-5});
 assert.deepEqual(gearById('plating').modifiers,{armor:25,speed:.98});
 assert.deepEqual(gearById('reactive').modifiers,{armor:15,health:10});
 assert.deepEqual(gearById('stim').modifiers,{health:20,speed:1.04});
 assert.deepEqual(gearById('mag').modifiers,{spread:.92,speed:.99});
});

test('resolveGear enforces the §4.8 envelope caps on every loadout',()=>{
 assert.deepEqual({...GEAR_CAPS},{offense:1.15,mobility:1.1,ehp:15,spread:.85,handling:.9});
 const bySlot=GEAR_SLOTS.map(slot=>GEAR.filter(item=>item.slot===slot.id));
 const loadouts=[[]];
 for(const primary of bySlot[0])for(const armor of bySlot[1])for(const utility of bySlot[2])loadouts.push([primary.id,armor.id,utility.id]);
 loadouts.push(['scope','heavy-barrel'],['scope','mag'],['heavy-barrel','mag'],['servo','stim'],['plating','stim']);
 for(const ids of loadouts){
  const label=ids.join('+')||'empty',modifiers=resolveGear(ids).modifiers;
  assert.ok(modifiers.damage<=GEAR_CAPS.offense+EPS,`${label} damage ${modifiers.damage}`);
  assert.ok(modifiers.speed<=GEAR_CAPS.mobility+EPS,`${label} speed ${modifiers.speed}`);
  assert.ok(modifiers.spread>=GEAR_CAPS.spread-EPS,`${label} spread floor ${modifiers.spread}`);
  assert.ok(modifiers.spread<=1/GEAR_CAPS.handling+EPS,`${label} handling floor ${modifiers.spread}`);
  assert.ok(modifiers.health+modifiers.armor<=GEAR_CAPS.ehp+EPS,`${label} pooled EHP ${modifiers.health+modifiers.armor}`);
  assert.ok(modifiers.health>=0&&modifiers.armor>=0,`${label} pools stay non-negative`);
 }
 assert.equal(resolveGear(['scope','heavy-barrel']).modifiers.damage,GEAR_CAPS.offense,'duplicate primaries cannot pass the offense cap');
 assert.equal(resolveGear(['scope','mag']).modifiers.spread,GEAR_CAPS.spread,'stacked accuracy cannot pass the spread floor');
 assert.equal(resolveGear(['servo','stim']).modifiers.speed,GEAR_CAPS.mobility,'stacked mobility cannot pass the mobility cap');
 const pooled=resolveGear(['plating','stim']).modifiers;
 assert.ok(Math.abs(pooled.health+pooled.armor-GEAR_CAPS.ehp)<EPS,'stacked EHP is trimmed to the pooled cap');
});

test('resolveGear keeps its merge contract, freezes the result and stays deterministic',()=>{
 const list=resolveGear(['scope','plating','stim']),keyed=resolveGear({primary:'scope',armor:'plating',utility:'stim'});
 assert.deepEqual(keyed.modifiers,list.modifiers);
 assert.deepEqual(list.items.map(item=>item.id),['scope','plating','stim']);
 assert.deepEqual(Object.keys(list.modifiers).sort(),['armor','damage','health','speed','spread']);
 assert.deepEqual(resolveGear(['scope','plating','stim']).modifiers,list.modifiers);
 assert.equal(resolveGear(['nope','']).items.length,0);
 assert.ok(Object.isFrozen(list)&&Object.isFrozen(list.items)&&Object.isFrozen(list.modifiers));
 assert.throws(()=>{list.modifiers.damage=9;},TypeError);
});

test('the career catalogue is pinned, per-slot real and spread through the cap',()=>{
 // Every non-launch item is deliberate: a new id without a pinned table entry
 // fails here, so the catalogue cannot silently grow with untested items.
 const launch=new Set(LAUNCH_GEAR);
 const career=GEAR.filter(item=>!launch.has(item.id));
 assert.ok(career.length>=12,'the career catalogue adds real per-slot choice');
 assert.deepEqual(career.map(item=>item.id).sort(),Object.keys(EXPECTED_CAREER).sort());
 for(const item of GEAR){
  assert.ok(Number.isInteger(item.level)&&item.level>=1&&item.level<=MAX_LEVEL,`${item.id} level in range`);
 }
 for(const slot of GEAR_SLOTS){
  const items=GEAR.filter(item=>item.slot===slot.id);
  assert.ok(items.length>=5,`${slot.id} offers a real choice`);
  const levels=items.map(item=>item.level);
  assert.equal(new Set(levels).size,levels.length,`${slot.id} levels are unique`);
  assert.ok(Math.min(...levels)<=6,`${slot.id} opens early in the career`);
 }
 assert.ok(career.some(item=>item.level>=40),'a late-career reward exists near the cap');
 for(const [id,expected] of Object.entries(EXPECTED_CAREER)){
  const item=gearById(id);
  assert.ok(item,`${id} exists`);
  assert.equal(item.slot,expected.slot,`${id} slot`);
  assert.equal(item.level,expected.level,`${id} level`);
  assert.equal(item.powerAxis,expected.powerAxis,`${id} power axis`);
  assert.equal(item.costAxis,expected.costAxis,`${id} cost axis`);
  assert.deepEqual(statVector(item),expected.vector,`${id} vector`);
 }
});

test('every career item pays a real cost and keeps cost >= 60% of power',()=>{
 const launch=new Set(LAUNCH_GEAR);
 for(const item of GEAR){
  const spend=gearBudget(item);
  assert.ok(spend.power>0,`${item.id} spends on its power axis`);
  if(launch.has(item.id))continue;
  assert.ok(spend.cost>0,`${item.id} declares a real cost axis`);
  assert.ok(spend.cost>=.6*spend.power-EPS,`${item.id} cost ${spend.cost} is under 60% of power ${spend.power}`);
  assert.ok(spend.net<=GEAR_BUDGET[item.slot]+EPS,`${item.id} stays under its slot budget`);
 }
});

test('career items resolve solo to their declared vector under the caps',()=>{
 const launch=new Set(LAUNCH_GEAR);
 for(const item of GEAR){
  if(launch.has(item.id))continue;
  // No career item declares past an envelope cap, so a solo resolve is exact.
  assert.deepEqual(statVector({modifiers:resolveGear([item.id]).modifiers}),statVector(item),`${item.id} resolves exactly`);
 }
});

test('equipped career gear changes the live spawned actor envelope',()=>{
 const spawn=gear=>new Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'deathmatch',botCount:0,loadouts:{0:{character:'chatgpt',harness:'openclaw',gear}}}).actors[0];
 const base=spawn(undefined);
 const scout=spawn({armor:'scout-plate'});
 assert.ok(scout.gearSpeed>base.gearSpeed,'scout plate raises the live gear speed');
 assert.ok(scout.gearDamage<base.gearDamage,'scout plate trades live gear damage');
 assert.ok(scout.armor>base.armor,'scout plate adds live spawn armour');
 const fortress=spawn({armor:'fortress-plate'});
 assert.ok(fortress.maxHealth>base.maxHealth,'fortress plate raises live spawn health');
 assert.ok(fortress.armor>base.armor,'fortress plate raises live spawn armour');
 assert.ok(fortress.gearSpread>base.gearSpread,'fortress plate trades live spread control');
 const overcharge=spawn({utility:'overcharge-cell'});
 assert.ok(overcharge.gearDamage>base.gearDamage,'overcharge cell raises live gear damage');
 assert.ok(overcharge.gearSpeed<base.gearSpeed,'overcharge cell taxes live gear speed');
 const gunner=spawn({armor:'gunner-harness'});
 assert.ok(gunner.gearSpread<base.gearSpread,'gunner harness tightens live spread');
 assert.ok(gunner.gearDamage<base.gearDamage,'gunner harness trades live gear damage');
 assert.ok(gunner.armor>base.armor,'gunner harness adds live spawn armour');
});
