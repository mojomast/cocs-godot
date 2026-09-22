import {BackSide,FrontSide,ObjectSpaceNormalMap} from 'three';

// Call on the export-only hierarchy, AFTER expanding InstancedMesh. Object3D
// clone() still shares geometry/materials with the live source: replace, never
// edit, those resources. glTF doubleSided cannot express Three's BackSide.
export function normalizeGLTFSides(root){
 const report={policy:'BackSide: reversed triangles, negated normals, tangent handedness; FrontSide glTF material',meshes:0,triangles:0};
 root.traverse(object=>{
  if(!object.isMesh)return;
  const materials=[object.material].flat();
  if(!materials.some(material=>material?.side===BackSide))return;
  if(object.isInstancedMesh||object.isBatchedMesh)throw Error('GLTF side: expand instances/batches before normalization');
  if(materials.some(material=>!material||material.side!==BackSide))throw Error('GLTF side: mixed-side material groups require explicit splitting');
  if(materials.some(material=>material.isShaderMaterial))throw Error('GLTF side: BackSide ShaderMaterial requires explicit standard-material conversion');
  if(materials.some(material=>material.normalMap&&material.normalMapType===ObjectSpaceNormalMap))throw Error('GLTF side: object-space normal maps require explicit baking');
  const source=object.geometry;
  const count=source.index?.count??source.attributes.position?.count;
  if(!Number.isInteger(count)||count%3!==0)throw Error('GLTF side: expected triangle geometry');
  for(const range of [source.drawRange,...source.groups]){
   if(range.start%3!==0||(range.count!==Infinity&&range.count%3!==0))throw Error('GLTF side: unaligned triangle range');
  }
  const geometry=source.clone();
  // Adding an index for non-indexed input keeps every vertex attribute (UV,
  // color, skin weights, morphs, custom data) attached to its original vertex.
  if(!geometry.index)geometry.setIndex(Array.from({length:count},(_,i)=>i));
  const index=geometry.index;
  for(let i=0;i<count;i+=3){const b=index.getX(i+1);index.setX(i+1,index.getX(i+2));index.setX(i+2,b);}
  index.needsUpdate=true;
  for(const normal of [geometry.attributes.normal,...(geometry.morphAttributes.normal??[])].filter(Boolean)){
   for(let i=0;i<normal.count;i++)normal.setXYZ(i,-normal.getX(i),-normal.getY(i),-normal.getZ(i));
   normal.needsUpdate=true;
  }
  // Three r185 FLIP_SIDED keeps T and B but negates N. Since glTF derives
  // B=cross(N,T)*w, negate w (not tangent.xyz) to retain the authored UV basis.
  const tangent=geometry.attributes.tangent;
  if(tangent){for(let i=0;i<tangent.count;i++)tangent.setW(i,-tangent.getW(i));tangent.needsUpdate=true;}
  const converted=materials.map(material=>{const copy=material.clone();copy.side=FrontSide;return copy;});
  object.geometry=geometry;
  object.material=Array.isArray(object.material)?converted:converted[0];
  report.meshes++;report.triangles+=count/3;
 });
 return report;
}
