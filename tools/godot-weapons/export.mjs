// Read-only source export. No browser, random values, or external preview assets.
// Source geometry (`game/weapon-models/**`) is locked and read-only: this
// exporter only *bolts on* detail geometry (tools/godot-weapons/detail.mjs),
// rebases authored anchors into the moving assemblies and bakes one mesh per
// (assembly, material slot). See port/native-weapon-detail/WEAPON_IDENTITY.md.
import * as T from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {buildWeaponBody} from '../../game/weapon-models/index.mjs';
import {CHASSIS} from '../../game/weapon-models/chassis.mjs';
import {handlingAnchors, handlingProfile, presentationProfile} from './handling.mjs';
import {buildDetail, IDENTITY, SLOTS, remapFor, hardpoints} from './detail.mjs';
import {WEAPONS} from '../../game/data.mjs';
import {ADS_PROFILES} from '../../game/weapon-ads.mjs';
import {resolveActiveSight} from '../../game/reticle.mjs';
import {solveSightPose} from '../../game/sights.mjs';
import {mkdir, writeFile, readFile, readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';

globalThis.FileReader = class {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(data => { this.result=data; this.onloadend?.(); }); }
};
const root=new URL('../../',import.meta.url), out=new URL('godot/first_person/generated/',root);
await mkdir(out,{recursive:true});
const sha=data=>createHash('sha256').update(data).digest('hex');
const sources={};
for(const file of ['game/data.mjs','game/model-geometry.mjs','game/sights.mjs','game/weapon-ads.mjs','game/reticle.mjs','tools/godot-weapons/detail.mjs','tools/godot-weapons/handling.mjs',...(await readdir(new URL('game/weapon-models/',root))).filter(n=>n.endsWith('.mjs')).map(n=>'game/weapon-models/'+n)]) sources[file]=sha(await readFile(new URL(file,root)));

// Hoop tessellation. The author's rings are 6x32-segment tori. Rings that
// frame the sight picture (anything attached to the sight assembly: the optic
// tube and clamp rings) keep the author's 32 tubular segments exactly, because
// they fill the ADS frame at magnification. Barrel/chassis collars — small
// rings seen at 0.4-1.5 m — generate 16 segments (20 for the two largest,
// radius >= 0.09 m): at capture resolution the silhouette delta is about one
// pixel, so the recovered budget buys real detail instead of ring smoothness.
// Shape, radius and position are unchanged; see
// port/native-weapon-detail/README.md for the measured silhouette delta.
function ringSegments(parent, radius) {
  if (parent && parent.name === 'sight-assembly') return 32;
  return radius >= .09 ? 20 : 16;
}
const detailThree = {...T};


// Sight corridor keeps-out volumes. Detail must never sit between the eye and
// the target through the notch/aperture, nor in the 4x4 px target gap.
function corridorFor(id, ch, sights) {
  const [, h, len, , my] = ch, front = -len, top = my + h / 2;
  if (id === 2 || id === 8) return {kind: 'scope', y: top + .079, z0: -.46, z1: .16, radius: .042};
  return {kind: 'box', minX: -.046, maxX: .046, minY: top + .026, maxY: top + .18,
    minZ: front - .10, maxZ: (sights?.rear?.z ?? -.065) + .16};
}

function intersectsCorridor(box, corridor) {
  if (corridor.kind === 'box') {
    return box.max.x > corridor.minX && box.min.x < corridor.maxX &&
      box.max.y > corridor.minY && box.min.y < corridor.maxY &&
      box.max.z > corridor.minZ && box.min.z < corridor.maxZ;
  }
  // Scope: shortest XY distance from the optical axis over the optical window.
  if (box.min.z > corridor.z1 || box.max.z < corridor.z0) return false;
  const dx = Math.max(0, box.min.x, -box.max.x);
  const dy = Math.max(0, box.min.y - corridor.y, corridor.y - box.max.y);
  return Math.hypot(dx, dy) < corridor.radius;
}

const manifest={schema:2,sourceBaseline:'64da4bc',detail:'weapon identity/detail pass (first person)',sources,weapons:[]};
const table=[];
for(let id=0;id<WEAPONS.length;id++) {
  const info=WEAPONS[id], group=new T.Group();group.name='weapon';
  const materials=new Map(), geometries=new Map();
  const material=(color,metal=.5,rough=.42,emissive=false)=>{
    const key=JSON.stringify([color,metal,rough,emissive]);
    if(!materials.has(key)) materials.set(key,new T.MeshStandardMaterial({name:'source-'+materials.size,color,metalness:metal,roughness:rough,...(emissive?{emissive:color,emissiveIntensity:1}:{})}));
    return materials.get(key);
  };
  const geo=(key,make)=>{if(!geometries.has(key))geometries.set(key,make());return geometries.get(key);};
  const put=(p,g,x,y,z,m)=>{const mesh=new T.Mesh(g,m);mesh.position.set(x,y,z);p.add(mesh);return mesh;};
  const dark=material('#222f37'), light=material('#73848a'), glow=material(info.color,.3,.3,true);
  const detailMaterial={
    dark, light, glow,
    // Two new shared materials, identical on every weapon: a polished machined
    // steel for the reciprocating action and exposed hardware, and a near-black
    // recess tone so vents and port mouths read at viewmodel distance.
    trim: material('#c6ced2',.85,.26),
    cavity: material('#0d1519',.35,.62),
  };
  const ctx={T:detailThree,info,material,geo,palette:{dark,light,glow},detail:detailMaterial,
    box:(p,w,h,d,x,y,z,m)=>put(p,geo(`b${w}|${h}|${d}`,()=>new T.BoxGeometry(w,h,d)),x,y,z,m),
    cylinder:(p,r1,r2,h,x,y,z,m,s=12)=>put(p,geo(`c${r1}|${r2}|${h}|${s}`,()=>new T.CylinderGeometry(r1,r2,h,s)),x,y,z,m),
    ring:(p,r,t,x,y,z,m,rx=Math.PI/2)=>{const seg=ringSegments(p,r);const mesh=put(p,geo(`t${r}|${t}|${seg}`,()=>new T.TorusGeometry(r,t,6,seg)),x,y,z,m);mesh.rotation.x=rx;return mesh;}};
  const sourceTriangleStart=geometryCount(group);
  const ch=CHASSIS[id];
  buildWeaponBody(id,group,ctx);
  group.updateMatrixWorld(true);
  const sourceTriangles=geometryCount(group);
  // Pre-pass weapon-space bounds of the moving assemblies: the detail kits
  // dress feeds/stocks relative to the shape the source actually authored.
  const parts=group.userData.parts??{};
  const bounds={};
  for(const [name,node] of Object.entries({feed:parts.magazine,bolt:parts.bolt,barrel:parts.barrel})) {
    if(node) bounds[name]=new T.Box3().setFromObject(node);
  }
  bounds.body=new T.Box3().setFromObject(group);
  const detail=buildDetail(id,group,ctx,ch,parts,bounds);
  // Batch plan: the two detail materials replace source tones on the moving
  // assemblies (geometry untouched); every weapon lands on eight batches.
  const remap=remapFor(id);
  const roleOwner=node=>{
    for(let p=node;p&&p!==group;p=p.parent){
      if(p===parts.bolt) return 'bolt';
      if(p===parts.barrel) return 'barrel';
      if(p===parts.magazine) return 'feed';
    }
    return 'body';
  };
  const roleOf=new Map([[dark,'dark'],[light,'light'],[glow,'glow'],[detailMaterial.trim,'trim'],[detailMaterial.cavity,'cavity']]);
  group.traverse(node=>{
    if(!node.isMesh) return;
    const role=roleOf.get(node.material);
    const assembly=roleOwner(node);
    const target=remap[assembly]?.[role];
    if(target) { node.material=detailMaterial[target]; node.userData.detailRemap=role+'>'+target; }
  });
  group.updateMatrixWorld(true);
  // Sight/identity invariants that must hold before anything is baked.
  const sights=group.userData.sights;
  if(!sights?.rear||!sights?.front)throw new Error(`Missing authored sight anchors: ${id}`);
  const corridor=corridorFor(id,ch,sights);
  for(const box of detail.boxes) {
    const scopeBox=new T.Box3(new T.Vector3(...box.min),new T.Vector3(...box.max));
    if(intersectsCorridor(scopeBox,corridor)) throw new Error(`detail ${id} ${box.a}/${box.c} intrudes on the sight corridor: ${JSON.stringify(box)}`);
  }
  // Bake static descendants into one geometry per material and moving assembly.
  // Keeps authored feed/barrel/bolt pivots while bounding native draw calls.
  const {mergeGeometries}=await import('three/addons/utils/BufferGeometryUtils.js');
  const scene=new T.Scene(), baked=new T.Group();baked.name='weapon';scene.add(baked);
  const buckets=new Map();
  group.traverse(node=>{
    if(!node.isMesh)return;
    let owner=null;
    for(let parent=node;parent && parent!==group;parent=parent.parent) if(Object.values(parts).includes(parent)){owner=parent;break;}
    const name=owner?.name||'body', ownerRole=roleOwner(node), role=roleOf.get(node.material)??'dark', key=name+'|'+role;
    if(!buckets.has(key))buckets.set(key,{name,ownerRole,role,owner,material:node.material,geometries:[]});
    const transform=owner?owner.matrixWorld.clone().invert().multiply(node.matrixWorld):node.matrixWorld;
    let geometry=node.geometry.clone().applyMatrix4(transform);
    if(geometry.index) geometry=geometry.toNonIndexed();
    for(const attr of Object.keys(geometry.attributes))if(!['position','normal','uv'].includes(attr))geometry.deleteAttribute(attr);
    if(!geometry.attributes.uv)geometry.setAttribute('uv',new T.BufferAttribute(new Float32Array(geometry.attributes.position.count*2),2));
    buckets.get(key).geometries.push(geometry);
  });
  const assemblies=new Map();let triangles=0;
  const batchPlan=[];
  for(const {name,ownerRole,role,owner,material,geometries:gs} of buckets.values()) {
    if(!assemblies.has(name)){const p=new T.Group();p.name=name;if(owner)owner.matrixWorld.decompose(p.position,p.quaternion,p.scale);baked.add(p);assemblies.set(name,p);}
    const geometry=mergeGeometries(gs), mesh=new T.Mesh(geometry,material);mesh.name=name+'-'+role;triangles+=geometry.attributes.position.count/3;
    assemblies.get(name).add(mesh);
    batchPlan.push({assembly:name,slot:ownerRole,role});
  }
  const plan=SLOTS[id], expected=Object.entries(plan).flatMap(([a,roles])=>roles.map(r=>a+'|'+r)).sort();
  const actual=batchPlan.map(b=>b.slot+'|'+b.role).sort();
  if(JSON.stringify(expected)!==JSON.stringify(actual))throw new Error(`Batch plan mismatch weapon ${id}: ${actual.join(',')}`);
  // Detail budget: 6,000 triangles per weapon. The two weapons that ship an
  // integrated optic (2, 8) already spend >=5,980 triangles on locked source
  // geometry and the author-tessellated optic rings, so they get the 6,500
  // gate ceiling less a safety margin instead.
  const ceiling=sourceTriangles>=5980?6480:6000;
  if(triangles>ceiling)throw new Error(`Triangle budget exceeded weapon ${id}: ${triangles} > ${ceiling}`);
  // Anchor coordinates are authored in weapon space, then rebased into the
  // *same* moving assembly as the source geometry (not a static muzzle table).
  const point=p=>[p.x,p.y,p.z];
  const muzzles=(id===3?[-.12,.12]:[0]).map(x=>[x,ch[4],ch[3]]);
  const barrel=parts.barrel;
  const anchors={};
  function anchor(name,position,owner=null){
    const p=new T.Object3D();p.name=name;p.position.fromArray(position);
    const parent=owner?assemblies.get(owner.name):baked;
    if(!parent)throw new Error(`Missing anchor parent: ${name}`);
    if(owner)p.position.applyMatrix4(owner.matrixWorld.clone().invert());
    parent.add(p);anchors[name]={parent:owner?.name||'weapon',position:p.position.toArray(),weaponPosition:position};
  }
  muzzles.forEach((p,i)=>anchor(`Muzzle${i}`,p,barrel));
  anchor('SightRear',point(sights.rear));anchor('SightFront',point(sights.front));
  anchor('OpticCenter',point(sights.rear));
  // Contact stations follow the source chassis grip, handguard and feed shapes.
  anchor('GripRight',[.018,ch[4]-ch[1]/2-.09,-.035]);
  anchor('GripSupport',[-.025,ch[4]-ch[1]*.45-.04,-ch[2]-.065],id===3?barrel:null);
  const feedPoint=id===1?[-.10,ch[4]-.16,-.30]:id===3?[-.055,ch[4]-.07,-.18]:id===5?[-.08,ch[4]-.23,-.25]:[id===7?-.09:-.025,ch[4]-ch[1]/2-.15,-.28];
  anchor('GripReload',feedPoint,parts.magazine);
  // Authored handling stations (bolt carrier, charging paddle, casing port,
  // feed body, heat region), rebased into the same moving assemblies.
  const handling=handlingProfile(id,ch,info);
  for(const station of handlingAnchors(id,ch,parts)) anchor(station.name,station.position,station.owner);
  const ads={...ADS_PROFILES[id],...resolveActiveSight({weapon:id,aiming:true}),pose:solveSightPose(sights.rear,sights.front)};
  const bytes=Buffer.from(await new GLTFExporter().parseAsync(scene,{binary:true,onlyVisible:true}));
  const file=`weapon-${id}.glb`;await writeFile(new URL(file,out),bytes);
  const boundsBox=new T.Box3().setFromObject(group);
  // Measured clearance of every authored detail primitive from the hand
  // capsules and the sight corridor, in weapon space. The rendered gate
  // re-checks the same boxes against the live animated assemblies.
  const grips={GripRight:[.018,ch[4]-ch[1]/2-.09,-.035],
    GripSupport:[-.025,ch[4]-ch[1]*.45-.04,-ch[2]-.065],GripReload:feedPoint};
  let nearestHand=Infinity,worstHand=null;
  const boxDistance=(box,station)=>{
    const dx=Math.max(box.min[0]-station[0],0,station[0]-box.max[0]);
    const dy=Math.max(box.min[1]-station[1],0,station[1]-box.max[1]);
    const dz=Math.max(box.min[2]-station[2],0,station[2]-box.max[2]);
    return Math.hypot(dx,dy,dz);
  };
  for(const box of detail.boxes) {
    for(const [stationName,station] of Object.entries(grips)) {
      const gap=boxDistance(box,station);
      if(gap<nearestHand){nearestHand=gap;worstHand={box,station:stationName};}
    }
  }
  if(nearestHand<.045)throw new Error(`Detail inside the hand capsule weapon ${id}: ${nearestHand.toFixed(4)} m ${JSON.stringify(worstHand)}`);
  manifest.weapons.push({id,name:info.name,file,sha256:sha(bytes),bytes:bytes.length,triangles,meshInstances:buckets.size,batches:batchPlan,
    sourceTriangles,detailTriangles:detail.stats.triangles,detailPrimitives:detail.stats.primitives,
    detailChannels:detail.stats.channels,detailBoxes:detail.boxes,identity:IDENTITY[id],slots:plan,
    nearestHandClearance:+nearestHand.toFixed(5),bounds:[boundsBox.min.toArray(),boundsBox.max.toArray()],muzzles,anchors,handling,
    presentation:presentationProfile(id,ch,info),ads,color:info.color,kick:info.feel.kick,muzzle:info.feel.muzzle});
  table.push({id,triangles,sourceTriangles:sourceTriangles,detailTriangles:detail.stats.triangles,
    batches:buckets.size,bytes:bytes.length,primitives:detail.stats.primitives,nearestHand:+nearestHand.toFixed(4)});
}
await writeFile(new URL('manifest.json',out),JSON.stringify(manifest,null,2)+'\n');
// A native script resource is automatically included by all_resources exports.
// The audit JSON does not have to be added to lead-owned export include filters.
await writeFile(new URL('catalog.gd',out),'extends RefCounted\n# Generated by tools/godot-weapons/export.mjs; source metadata, no gameplay rules.\nconst WEAPONS = '+JSON.stringify(manifest.weapons,null,'\t')+'\n');
console.log(JSON.stringify(table,null,2));

function geometryCount(node){
  let triangles=0;
  node.traverse(child=>{
    if(!child.isMesh)return;
    const g=child.geometry;
    triangles+=(g.index?g.index.count:g.attributes.position.count)/3;
  });
  return triangles;
}
