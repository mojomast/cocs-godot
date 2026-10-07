// Consolidation advance: the newest supporting-input reconciliation for the
// 2026-10-06 audit implementation. It owns the package-input/runtime-hook deltas
// of the decode-once base hook (godot/net/client.gd), menu disclosure
// (godot/ui/main_menu.gd) and same-batch weapon attribution
// (godot/world/audio_feedback.gd), plus the verifier modules it changes, so every
// earlier lane (apron, dressing, racing, movement and polish) can still
// reconstruct its exact committed predecessor bytes.
//
// The layer is carried in all seven receipts because the three runtime files are
// declared package inputs of every unit. Like the apron advance it records the
// declared source fingerprint even when source is unchanged, because
// verifyMovementPredecessor hashes the whole reconstructed receipt against a
// historical value and a stale fingerprint would break that identity.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export const CONSOLIDATION_REVIEW = Object.freeze({
  scope: 'Audit 2026-10-06 implementation: decoded-frame base hook with the native-arena and campaign clients migrated to bounded deliver_frame validation (godot/net/client.gd, godot/native_arenas/client.gd, godot/campaign/client.gd), developer-navigation disclosure in godot/ui/main_menu.gd, and same-batch weapon attribution in godot/world/audio_feedback.gd, plus the re-exported first-person weapon export manifest byte (godot/first_person/generated/manifest.json) that the same advance names as an explicit closure root. Protocol/presentation only; source gameplay authority, epochs, acknowledgements, event ordering and snapshot coalescing are preserved.',
  nativeChecks: 'pending',
  document: 'docs/audit-2026-10-06/GATE_STATUS.md',
});

export function verifyConsolidationAdvance(receipt, read) {
  const r = receipt.consolidationAdvance;
  assert.ok(r, 'Explicit consolidation reconciliation required');
  assert.match(r.previousReceipt?.commit ?? '', /^[0-9a-f]{40}$/, 'Consolidation predecessor commit');
  assert.equal(r.previousReceipt.path, `tools/godot-package/production_receipts/${receipt.unit}.json`,
    'Consolidation predecessor receipt path');
  assert.match(r.previousReceipt.sha256 ?? '', /^[0-9a-f]{64}$/, 'Consolidation predecessor receipt identity');
  assert.deepEqual({scope: r.review?.scope, nativeChecks: r.review?.nativeChecks, document: r.review?.document},
    {scope: CONSOLIDATION_REVIEW.scope, nativeChecks: CONSOLIDATION_REVIEW.nativeChecks, document: CONSOLIDATION_REVIEW.document},
    'Consolidation review boundary');
  const pre = structuredClone(receipt);
  delete pre.consolidationAdvance;
  assert.ok(r.changed && typeof r.changed === 'object', 'Consolidation package delta shape');
  assert.ok(r.added && typeof r.added === 'object', 'Consolidation addition shape');
  assert.ok(r.runtimeChanged && typeof r.runtimeChanged === 'object', 'Consolidation hook delta shape');
  assert.ok(r.sourceChanged && typeof r.sourceChanged === 'object', 'Consolidation source delta shape');
  for (const [path, sha] of Object.entries(r.added)) {
    assert.equal(pre.packageInputs[path], sha, 'Consolidation addition identity: ' + path);
    delete pre.packageInputs[path];
  }
  for (const [path, change] of Object.entries(r.changed)) {
    assert.equal(pre.packageInputs[path], change.after, 'Consolidation delta identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.packageInputs[path] = change.before;
  }
  for (const [path, change] of Object.entries(r.runtimeChanged)) {
    assert.equal(pre.runtimeHooks?.[path], change.after, 'Consolidation hook identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.runtimeHooks[path] = change.before;
  }
  for (const [path, change] of Object.entries(r.sourceChanged)) {
    assert.equal(pre.sourceHashes?.[path], change.after, 'Consolidation source identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.sourceHashes[path] = change.before;
  }
  assert.equal(hash(JSON.stringify(pre.packageInputs)), r.previousPackageFingerprint,
    'Consolidation previous fingerprint');
  assert.equal(hash(JSON.stringify(pre.sourceHashes)), r.previousSourceFingerprint,
    'Consolidation previous source fingerprint');
  // sourceFingerprint is a top-level field, so undoing this layer has to undo it
  // too; verifyMovementPredecessor hashes the whole reconstructed receipt.
  pre.sourceFingerprint = r.previousSourceFingerprint;
  assert.equal(hash(JSON.stringify(receipt.packageInputs)), r.packageFingerprint,
    'Consolidation current fingerprint');
  assert.equal(hash(JSON.stringify(receipt.sourceHashes)), r.sourceFingerprint,
    'Consolidation current source fingerprint');
  for (const [path, change] of Object.entries(r.changed)) {
    assert.equal(hash(read(path)), change.after, 'Reviewed consolidation bytes: ' + path);
  }
  for (const [path, change] of Object.entries(r.runtimeChanged)) {
    assert.equal(hash(read(path)), change.after, 'Reviewed consolidation hook bytes: ' + path);
  }
  for (const [path, change] of Object.entries(r.sourceChanged)) {
    assert.equal(hash(read(path)), change.after, 'Reviewed consolidation source bytes: ' + path);
  }
  return pre;
}

export function reverseConsolidationAdvance(receipt, read) {
  return receipt.consolidationAdvance ? verifyConsolidationAdvance(receipt, read) : receipt;
}

// Later lanes that recorded a hash against the *pre-consolidation* tree resolve
// it here (this is the newest layer, so nobody resolves through it yet).
export function consolidationSupportingHash(path, before, receipt) {
  const change = receipt.consolidationAdvance?.changed?.[path] ?? receipt.consolidationAdvance?.runtimeChanged?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-consolidation supporting history: ' + path);
  return change.after;
}

export function consolidationSupportingHookHash(path, before, receipt) {
  const change = receipt.consolidationAdvance?.runtimeChanged?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-consolidation supporting hook history: ' + path);
  return change.after;
}
