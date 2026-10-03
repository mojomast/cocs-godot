import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {planJourney} from './journey-plan.mjs';
import {EventCursor} from '../../../port/native-arenas/event-cursor.mjs';
import {recipes} from './recipe.mjs';
const read=p=>readFileSync(new URL('../../../'+p,import.meta.url));
const catalog=JSON.parse(read('godot/biomes/expansion/catalog.json'));
test('native-reviewed exterior relief remains inside unchanged collision envelopes',()=>{
 for(const assembly of recipes())for(const part of assembly.parts)for(const [x,y,z] of part.vertices){
  assert.ok(Math.abs(x)<=.5&&y>=0&&y<=1&&Math.abs(z)<=.5,assembly.id+'/'+part.name);
  assert.ok(Math.abs(z)>=.474,'Relief must sit outside retained main facade');
 }
});
test('four connected source-clear itineraries bind six actual LOD names and both workshops; no authority runs',()=>{
 for(const id of Object.keys(catalog.chapters)){
  const raw=read(`godot/campaign/generated/${id}.json`),data=JSON.parse(raw),plan=planJourney(data,catalog,raw);
  assert.equal(plan.assets.length,3);assert.equal(plan.workshops.length,2);assert.ok(plan.clearanceSamples>100);
  assert.deepEqual(plan.stages.at(-1).point,plan.start);
  for(const workshop of plan.workshops)assert.ok(plan.stages.some(s=>s.kind==='interact'&&s.id===workshop&&s.stage===2));
  const wrong=structuredClone(catalog);wrong.chapters[id].geometryHash='0'.repeat(64);
  assert.throws(()=>planJourney(data,wrong,raw));
  assert.throws(()=>planJourney(data,catalog,Buffer.concat([raw,Buffer.from(' ')])));
 }
});
test('production adapter has one post-validation publication boundary and synchronous owned cleanup',()=>{
 const source=read('godot/biomes/expansion/scenery_pack.gd').toString();
 assert.equal((source.match(/loaded_assets\.assign/g)??[]).length,1);
 assert.ok(source.indexOf('loaded_assets.assign(selected)')>source.indexOf('pending.append(instance)'));
 assert.doesNotMatch(source,/loaded_assets\.append|queue_free\(/);
 assert.match(source,/not resource is PackedScene/);assert.match(source,/not node is Node3D/);
 assert.match(source,/material\.duplicate\(\)/);assert.match(source,/for child: Node3D in _installed/);
 const driver=read('godot/tests/biome_assets/connected_journey.gd').toString();
 assert.match(driver,/Input\.parse_input_event/);assert.match(driver,/rows\.leave\.pressed\.emit/);
 assert.doesNotMatch(driver,/session\.(yaw|pitch)\s*=|global_position\s*=|\.process_mode\s*=|solo.cheat|checkpointPoint/);
});
test('public workshop completion uses preserved sourceId, not the finite wire event ordinal',()=>{
 const [event]=new EventCursor().take({events:[{id:'nursery',type:'campaign-interlude',completed:true}]});
 assert.equal(event.id,1);assert.equal(event.sourceId,'nursery');
 assert.match(read('godot/tests/biome_assets/connected_journey.gd').toString(),/e\.get\("sourceId"\)==id/);
 assert.match(read('tools/godot-biomes/expansion/connected-journey.mjs').toString(),/workshops\.push\(event\.sourceId\)/);
});
