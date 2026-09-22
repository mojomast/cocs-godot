// Export the actual robotModel/refineOperatorCharacter output, never a recipe replica.
// game/* is read-only. Fresh export-only nodes avoid cyclic userData/Class references.
import * as T from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {mergeGeometries, mergeVertices} from 'three/addons/utils/BufferGeometryUtils.js';
import {robotModel} from '../../game/view.mjs';
import {ModelAssets} from '../../game/effects-fx.mjs';
import {CHARACTERS} from '../../game/data.mjs';
import {characterPose, deathLimbPose} from '../../game/character-anim.mjs';
import {TEAM_PALETTE} from '../../game/team-presentation.mjs';
import {selectModelLOD} from '../../scripts/measure-lattice-models.mjs';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

globalThis.FileReader = class {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(data => { this.result=data; this.onloadend?.(); }); }
};
const root=new URL('../../',import.meta.url), out=new URL('godot/source_operators/generated/',root);
await mkdir(out,{recursive:true});
const sha=data=>createHash('sha256').update(data).digest('hex');
const sources={};
for(const name of ['view','effects-fx','models','model-geometry','operator-anatomy','operator-detail','character-anim','data','kits','textures','team-presentation','weapon-models/index','weapon-models/chassis']) {
  const file=`game/${name}.mjs`;
  sources[file]=sha(await readFile(new URL(file,root)));
}
const states={
  idle:{time:1.2},walk:{time:1.2,phase:.7,speedNorm:.4,forward:1},
  run:{time:.3,phase:2.1,speedNorm:1,forward:1},
  crouch:{time:1.2,crouch:1},aim:{ads:1,focusYaw:.42,focusPitch:-.35},
  crouch_aim:{crouch:.65,ads:.8,phase:1.1,speedNorm:.3,strafe:-.6,forward:-.5,focusPitch:.24},
  reload:{reload:.8,ads:.3,phase:2.5,speedNorm:.2},
  hit:{hit:.9,bank:.3,accel:-.4,lateral:.7,land:.4,landRoll:-.6},
  airborne:{grounded:false,strafe:.7,focusYaw:-.4,focusPitch:.2},
  slide:{slide:.8,phase:3.7,speedNorm:.8,forward:1},
  secondary:{secondary:{headYaw:.2,headPitch:-.1,chestYaw:.12,chestRoll:-.08}},
  reduced:{reduced:true,phase:2,speedNorm:1,crouch:.4},
};
const manifest={schema:1,sources,method:'Actual source construction, visible mesh union at 2/10/50m; material/rigid-owner/LOD-mask batches. No anatomy scaling. No triangle decimation.',textureAudit:'robotModel does not call applyProceduralTexturesToModel; all constructed materials have no map/normalMap. Original PBR and precision vertex colors exported.',operators:[]};
const updateSequence=Array.from({length:90},(_,i)=>({dt:1/60,time:i/60,speed:i<20?0:i<55?5:8,maxSpeed:8,ads:i>40,crouch:i>70,strafe:i>25?-.6:0,forward:1,grounded:i<60||i>66,reload:i>75?1:0,focusYaw:.24,focusPitch:-.2,bank:.2}));
const fixtures={states,updateSequence,operators:[]};
const only=process.argv.find(a=>a.startsWith('--only='))?.split('=')[1]?.split(',');
for(const info of CHARACTERS.filter(c=>!only||only.includes(c.id))) {
  const assets=new ModelAssets(), model=robotModel(info.id,assets), joints=model.userData.joints;
  const boundaries=new Set([model]), names=new Map([[model,'SourceOperator']]);
  for(const [key,node] of Object.entries(joints))if(node?.isObject3D){boundaries.add(node);names.set(node,key);}
  // Keep weapon, secondary attachment and hand-contact pivots independently addressable.
  for(const [key,node] of Object.entries({backpack:model.userData.backpack,weapon:model.userData.weapon,...Object.fromEntries(['L','R'].map(s=>['grip'+s,model.userData.characterRefinement['grip'+s]]))}))if(node){boundaries.add(node);names.set(node,key);}
  for(const node of [...boundaries])for(let p=node.parent;p&&p!==model;p=p.parent)boundaries.add(p);
  model.updateMatrixWorld(true);
  const copied=new Map(), scene=new T.Scene();let serial=0;
  function copy(node){
    if(copied.has(node))return copied.get(node);
    const result=new T.Group();result.name=names.get(node)||`rigPivot${serial++}`;
    result.position.copy(node.position);result.quaternion.copy(node.quaternion);result.scale.copy(node.scale);
    copied.set(node,result);(node===model?scene:copy(node.parent)).add(result);return result;
  }
  for(const node of boundaries)copy(node);
  const memberships=new Map(), lods=[];
  for(const [level,distance] of [2,10,50].entries()){
    selectModelLOD(model,{distance});
    // Presentation FX/team ring are not anatomy; retain held source pulse weapon.
    model.userData.base.visible=false;
    let triangles=0,drawObjects=0;const bounds=new T.Box3();
    model.traverseVisible(n=>{if(!n.isMesh)return;
      memberships.set(n,(memberships.get(n)||0)|(1<<level));
      triangles+=(n.geometry.index?.count??n.geometry.attributes.position.count)/3;drawObjects++;
      n.geometry.computeBoundingBox();bounds.union(n.geometry.boundingBox.clone().applyMatrix4(n.matrixWorld));
    });
    lods.push({level,distance,triangles,sourceDrawObjects:drawObjects,bounds:[bounds.min.toArray(),bounds.max.toArray()]});
  }
  const buckets=new Map(), mats=new Map();
  for(const [node,mask] of memberships){
    if(Array.isArray(node.material))throw new Error('Unexpected multi-material source mesh');
    const srcMat=node.material;
    if(srcMat.map||srcMat.normalMap||srcMat.roughnessMap)throw new Error('Source gained textures: bake original canvas before exporting');
    if(!mats.has(srcMat)){const m=srcMat.clone();m.userData={};m.name=`sourceMaterial${mats.size}`;mats.set(srcMat,m);}
    let owner=node;
    while(!boundaries.has(owner))owner=owner.parent;
    const key=`${copy(owner).name}|${mats.get(srcMat).name}|${mask}|${+node.castShadow}`;
    if(!buckets.has(key))buckets.set(key,{owner,mask,material:mats.get(srcMat),geometries:[],castShadow:node.castShadow,sourceMeshes:0});
    const transform=owner.matrixWorld.clone().invert().multiply(node.matrixWorld);
    let geometry=node.geometry.clone().applyMatrix4(transform);
    if(geometry.index)geometry=geometry.toNonIndexed();
    // Keep source normals, UVs and precision vertex color. White is neutral for non-colored meshes.
    for(const attr of Object.keys(geometry.attributes))if(!['position','normal','uv','color'].includes(attr))geometry.deleteAttribute(attr);
    const count=geometry.attributes.position.count;
    if(!geometry.attributes.uv)geometry.setAttribute('uv',new T.Float32BufferAttribute(new Float32Array(count*2),2));
    if(!geometry.attributes.color)geometry.setAttribute('color',new T.Float32BufferAttribute(new Float32Array(count*3).fill(1),3));
    if(transform.determinant()<0){
      // A reflected rigid transform must reverse triangle order after baking.
      for(const attr of Object.values(geometry.attributes))for(let i=0;i<count;i+=3)for(let k=0;k<attr.itemSize;k++){
        const a=(i+1)*attr.itemSize+k,b=(i+2)*attr.itemSize+k,v=attr.array[a];attr.array[a]=attr.array[b];attr.array[b]=v;
      }
    }
    buckets.get(key).geometries.push(geometry);buckets.get(key).sourceMeshes++;
  }
  const batches=[],geometrySamples={};
  for(const b of buckets.values()){
    const geometry=mergeVertices(mergeGeometries(b.geometries),1e-7),mesh=new T.Mesh(geometry,b.material);
    if(!b.material.vertexColors)geometry.deleteAttribute('color');
    mesh.name=`LOD${b.mask}_Batch${batches.length}`;copy(b.owner).add(mesh);
    mesh.userData={sourceLodMask:b.mask,sourceCastShadow:b.castShadow};
    batches.push({name:mesh.name,owner:copy(b.owner).name,mask:b.mask,triangles:geometry.index.count/3,sourceMeshes:b.sourceMeshes,castShadow:b.castShadow});
    // Source-side triangle samples exercise native winding and normals after import.
    const samples=[];
    for(let i=0;i<geometry.index.count&&samples.length<2;i+=3){
      const vertices=[0,1,2].map(k=>{const index=geometry.index.getX(i+k);return {position:new T.Vector3().fromBufferAttribute(geometry.attributes.position,index).toArray(),normal:new T.Vector3().fromBufferAttribute(geometry.attributes.normal,index).normalize().toArray(),...(geometry.attributes.color?{color:new T.Vector3().fromBufferAttribute(geometry.attributes.color,index).toArray()}: {})};});
      const p=vertices.map(v=>new T.Vector3().fromArray(v.position));
      if(p[1].clone().sub(p[0]).cross(p[2].clone().sub(p[0])).length()>1e-9&&vertices.every(v=>Math.hypot(...v.normal)>.9))samples.push(vertices);
    }
    geometrySamples[mesh.name]=samples;
    for(const g of b.geometries)g.dispose();
  }
  for(const lod of lods){lod.drawObjects=batches.filter(b=>b.mask&(1<<lod.level)).length;
    if(lod.triangles!==batches.filter(b=>b.mask&(1<<lod.level)).reduce((n,b)=>n+b.triangles,0))throw new Error('Triangle loss');}
  const sourceJoints=Object.fromEntries([...copied].map(([node,clone])=>[clone.name,{parent:node===model?'':copied.get(node.parent).name,position:node.position.toArray(),quaternion:node.quaternion.toArray(),scale:node.scale.toArray()}]));
  // Explicit attachment contracts, all source-authored coordinates.
  const anchors={FeetOrigin:[0,0,0],Helmet:copy(joints.head).name,GunMount:copy(joints.gunAnchor).name,GripLeft:'gripL',GripRight:'gripR'};
  const muzzle=model.userData.weapon.userData.muzzle;
  const muzzleNode=new T.Group();muzzleNode.name='Muzzle';
  if(!muzzle?.isObject3D)throw new Error('Missing source weapon muzzle anchor');
  muzzleNode.position.copy(muzzle.position);
  copy(model.userData.weapon).add(muzzleNode);
  anchors.Muzzle={parent:'weapon',position:muzzleNode.position.toArray(),source:'simpleWeaponModel pulse barrel endpoint'};
  // Actual source bar meshes, independent of neutral anatomy LOD counts.
  for(const [side,mark] of model.userData.teamMarks.entries()){
    const group=new T.Group();group.name=`TeamMark${side}`;group.position.copy(mark.position);group.quaternion.copy(mark.quaternion);copy(model).add(group);
    for(const [index,bar] of mark.children.entries()){
      const mesh=new T.Mesh(bar.geometry,bar.material.clone());mesh.material.userData={};mesh.material.name='sourceTeamIvory';
      mesh.name=`TeamBar${side}${index}`;mesh.position.copy(bar.position);group.add(mesh);
    }
  }
  const snapshots={};
  const snapshot=()=>{model.updateMatrixWorld(true);return Object.fromEntries([...copied].map(([node,clone])=>[clone.name,{position:node.position.toArray(),quaternion:node.quaternion.toArray(),world:node.matrixWorld.toArray()}]));};
  snapshots.bind=snapshot();
  for(const [name,state] of Object.entries(states)){model.userData.rig.reset();model.userData.rig.apply(characterPose({...state,contactGait:true}));snapshots[name]=snapshot();}
  const death=deathLimbPose({pose:'back',seed:17,progress:1});
  model.userData.rig.reset();model.userData.rig.lifecycle='dead';model.userData.rig.applyCorpse(death);snapshots.death=snapshot();
  model.userData.rig.reset();snapshots.reset=snapshot();
  const sequence={};
  for(const [index,state] of updateSequence.entries()){model.userData.rig.update(state);if(index%15===14)sequence[index]=snapshot();}
  model.userData.rig.reset();
  fixtures.operators.push({id:info.id,snapshots,sequence,geometrySamples});
  const bytes=Buffer.from(await new GLTFExporter().parseAsync(scene,{binary:true,onlyVisible:true}));
  const file=`${info.id}.glb`;await writeFile(new URL(file,out),bytes);
  manifest.operators.push({id:info.id,name:info.name,file,sha256:sha(bytes),bytes:bytes.length,lods,batches,joints:sourceJoints,anchors,deathPose:death,teamArmorMaterial:mats.get(model.userData.armor).name,teamPalette:TEAM_PALETTE,materials:[...mats.values()].map(m=>({name:m.name,color:m.color.toArray(),metalness:m.metalness??0,roughness:m.roughness??1,emissive:m.emissive?.toArray()??[0,0,0],emissiveIntensity:m.emissiveIntensity??0,vertexColors:m.vertexColors,unlit:m.isMeshBasicMaterial===true}))});
  console.log(info.id,JSON.stringify(lods.map(({triangles,drawObjects})=>({triangles,drawObjects}))),bytes.length);
  assets.dispose();
}
await writeFile(new URL('manifest.json',out),JSON.stringify(manifest,null,2)+'\n');
await writeFile(new URL('catalog.gd',out),'extends RefCounted\n# Generated from the actual source model; no gameplay authority.\nconst OPERATORS = '+JSON.stringify(Object.fromEntries(manifest.operators.map(o=>[o.id,o])),null,'\t')+'\n');
await mkdir(new URL('godot/tests/source_operators/',root),{recursive:true});
await writeFile(new URL('godot/tests/source_operators/source_transforms.json',root),JSON.stringify(fixtures)+'\n');
