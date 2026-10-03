import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const POLISH_INVENTORY='tools/godot-package/polish_8921_inventory.json';
export const POLISH_INVENTORY_SHA='81f8d2531486fcb88da14dc98cd19565a543e87a4fc389329cbdbb2de6109015';
const hash=b=>createHash('sha256').update(b).digest('hex');
export function polishInventory(read){
 const bytes=read(POLISH_INVENTORY);assert.equal(hash(bytes),POLISH_INVENTORY_SHA,'Exact 8921ed41 snapshot identity');return JSON.parse(bytes);
}
export function polishPaths(read){
 const s=polishInventory(read);
 return [POLISH_INVENTORY,...Object.keys(s.changed),...Object.keys(s.added),...Object.keys(s.evidence),...Object.keys(s.operatorFinish.data),...Object.entries(s.operatorFinish.imports).flatMap(([p,r])=>[p,r.sidecar])];
}
// Only advance a historical supporting hash if its exact old value is the
// reviewed predecessor. Earlier records themselves are never rewritten.
export function polishSupportingHash(path,before,receipt){
 const c=receipt.polishAdvance?.reviewedSource?.changed?.[path];
 if(!c)return before;
 assert.equal(c.before,before,'Broken pre-polish supporting history: '+path);
 return c.after;
}
export function verifyPolishAdvance(receipt,read){
 const s=polishInventory(read),r=receipt.polishAdvance;
 assert.ok(r,'Explicit polish reconciliation required');
 assert.deepEqual(r.review,{foundation:s.foundation,scope:s.scope,combinedNativeChecks:'pending',liveKickAcceptance:'not accepted',document:'port/finish/polish/PACKAGE_RECONCILIATION.md'},'Polish review boundary');
 assert.deepEqual(r.reviewedSource,{previous:s.previous,foundation:s.foundation,changed:s.changed,added:s.added},'Exact reviewed polish source history');
 const hook='godot/multiplayer_worlds/sports_demo.gd',c=s.changed[hook];
 const policy=receipt.unit==='stormglass-causeway'?{[hook]:{before:c.before,after:c.after}}:{};
 assert.deepEqual(r.runtimeChanged,policy,'Exact polish activation hook advance');
 for(const [p,c]of Object.entries(policy))assert.equal(receipt.runtimeHooks[p],c.after,'Polish current runtime identity');
 for(const [p,c]of Object.entries(s.changed))assert.equal(receipt.packageInputs[p],c.after,'Reviewed polish dependency identity: '+p);
 for(const [p,sha]of Object.entries({...s.added,...s.evidence,...s.operatorFinish.data}))assert.equal(receipt.packageInputs[p],sha,'Exact polish addition: '+p);
}
export function verifyOperatorFinishImports(read){
 const s=polishInventory(read),entries=Object.entries(s.operatorFinish.imports);assert.equal(entries.length,116);
 for(const [p,r]of entries){
  const bytes=read(p),meta=read(r.sidecar);assert.equal(hash(bytes),r.sha256,'Operator finish PNG identity: '+p);assert.equal(hash(meta),r.sidecarSHA256,'Released K sidecar identity: '+r.sidecar);
  assert.equal(bytes.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
  const lines=meta.toString().split('\n');for(const line of [`source_file="res://${p.slice(6)}"`,'importer="texture"','compress/mode=0','compress/normal_map=0','process/normal_map_invert_y=false','process/size_limit=0'])assert.ok(lines.includes(line),'Operator finish import policy: '+p+' '+line);
 }
}
