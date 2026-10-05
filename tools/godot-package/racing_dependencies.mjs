// Racing lane advance: the newest supporting-input reconciliation. Validates
// and reverses the racing layer so earlier lanes (movement in particular) can
// still reconstruct their exact pre-racing predecessor bytes.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {reverseDressing} from './dressing_dependencies.mjs';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export function verifyRacingAdvance(receipt, read) {
  // Newer layers sit on top of racing; reverse them before reconstructing the
  // racing-era package inputs.
  receipt = reverseDressing(receipt, read);
  const r = receipt.racingAdvance;
  assert.ok(r, 'Explicit racing reconciliation required');
  assert.match(r.previousReceipt?.commit ?? '', /^[0-9a-f]{40}$/, 'Racing predecessor commit');
  assert.equal(r.previousReceipt.path, `tools/godot-package/production_receipts/${receipt.unit}.json`,
    'Racing predecessor receipt path');
  assert.match(r.previousReceipt.sha256 ?? '', /^[0-9a-f]{64}$/, 'Racing predecessor receipt identity');
  assert.deepEqual(r.review, {
    foundation: '9812edfaa3e90a3ca4204d1ec2168587d8d657fb',
    scope: 'racing gameplay and presentation reconciliation; native race acceptance pending',
    nativeChecks: 'pending',
    document: 'port/finish/RACING_RECONCILIATION.md',
  }, 'Racing review boundary');
  const pre = structuredClone(receipt);
  delete pre.racingAdvance;
  for (const [path, sha] of Object.entries(r.added ?? {})) {
    assert.equal(pre.packageInputs[path], sha, 'Racing addition identity: ' + path);
    delete pre.packageInputs[path];
  }
  for (const [path, change] of Object.entries(r.changed ?? {})) {
    assert.equal(pre.packageInputs[path], change.after, 'Racing delta identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.packageInputs[path] = change.before;
  }
  for (const [path, change] of Object.entries(r.runtimeChanged ?? {})) {
    assert.equal(pre.runtimeHooks?.[path], change.after, 'Racing hook identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.runtimeHooks[path] = change.before;
  }
  assert.equal(hash(JSON.stringify(pre.packageInputs)), r.previousPackageFingerprint,
    'Racing previous fingerprint');
  assert.equal(hash(JSON.stringify(receipt.packageInputs)), r.packageFingerprint,
    'Racing current fingerprint');
  for (const [path, change] of Object.entries(r.changed ?? {})) {
    assert.equal(hash(read(path)), change.after, 'Reviewed racing bytes: ' + path);
  }
  for (const [path, change] of Object.entries(r.runtimeChanged ?? {})) {
    assert.equal(hash(read(path)), change.after, 'Reviewed racing hook bytes: ' + path);
  }
  return pre;
}

export function reverseRacing(receipt, read) {
  return receipt.racingAdvance ? verifyRacingAdvance(receipt, read) : receipt;
}

export function racingSupportingHash(path, before, receipt) {
  const change = receipt.racingAdvance?.changed?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-racing supporting history: ' + path);
  return change.after;
}

export function racingSupportingHookHash(path, before, receipt) {
  const change = receipt.racingAdvance?.runtimeChanged?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-racing hook history: ' + path);
  return change.after;
}
