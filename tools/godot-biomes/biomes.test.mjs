import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {BIOMES,compileBiome} from './compile.mjs';
import {parseIdentityArena} from '../../port/native-arenas/schema.mjs';
import {createNativeMatch} from '../../port/native-arenas/match.mjs';
import {floorAt,walkEdge,obstructed} from '../../game/core.mjs';
import {seededRandom,aimedControls} from '../../port/native-arenas/tests/fixtures.mjs';
import {launchOptions} from '../godot-dev/launch_options.mjs';
import {options} from '../godot-package/options.mjs';

const catalog=JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json',import.meta.url)));
for(const id of BIOMES) {
  test(`${id}: deterministic committed geometry, substantial elevation and material variety`,()=>{
    const data=compileBiome(id);
    assert.deepEqual(compileBiome(id),data);
    assert.deepEqual(JSON.parse(readFileSync(new URL(`../../godot/identity_maps/generated/${id}.json`,import.meta.url))),data);
    parseIdentityArena(data,id);
    const vertices=data.arena.terrain.surfaces.flatMap(s=>s.vertices);
    assert.ok(Math.max(...vertices.map(v=>v[1]))-Math.min(...vertices.map(v=>v[1]))>=8);
    assert.ok(new Set(data.arena.terrain.surfaces.map(s=>s.material)).size>=3);
    for(const resolve of [launchOptions,options]) assert.equal(resolve(['--experience=native-dm',`--map=${id}`],catalog).map,id);
  });
  test(`${id}: every route supports source walking and spawn exits have equal grades`,()=>{
    const {arena,routes,spawnPoints}=compileBiome(id);
    for(const route of routes) for(let i=1;i<route.points.length;i++)
      assert.ok(walkEdge(route.points[i-1],route.points[i],arena),`${route.id} segment ${i} blocked`);
    for(const p of spawnPoints) {
      assert.ok(Math.abs(floorAt(p.x,p.z,arena)-p.y)<.02);
      assert.equal(obstructed(p.x,p.y,p.z,.52,arena),false);
      assert.ok(Math.abs(floorAt(-p.x,-p.z,arena)-p.y)<.02,'opposing spawn grade differs');
    }
    // Each upper route has four separated two-way ascents, not a single choke.
    assert.equal(routes.filter(r=>r.id.startsWith('ascent-')).length,4);
    const match=createNativeMatch({mapId:id,random:seededRandom(42)});
    for(const p of spawnPoints) assert.ok(match.nav.some(n=>Math.hypot(n.x-p.x,n.z-p.z)<.2),'spawn disconnected from bot graph');
    for(const [kind,x,z] of arena.pickups) assert.ok(match.nav.some(n=>Math.hypot(n.x-x,n.z-z)<.2),`${kind} disconnected from bot graph`);
  });
  test(`${id}: normal-rate source bot combat, timed results and fresh restart`,()=>{
    const match=createNativeMatch({mapId:id,random:seededRandom(42),config:{timeLimit:60,fragLimit:50}});
    const origins=match.actors.map(a=>[a.x,a.z]);
    let moved=false,routed=false,damage=false;
    for(let i=0;i<61*60&&!match.over;i++) {
      match.step(1/60,{inputs:{0:aimedControls(match)}});
      moved ||= match.actors.slice(1).some(a=>Math.hypot(a.x-origins[a.id][0],a.z-origins[a.id][1])>3);
      routed ||= match.actors.slice(1).some(a=>a.bot.route.length>0);
      damage ||= match.events.some(e=>e.type==='damage'&&e.amount>0);
    }
    assert.ok(moved);assert.ok(routed);assert.ok(damage);
    assert.ok(match.actors.some(a=>a.shots>0));assert.ok(match.stats.kills>0);
    assert.ok(match.over);assert.ok(match.snapshot().leaders.length>0);
    const fresh=createNativeMatch({mapId:id,random:seededRandom(42)});
    assert.equal(fresh.time,0);assert.ok(fresh.actors.every(a=>a.frags===0&&a.deaths===0));
    console.log(JSON.stringify({id,nav:match.nav.length,kills:match.stats.kills,time:match.time}));
  });
}
