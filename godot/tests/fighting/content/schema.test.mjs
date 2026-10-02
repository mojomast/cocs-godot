import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { schema } from '../../../../tools/fighting/content/schema.mjs';
import { expandTrace } from '../../../../tools/fighting/content/trace.mjs';
import { validate, validateManifest, fingerprint, readJSON, verifyFreeze } from '../../../../tools/fighting/content/validate.mjs';
const root=fileURLToPath(new URL('../../../../',import.meta.url));
const roster=readJSON('godot/fighting/data/roster.json'),rules=readJSON('godot/fighting/data/rules.json');
const mutate=fn=>{const r=structuredClone(roster),s=structuredClone(rules);fn(r,s);return validate(r,s);};
const manifestMutation=fn=>{const m=readJSON('port/fighting/content/ANIMATION_COVERAGE.json');fn(m);return validateManifest(roster,m);};
const mechanics=['projectile','movement','throw','counter','resource_effect','armor','stance','input'];
const fixtureFor=(mechanic,field)=>{
 for(let i=0;i<roster.operators.length;i++)for(const [key,m]of Object.entries(roster.operators[i].moves))if(m[mechanic]&&Object.hasOwn(m[mechanic],field))return {i,key};
 throw new Error(`No authored fixture for ${mechanic}.${field}`);
};
for(const mechanic of mechanics){
 const definition=schema.$defs[mechanic]??schema.$defs.move.properties[mechanic];
 for(const [field,shape]of Object.entries(definition.properties)){
  const {i,key}=fixtureFor(mechanic,field);
  test(`strict type for existing ${mechanic}.${field}`,()=>{
   const wrong=shape.type==='boolean'?1:shape.type==='integer'?'1':shape.type==='string'?false:[];
   assert.ok(mutate(r=>{r.operators[i].moves[key][mechanic][field]=wrong;}).some(e=>e.includes(`${mechanic}.${field}`)),`${mechanic}.${field} wrong type accepted`);
  });
  if(definition.required.includes(field))test(`missing required ${mechanic}.${field}`,()=>assert.ok(mutate(r=>{delete r.operators[i].moves[key][mechanic][field];}).some(e=>e.includes(`missing ${field}`))));
  if(shape.type==='integer')test(`finite safe integer/range for ${mechanic}.${field}`,()=>{
   for(const bad of [NaN,Infinity,-Infinity,1.25,Number.MAX_SAFE_INTEGER+1,shape.minimum-1,shape.maximum+1])assert.ok(mutate(r=>{r.operators[i].moves[key][mechanic][field]=bad;}).some(e=>e.includes(`${mechanic}.${field}`)),`${mechanic}.${field} accepted ${bad}`);
  });
  if(shape.enum)test(`unknown enum for ${mechanic}.${field}`,()=>assert.ok(mutate(r=>{r.operators[i].moves[key][mechanic][field]='unsupported';}).some(e=>e.includes('unknown enum'))));
 }
 test(`unknown key rejected inside ${mechanic}`,()=>{
  const {i,key}=fixtureFor(mechanic,Object.keys(definition.properties)[0]);
  assert.ok(mutate(r=>{r.operators[i].moves[key][mechanic].unsupported_mechanic=1;}).some(e=>e.includes('unsupported_mechanic: unknown key')));
 });
}
test('unknown move scalar and unknown dynamic move key rejected',()=>{
 assert.ok(mutate(r=>{r.operators[0].moves.stand_l.unsupported=1;}).some(e=>e.includes('unsupported: unknown key')));
 assert.ok(mutate(r=>{r.operators[0].moves.secret_move=structuredClone(r.operators[0].moves.stand_l);}).some(e=>e.includes('unknown move key')));
});
test('known scalar flags and knockdown are typed/bounded',()=>{
 for(const field of ['air_ok','ground_ok'])assert.ok(mutate(r=>{r.operators[0].moves.stand_l[field]='false';}).some(e=>e.includes(field)));
 for(const bad of [false,NaN,Infinity,-1,61])assert.ok(mutate(r=>{r.operators[0].moves.super.knockdown_frames=bad;}).some(e=>e.includes('knockdown_frames')));
});
test('malformed required containers return diagnostics rather than throwing',()=>{
 for(const bad of [null,[],1,'roster'])assert.ok(validate(bad,rules).length>0);
 assert.ok(mutate(r=>{r.operators[0].moves=null;}).length>0);
 assert.ok(mutate(r=>{delete r.operators[0].moves.special1;}).some(e=>e.includes('missing special1')));
});
test('conflicting restrictions and invalid invulnerability pairs rejected',()=>{
 assert.ok(mutate(r=>{r.operators[6].moves.special2.movement.ground_only=true;}).some(e=>e.includes('contradictory')));
 assert.ok(mutate(r=>{r.operators[7].moves.special2.movement.invulnerable_from=0;}).some(e=>e.includes('disabled pair')));
 assert.ok(mutate(r=>{const m=r.operators[7].moves.special2.movement;m.invulnerable_from=12;m.invulnerable_to=10;}).some(e=>e.includes('invulnerability to')));
 assert.ok(mutate(r=>{delete r.operators[0].moves.special2.movement.pull_speed;}).some(e=>e.includes('pull')));
});
test('charge frames and direction are required together',()=>assert.ok(mutate(r=>{delete r.operators[5].moves.special1.input.charge_axis;}).some(e=>e.includes('charge requires'))));
test('recognized movement members cannot silently attach to unsupported operations',()=>{
 assert.ok(mutate(r=>{r.operators[7].moves.special2.movement.pull_speed=50;}).some(e=>e.includes('only belongs to pull movement')));
 assert.ok(mutate(r=>{r.operators[7].moves.special2.movement.reset_on_land=true;}).some(e=>e.includes('only belongs to air movement')));
 assert.ok(mutate(r=>{r.operators[7].moves.special2.movement.anchor_life=30;}).some(e=>e.includes('only belongs to anchor')));
});
test('stance mappings cannot reference unlisted variants',()=>assert.ok(mutate(r=>{r.operators[4].moves.special2.stance.variants.stand_m='unlisted';}).some(e=>e.includes('variant mapping'))));
test('unrecognized universal state, duplicate state and non-string state rejected',()=>{
 for(const bad of ['unsupported_state','idle',1])assert.ok(manifestMutation(m=>{m.operators[0].states[1]=bad;}).some(e=>e.includes('state')));
 assert.ok(manifestMutation(m=>{m.operators[0].states.pop();}).some(e=>e.includes('state')));
});
test('manifest contact/projectile/movement/counter windows must match actual data',()=>{
 assert.ok(manifestMutation(m=>{m.operators[0].combat[0].contact_windows[0][0]++;}).some(e=>e.includes('contact_windows')));
 assert.ok(manifestMutation(m=>{m.operators[0].combat.find(c=>c.clip==='special1').projectile_spawn++;}).some(e=>e.includes('projectile_spawn')));
 assert.ok(manifestMutation(m=>{m.operators[0].combat.find(c=>c.clip==='special2').movement_window[1]++;}).some(e=>e.includes('movement_window')));
 assert.ok(manifestMutation(m=>{m.operators[1].combat.find(c=>c.clip==='special3').counter_window[1]++;}).some(e=>e.includes('counter_window')));
});
test('paired victim timings/placement and clip identity must agree with move',()=>{
 for(const field of ['damage','release','contact','victim_x','victim_y'])assert.ok(manifestMutation(m=>{m.paired_timelines[0][field]++;}).length>0);
 assert.ok(manifestMutation(m=>{m.paired_timelines[0].release=1;}).some(e=>e.includes('chronology')));
 assert.ok(manifestMutation(m=>{m.paired_timelines[0].side_swap='true';}).some(e=>e.includes('side_swap')));
 assert.ok(manifestMutation(m=>{m.operators[0].victim_clips[0]='wrong_clip';}).some(e=>e.includes('victim clip')));
 assert.ok(manifestMutation(m=>{m.paired_timelines[0].clip=m.paired_timelines[1].clip;}).some(e=>e.includes('paired timeline coverage')));
});
test('move throw and counter timelines reject contradictory damage/release',()=>{
 assert.ok(mutate(r=>{r.operators[0].moves.throw_f.throw.release_frame=1;}).some(e=>e.includes('release time')));
 assert.ok(mutate(r=>{r.operators[1].moves.special3.counter.damage_frame=1;}).some(e=>e.includes('counter damage')));
});
test('fingerprints include all gameplay fields and ignore only presentation fields',()=>{
 const move=roster.operators[0].moves.stand_l;
 for(const field of ['level','cancels','meter_gain','meter_cost','pushback','launch_velocity','juggle_cost','chip','resource_effect','input','air_ok','ground_ok']){
  const other=structuredClone(move);other[field]=field==='cancels'?[]:field==='input'?{...other.input,motion:'new command'}:field==='resource_effect'?{resource:'adaptation',cost:1,gain:0,on:'start',reset_on_land:false}:typeof other[field]==='number'?other[field]+1:typeof other[field]==='boolean'?!other[field]:'overhead';
  assert.notEqual(fingerprint(move),fingerprint(other),`${field} omitted from fingerprint`);
 }
 const renamed={...move,name:'New art label',animation:'another',effect:'another',description:'Different prose',counterplay:'Different prose'};
 assert.equal(fingerprint(move),fingerprint(renamed));
 assert.equal(fingerprint(move),fingerprint(Object.fromEntries(Object.entries(move).reverse())));
});
test('sparse one-tick inputs release naturally; hold duration creates only one edge',()=>{
 const combo={setup_inputs:[],inputs:[{tick:1,axis_x:0,axis_y:-1,held:1,pressed:1,duration:3},{tick:5,axis_x:1,axis_y:1,held:1,pressed:1}]};
 const inputs=expandTrace(combo);
 assert.deepEqual(inputs.map(i=>i.held),[0,1,1,1,0,1,0]);
 assert.deepEqual(inputs.map(i=>i.pressed),[0,1,0,0,0,1,0]);
 assert.equal(inputs[1].axis_y,-1);assert.equal(inputs[5].axis_y,1);
 assert.equal(expandTrace(combo,-1)[5].axis_x,-1);
});
test('pressed hints cannot invent an edge, repeat held edges or claim unheld buttons',()=>{
 for(const samples of [[{tick:0,axis_x:0,axis_y:0,held:0,pressed:1}],[{tick:0,axis_x:0,axis_y:0,held:1,pressed:1},{tick:1,axis_x:0,axis_y:0,held:1,pressed:1}]])assert.throws(()=>expandTrace({setup_inputs:[],inputs:samples}),/held rising edge/);
 assert.ok(mutate(r=>{r.operators[0].combos[0].inputs[0].pressed=2;}).some(e=>e.includes('held rising edge')));
});
test('invalid durations, overlaps and wrong axis types rejected',()=>{
 for(const duration of [0,-1,Infinity,1.5])assert.ok(mutate(r=>{r.operators[0].combos[0].inputs[0].duration=duration;}).some(e=>e.includes('duration')));
 assert.ok(mutate(r=>{r.operators[0].combos[0].inputs[0].duration=100;}).some(e=>e.includes('overlap')));
 assert.ok(mutate(r=>{r.operators[0].combos[0].inputs[0].axis_y='down';}).some(e=>e.includes('axis_y')));
});
test('all 27 authored traces expand canonically for both facing directions',()=>{
 for(const op of roster.operators)for(const combo of op.combos){const normal=expandTrace(combo),mirror=expandTrace(combo,-1);assert.equal(normal.length,mirror.length);normal.forEach((sample,i)=>{assert.equal(sample.axis_x,-mirror[i].axis_x);assert.equal(sample.axis_y,mirror[i].axis_y);assert.equal(sample.held,mirror[i].held);});}
});
test('machine schema export is current and freeze excludes all working prose',()=>{
 assert.deepEqual(readJSON('godot/fighting/data/schema.json'),schema);
 const freeze=readJSON('port/fighting/content/FREEZE.json');
 assert.ok(Object.keys(freeze.source_files).every(path=>!path.endsWith('.md')));
 assert.ok(freeze.source_files['tools/fighting/content/balance_targets.json']);
 const changedHistory=structuredClone(freeze);changedHistory.historical_provenance.initial_design_sha256='historical-only';
 assert.deepEqual(verifyFreeze(changedHistory),[]);
});
test('fresh generator output exactly reproduces current runtime/data artifacts',()=>{
 const temp=mkdtempSync('/tmp/opencode/fighting-content-regen-');
 try{
  const run=spawnSync(process.execPath,['tools/fighting/content/author.mjs',temp],{cwd:root,encoding:'utf8'});assert.equal(run.status,0,run.stdout+run.stderr);
  for(const path of ['godot/fighting/data/roster.json','godot/fighting/data/rules.json','godot/fighting/data/schema.json','port/fighting/content/ANIMATION_COVERAGE.json','port/fighting/content/COMBO_ESTIMATES.json','port/fighting/content/MOVE_LIST.md','port/fighting/content/FREEZE.json'])assert.equal(readFileSync(`${temp}/${path}`,'utf8'),readFileSync(root+path,'utf8'),`${path} regen drift`);
 }finally{rmSync(temp,{recursive:true,force:true});}
});
