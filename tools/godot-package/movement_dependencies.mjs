import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {reverseRacing} from './racing_dependencies.mjs';
export const MOVEMENT_INVENTORY='tools/godot-package/movement_f61_inventory.json';
export const MOVEMENT_INVENTORY_SHA='532faf2b9fa92b674f06a4485615e5405a73666fd43893f31baedccee9f6712d';
const hash=b=>createHash('sha256').update(b).digest('hex');
const PREVIOUS={
 'parallax-interiors':'a04d631904a35983ccc6aa08bb24ff74f888fcc68d2f9b2ab60b5acff59db83f',
 robots:'e5b28e90bd27a7420402634a62f35e98d458b30da7a804f5df810b4358e444de',
 vehicles:'200f5d7827d8cba331ac4161e1e84933af7de5963514a4178b2b97b6b6f14c6b',
 scenery:'726c62f8dd3fe00b93e63d8cbf480fff6cdbd3cd40e2d0121ba6222743ba6072',
 'vesper-viaduct':'a6f642f97e6d938b66f5e82c1778d2e9d5e13732b945fe5992ecbe12eeff10da',
 'abyssal-pressureworks':'5606d508ee887576a7ea37f668945a9734e93b06b03099871e6a1522d0807c97',
 'stormglass-causeway':'b68176868a1afdf310fec4f034282f0d9212010e7f9018bb016431923046e7c7',
};
// Reverse the complete delta and require the immutable original receipt bytes.
// This binds unknown producer fields and every earlier review, not only a list
// of familiar keys. Current receipt hashes still bind the reviewed new bytes.
export function verifyMovementPredecessor(receipt,read){
 assert.ok(receipt.movementAdvance,'Explicit movement reconciliation required');
 receipt=reverseRacing(receipt,read);
 const r=receipt.movementAdvance,s=movementInventory(read),old=structuredClone(receipt);
 delete old.movementAdvance;
 assert.deepEqual(r.previousReceipt,{commit:s.foundation,path:`tools/godot-package/production_receipts/${receipt.unit}.json`,sha256:PREVIOUS[receipt.unit]},'Exact movement predecessor receipt');
 for(const [p,sha]of Object.entries(r.added)){
  assert.equal(old.packageInputs[p],sha,'Movement addition identity');delete old.packageInputs[p];
 }
 for(const [p,c]of Object.entries(r.changed)){
  assert.equal(old.packageInputs[p],c.after,'Movement delta identity');assert.notEqual(c.before,c.after);old.packageInputs[p]=c.before;
 }
 assert.equal(hash(JSON.stringify(old.packageInputs)),r.previousPackageFingerprint,'Movement previous fingerprint');
 assert.equal(hash(JSON.stringify(receipt.packageInputs)),r.packageFingerprint,'Movement current fingerprint');
 assert.equal(hash(JSON.stringify(old,null,2)+'\n'),PREVIOUS[receipt.unit],'Full pre-movement producer/history identity');
}
export function movementInventory(read){
 const b=read(MOVEMENT_INVENTORY);assert.equal(hash(b),MOVEMENT_INVENTORY_SHA,'Exact movement inventory');return JSON.parse(b);
}
export function movementPaths(read){
 const s=movementInventory(read);
 return [MOVEMENT_INVENTORY,'tools/godot-package/movement_dependencies.mjs','tools/godot-package/source_derivative.mjs','port/contracts/lattice-catalog-derivative.json',...Object.keys(s.changed),...Object.keys(s.added)];
}
export function movementSupportingHash(path,before,read){
 const c=movementInventory(read).changed[path];if(!c)return before;
 assert.equal(before,c.before,'Broken pre-movement supporting history: '+path);return c.after;
}
export function verifyMovementAdvance(receipt,read){
 const s=movementInventory(read),r=receipt.movementAdvance;
 assert.ok(r,'Explicit movement reconciliation required');
 assert.deepEqual(r.reviewedSource,s,'Exact movement source history');
 const hook='godot/horde/demo.gd',policy=receipt.unit==='robots'?{[hook]:s.changed[hook]}:{};
 assert.deepEqual(r.runtimeChanged,policy,'Exact movement consumer hook mapping');
 for(const [p,c]of Object.entries(policy))assert.equal(receipt.runtimeHooks[p],c.before,'Original native hook identity retained');
 assert.deepEqual(r.review,{foundation:s.foundation,status:s.status,nativeChecks:'pending',assetProduction:'reuse unchanged original production bytes',document:'port/finish/movement-research/PACKAGE_RECONCILIATION.md'},'Movement review boundary');
 for(const [p,sha]of Object.entries({...Object.fromEntries(Object.entries(s.changed).map(([p,c])=>[p,c.after])),...s.added})){
  assert.equal(hash(read(p)),sha,'Reviewed movement bytes: '+p);
  assert.equal(receipt.packageInputs[p],sha,'Current movement dependency: '+p);
 }
}
