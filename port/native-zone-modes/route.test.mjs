import test from 'node:test';
import assert from 'node:assert/strict';
import {DESTINATION_COMBAT_MAPS} from '../../game/destination-combat-maps.mjs';
import {objectiveTemplate} from '../../game/mode-data.mjs';
import {groundRouteGeometry} from '../native-projectile-combat/route.mjs';
import {zoneRouter,bindRoute} from './route.mjs';
test('KOTH template route binds only exact received geometry, never inferred rotation',()=>{
  const route={start:[-28,0,30],waypoints:[[8,-4]],zone:{id:'hill',x:8,y:0,z:-4,radius:4}};
  const zone={id:'alpha',x:8,y:0,z:-4,radius:4};
  assert.equal(bindRoute(route,[zone]).zone.id,'alpha');
  for(const key of ['x','y','z','radius'])assert.ok(bindRoute(route,[{...zone,[key]:zone[key]+1}]).error);
  assert.equal(route.zone.id,'hill');
});
for(const [id,mode] of [['meridian-exchange','domination'],['verdant-reliquary','koth']])test(`${id}: every authored spawn has source-supported zone route`,()=>{
  const map=DESTINATION_COMBAT_MAPS.find(m=>m.id===id), router=zoneRouter(map), geometry=groundRouteGeometry(map), zones=objectiveTemplate(mode,map,{mode}).zones;
  for(const [x,z] of map.spawns){const result=router({x,y:0,z},zones);assert.ok(!result.error,JSON.stringify(result));let last=[x,z];for(const p of result.waypoints){assert.ok(geometry.edge(last,p),JSON.stringify({last,p}));last=p;}assert.ok(Math.hypot(last[0]-result.zone.x,last[1]-result.zone.z)<=result.zone.radius);}
});
