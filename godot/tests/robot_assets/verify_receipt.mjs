// Post-build gate: requires actual files, never treats planned outputs as assets.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../../',import.meta.url));
const dir=root+'godot/robot_assets/switchyard/';
const contract=JSON.parse(readFileSync(dir+'contract.json'));
const receipt=JSON.parse(readFileSync(dir+'generated/build-receipt.json'));
const budget=contract.budgetsNotMeasurements;
assert.equal(receipt.seed,contract.seed);
assert.equal(Object.keys(receipt.assets).length,9);
const hash=b=>createHash('sha256').update(b).digest('hex');
assert.equal(receipt.generatorSHA256,hash(readFileSync(root+'tools/godot-robots/build.py')));
for(const [name,asset] of Object.entries(receipt.assets)){
  const bytes=readFileSync(dir+'generated/'+name+'.glb');
  assert.equal(hash(bytes),asset.sha256,name+' exported-byte provenance');
  assert.equal(bytes.readUInt32LE(0),0x46546c67,'real GLB magic');
  assert.equal(bytes.readUInt32LE(4),2);
  assert.equal(bytes.readUInt32LE(8),bytes.length);
  const gltf=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString('utf8'));
  assert.ok(gltf.meshes?.length);
  assert.ok(!gltf.nodes.some(n=>/collision|collider/i.test(n.name??'')));
  for(const mesh of gltf.meshes){
    assert.equal(mesh.primitives.length,1,name+' one surface per assembly');
    for(const p of mesh.primitives){
      assert.ok(Number.isInteger(p.attributes.POSITION));
      assert.ok(Number.isInteger(p.attributes.NORMAL));
      assert.ok(Number.isInteger(p.attributes.COLOR_0));
      const a=gltf.accessors[p.attributes.POSITION];
      assert.ok(a.count>0&&a.min.every(Number.isFinite)&&a.max.every(Number.isFinite));
    }
  }
  for(const [lod,meshes] of Object.entries(asset.lods??{prop:asset.meshes})){
    const rows=Object.values(meshes), i=Number(lod.slice(-1));
    const triangles=rows.reduce((n,m)=>n+m.triangles,0), draws=rows.reduce((n,m)=>n+m.surfaces,0);
    assert.ok(triangles>0&&triangles<=(lod==='prop'?budget.propTriangles:budget.robotTrianglesPerLOD[i]),name+' triangle budget');
    assert.ok(draws<=(lod==='prop'?budget.propDraws:budget.robotDrawsPerLOD[i]),name+' draw budget');
    for(const m of rows)assert.ok(m.boundsBlender.flat().every(Number.isFinite));
    console.log(name,lod,{triangles,draws});
  }
}
