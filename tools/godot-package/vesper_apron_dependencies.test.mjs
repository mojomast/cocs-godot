import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {verifyVesperApronAdvance,reverseVesperApron,vesperApronSupportingHash,APRON_UNIT} from './vesper_apron_dependencies.mjs';
import {consolidationSupportingHash,reverseConsolidationAdvance} from './consolidation_dependencies.mjs';
import {reverseDressing} from './dressing_dependencies.mjs';
import {reverseRacing} from './racing_dependencies.mjs';
import {verifyMovementPredecessor} from './movement_dependencies.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const receipt=id=>`tools/godot-package/production_receipts/${id}.json`;
const git=(...args)=>execFileSync('git',args,{maxBuffer:128*1024*1024});
const options={read,has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway'],strict:true};

// Same forgery harness the movement/racing lanes use: mutate a receipt in memory,
// re-pin it in the requirements file, and prove the whole verifier rejects it.
function forged(id,mutate){
  const p=receipt(id),r=JSON.parse(read(p)),req=JSON.parse(read(REQUIREMENTS));mutate(r);
  const bytes=Buffer.from(JSON.stringify(r));req.units[id].promotion.sha256=hash(bytes);
  return ()=>productionResources({...options,read:x=>x===p?bytes:x===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(x)});
}

test('every unit carries the apron layer, and undoing it lands on its exact committed predecessor',()=>{
  for(const id of REQUIRED_UNITS){
    const r=JSON.parse(read(receipt(id))),layer=r.vesperApronAdvance;
    const apronEra=reverseConsolidationAdvance(r,read);
    assert.ok(layer,id+': explicit Vesper apron reconciliation required');
    assert.equal(layer.previousReceipt.path,receipt(id),id+': predecessor receipt path');
    const committed=git('show',`${layer.previousReceipt.commit}:${layer.previousReceipt.path}`);
    assert.equal(hash(committed),layer.previousReceipt.sha256,id+': predecessor receipt identity');
    // The layer must reverse to the committed bytes, not merely to a plausible
    // state: verifyMovementPredecessor hashes the whole reconstructed receipt.
    assert.equal(JSON.stringify(reverseVesperApron(r,read),null,2)+'\n',committed.toString('utf8'),
      id+': reversal must reproduce the committed predecessor receipt');
    assert.equal(layer.previousPackageFingerprint,hash(JSON.stringify(JSON.parse(committed.toString('utf8')).packageInputs)),
      id+': previous package fingerprint');
    // And the live tree must still hold the reviewed bytes this layer declares.
    for(const [p,c]of Object.entries(layer.changed))assert.equal(hash(read(p)),consolidationSupportingHash(p,c.after,r),id+': reviewed apron bytes: '+p);
    for(const [p,c]of Object.entries(layer.runtimeChanged))assert.equal(hash(read(p)),consolidationSupportingHash(p,c.after,r),id+': reviewed apron hook bytes: '+p);
    for(const [p,c]of Object.entries(layer.sourceChanged))assert.equal(hash(read(p)),consolidationSupportingHash(p,c.after,r),id+': reviewed apron source bytes: '+p);
    for(const [p,sha]of Object.entries(layer.added))assert.equal(hash(read(p)),consolidationSupportingHash(p,sha,r),id+': apron addition: '+p);
    assert.equal(layer.packageFingerprint,hash(JSON.stringify(apronEra.packageInputs)),id+': current package fingerprint');
    assert.equal(layer.sourceFingerprint,hash(JSON.stringify(apronEra.sourceHashes)),id+': current source fingerprint');
    // The whole chain still reconstructs its own historical predecessor.
    const r2=JSON.parse(read(receipt(id)));
    verifyMovementPredecessor(reverseRacing(r2,read),read);
  }
});

test('only the Vesper receipt binds the aproned geometry identity',()=>{
  const v=JSON.parse(read(receipt(APRON_UNIT))),b=v.vesperApronAdvance.bindsGeometry;
  assert.equal(JSON.parse(read(b.world)).geometryHash,b.geometryHash);
  assert.equal(JSON.parse(read(b.dressingProfile)).geometry_hash,b.geometryHash);
  assert.ok(read(b.identityTable).toString().includes(`"${APRON_UNIT}": "${b.geometryHash}"`));
  for(const id of REQUIRED_UNITS.filter(id=>id!==APRON_UNIT))
    assert.equal(JSON.parse(read(receipt(id))).vesperApronAdvance.bindsGeometry,undefined,
      id+': only Vesper may bind the aproned geometry identity');
});

test('a missing, forged or rewritten apron layer is rejected',()=>{
  const layer=r=>r.vesperApronAdvance;
  assert.throws(forged(APRON_UNIT,r=>delete r.vesperApronAdvance),/Explicit Vesper apron reconciliation required/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).previousReceipt.path='x'),/predecessor receipt path/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).changed['tools/godot-multiplayer/new-maps/vesper-viaduct/recipe.mjs'].after='0'.repeat(64)),/Vesper apron delta identity|Production content hash mismatch/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).sourceFingerprint='0'.repeat(64)),/current source fingerprint/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).previousSourceFingerprint='0'.repeat(64)),/previous source fingerprint/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).packageFingerprint='0'.repeat(64)),/current fingerprint|Production content hash mismatch/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).previousPackageFingerprint='0'.repeat(64)),/previous fingerprint/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).review.nativeChecks='accepted'),/review boundary/);
  assert.throws(forged(APRON_UNIT,r=>delete layer(r).bindsGeometry),/geometry binding shape/);
  assert.throws(forged(APRON_UNIT,r=>layer(r).bindsGeometry.geometryHash='0'.repeat(64)),/dressing profile must bind|IDENTITIES must bind|geometry hash/);
  assert.throws(forged('abyssal-pressureworks',r=>r.vesperApronAdvance.bindsGeometry={world:'x',geometryHash:'0'.repeat(64),dressingProfile:'x',identityTable:'x'}),
    /only the Vesper receipt may bind/i);
  assert.throws(forged(APRON_UNIT,r=>delete layer(r).runtimeChanged),/hook identity|Production content hash mismatch/);
});

test('a sibling receipt cannot drop the shared apron delta without failing',()=>{
  // profile.gd is a packageInput in all seven receipts, so any sibling that stops
  // advancing it drifts from the live shared runtime file.
  assert.throws(forged('scenery',r=>{r.packageInputs['godot/multiplayer_worlds/dressing/profile.gd']=r.dressingAdvance.changed['godot/multiplayer_worlds/dressing/profile.gd'].after;}),
    /Production content hash mismatch/);
  assert.throws(forged('scenery',r=>{const k=Object.keys(r.vesperApronAdvance.added)[0];r.vesperApronAdvance.added[k]='0'.repeat(64);}),/addition identity|Production content hash mismatch/);
  // parallax reads the identity table at map load, so it also advances the hook.
  const p=JSON.parse(read(receipt('parallax-interiors')));
  assert.ok(p.vesperApronAdvance.runtimeChanged['godot/multiplayer_worlds/dressing/profile.gd']);
  assert.throws(forged('parallax-interiors',r=>{r.runtimeHooks['godot/multiplayer_worlds/dressing/profile.gd']=r.dressingAdvance.runtimeChanged['godot/multiplayer_worlds/dressing/profile.gd'].after;}),
    /Production content hash mismatch/);
});

test('a tampered apron input is caught against the live tree, not just the receipt',()=>{
  const p='godot/multiplayer_worlds/generated/vesper-viaduct.json';
  assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\n')]):read(x)}),
    /Production content hash mismatch/);
  const r='godot/multiplayer_worlds/dressing/profile.gd';
  assert.throws(()=>productionResources({...options,read:x=>x===r?Buffer.from(read(x).toString().replace('db20ce1f','00000000')):read(x)}),
    /Production content hash mismatch/);
});
