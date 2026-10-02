import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {robotHitVolume} from '../../../port/native-campaign/enemies.mjs';
import {ROBOT_FOR_ROLE, ROBOT_SILHOUETTE, hordeRobotState} from '../../../port/native-horde/robot-roles.mjs';
import {eye, aim} from '../../../game/core.mjs';

const root=fileURLToPath(new URL('../../../', import.meta.url));
const contract=JSON.parse(readFileSync(root+'godot/robot_assets/switchyard/contract.json'));
const recipe=()=>JSON.parse(execFileSync('python3',[root+'tools/godot-robots/recipe.py'],{encoding:'utf8'}));
const pack=recipe();
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,`${a} != ${b}`);
function compare(a,b){for(const k of Object.keys(b))typeof b[k]==='object'?compare(a[k],b[k]):near(a[k],b[k]);}
function origin(r,j){const joint=r.joints[j];const p=joint.parent?origin(r,joint.parent):[0,0,0];return p.map((v,i)=>v+joint.at[i]);}
function bounds(p){
  if(p.size)return [p.p.map((v,i)=>v-p.size[i]/2),p.p.map((v,i)=>v+p.size[i]/2)];
  // Conservative radial envelope; bevel removes material and cannot enlarge it.
  return [p.a.map((v,i)=>Math.min(v,p.b[i])-p.radius),p.a.map((v,i)=>Math.max(v,p.b[i])+p.radius)];
}
function checkBody(r){
  const c=contract.authority.campaignContact[r.role], s=contract.authority.campaignScale[r.role];
  for(const p of r.pieces.filter(p=>['Chassis','Turret'].includes(p.joint))){
    const o=origin(r,p.joint), [lo,hi]=bounds(p).map(b=>b.map((v,i)=>(v+o[i])*s));
    const mn=[c.offsetX-c.width/2,c.bottom,c.offsetZ-c.depth/2];
    const mx=[c.offsetX+c.width/2,c.top,c.offsetZ+c.depth/2];
    for(let i=0;i<3;i++)assert.ok(lo[i]>=mn[i]-1e-9&&hi[i]<=mx[i]+1e-9,`${r.id}/${p.name} axis ${i}: ${lo[i]}..${hi[i]} vs ${mn[i]}..${mx[i]}`);
  }
}

test('exact audited source hashes, including authority and contact solver',()=>{
  for(const [path,hash] of Object.entries(contract.source))assert.equal(createHash('sha256').update(readFileSync(root+path)).digest('hex'),hash,path);
});
test('literal campaign body/shield profiles and source eye/forward contracts',()=>{
  for(const [role,profile] of Object.entries(contract.authority.campaignContact))compare(robotHitVolume(role),profile);
  assert.deepEqual(eye({x:3,y:7,z:2}),{x:3,y:8.45,z:2});
  const d=aim(0,0);near(d.x,0);near(d.y,0);near(d.z,-1);
  const source=readFileSync(root+'game/core.mjs','utf8');
  assert.ok(source.includes('side,.24),d,.42);muzzle.y-=.24'));
});
test('Horde skin roles leave authority snapshots and hit scales untouched',()=>{
  for(const [role,model] of Object.entries(ROBOT_FOR_ROLE)){
    if(!Object.values(contract.skins).includes(model))continue;
    const actor={id:4,isNpc:true,npcType:role,hitScale:ROBOT_SILHOUETTE[role].hitScale,x:2,y:3,z:4};
    const input={actors:[actor]}, before=structuredClone(input), out=hordeRobotState(input);
    assert.deepEqual(input,before);assert.equal(out.actors[0].hitScale,actor.hitScale);
    assert.equal(out.actors[0].npcModel,model);
    assert.equal(out.actors[0].npcProfile.scale,ROBOT_SILHOUETTE[role].scale);
  }
});
test('recipe deterministic, finite, three complete articulated LOD families and six props',()=>{
  assert.deepEqual(pack,recipe());assert.equal(pack.seed,contract.seed);
  assert.equal(pack.robots.length,9);assert.equal(Object.keys(pack.props).length,6);
  for(const r of pack.robots){
    assert.equal(r.rigidWeight,1);assert.deepEqual(r.sockets.forward,[0,0,-1]);
    assert.deepEqual(r.sockets.feetOrigin,[0,-.9,0]);
    const count=r.role==='mortar'?4:2;
    for(let i=0;i<count;i++){
      const hip=r.joints[`Hip${i}`],shin=r.joints[`Shin${i}`];
      const sole=r.pieces.find(p=>p.name==='contact_sole'&&p.joint===(r.lod===2?`Hip${i}`:`Shin${i}`));
      near(hip.at[1]+(r.lod===2?0:shin.at[1])+sole.p[1]-.09,0);
    }
    const expected=['Chassis','Turret','Optics','Weapon',...Array.from({length:count},(_,i)=>`Hip${i}`),...(r.lod<2?Array.from({length:count},(_,i)=>`Shin${i}`):[]),...(r.role==='bulwark'?['Shield']:[])].sort();
    assert.deepEqual([...new Set(r.pieces.map(p=>p.joint))].sort(),expected);
    for(const p of r.pieces){
      assert.ok(r.joints[p.joint]);assert.ok(pack.palette[p.material]);
      const nums=[...(p.p??p.a),...(p.size??p.b),p.bevel,p.radius??1];
      assert.ok(nums.every(Number.isFinite));assert.ok((p.size??[p.radius]).every(v=>v>0));
      if(p.shape==='rod')assert.ok(Math.hypot(...p.a.map((v,i)=>v-p.b[i]))>0);
    }
  }
});
test('all authored solid body envelopes fit unchanged campaign contact volumes',()=>{
  pack.robots.forEach(checkBody);
  const bad=structuredClone(pack.robots[0]);bad.pieces[0].p[0]+=1;
  assert.throws(()=>checkBody(bad),'validator must reject enlarged chassis');
});
test('shield visible plate fits literal source shield contact',()=>{
  for(const r of pack.robots.filter(r=>r.role==='bulwark')){
    const c=contract.authority.campaignContact.bulwark.shield,s=1.5,o=origin(r,'Shield');
    for(const p of r.pieces.filter(p=>p.joint==='Shield')){
      const [lo,hi]=bounds(p).map(b=>b.map((v,i)=>(v+o[i])*s));
      assert.ok(lo[0]>=c.offsetX-c.width/2 && hi[0]<=c.offsetX+c.width/2);
      assert.ok(lo[1]>=c.bottom && hi[1]<=c.top);
      assert.ok(lo[2]>=c.offsetZ-c.depth/2 && hi[2]<=c.offsetZ+c.depth/2);
    }
  }
});
