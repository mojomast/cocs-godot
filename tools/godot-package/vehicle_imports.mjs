import assert from 'node:assert/strict';

const evidence='port/expansion-four/vehicles/production-e/';
export const VEHICLE_EVIDENCE=[
  'generic-receipt.json','HEAVY_GRANT_RELEASE.json',
  '20261003T003535.707648Z/native-process.json','20261003T003539.486740Z/journey-process.json',
  ...['puma','titan','scout'].flatMap(kind=>[`${kind}/outcome.json`,`${kind}/stages.json`,`inspection/${kind}-lod0-close.png`]),
  'titan-ui150.png',
].map(p=>evidence+p);

// The production-E material/image contract, bounded by the nine declared LOD
// exports. LOD2 omits the red lamp coating. No filesystem discovery is used.
function roles(path) {
  assert.match(path,/^godot\/vehicle_assets\/generated\/(puma|titan|scout)-lod[012]\.glb$/);
  return ['armor','edge','rubber','recess','seat','team_accent',...path.endsWith('lod2.glb')?[]:['red']];
}
export function vehicleImportPaths(exports) {
  return exports.flatMap(path=>[path+'.import',...['MothLocalNormal_edge',...roles(path).map(r=>'MothLocal_'+r)].flatMap(name=>{
    const png=path.replace(/\.glb$/,'_'+name+'.png');return [png,png+'.import'];
  })]);
}

export function verifyVehicleImports(exports,read) {
  for(const path of exports) {
    const bytes=read(path),length=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+length)),bin=bytes.subarray(28+length);
    const expectedRoles=roles(path),names=['MothLocalNormal_edge',...expectedRoles.map(r=>'MothLocal_'+r)];
    assert.deepEqual(doc.images.map(i=>i.name).sort(),names.sort(),'Vehicle embedded image inventory');
    for(const image of doc.images) {
      assert.equal(image.mimeType,'image/png');assert.equal(image.uri,undefined);
      const view=doc.bufferViews[image.bufferView];assert.equal(view.buffer,0);
      const png=path.replace(/\.glb$/,'_'+image.name+'.png');
      assert.deepEqual(read(png),bin.subarray(view.byteOffset??0,(view.byteOffset??0)+view.byteLength),'Vehicle extracted PNG differs from embedded image');
    }
    for(const source of [path,...vehicleImportPaths([path]).filter(p=>p.endsWith('.png'))]) {
      const text=read(source+'.import').toString(),scene=source===path;
      assert.ok(text.split('\n').includes(`source_file="res://${source.slice(6)}"`),'Vehicle import source identity');
      assert.ok(text.split('\n').includes(`importer="${scene?'scene':'texture'}"`),'Vehicle importer identity');
      if(scene) {
        assert.match(text,/^gltf\/embedded_image_handling=1$/m,'Vehicle extracted-image policy');
        assert.match(text,/^meshes\/ensure_tangents=true$/m,'Vehicle tangent policy');
      } else {
        assert.match(text,/^compress\/normal_map=0$/m,'Reviewed vehicle texture normal import mode');
        assert.match(text,/^process\/normal_map_invert_y=false$/m,'Reviewed vehicle normal orientation');
      }
    }
    const imageFor=texture=>{
      assert.ok(texture&&Number.isInteger(texture.index),'Vehicle material texture binding');
      assert.equal(texture.texCoord??0,0,'Vehicle material uses local UV0');
      return doc.images[doc.textures[texture.index].source]?.name;
    };
    for(const role of expectedRoles) {
      const material=doc.materials.find(m=>m.name===role);assert.ok(material,'Missing vehicle material role');
      assert.equal(imageFor(material.pbrMetallicRoughness?.baseColorTexture),'MothLocal_'+role);
      if(role==='edge') {
        assert.equal(imageFor(material.normalTexture),'MothLocalNormal_edge');
        assert.ok(Math.abs(material.normalTexture.scale-.08)<1e-6,'Reviewed alloy normal strength');
      } else assert.equal(material.normalTexture,undefined,'Vehicle selective-normal policy');
    }
    for(const mesh of doc.meshes)for(const primitive of mesh.primitives) {
      assert.ok(Number.isInteger(primitive.attributes.TEXCOORD_0),'Vehicle local UV0 required');
      assert.equal(primitive.attributes.TEXCOORD_1,undefined,'Vehicle secondary UV rejected');
      // Vehicles use material colors, unlike the robots' authored COLOR_0.
      assert.equal(primitive.attributes.COLOR_0,undefined,'Unexpected vehicle vertex-color multiplication');
    }
  }
}
