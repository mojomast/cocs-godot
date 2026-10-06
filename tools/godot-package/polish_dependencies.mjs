import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {movementPaths,movementSupportingHash,verifyMovementAdvance} from './movement_dependencies.mjs';
import {racingSupportingHash,racingSupportingHookHash} from './racing_dependencies.mjs';
import {dressingSupportingHash} from './dressing_dependencies.mjs';
import {vesperApronSupportingHash} from './vesper_apron_dependencies.mjs';
import {consolidationSupportingHash} from './consolidation_dependencies.mjs';
export const POLISH_INVENTORY='tools/godot-package/polish_8921_inventory.json';
export const POLISH_INVENTORY_SHA='81f8d2531486fcb88da14dc98cd19565a543e87a4fc389329cbdbb2de6109015';
const hash=b=>createHash('sha256').update(b).digest('hex');
export const O_SOURCE_CHANGE={'godot/ui/local_settings.gd':{before:'569765028c3a7029c6fee7972d3b3926fe2d4af8cfec755012f595a212cf50a7',after:'073a48948796a68680cd0f4242655374c5f8b7fc5b835347ebaf0dd35b7d42f9'}};
export const O_EVIDENCE={
 'port/finish/acceptance/package-evidence-o/HEAVY_GRANT_RELEASE.json':'75e737cbf562be0601b83b73a09157fd0fce91632f7dc2fe2712b34ad7d7cde7',
 'port/finish/acceptance/package-evidence-o/world-final-01/receipt.json':'e35f5391b787d73c21e26a7ae98a18d5cb84070371b907c1b0438746ce640972',
 'port/finish/acceptance/package-evidence-o/combined-home-regression-01/receipt.json':'3b97393b6388145314535d7a5c8f91abffb2a2fd8173eb11f0942e16ce2fe4c1',
 'port/finish/acceptance/package-evidence-o/controls-final-01/receipt.json':'30affd0776ab8bfd1fb4b11810e987580e8450e40f5bcb4235bc2c3d6fe547ee',
};
export function verifyOReview(receipt,read){
 verifyMovementAdvance(receipt,read);
 const r=receipt.oReviewAdvance;
 assert.ok(r,'Explicit O reconciliation required');
 assert.deepEqual(r.sourceChanged,O_SOURCE_CHANGE,'Exact O source history');
 assert.deepEqual(r.runtimeChanged,{},'O has no declared activation hook changes');
 assert.deepEqual(r.review,{foundation:'b17360c9',scope:'one reviewed Settings Return Home correction and retained O final receipts',nativeCoverage:'ordinary world and combined-arms journeys plus 90-assertion controls fixture; not final 142 acceptance',liveKickAcceptance:'not accepted',document:'port/finish/acceptance/O_PACKAGE_RECONCILIATION.md'},'O review boundary');
 for(const [p,c]of Object.entries(O_SOURCE_CHANGE))assert.equal(receipt.packageInputs[p],c.after,'Current O dependency identity');
 for(const [p,sha]of Object.entries(O_EVIDENCE))assert.equal(hash(read(p)),sha,'Exact retained O evidence: '+p);
}
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
 verifyOReview(receipt,read);
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
 return [...movementPaths(read),POLISH_INVENTORY,...Object.keys(O_EVIDENCE),...Object.keys(L_EVIDENCE),...Object.keys(s.changed),...Object.keys(s.added),...Object.keys(s.evidence),...Object.keys(s.operatorFinish.data),...Object.entries(s.operatorFinish.imports).flatMap(([p,r])=>[p,r.sidecar])];
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
 for(const [p,c]of Object.entries(policy))assert.equal(receipt.runtimeHooks[p],racingSupportingHookHash(p,c.after,receipt),'Polish current runtime identity');
 for(const [p,c]of Object.entries(s.changed))assert.equal(receipt.packageInputs[p],consolidationSupportingHash(p,vesperApronSupportingHash(p,dressingSupportingHash(p,racingSupportingHash(p,movementSupportingHash(p,lSupportingHash(p,c.after),read),receipt),receipt),receipt),receipt),'Reviewed polish dependency identity: '+p);
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
