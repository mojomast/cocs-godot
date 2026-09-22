import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {normalizeGLTFSides} from './gltf_side.mjs';

function triangle(indexed){
 const geometry=new T.BufferGeometry();
 geometry.setAttribute('position',new T.Float32BufferAttribute([0,0,0,1,0,0,0,1,0],3));
 geometry.setAttribute('normal',new T.Float32BufferAttribute([0,0,1,0,0,1,0,0,1],3));
 geometry.setAttribute('tangent',new T.Float32BufferAttribute([1,0,0,1,1,0,0,1,1,0,0,1],4));
 geometry.setAttribute('uv',new T.Float32BufferAttribute([0,0,1,0,0,1],2));
 geometry.setAttribute('color',new T.Uint8BufferAttribute([255,0,0,0,255,0,0,0,255],3,true));
 geometry.morphAttributes.normal=[geometry.attributes.normal.clone()];
 geometry.morphAttributes.position=[geometry.attributes.position.clone()];
 geometry.addGroup(0,3,0);geometry.setDrawRange(0,3);
 if(indexed)geometry.setIndex([0,1,2]);
 return geometry;
}
for(const indexed of [true,false])test(`BackSide clone isolation and UV tangent basis (${indexed?'indexed':'nonindexed'})`,()=>{
 const source=new T.Group(),geometry=triangle(indexed);
 const back=new T.MeshStandardMaterial({side:T.BackSide}),front=new T.MeshStandardMaterial(),double=new T.MeshStandardMaterial({side:T.DoubleSide});
 source.add(new T.Mesh(geometry,back),new T.Mesh(geometry,front),new T.Mesh(geometry,double));
 const before=JSON.stringify(source.toJSON()),copy=source.clone(true);
 const result=normalizeGLTFSides(copy),converted=copy.children[0];
 assert.equal(result.meshes,1);assert.equal(result.triangles,1);
 assert.equal(JSON.stringify(source.toJSON()),before);
 assert.notEqual(converted.geometry,geometry);assert.notEqual(converted.material,back);
 assert.equal(copy.children[1].geometry,geometry);assert.equal(copy.children[2].geometry,geometry);
 assert.equal(copy.children[1].material,front);assert.equal(copy.children[2].material,double);
 assert.equal(converted.material.side,T.FrontSide);
 assert.deepEqual([...converted.geometry.index.array],[0,2,1]);
 for(const key of ['position','uv','color'])assert.deepEqual(converted.geometry.attributes[key].array,geometry.attributes[key].array);
 assert.deepEqual(converted.geometry.groups,geometry.groups);assert.deepEqual(converted.geometry.drawRange,geometry.drawRange);
 assert.deepEqual(converted.geometry.morphAttributes.position[0].array,geometry.morphAttributes.position[0].array);
 const n=new T.Vector3().fromBufferAttribute(converted.geometry.attributes.normal,0);
 const t=new T.Vector3().fromBufferAttribute(converted.geometry.attributes.tangent,0);
 assert.equal(n.z,-1);assert.equal(converted.geometry.morphAttributes.normal[0].getZ(0),-1);
 assert.deepEqual(t.toArray(),[1,0,0]);
 const bitangent=n.clone().cross(t).multiplyScalar(converted.geometry.attributes.tangent.getW(0));
 assert.equal(bitangent.y,1); // Three's original BackSide TBN is (+X,+Y,-Z).
 const vertices=[...converted.geometry.index.array].map(i=>new T.Vector3().fromBufferAttribute(converted.geometry.attributes.position,i));
 assert.ok(vertices[1].sub(vertices[0]).cross(vertices[2].sub(vertices[0])).dot(n)>0);
 assert.equal(normalizeGLTFSides(copy).meshes,0); // idempotent
});

test('expanded instances sharing source geometry each get isolated BackSide copies',()=>{
 const geometry=triangle(true),material=new T.MeshBasicMaterial({side:T.BackSide});
 const source=new T.InstancedMesh(geometry,material,2),exported=new T.Group();
 const before=JSON.stringify(geometry.toJSON());
 for(let i=0;i<source.count;i++){const mesh=new T.Mesh(source.geometry,source.material);mesh.position.x=i;exported.add(mesh);}
 assert.equal(normalizeGLTFSides(exported).meshes,2);
 assert.notEqual(exported.children[0].geometry,exported.children[1].geometry);
 assert.deepEqual(exported.children.map(mesh=>mesh.position.x),[0,1]);
 assert.equal(JSON.stringify(geometry.toJSON()),before);assert.equal(source.material.side,T.BackSide);
 assert.throws(()=>normalizeGLTFSides(source),/expand instances/);
});

test('closed sphere faces inward after conversion with original exterior intact',()=>{
 const geometry=new T.SphereGeometry(185,48,32),mesh=new T.Mesh(geometry,new T.MeshBasicMaterial({side:T.BackSide}));
 const before=JSON.stringify(geometry.toJSON());normalizeGLTFSides(mesh);
 let inward=0;
 for(let i=0;i<mesh.geometry.index.count;i+=3){
  const [a,b,c]=[0,1,2].map(j=>new T.Vector3().fromBufferAttribute(mesh.geometry.attributes.position,mesh.geometry.index.getX(i+j)));
  const face=b.clone().sub(a).cross(c.clone().sub(a));assert.ok(face.dot(a)<0);inward++;
 }
 assert.equal(inward,2976);assert.equal(JSON.stringify(geometry.toJSON()),before);
});

test('homogeneous BackSide arrays preserve groups; mixed-side arrays fail explicitly',()=>{
 const geometry=triangle(true),back=new T.MeshBasicMaterial({side:T.BackSide});
 const mesh=new T.Mesh(geometry,[back,back]);normalizeGLTFSides(mesh);
 assert.ok(mesh.material.every(m=>m.side===T.FrontSide));assert.deepEqual(mesh.geometry.groups,geometry.groups);
 const mixed=new T.Mesh(geometry,[back,new T.MeshBasicMaterial()]);
 assert.throws(()=>normalizeGLTFSides(mixed),/mixed-side/);assert.equal(mixed.geometry,geometry);
});

test('unsupported BackSide shader/object-space normal and partial triangles fail explicitly',()=>{
 for(const material of [new T.ShaderMaterial({side:T.BackSide}),new T.MeshStandardMaterial({side:T.BackSide,normalMap:new T.Texture(),normalMapType:T.ObjectSpaceNormalMap})]){
  assert.throws(()=>normalizeGLTFSides(new T.Mesh(triangle(true),material)),/explicit/);
 }
 const geometry=triangle(false);geometry.setDrawRange(1,2);
 assert.throws(()=>normalizeGLTFSides(new T.Mesh(geometry,new T.MeshBasicMaterial({side:T.BackSide}))),/unaligned/);
});
