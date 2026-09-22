// The actual source third-person builders and post-pose grip pass, read-only.
import * as T from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {mergeGeometries,mergeVertices} from 'three/addons/utils/BufferGeometryUtils.js';
import {robotModel,simpleWeaponModel} from '../../game/view.mjs';
import {ModelAssets} from '../../game/effects-fx.mjs';
import {WEAPONS,CHARACTERS} from '../../game/data.mjs';
import {chassisFor} from '../../game/weapon-models/chassis.mjs';
import {characterPose} from '../../game/character-anim.mjs';
import {alignLivingCharacter} from '../../game/rig.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
globalThis.FileReader=class {readAsArrayBuffer(blob){blob.arrayBuffer().then(data=>{this.result=data;this.onloadend?.();});}};
const root=new URL('../../',import.meta.url),out=new URL('godot/source_operators/generated/world_weapons/',root);
await mkdir(out,{recursive:true});
const sha=data=>createHash('sha256').update(data).digest('hex'),sources={};
for(const file of ['game/view.mjs','game/rig.mjs','game/character-anim.mjs','game/weapon-models/chassis.mjs','game/model-geometry.mjs','game/data.mjs'])sources[file]=sha(await readFile(new URL(file,root)));
const manifest={schema:1,sources,method:'Actual simpleWeaponModel construction at source scale; two material batches. Grip coordinates are the chassis-derived fallback used verbatim by alignLivingCharacter in game/rig.mjs.',weapons:[]};
for(let type=0;type<WEAPONS.length;type++){
  const source=simpleWeaponModel(type,new ModelAssets());source.updateMatrixWorld(true);
  const scene=new T.Scene(),weapon=new T.Group();weapon.name='WorldWeapon';scene.add(weapon);
  const buckets=new Map();let triangles=0;
  source.traverseVisible(node=>{
    if(!node.isMesh)return;
    if(!buckets.has(node.material))buckets.set(node.material,[]);
    let geo=node.geometry.clone().applyMatrix4(node.matrixWorld);
    if(geo.index)geo=geo.toNonIndexed();
    for(const attr of Object.keys(geo.attributes))if(!['position','normal','uv'].includes(attr))geo.deleteAttribute(attr);
    triangles+=geo.attributes.position.count/3;buckets.get(node.material).push(geo);
  });
  let serial=0;
  const bounds=new T.Box3();
  for(const [material,geometries] of buckets){
    const mat=material.clone();mat.userData={};mat.name=`WorldMaterial${serial}`;
    const geometry=mergeVertices(mergeGeometries(geometries),1e-7);
    geometry.computeBoundingBox();bounds.union(geometry.boundingBox);
    const mesh=new T.Mesh(geometry,mat);mesh.name=`WorldBatch${serial++}`;weapon.add(mesh);
  }
  const [width,height,length,,y]=chassisFor(type);
  const anchors={Muzzle:source.userData.muzzle.position.toArray(),WeaponGripLeft:[-width/2-.025,y-height/2-.015,-length*.48],WeaponGripRight:[0,y-height/2-.08,-.035]};
  for(const [name,position] of Object.entries(anchors)){const node=new T.Group();node.name=name;node.position.fromArray(position);weapon.add(node);}
  const bytes=Buffer.from(await new GLTFExporter().parseAsync(scene,{binary:true,onlyVisible:true}));
  const file=`weapon-${type}.glb`;await writeFile(new URL(file,out),bytes);
  manifest.weapons.push({id:type,name:WEAPONS[type].name,file,sha256:sha(bytes),bytes:bytes.length,triangles,draws:buckets.size,anchors,bounds:[bounds.min.toArray(),bounds.max.toArray()]});
}
const states={carry:{time:.4},walk:{time:.4,phase:.8,speedNorm:.65,forward:1},aim:{ads:1,focusYaw:.4,focusPitch:-.3},crouch:{crouch:1,ads:.8,focusYaw:-.3,focusPitch:.3},reload:{reload:1,ads:.4}};
const fixtures={states,operators:[]};
for(const {id} of CHARACTERS){
  const model=robotModel(id,new ModelAssets()),d=model.userData,j=d.joints,entries=[];
  for(let type=0;type<WEAPONS.length;type++){
    d.weapon.removeFromParent();d.weapon=simpleWeaponModel(type,new ModelAssets());d.gunAnchor.add(d.weapon);
    for(const [name,state] of Object.entries(states)){
      d.rig.reset();d.rig.apply(characterPose({...state,contactGait:true}));
      d.gunAnchor.rotation.set(-(state.focusPitch??0),state.focusYaw??0,0);
      const result=alignLivingCharacter(model,{grounded:false});model.updateMatrixWorld(true);
      const joints=Object.fromEntries(['armUpperL','armUpperR','forearmL','forearmR','handL','handR'].map(key=>[key,{quaternion:j[key].quaternion.toArray(),world:j[key].matrixWorld.toArray()}]));
      const grips=Object.fromEntries(['L','R'].map(side=>[side,d.characterRefinement[`grip${side}`].getWorldPosition(new T.Vector3()).toArray()]));
      entries.push({type,state:name,joints,grips,hands:result.hands});
    }
  }
  fixtures.operators.push({id,entries});
}
await writeFile(new URL('manifest.json',out),JSON.stringify(manifest,null,2)+'\n');
await writeFile(new URL('catalog.gd',out),'extends RefCounted\n# Actual source simpleWeaponModel; source rig chassis contacts, no rescaling.\nconst WEAPONS = '+JSON.stringify(manifest.weapons,null,'\t')+'\n');
await writeFile(new URL('godot/tests/source_operators/source_grips.json',root),JSON.stringify(fixtures)+'\n');
console.log(JSON.stringify(manifest.weapons.map(({id,bytes,triangles,draws})=>({id,bytes,triangles,draws}))));
console.log('Source grip cases:',fixtures.operators.reduce((n,o)=>n+o.entries.length,0),'max source contact error:',Math.max(...fixtures.operators.flatMap(o=>o.entries.flatMap(e=>e.hands.map(h=>h.error)))));
