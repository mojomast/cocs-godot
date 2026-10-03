// Reuse approved U height/camera/anchor policy, adding successor witnesses.
import {readFileSync} from 'node:fs';
import {makeProbes,support} from '../botanical-stage/probes.mjs';
const [authority,accepted]=process.argv.slice(2);
const data=JSON.parse(readFileSync(authority)),base=JSON.parse(readFileSync(accepted));
const p=makeProbes(data,base);p.raySpecs=[];
for(const camera of p.cameras)if(camera.player) {
  camera.eye[1]=camera.ground+1.45;camera.beforeEye[1]=camera.beforeGround+1.45;
  camera.playerEyeHeightMetres=1.45;
  camera.sourceCameraAdjustment+='; X default player eye 1.45m above verified support';
}
for(const portal of p.portals) {
  const size=Math.hypot(...portal.dir),dx=portal.dir[0]/size,dz=portal.dir[1]/size;
  if(!Number.isFinite(size)||size===0)throw new Error('Malformed portal direction');
  for(const side of [-.35,0,.35])for(const h of [.5,1.5]) {
    const [x,y,z]=portal.at;
    p.raySpecs.push({id:`portal:${portal.id}:${side}:${h}`,kind:'portal',
      origin:[x-dx*portal.depth/2-dz*side*portal.width,y+h,z-dz*portal.depth/2+dx*side*portal.width],direction:[dx,0,dz],max:portal.depth});
  }
}
if(data.id==='vesper-viaduct')p.raySpecs.push({id:'U-parapet-counterexample',kind:'solid',origin:[-66.66666666666667,26.8,-57.675],direction:[0,0,-1],max:.3});
const add=(id,x,y,z,kind)=>{support(data.arena,x,z,y);p.points.push({id,x,y,z,kind});};
if(data.id==='helix-conservatory') {
  const camera=p.cameras.find(c=>c.id==='greenhouse-eye');
  camera.target=[87*Math.cos(82*Math.PI/180),22,87*Math.sin(82*Math.PI/180)];
  camera.targetLineage='successor radial greenhouse spring/crown; unchanged supported before/after eye';
  for(const angle of [70,76,82,88,94])for(const radius of [80.8,93.2]) {
    const a=angle*Math.PI/180,x=radius*Math.cos(a),z=radius*Math.sin(a),witness=a+17*Math.PI/180;
    // Radial witnesses can be exactly coplanar with inherited pavilion seam
    // walls. Float32 export then invents a near-origin crossing. Oblique rays
    // through the same post centre cross those planes unambiguously.
    for(const h of [.5,1.5,2.5])for(const side of [-1,1])
      p.raySpecs.push({id:`post:${angle}:${radius}:${h}:${side}`,kind:'frame-post',origin:[x+side*Math.cos(witness),16+h,z+side*Math.sin(witness)],direction:[-side*Math.cos(witness),0,-side*Math.sin(witness)],max:2});
  }
}
if(data.id==='parallax-observatory') {
  for(let j=0;j<=30;j++) {
    const z=-37+j*.2;
    for(const direction of [-1,1]) {
      for(let i=0;i<=20;i++)add(`aperture:${j}:${direction}:${i}`,direction===1?44+i*.2:48-i*.2,12,z,'successor-aperture');
      for(const h of [.1,.5,1,1.5,1.8,2.1])p.raySpecs.push({id:`aperture-ray:${j}:${direction}:${h}`,kind:'aperture',origin:[direction===1?44:48,12+h,z],direction:[direction,0,0],max:4});
    }
  }
  for(const direction of [-1,1])for(let i=0;i<=102;i++)for(const x of [48,49.5,51]) {
    const n=direction===1?i:102-i,z=-37.5-n*.25,y=12+n*.25*12/25.5;
    add(`grade:${direction}:${i}:${x}`,x,y,z,'successor-grade');
    p.raySpecs.push({id:`grade-ray:${direction}:${i}:${x}`,kind:'grade',origin:[x,y+.2,z],direction:[0,-1,0],max:.4});
  }
}
if(data.id==='vesper-viaduct')for(const d of data.arena.art.baseCraft.canonicalSolids.descriptors) {
  if(d.replacement.kind!=='authority')continue;
  for(let axis=0;axis<3;axis++)for(const side of [-1,1]) {
    const origin=d.min.map((v,i)=>(v+d.max[i])/2),direction=[0,0,0];
    origin[axis]=(side===-1?d.min[axis]:d.max[axis])+side*.02;direction[axis]=-side;
    p.raySpecs.push({id:`parapet:${d.id}:${axis}:${side}`,kind:'canonical-parapet',origin,direction,max:.04});
  }
}
// Preserve the reviewed U component-ray gate for every new solid, plus these
// explicit aperture/post/legacy-shell witnesses; actual distances added later.
console.log(JSON.stringify(p));
