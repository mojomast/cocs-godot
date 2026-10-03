import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {physicalIndex,standingFailure,traceRoute} from '../map_variety/navigation_audit.mjs';
const load=(id,rev)=>JSON.parse(readFileSync(`port/new-maps/${id}/variety/${rev}/authority.json`)).arena;
for(const [id,before,after] of [['helix-conservatory','revision-3','revision-4'],['parallax-observatory','districts-v3','districts-v4'],['vesper-viaduct','urban-v2','urban-v3']]) {
  const old=load(id,before),next=load(id,after);
  test(id+' preserves every U route endpoint/nav coordinate, authored and resolved heights',()=>{
    for(const r of old.routes)assert.deepEqual(next.routes.find(n=>n.id===r.id),r);
    assert.deepEqual(next.navNodes.slice(0,old.navNodes.length),old.navNodes);
    const a=physicalIndex(old),b=physicalIndex(next);
    for(const n of old.navNodes) {
      const x=n.x??n[0],z=n.z??n[1];
      const was=a.support(x,z)?.y,now=b.support(x,z)?.y;
      assert.ok(was===now||(Number.isFinite(was)&&Number.isFinite(now)&&Math.abs(was-now)<1e-8),JSON.stringify(n));
    }
    for(const key of ['spawns','teamSpawns','flagSpawns','objectiveZones'])assert.deepEqual(next[key],old[key]);
    assert.deepEqual(next.art.portals,old.art.portals);
  });
}
test('new east landing/graded connection is continuous in both directions at 10cm spacing',()=>{
  const a=load('parallax-observatory','districts-v4');
  const route=a.routes.find(r=>r.id==='court-east-connection-v4');
  assert.deepEqual(traceRoute(a,route.points,{spacing:.1}),[]);
  assert.deepEqual(traceRoute(a,[...route.points].reverse(),{spacing:.1}),[]);
  for(const [x,y] of [[32,8],[40,10],[44,12]])assert.ok(Math.abs(physicalIndex(a).support(x,-34).y-y)<1e-8);
});
test('source standing envelope covers full unchanged portal width and both approaches',()=>{
  const a=load('parallax-observatory','districts-v4');
  for(let x=44;x<=48;x+=.1)for(let z=-37;z<=-31;z+=.1)assert.equal(standingFailure(a,x,z,12),null);
});
