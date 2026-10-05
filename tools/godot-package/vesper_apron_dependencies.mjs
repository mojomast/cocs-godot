// Vesper apron lane advance: the newest supporting-input reconciliation. Validates
// and reverses the support-visible stair apron layer, so every earlier lane
// (dressing, racing, movement and polish) can still reconstruct its exact
// pre-apron predecessor bytes.
//
// This layer is carried in all seven receipts, not just Vesper's, because two of
// the files it changes are shared runtime inputs: `dressing/profile.gd` holds the
// `Profile.IDENTITIES` table every map's binder reads, and
// `dressing_dependencies.mjs` is inside every unit's helper closure. Rebinding
// Vesper's geometry identity therefore moves a packageInput that all seven
// receipts declare, exactly as `dressingAdvance` did. In Vesper's receipt the
// layer also carries `bindsGeometry`; in the other six it records only the shared
// delta, and the verifier enforces that split rather than trusting it.
//
// Three differences from dressing_dependencies.mjs, all forced by what this layer
// touches rather than by choice:
//
// 1. It owns the declared *source* identity as well as the package inputs.
//    recipe.mjs is in `unit.recipePaths`, so its bytes feed `sourceHashes` and
//    `sourceFingerprint`, which production_resources.mjs re-derives from the live
//    tree with no supporting-hash indirection. The dressing and racing layers only
//    changed files outside `sourceHashes`, so they had nothing to reverse there.
//    Reverting it is not optional: `verifyMovementPredecessor` asserts the *whole*
//    reconstructed receipt serialises to a historical sha256, so leaving the new
//    `sourceHashes` in place would break the movement predecessor identity.
//
// 2. It records `runtimeChanged`. `profile.gd` is a runtimeHook in Parallax's
//    receipt, because Parallax's binder reads the identity table at map load. The
//    house pattern keeps a hook's original receipt identity and resolves the live
//    comparison through the owning lane instead, so the hook must be advanced here.
//
// 3. It re-checks `bindsGeometry` on the Vesper receipt, because that is the one
//    thing this lane exists for: the dressing profile and `Profile.IDENTITIES`
//    must name the aproned world's geometryHash, and the world must carry it.
//    Everything else in the chain is bookkeeping.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export const APRON_UNIT = 'vesper-viaduct';

export const APRON_REVIEW = Object.freeze({
  scope: 'Vesper support-visible stair apron: 80 walkable -apron surfaces carry the ascent face at 40.030259 deg, inside terrain.maxSlope (40.107 deg). Vesper rebinds its runtime dressing identity to the aproned world; the shared Profile.IDENTITIES table and its verifier change therefore rebind in all seven receipts. Native acceptance pending.',
  nativeChecks: 'pending',
  document: 'port/finish/map-variety/VESPER_APRON_PROMOTION_READY_20261005.md',
});

export function verifyVesperApronAdvance(receipt, read) {
  const r = receipt.vesperApronAdvance;
  assert.ok(r, 'Explicit Vesper apron reconciliation required');
  assert.match(r.previousReceipt?.commit ?? '', /^[0-9a-f]{40}$/, 'Vesper apron predecessor commit');
  assert.equal(r.previousReceipt.path, `tools/godot-package/production_receipts/${receipt.unit}.json`,
    'Vesper apron predecessor receipt path');
  assert.match(r.previousReceipt.sha256 ?? '', /^[0-9a-f]{64}$/, 'Vesper apron predecessor receipt identity');
  assert.deepEqual({scope: r.review?.scope, nativeChecks: r.review?.nativeChecks, document: r.review?.document},
    {scope: APRON_REVIEW.scope, nativeChecks: APRON_REVIEW.nativeChecks, document: APRON_REVIEW.document},
    'Vesper apron review boundary');
  const pre = structuredClone(receipt);
  delete pre.vesperApronAdvance;
  // The geometry binding belongs to Vesper alone. Enforce the split so a sibling
  // receipt cannot quietly claim to bind the aproned world, and Vesper's cannot
  // quietly drop the claim that names it.
  if (receipt.unit === APRON_UNIT) {
    assert.deepEqual(Object.keys(r.bindsGeometry ?? {}).sort(),
      ['dressingProfile', 'geometryHash', 'identityTable', 'world'], 'Vesper apron geometry binding shape');
    assert.match(r.bindsGeometry.geometryHash ?? '', /^[0-9a-f]{64}$/, 'Aproned geometry hash');
    const world = JSON.parse(read(r.bindsGeometry.world).toString());
    assert.equal(world.geometryHash, r.bindsGeometry.geometryHash,
      'Aproned world must carry the bound geometry hash');
    assert.equal(JSON.parse(read(r.bindsGeometry.dressingProfile).toString()).geometry_hash,
      r.bindsGeometry.geometryHash, 'Vesper dressing profile must bind the aproned geometry hash');
    const identity = new RegExp(`"${APRON_UNIT}": "(${r.bindsGeometry.geometryHash})"`);
    assert.ok(identity.test(read(r.bindsGeometry.identityTable).toString()),
      'Profile.IDENTITIES must bind the aproned geometry hash');
  } else {
    assert.equal(r.bindsGeometry, undefined,
      'Only the Vesper receipt may bind the aproned geometry identity');
  }
  for (const [path, sha] of Object.entries(r.added ?? {})) {
    assert.equal(pre.packageInputs[path], sha, 'Vesper apron addition identity: ' + path);
    delete pre.packageInputs[path];
  }
  for (const [path, change] of Object.entries(r.changed ?? {})) {
    assert.equal(pre.packageInputs[path], change.after, 'Vesper apron delta identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.packageInputs[path] = change.before;
  }
  for (const [path, change] of Object.entries(r.runtimeChanged ?? {})) {
    assert.equal(pre.runtimeHooks?.[path], change.after, 'Vesper apron hook identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.runtimeHooks[path] = change.before;
  }
  assert.ok(r.runtimeChanged && typeof r.runtimeChanged === 'object', 'Vesper apron hook identity shape');
  assert.ok(r.sourceChanged && typeof r.sourceChanged === 'object', 'Vesper apron source identity shape');
  // Artifact rows live in the receipt's masters/exports arrays rather than
  // packageInputs, and only Vesper re-derives them: the apron adds 160 walkable
  // triangles to the runtime GLB and the authoring pipeline re-saves both the
  // master and the measured triangle count. Reversing them keeps the whole
  // receipt serialisation identical to the committed predecessor.
  if (receipt.unit === APRON_UNIT) {
    for (const [section, rows] of [['exports', pre.exports], ['masters', pre.masters]]) {
      const changes = r[section + 'Changed'] ?? {};
      assert.ok(Object.keys(changes).length, 'Vesper apron ' + section + ' reconciliation required');
      for (const [path, change] of Object.entries(changes)) {
        const row = rows.find((candidate) => candidate.path === path);
        assert.ok(row, 'Vesper apron ' + section + ' row: ' + path);
        assert.equal(hash(read(path)), change.after.sha256, 'Reviewed apron ' + section + ' bytes: ' + path);
        for (const [field, value] of Object.entries(change.after)) {
          assert.equal(row[field], value, 'Vesper apron ' + section + ' ' + field + ' identity: ' + path);
          row[field] = change.before[field];
        }
      }
    }
    for (const [field, change] of Object.entries(r.fieldChanged ?? {})) {
      assert.equal(pre[field], change.after, 'Vesper apron field identity: ' + field);
      pre[field] = change.before;
    }
  } else {
    assert.equal(r.exportsChanged, undefined, 'Only the Vesper receipt may change apron exports');
    assert.equal(r.mastersChanged, undefined, 'Only the Vesper receipt may change apron masters');
    assert.equal(r.fieldChanged, undefined, 'Only the Vesper receipt may change apron fields');
  }
  // The apron changed recipe.mjs, which is a declared production *source* path,
  // so this layer owns sourceHashes and the fingerprint derived from it.
  for (const [path, change] of Object.entries(r.sourceChanged ?? {})) {
    assert.equal(pre.sourceHashes[path], change.after, 'Vesper apron source identity: ' + path);
    assert.notEqual(change.before, change.after);
    pre.sourceHashes[path] = change.before;
  }
  assert.equal(hash(JSON.stringify(pre.sourceHashes)), r.previousSourceFingerprint,
    'Vesper apron previous source fingerprint');
  // sourceFingerprint is a top-level field, so undoing this layer has to undo it
  // too. verifyMovementPredecessor hashes the whole reconstructed receipt against
  // a historical value, so a stale fingerprint left behind breaks that identity.
  pre.sourceFingerprint = r.previousSourceFingerprint;
  assert.equal(hash(JSON.stringify(receipt.sourceHashes)), r.sourceFingerprint,
    'Vesper apron current source fingerprint');
  assert.equal(hash(JSON.stringify(pre.packageInputs)), r.previousPackageFingerprint,
    'Vesper apron previous fingerprint');
  assert.equal(hash(JSON.stringify(receipt.packageInputs)), r.packageFingerprint,
    'Vesper apron current fingerprint');
  for (const [path, change] of Object.entries(r.changed ?? {})) {
    assert.equal(hash(read(path)), change.after, 'Reviewed apron bytes: ' + path);
  }
  for (const [path, change] of Object.entries(r.sourceChanged ?? {})) {
    assert.equal(hash(read(path)), change.after, 'Reviewed apron source bytes: ' + path);
  }
  for (const [path, change] of Object.entries(r.runtimeChanged ?? {})) {
    assert.equal(hash(read(path)), change.after, 'Reviewed apron hook bytes: ' + path);
  }
  return pre;
}

export function reverseVesperApron(receipt, read) {
  return receipt.vesperApronAdvance ? verifyVesperApronAdvance(receipt, read) : receipt;
}

// Later lanes that recorded a hash against the *pre-apron* tree resolve it here.
export function vesperApronSupportingHash(path, before, receipt) {
  const change = receipt.vesperApronAdvance?.changed?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-apron supporting history: ' + path);
  return change.after;
}

export function vesperApronSupportingHookHash(path, before, receipt) {
  const change = receipt.vesperApronAdvance?.runtimeChanged?.[path];
  if (!change) return before;
  assert.equal(change.before, before, 'Broken pre-apron supporting hook history: ' + path);
  return change.after;
}