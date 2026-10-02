import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import vm from 'node:vm';
import {recipe,contracts} from '../../../tools/godot-vehicle-assets/recipe.mjs';
import {createVehicle,vehicleMuzzles,vehicleSeatPosition,PUMA,VEHICLE_KIND_IDS} from '../../../game/vehicles.mjs';
const root=new URL('../../../',import.meta.url);
const text=p=>readFileSync(new URL(p,root),'utf8');
const plus=(a,b)=>a.map((v,i)=>v+b[i]);
const yaw=(p,a)=>[p[0]*Math.cos(a)+p[2]*Math.sin(a),p[1],-p[0]*Math.sin(a)+p[2]*Math.cos(a)];
const close=(a,b)=>a.forEach((v,i)=>assert.ok(Math.abs(v-b[i])<1e-9,`${a} != ${b}`));
const core=text('game/core.mjs');
// Execute the actual private source OBB routine without copying/reimplementing it.
const start=core.indexOf('function hitVehicle('),end=core.indexOf('// Sentries are small',start);
const hitVehicle=vm.runInNewContext(`(${core.slice(start,end).trim()})`,{GUNTRUCK:PUMA});

for(const [kind,c] of Object.entries(contracts)){
  test(`${kind}: actual identity, local rigid pivots and finite bounded LOD geometry`,()=>{
    assert.ok(VEHICLE_KIND_IDS.includes(kind));
    let previous=Infinity;
    for(let lod=0;lod<3;lod++){
      const r=recipe(kind,lod);assert.deepEqual(r,recipe(kind,lod));
      assert.deepEqual(r.joints.turret,c.pivot);
      assert.deepEqual(r.dimensions,c.source.dimensions);
      let i=0;for(const x of c.xs)for(const z of c.zs)assert.deepEqual(r.joints[`wheel_${i++}`],[x,c.radius,z]);
      let tris=0;const min=[Infinity,Infinity,Infinity],max=[-Infinity,-Infinity,-Infinity];
      for(const p of r.parts){
        assert.ok(r.palette[p.material]);assert.ok(p.vertices.length>2);
        for(const face of p.faces){assert.ok(face.length>=3);tris+=face.length-2;for(const n of face)assert.ok(Number.isInteger(n)&&n>=0&&n<p.vertices.length);}
        for(const local of p.vertices){assert.equal(local.length,3);const v=plus(local,r.joints[p.joint]);v.forEach((n,k)=>{assert.ok(Number.isFinite(n));min[k]=Math.min(min[k],n);max[k]=Math.max(max[k],n);});}
      }
      assert.ok(tris<previous,'LOD strictly reduces triangle count');previous=tris;
      assert.ok(tris<[45000,30000,16000][lod],`${tris} bounded recipe triangles`);
      // Native Scout tire width is 0.22, 1 cm beyond each source OBB side.
      // Permit only that inherited tyre discrepancy; no oversized hull expansion.
      const tolerance=kind==='scout'?.011:.01;
      assert.ok(min[0]>=-r.dimensions.width/2-tolerance,`${kind} minX ${min[0]}`);
      assert.ok(max[0]<=r.dimensions.width/2+tolerance,`${kind} maxX ${max[0]}`);
      assert.ok(min[1]>=-1e-8,`${kind} ground ${min[1]}`);
      assert.ok(max[1]<=r.dimensions.height,`${kind} height ${max[1]}`);
      assert.ok(min[2]>=-r.dimensions.length/2 && max[2]<=r.dimensions.length/2,`${kind} length ${min[2]} ${max[2]}`);
      console.log(JSON.stringify({kind,lod,parts:r.parts.length,triangles:tris,min,max,sourceContactRadius:Math.hypot(r.dimensions.width/2,r.dimensions.length/2)}));
    }
  });
  test(`${kind}: source seat and muzzle origins for yaw, mount offset and hull tilt`,()=>{
    const r=recipe(kind),v=createVehicle(c.source);
    v.position={x:13,y:7,z:-9};v.roll=.3;v.pitchBody=-.2;
    for(const a of [0,.5,Math.PI/2,-2.1])for(const t of [0,-.6,Math.PI]){
      v.heading=a;v.turretYaw=t;
      const source=vehicleMuzzles(v);
      r.muzzles.forEach((m,i)=>{
        // Adapter cancels the hull basis and rotates native mount + local mesh.
        const local=m.map((n,k)=>n-c.pivot[k]);
        const actual=plus([13,7,-9],plus(yaw(c.pivot,a+t),yaw(local,a+t)));
        close(actual,[source[i].x,source[i].y,source[i].z]);
        const barrel=r.parts.find(p=>p.name===`barrel-${i}`);
        assert.ok(barrel,'actual hollow barrel exists');
        const tip=barrel.vertices.slice(20,40).reduce((acc,p)=>plus(acc,p),[0,0,0]).map(n=>n/20);
        close(plus(tip,c.pivot),m);
      });
      for(const seat of r.seats){const [role,index]=seat.name.split('_'),src=vehicleSeatPosition(v,role==='passenger'?'passenger':role,Number(index||0));close(plus([13,7,-9],yaw(seat.position,a)),[src.x,src.y,src.z]);}
    }
  });
  test(`${kind}: actual source OBB rays, cover faces and movement-radius envelope`,()=>{
    const v=createVehicle(c.source),{width:w,length:l,height:h}=c.source.dimensions;
    for(const a of [0,.7,Math.PI/2]){
      v.heading=a;
      for(const [point,dir,distance,face] of [
        [[0,h*.5,l/2+3],[0,0,-1],3,'front'],
        [[0,h*.5,-l/2-3],[0,0,1],3,'rear'],
        [[w/2+3,h*.5,0],[-1,0,0],3,'right'],
        [[-w/2-3,h*.5,0],[1,0,0],3,'left'],
      ]){
        const p=yaw(point,a),d=yaw(dir,a),hit=hitVehicle({x:p[0],y:p[1],z:p[2]},{x:d[0],y:d[1],z:d[2]},v,20);
        assert.ok(Math.abs(hit.distance-distance)<1e-9);assert.equal(hit.face,face);
      }
      assert.equal(hitVehicle({x:0,y:h+.01,z:0},{x:0,y:0,z:1},v,20),null);
    }
    const radius=Math.hypot(w/2,l/2);
    const r=recipe(kind);
    for(const p of r.parts)for(const local of p.vertices){const vertex=plus(local,r.joints[p.joint]);assert.ok(Math.hypot(vertex[0],vertex[2])<=radius,`visual ${p.name} ${vertex} inside source world-contact circle ${radius}`);}
    assert.match(core,/const vehicleRadius=vehicle=>Math\.hypot/);
  });
}
test('native source wheel contracts and no-asset fallback are retained',()=>{
  const puma=text('godot/vehicles/puma.gd'),chassis=text('godot/combined_arms/chassis.gd');
  assert.match(puma,/Vector3\(x, 0\.42, z\)/);assert.match(puma,/\[-0\.9, 0\.9\]/);assert.match(puma,/\[-1\.18, 1\.18\]/);
  assert.match(puma,/roll_age = minf\(0\.1/);assert.match(puma,/roll_speed \* roll_age \/ 0\.42/);
  assert.match(chassis,/wheel\(x, -2\.1 \+ i \* 0\.6, 0\.37/);assert.match(chassis,/wheel\(x, z, 0\.245/);
  const adapter=text('godot/vehicle_assets/attachment.gd');
  assert.ok(adapter.indexOf('if not ResourceLoader.exists(path)')<adapter.indexOf('child.visible = false'));
  assert.match(adapter,/host\.transform\.affine_inverse\(\) \* source_turret/);
  console.log('Generated art present:',Object.keys(contracts).filter(kind=>existsSync(new URL(`godot/vehicle_assets/generated/${kind}-lod0.glb`,root))));
});
