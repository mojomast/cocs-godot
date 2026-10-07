// Consolidation advance contract: every unit carries the newest layer, it
// reverses to its exact committed predecessor, forged deltas are rejected, and
// a self-consistent deletion of an added input is still caught by the closure.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {verifyConsolidationAdvance,reverseConsolidationAdvance,CONSOLIDATION_REVIEW} from './consolidation_dependencies.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const receipt=id=>`tools/godot-package/production_receipts/${id}.json`;
const git=args=>execFileSync('git',args,{maxBuffer:128*1024*1024});
const ADDED='tools/godot-package/consolidation_dependencies.mjs';

test('every unit carries the consolidation layer and reverses to its exact committed predecessor',()=>{
  const deltas=[];
  for(const id of REQUIRED_UNITS){
    const r=JSON.parse(read(receipt(id))),layer=r.consolidationAdvance;
    assert.ok(layer,id+': explicit consolidation reconciliation required');
    assert.deepEqual({scope:layer.review?.scope,nativeChecks:layer.review?.nativeChecks,document:layer.review?.document},
      {scope:CONSOLIDATION_REVIEW.scope,nativeChecks:CONSOLIDATION_REVIEW.nativeChecks,document:CONSOLIDATION_REVIEW.document},
      id+': consolidation review boundary');
    assert.equal(layer.previousReceipt.path,receipt(id),id+': predecessor receipt path');
    const committed=git(['show',`${layer.previousReceipt.commit}:${layer.previousReceipt.path}`]);
    assert.equal(hash(committed),layer.previousReceipt.sha256,id+': predecessor receipt identity');
    // The layer must reverse to the committed bytes, not merely a plausible
    // state: verifyMovementPredecessor hashes the whole reconstructed receipt.
    assert.equal(JSON.stringify(reverseConsolidationAdvance(r,read),null,2)+'\n',committed.toString('utf8'),
      id+': reversal must reproduce the committed predecessor receipt');
    deltas.push({changed:Object.keys(layer.changed).sort(),added:Object.keys(layer.added).sort()});
  }
  // The newest layer is shared across the seven closures except where a unit's
  // own production contract pins a supporting input no other closure owns: the
  // robots Switchyard contract source map pins port/native-campaign/enemies.mjs,
  // so that key rides only the robots receipt. Added inputs stay identical
  // everywhere, and every unit-specific changed key must be one of these
  // documented contract pins.
  const sharedChanged=deltas[0].changed.filter(p=>deltas.every(d=>d.changed.includes(p)));
  const perUnitChanged={robots:['port/native-campaign/enemies.mjs']};
  for(const [i,delta]of deltas.entries()){
    const id=REQUIRED_UNITS[i];
    assert.deepEqual(delta.changed,[...sharedChanged,...(perUnitChanged[id]??[])].sort(),id+': consolidation changed set');
    assert.deepEqual(delta.added,deltas[0].added,id+': shared consolidation additions');
  }
  assert.ok(deltas[0].added.includes(ADDED),'the new verifier module is a recorded addition');
});

test('the consolidation layer rejects forged hashes, additions and a missing layer',()=>{
  const id=REQUIRED_UNITS[0],raw=JSON.parse(read(receipt(id)));
  const forged=mutate=>{const copy=structuredClone(raw);mutate(copy);return copy;};
  const path=Object.keys(raw.consolidationAdvance.changed)[0];
  assert.throws(()=>verifyConsolidationAdvance(forged(r=>{r.consolidationAdvance.changed[path].after='0'.repeat(64);}),read),
    /Consolidation delta identity/);
  assert.throws(()=>verifyConsolidationAdvance(forged(r=>{r.consolidationAdvance.changed[path].before='0'.repeat(64);}),read),
    /Consolidation previous fingerprint/);
  assert.throws(()=>verifyConsolidationAdvance(forged(r=>{delete r.consolidationAdvance.added[ADDED];}),read),
    /Consolidation previous fingerprint/);
  assert.throws(()=>verifyConsolidationAdvance(forged(r=>{delete r.consolidationAdvance;}),read),
    /Explicit consolidation reconciliation required/);
});

test('a self-consistent deletion of an added input is still rejected by the closure',()=>{
  // The layer verifier cannot know the expected input set: a forged receipt that
  // deletes both the `added` entry and its package input and recomputes the
  // fingerprints is self-consistent. The production closure's exact
  // packageInputs equality is the second, authoritative guard.
  const id=REQUIRED_UNITS[0],receiptPath=receipt(id);
  const forged=JSON.parse(read(receiptPath));
  delete forged.packageInputs[ADDED];
  delete forged.consolidationAdvance.added[ADDED];
  forged.consolidationAdvance.packageFingerprint=hash(JSON.stringify(forged.packageInputs));
  verifyConsolidationAdvance(forged,read); // self-consistent at the layer
  const bytes=Buffer.from(JSON.stringify(forged,null,2)+'\n');
  const requirements=JSON.parse(read(REQUIREMENTS));
  requirements.units[id].promotion.sha256=hash(bytes);
  assert.throws(()=>productionResources({
    read:p=>p===receiptPath?bytes:p===REQUIREMENTS?Buffer.from(JSON.stringify(requirements)):read(p),
    has:existsSync,worldIds:Object.keys(WORLDS),strict:true,
  }),/Incomplete production packageInputs/);
});
