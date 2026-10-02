import assert from 'node:assert/strict';

// Bounded producer contract: exactly one named enamel image per declared GLB.
// No directory scan, guessed normal map, or fighter animation policy.
export function robotImportPaths(exports) {
  return exports.flatMap(path=>{
    const image=path.replace(/\.glb$/,'_MothLocal_Switchyard_vertex_enamel.png');
    return [path+'.import',image,image+'.import'];
  });
}

export function verifyRobotImports(exports,read) {
  for(const path of exports) {
    const bytes=read(path),jsonLength=bytes.readUInt32LE(12);
    const doc=JSON.parse(bytes.subarray(20,20+jsonLength));
    const bin=bytes.subarray(28+jsonLength);
    assert.equal(doc.images?.length,1,'Robot must retain its single enamel image');
    const image=doc.images[0];
    assert.equal(image.name,'MothLocal_Switchyard_vertex_enamel');
    assert.equal(image.mimeType,'image/png');
    const extracted=path.replace(/\.glb$/,'_'+image.name+'.png');
    const view=doc.bufferViews[image.bufferView];
    assert.equal(view.buffer,0);
    const embedded=bin.subarray(view.byteOffset??0,(view.byteOffset??0)+view.byteLength);
    assert.deepEqual(read(extracted),embedded,'Robot extracted texture differs from embedded image');
    for(const [source,importer]of [[path,'scene'],[extracted,'texture']]) {
      const text=read(source+'.import').toString();
      assert.ok(text.split('\n').includes(`source_file="res://${source.slice(6)}"`),'Robot import source identity');
      assert.ok(text.split('\n').includes(`importer="${importer}"`),'Robot importer identity');
      if(importer==='scene') {
        assert.match(text,/^gltf\/embedded_image_handling=1$/m,'Robot extracted-image policy');
        assert.match(text,/^meshes\/ensure_tangents=true$/m,'Robot tangent import policy');
      }
    }
    for(const mesh of doc.meshes)for(const primitive of mesh.primitives) {
      assert.ok(Number.isInteger(primitive.attributes.TEXCOORD_0),'Robot local UV stream required');
      assert.equal(primitive.attributes.TEXCOORD_1,undefined,'Unexpected robot secondary UV stream');
      const color=doc.accessors[primitive.attributes.COLOR_0];
      assert.ok(color,'Robot authored COLOR_0 required');
      assert.equal(color.componentType,5123);assert.equal(color.type,'VEC4');assert.equal(color.normalized,true);
      const v=doc.bufferViews[color.bufferView],start=(v.byteOffset??0)+(color.byteOffset??0),stride=v.byteStride??8;
      let tinted=false;
      for(let i=0;i<color.count;i++)for(let c=0;c<3;c++)if(bin.readUInt16LE(start+i*stride+c*2)!==65535)tinted=true;
      assert.ok(tinted,'Robot white placeholder COLOR_0 rejected');
    }
  }
}
