// Read-only source export. No browser, random values, or external preview assets.
import * as T from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {buildWeaponBody} from '../../game/weapon-models/index.mjs';
import {CHASSIS} from '../../game/weapon-models/chassis.mjs';
import {WEAPONS} from '../../game/data.mjs';
import {mkdir, writeFile, readFile, readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';

globalThis.FileReader = class {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(data => { this.result=data; this.onloadend?.(); }); }
};
const root=new URL('../../',import.meta.url), out=new URL('godot/first_person/generated/',root);
await mkdir(out,{recursive:true});
const sha=data=>createHash('sha256').update(data).digest('hex');
const sources={};
for(const file of ['game/data.mjs','game/model-geometry.mjs','game/sights.mjs',...(await readdir(new URL('game/weapon-models/',root))).filter(n=>n.endsWith('.mjs')).map(n=>'game/weapon-models/'+n)]) sources[file]=sha(await readFile(new URL(file,root)));
const manifest={schema:1,sourceBaseline:'b0ac0b54aa6d815e4d61f63e929612069e2c3d11',sources,weapons:[]};
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
  const ctx={T,info,material,geo,palette:{dark:material('#222f37'),light:material('#73848a'),glow:material(info.color,.3,.3,true)},
    box:(p,w,h,d,x,y,z,m)=>put(p,geo(`b${w}|${h}|${d}`,()=>new T.BoxGeometry(w,h,d)),x,y,z,m),
    cylinder:(p,r1,r2,h,x,y,z,m,s=12)=>put(p,geo(`c${r1}|${r2}|${h}|${s}`,()=>new T.CylinderGeometry(r1,r2,h,s)),x,y,z,m),
    ring:(p,r,t,x,y,z,m,rx=Math.PI/2)=>{const mesh=put(p,geo(`t${r}|${t}`,()=>new T.TorusGeometry(r,t,6,32)),x,y,z,m);mesh.rotation.x=rx;return mesh;}};
  buildWeaponBody(id,group,ctx);
  group.updateMatrixWorld(true);
  // Bake static descendants into one geometry per material and moving assembly.
  // Keeps authored feed/barrel/bolt pivots while bounding native draw calls.
  const {mergeGeometries}=await import('three/addons/utils/BufferGeometryUtils.js');
  const scene=new T.Scene(), baked=new T.Group();baked.name='weapon';scene.add(baked);
  const parts=group.userData.parts??{}, buckets=new Map();
  group.traverse(node=>{
    if(!node.isMesh)return;
    let owner=null;
    for(let parent=node;parent && parent!==group;parent=parent.parent) if(Object.values(parts).includes(parent)){owner=parent;break;}
    const name=owner?.name||'body', key=name+'|'+node.material.uuid;
    if(!buckets.has(key))buckets.set(key,{name,owner,material:node.material,geometries:[]});
    const transform=owner?owner.matrixWorld.clone().invert().multiply(node.matrixWorld):node.matrixWorld;
    let geometry=node.geometry.clone().applyMatrix4(transform);
    if(geometry.index) geometry=geometry.toNonIndexed();
    for(const attr of Object.keys(geometry.attributes))if(!['position','normal','uv'].includes(attr))geometry.deleteAttribute(attr);
    if(!geometry.attributes.uv)geometry.setAttribute('uv',new T.BufferAttribute(new Float32Array(geometry.attributes.position.count*2),2));
    buckets.get(key).geometries.push(geometry);
  });
  const assemblies=new Map();let triangles=0;
  for(const {name,owner,material,geometries:gs} of buckets.values()) {
    if(!assemblies.has(name)){const p=new T.Group();p.name=name;if(owner)owner.matrixWorld.decompose(p.position,p.quaternion,p.scale);baked.add(p);assemblies.set(name,p);}
    const geometry=mergeGeometries(gs), mesh=new T.Mesh(geometry,material);mesh.name=name+'-'+material.name;triangles+=geometry.attributes.position.count/3;assemblies.get(name).add(mesh);
  }
  const bytes=Buffer.from(await new GLTFExporter().parseAsync(scene,{binary:true,onlyVisible:true}));
  const file=`weapon-${id}.glb`;await writeFile(new URL(file,out),bytes);
  const bounds=new T.Box3().setFromObject(group), ch=CHASSIS[id];
  manifest.weapons.push({id,name:info.name,file,sha256:sha(bytes),bytes:bytes.length,triangles,meshInstances:buckets.size,bounds:[bounds.min.toArray(),bounds.max.toArray()],muzzles:(id===3?[-.12,.12]:[0]).map(x=>[x,ch[4],ch[3]]),color:info.color,kick:info.feel.kick,muzzle:info.feel.muzzle});
}
await writeFile(new URL('manifest.json',out),JSON.stringify(manifest,null,2)+'\n');
// A native script resource is automatically included by all_resources exports.
// The audit JSON does not have to be added to lead-owned export include filters.
await writeFile(new URL('catalog.gd',out),'extends RefCounted\n# Generated by tools/godot-weapons/export.mjs; source metadata, no gameplay rules.\nconst WEAPONS = '+JSON.stringify(manifest.weapons,null,'\t')+'\n');
console.log(JSON.stringify(manifest.weapons.map(({id,bytes,triangles,meshInstances})=>({id,bytes,triangles,meshInstances})),null,2));
