import assert from 'node:assert/strict';
export function materialRule(contract,unit,mat){
 const name=(mat?.name??'').replace(/\.\d{3,}$/,'').toLowerCase();
 const rule=contract.units[unit]?.[name];
 assert.ok(rule,'Unreviewed material '+unit+'/'+name);return rule;
}
export function validateSurface(contract,unit,mat,p){
 const rule=materialRule(contract,unit,mat);
 if(rule.role==='preserve')return false;
 const color=mat?.pbrMetallicRoughness?.baseColorTexture;
 assert.ok(color&&p.attributes['TEXCOORD_'+(color.texCoord??0)]!==undefined&&p.attributes.NORMAL!==undefined,'Missing texture, bound phase UV or geometry normals');
 assert.equal(Boolean(mat.normalTexture),rule.normalRequired,'Selective normal policy mismatch');
 if(mat.normalTexture){
  assert.equal(mat.normalTexture.texCoord??0,color.texCoord??0,'Normal/albedo phase mismatch');
  assert.ok(Math.abs((mat.normalTexture.scale??1)-rule.normalStrength)<1e-6,'Normal strength changed');
 }
 if(rule.colorRequired)assert.notEqual(p.attributes.COLOR_0,undefined,'Robot COLOR_0 lost');
 assert.equal(mat.extras?.moth_finish_revision,2,'Stale refined material');
 assert.equal(mat.extras?.moth_family,rule.role);
 assert.deepEqual(JSON.parse(mat.extras?.moth_resource_sha256??'null'),rule.sourceHashes,'Material baked-source identity mismatch');
 assert.ok(Object.values(contract.master).includes(mat.extras?.moth_baked_master_sha256),'Wrong Moth master');
 return true;
}
