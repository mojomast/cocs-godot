import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const POLISH_INVENTORY='tools/godot-package/polish_8921_inventory.json';
export const POLISH_INVENTORY_SHA='81f8d2531486fcb88da14dc98cd19565a543e87a4fc389329cbdbb2de6109015';
const hash=b=>createHash('sha256').update(b).digest('hex');
export const L_SOURCE_CHANGE={'godot/ui/lobby_choice.gd':{before:'2f2b0264984c1f959f497877e63936f79765219d8d808cc2fb10d3c724f2d19a',after:'9eba4c8067e4b769a3486cf0949680a5e145c1620d00608f9ece1fad8b9d7e95'}};
export const L_EVIDENCE={
 'port/finish/polish/package-evidence-l/release-L.json':'819946192b5425341e3759d0f1ea0e00b03e6ee287b06ff6651eed6d3dc44675',
 'port/finish/polish/package-evidence-l/NATIVE_RESULTS_L.json':'2365f98ddf01a038503982febebc686c35812436ff37f9acdf6ac5619a6feae2',
 'port/finish/polish/package-evidence-l/sidecars-post-import.json':'6dd729453631d929094fb28ee1c027e740e180508a59958f6a2e78f0d53bdf5f',
};
export function lSupportingHash(path,before){
 const c=L_SOURCE_CHANGE[path];if(!c)return before;
 assert.equal(before,c.before,'Broken polish-to-L predecessor: '+path);return c.after;
}
export function verifyLReview(receipt,read){
 const r=receipt.lReviewAdvance;
 assert.ok(r,'Explicit L reconciliation required');
 assert.deepEqual(r.sourceChanged,L_SOURCE_CHANGE,'Exact L source history');
 assert.deepEqual(r.runtimeChanged,{},'L has no declared activation hook changes');
 assert.deepEqual(r.review,{foundation:'9cd1ac72',scope:'one reviewed lobby Cancel correction and retained supplemental L evidence',nativePolish:'L supplemental coverage passed; not final 142 acceptance',liveKickAcceptance:'not accepted',document:'port/finish/polish/L_PACKAGE_RECONCILIATION.md'},'L review boundary');
 for(const [p,c]of Object.entries(L_SOURCE_CHANGE))assert.equal(receipt.packageInputs[p],c.after,'Current L dependency identity');
 for(const [p,sha]of Object.entries(L_EVIDENCE))assert.equal(hash(read(p)),sha,'Exact retained L evidence: '+p);
}
export function polishInventory(read){
 const bytes=read(POLISH_INVENTORY);assert.equal(hash(bytes),POLISH_INVENTORY_SHA,'Exact 8921ed41 snapshot identity');return JSON.parse(bytes);
}
export function polishPaths(read){
 const s=polishInventory(read);
 return [POLISH_INVENTORY,...Object.keys(L_EVIDENCE),...Object.keys(s.changed),...Object.keys(s.added),...Object.keys(s.evidence),...Object.keys(s.operatorFinish.data),...Object.entries(s.operatorFinish.imports).flatMap(([p,r])=>[p,r.sidecar])];
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
 verifyLReview(receipt,read);
 const s=polishInventory(read),r=receipt.polishAdvance;
 assert.ok(r,'Explicit polish reconciliation required');
 assert.deepEqual(r.review,{foundation:s.foundation,scope:s.scope,combinedNativeChecks:'pending',liveKickAcceptance:'not accepted',document:'port/finish/polish/PACKAGE_RECONCILIATION.md'},'Polish review boundary');
 assert.deepEqual(r.reviewedSource,{previous:s.previous,foundation:s.foundation,changed:s.changed,added:s.added},'Exact reviewed polish source history');
 const hook='godot/multiplayer_worlds/sports_demo.gd',c=s.changed[hook];
 const policy=receipt.unit==='stormglass-causeway'?{[hook]:{before:c.before,after:c.after}}:{};
 assert.deepEqual(r.runtimeChanged,policy,'Exact polish activation hook advance');
 for(const [p,c]of Object.entries(policy))assert.equal(receipt.runtimeHooks[p],c.after,'Polish current runtime identity');
 for(const [p,c]of Object.entries(s.changed))assert.equal(receipt.packageInputs[p],lSupportingHash(p,c.after),'Reviewed polish dependency identity: '+p);
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
