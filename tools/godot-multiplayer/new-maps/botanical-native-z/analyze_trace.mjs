// Read-only native trace analysis plus explicitly labelled source headroom rays.
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {inputs} from '../botanical-post-x/movement.mjs';
import {ensureTerrainBvh,terrainRayHitFast} from '../../../../game/terrain-bvh.mjs';
const root=new URL('../../../../',import.meta.url);
const path='godot/tests/new_maps/botanical_post_x/vesper-Z-01/';
const raw=readFileSync(new URL(path+'accepted-civic-r035-journey.json',root));
const d=JSON.parse(raw),binding=JSON.parse(readFileSync(new URL(path+'accepted-civic-r035-binding.json',root)));
assert.equal(d.failed,true);assert.equal(d.records.length,10);assert.deepEqual(d.binding,binding.binding);
assert.equal(d.binding.bindingReady,true);assert.equal(d.binding.bothVariantsRuntimeVerified,true);
const {accepted,candidate}=inputs();const bvh=ensureTerrainBvh(accepted.arena.terrain);
const step=accepted.arena.terrain.surfaces.find(s=>s.id==='civic-stair-0');
const triangles=s=>s.triangles.map(t=>t.map(i=>s.vertices[i]));
assert.deepEqual(triangles(step),triangles(candidate.arena.terrain.surfaces.find(s=>s.id===step.id)));
const trials=[];let headroomRays=0,headroomHits=0;
for(const r of d.records){
 const t=r.frames,up=r.trial.goal[2]>r.trial.start[2],p=r.parameters;
 assert.equal(p.sprint,false);assert.equal(p.jump,false);assert.ok(Math.abs(p.physicsShape.radius-.35)<1e-7);
 let maxRise=0,maxDrop=0,maxHorizontal=0,maxXDrift=0,grounded=0,maxPhysicsGap=0,collisions=0;
 for(let i=0;i<t.length;i++){
  const f=t[i];assert.equal(f.clock.inPhysicsFrame,true);assert.equal(f.clock.physicsTicksPerSecond,60);assert.equal(f.clock.timeScale,1);
  assert.equal(f.resetCount,1);assert.ok(f.position.every(Number.isFinite));
  if(i){const gap=f.clock.physicsFrame-t[i-1].clock.physicsFrame;assert.equal(gap,1);maxPhysicsGap=Math.max(maxPhysicsGap,gap);assert.deepEqual(f.before,t[i-1].position);}
  maxRise=Math.max(maxRise,f.position[1]-f.before[1]);maxDrop=Math.max(maxDrop,f.before[1]-f.position[1]);
  maxHorizontal=Math.max(maxHorizontal,Math.hypot(f.position[0]-f.before[0],f.position[2]-f.before[2]));
  maxXDrift=Math.max(maxXDrift,Math.abs(f.position[0]-r.trial.start[0]));
  grounded+=Number(f.grounded);collisions+=f.collisions.length;
  for(const [dx,dz] of [[0,0],[-.35,-.35],[-.35,.35],[.35,-.35],[.35,.35]]){
   headroomRays++;
   if(terrainRayHitFast(bvh,{x:f.position[0]+dx,y:f.position[1]+.25,z:f.position[2]+dz},{x:0,y:1,z:0},1.8-.25))headroomHits++;
  }
 }
 const last=t.at(-1),firstContact=t.find(f=>f.collisions.some(c=>c.collider==='civic-stair-0Collider'));
 assert.equal(r.reached,!up);
 if(up){assert.equal(r.stalledFrames,120);assert.equal(t.length,127);assert.ok(last.collisions.every(c=>c.collider==='civic-stair-0Collider'));assert.deepEqual(last.velocity,[0,0,0]);}
 else{assert.equal(last.grounded,true);assert.ok(Math.hypot(last.position[0]-r.trial.goal[0],last.position[2]-r.trial.goal[2])<.15);assert.ok(Math.abs(last.position[1]-r.trial.goal[1])<=p.safeMargin+.001);}
 trials.push({id:r.trial.id,start:r.trial.start,goal:r.trial.goal,direction:up?'uphill':'downhill',reached:r.reached,
  frames:t.length,stalledFrames:r.stalledFrames,groundedFrames:grounded,collisionRecords:collisions,maxRise,maxDrop,maxHorizontal,maxXDrift,
  maxConsecutivePhysicsFrameGap:maxPhysicsGap,firstInputPhysicsFrame:t[0].clock.physicsFrame,lastInputPhysicsFrame:last.clock.physicsFrame,
  elapsedInputSeconds:(last.clock.physicsFrame-t[0].clock.physicsFrame+1)/60,wallUsecSpan:last.clock.monotonicUsec-t[0].clock.monotonicUsec,
  finalPosition:last.position,finalVelocity:last.velocity,finalSupport:last.support,finalSupportCollider:last.supportCollider,
  firstStair0Contact:firstContact??null,finalCollisions:last.collisions,
  finalContactAnglesDegrees:last.collisions.map(c=>Math.acos(Math.max(-1,Math.min(1,c.normal[1])))*180/Math.PI)});
}
assert.equal(headroomHits,0);
const report={scope:'Native trace analysis; headroom rays are source-only, not a native/full finite-capsule clearance gate',
 nativeTraceSha256:createHash('sha256').update(raw).digest('hex'),nativeGroup:'accepted-civic-r035',groupFailed:true,
 passed:5,failed:5,unrunGroups:['accepted-civic-r042','candidate-civic-r035','candidate-civic-r042','candidate-roof-r035','candidate-roof-r042'],unrunTrials:50,
 inputFrames:trials.reduce((n,t)=>n+t.frames,0),settleSteps:200,headroomRays,headroomHits,headroomRadius:.35,headroomVerticalBand:[.25,1.8],
 firstTread:step,firstTreadIdenticalInCandidate:true,trialSummaries:trials,
 conclusion:'Accepted exploration walker stalls on the first .15m tread: rounded lower-cap contact normal exceeds its 46-degree floor angle. It has no explicit step-up. Highest-floor authoritative JS stepping is a distinct solver. No candidate movement run, geometry change or static-contact waiver follows.'};
writeFileSync(new URL('evidence/trace-analysis.json',import.meta.url),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({passed:report.passed,failed:report.failed,unrun:report.unrunTrials,inputFrames:report.inputFrames,headroomRays,headroomHits}));
