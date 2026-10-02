import {test} from 'node:test';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {options,ROUTES,assertPublicObservation} from './connected-native.mjs';
import {filterCocsSnapshot} from '../../game/cocs-intel.mjs';

test('all four plans select existing native routes and appropriate isolated authority',()=>{
  for(const family of Object.keys(ROUTES)) {
    const plan=options([`--family=${family}`,'--plan','--compact']);
    assert.equal(plan.family,family);assert.equal(plan.compact,true);assert.equal(plan.plan,true);
    assert.ok(existsSync('godot/'+plan.route.scene.slice('res://'.length)));
    assert.ok(existsSync(fileURLToPath(new URL(plan.route.factory,import.meta.url))));
    assert.match(plan.route.factory,['world','sports'].includes(family)?/multiplayer-worlds\/derived\//:/^\.\.\/\.\.\/server\//);
  }
  assert.throws(()=>options(['--family=campaign']),/known --family/,'solo campaign never gains an invented spectator route');
});

test('wire-vs-native privacy assertion rejects local context and private target fields',()=>{
  const source=filterCocsSnapshot({time:10,actors:[{id:0,name:'A\nName',health:100,team:0,x:2,y:1,z:3,req:777,reqBuff:{private:true}}],cocs:{intel:{0:{private:true},1:{}},req:[{id:0,amount:777}]}},null);
  const observation={spectating:true,actor:-1,kit:{},marks:{},hits:[],target:0,targets:[{id:0,name:'A Name',health:100,team:0,x:2,y:1,z:3}]};
  assertPublicObservation(observation,source);
  const corrupt=mutate=>{const copy=structuredClone(observation);mutate(copy);assert.throws(()=>assertPublicObservation(copy,source));};
  corrupt(o=>{o.actor=0;});
  corrupt(o=>{o.kit={cooldown:9};});
  corrupt(o=>{o.marks={0:10};});
  corrupt(o=>{o.hits=[{name:'Previous actor context'}];});
  corrupt(o=>{o.feedMeta=[{assist:true}];});
  corrupt(o=>{o.recap='Previous hit';});
  corrupt(o=>{o.kill='Previous kill';});
  corrupt(o=>{o.targets[0].req=777;});
  corrupt(o=>{o.targets[0].x=999;});
  corrupt(o=>{o.targets[0].id=99;});
});
