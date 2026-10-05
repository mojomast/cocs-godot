// Dressing lane advance: the newest supporting-input reconciliation. Validates
// and reverses the runtime Moth dressing layer so earlier lanes (racing in
// particular) can still reconstruct their exact pre-dressing predecessor bytes.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {reverseVesperApron, vesperApronSupportingHash, vesperApronSupportingHookHash} from './vesper_apron_dependencies.mjs';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export function verifyDressingAdvance(receipt, read) {
  // The Vesper apron layer is newer than dressing; reverse it before
  // reconstructing the dressing-era package inputs. Keep the unreversed receipt:
  // a newer lane may have moved a path this lane also changed, and the
  // live-bytes assertions below must resolve through it rather than insist this
  // lane still owns the newest bytes.
  const newer = receipt;
  receipt = reverseVesperApron(receipt, read);
  const r = receipt.dressingAdvance;
  assert.ok(r, 'Explicit dressing reconciliation required');
  assert.match(r.previousReceipt?.commit ?? '', /^[0-9a-f]{40}$/, 'Dressing predecessor commit');
  assert.equal(r.previousReceipt.path, `tools/godot-package/production_receipts/${receipt.unit}.json`,
    'Dressing predecessor receipt path');
  assert.match(r.previousReceipt.sha256 ?? '', /^[0-9a-f]{64}$/, 'Dressing predecessor receipt identity');
  assert.deepEqual(r.review, {
    foundation: '09e100587fc23896b00ea422a4e5c7ef5c07acb1',
    scope: 'runtime Moth dressing for Vesper, Abyssal and Stormglass; native dressing acceptance pending',
    nativeChecks: 'pending',
    document: 'port/finish/map-variety/RUNTIME_DRESSING_THREE_MAPS_20261005.md',
  }, 'Dressing review boundary');
  const pre = structuredClone(receipt);
  delete pre.dressingAdvance;
  for (const [path, sha] of Object.entries(r.added ?? {})) {
    assert.equal(pre.packageInputs[path], sha, 'Dressing addition identity: ' + path);
    delete pre.packageInputs[path];
  }
  for (const [path, change] of Object.entries(r.changed ?? {})) {
    assert.equal(pre.packageInputs[path], change.after, 'Dressing delta identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.packageInputs[path] = change.before;
  }
  for (const [path, change] of Object.entries(r.runtimeChanged ?? {})) {
    assert.equal(pre.runtimeHooks?.[path], change.after, 'Dressing hook identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.runtimeHooks[path] = change.before;
  }
  assert.equal(hash(JSON.stringify(pre.packageInputs)), r.previousPackageFingerprint,
    'Dressing previous fingerprint');
  assert.equal(hash(JSON.stringify(receipt.packageInputs)), r.packageFingerprint,
    'Dressing current fingerprint');
  for (const [path, change] of Object.entries(r.changed ?? {})) {
    assert.equal(hash(read(path)), vesperApronSupportingHash(path, change.after, newer),
      'Reviewed dressing bytes: ' + path);
  }
  for (const [path, change] of Object.entries(r.runtimeChanged ?? {})) {
    assert.equal(hash(read(path)), vesperApronSupportingHookHash(path, change.after, newer),
      'Reviewed dressing hook bytes: ' + path);
  }
  return pre;
}

export function reverseDressing(receipt, read) {
  return receipt.dressingAdvance ? verifyDressingAdvance(receipt, read) : receipt;
}

export function dressingSupportingHash(path, before, receipt) {
  const change = receipt.dressingAdvance?.changed?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-dressing supporting history: ' + path);
  return change.after;
}

export function dressingSupportingHookHash(path, before, receipt) {
  const change = receipt.dressingAdvance?.runtimeChanged?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-dressing hook history: ' + path);
  return change.after;
}
