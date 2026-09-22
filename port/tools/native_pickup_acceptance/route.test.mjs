import test from 'node:test';
import assert from 'node:assert/strict';
import {MAPS} from '../../../game/maps.mjs';
import {planRoute} from './route.mjs';

test('recorded spawn route avoids intervening SMG and other authored pickups',()=>{
  const map=MAPS.find(m=>m.id==='meridian-exchange');
  // Genuine independent run 2026-09-22T00-09-25.115Z crossed SMG (-14,-8).
  const start=[-36,-6],goal=[-14,-19];
  const points=[start,...planRoute(map,{x:start[0],z:start[1]},goal)];
  assert.deepEqual(points.at(-1),goal);
  for(let i=1;i<points.length;i++) {
    const a=points[i-1],b=points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/.1);
    for(let k=0;k<=n;k++) {
      const x=a[0]+(b[0]-a[0])*k/n,z=a[1]+(b[1]-a[1])*k/n;
      for(const [,px,pz] of map.pickups)if(px!==goal[0]||pz!==goal[1])
        assert.ok(Math.hypot(x-px,z-pz)>=1.9,'Route overlaps unrelated pickup');
      assert.ok(!map.blocks.some(b=>Math.abs(x-b.x)<b.w/2+.8&&Math.abs(z-b.z)<b.d/2+.8));
    }
  }
});
