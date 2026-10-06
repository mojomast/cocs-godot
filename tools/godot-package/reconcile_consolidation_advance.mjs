// One-off transaction: record the reviewed consolidation advance on all seven
// production receipts (2026-10-06 audit implementation).
//
// The advance owns the package-input delta of the decode-once base hook, menu
// disclosure, same-batch weapon attribution and the verifier modules they
// change. It is regenerated from the unpromoted expectation closure so no
// receipt input is hand-edited, then verified end-to-end before writing.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {CONSOLIDATION_REVIEW} from './consolidation_dependencies.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const read = path => readFileSync(path);
const git = (rev, path) => execFileSync('git', ['show', `${rev}:${path}`], {maxBuffer:128*1024*1024});
const base = execFileSync('git', ['rev-parse', 'HEAD'], {encoding:'utf8'}).trim();

// Exactly the paths this implementation changed inside the production closure.
const IMPLEMENTATION = new Set([
  'godot/net/client.gd',
  'godot/native_arenas/client.gd',
  'godot/campaign/client.gd',
  'godot/ui/main_menu.gd',
  'godot/world/audio_feedback.gd',
  'godot/player_fx/impacts.gd',
  'godot/source_operators/moth_finish/manifest.json',
  'game/core.mjs',
  'game/feedback.mjs',
  'game/view.mjs',
  'port/native-campaign/core.generated.mjs',
  'port/native-campaign/generate-core.mjs',
  'tools/godot-package/contact_derivative.mjs',
  'godot/first_person/rig.gd',
  'godot/first_person/handling.gd',
  'godot/first_person/inertia.gd',
  'godot/first_person/sprint_fov.gd',
  'godot/first_person/session_binding.gd',
  'godot/first_person/profiles/weapon_presentation_profile.gd',
  'tools/godot-package/production_resources.mjs',
  'tools/godot-package/vesper_apron_dependencies.mjs',
  'tools/godot-package/consolidation_dependencies.mjs',
  'tools/godot-package/polish_dependencies.mjs',
  'tools/godot-package/dressing_dependencies.mjs',
  'tools/godot-package/racing_dependencies.mjs',
  'tools/godot-package/movement_dependencies.mjs',
]);

// Expected closure from the unpromoted snapshot: receipt bytes are not read, so
// the new advance cannot launder its own inputs.
const requirementsOriginal = read(REQUIREMENTS);
const unpromoted = structuredClone(JSON.parse(requirementsOriginal));
for (const unit of Object.values(unpromoted.units)) unit.promotion = null;
const units = productionResources({read: path => path === REQUIREMENTS ? Buffer.from(JSON.stringify(unpromoted)) : read(path),
  has:existsSync, strict:false}).units;

const files = new Map();
const audit = [];
const requirements = structuredClone(JSON.parse(requirementsOriginal));
for (const id of REQUIRED_UNITS) {
  const path = `tools/godot-package/production_receipts/${id}.json`;
  const original = git(base, path);
  const receipt = JSON.parse(original);
  const oldInputs = receipt.packageInputs;
  const previousPackageFingerprint = hash(JSON.stringify(oldInputs));
  const previousSourceFingerprint = hash(JSON.stringify(receipt.sourceHashes));
  const expected = units[id].expected.packageInputs;
  // Preserve the committed key order: the reversal must land on the exact
  // predecessor serialisation, not merely the same key set. New reviewed inputs
  // are appended so deleting them restores the original order.
  const rebuilt = {};
  for (const input of Object.keys(oldInputs)) {
    assert.ok(expected.includes(input), 'Dropped production input: ' + input);
    rebuilt[input] = hash(read(input));
  }
  const changed = {}, added = {};
  for (const input of expected) {
    if (Object.hasOwn(oldInputs, input)) continue;
    assert.ok(IMPLEMENTATION.has(input), 'Unreviewed new production input: ' + input);
    added[input] = hash(read(input));
    rebuilt[input] = added[input];
  }
  for (const input of Object.keys(oldInputs)) {
    if (oldInputs[input] === rebuilt[input]) continue;
    assert.ok(IMPLEMENTATION.has(input), 'Unreviewed production input drift: ' + input);
    changed[input] = {before:oldInputs[input], after:rebuilt[input]};
  }
  receipt.packageInputs = rebuilt;
  const runtimeChanged = {};
  // Runtime hooks are resolved through supporting-advance history in the real
  // verifier, so only this implementation's owned files are advanced here.
  for (const hook of IMPLEMENTATION) {
    if (!receipt.runtimeHooks || !Object.hasOwn(receipt.runtimeHooks, hook)) continue;
    const actual = hash(read(hook));
    if (actual === receipt.runtimeHooks[hook]) continue;
    runtimeChanged[hook] = {before:receipt.runtimeHooks[hook], after:actual};
    receipt.runtimeHooks[hook] = actual;
  }
  receipt.consolidationAdvance = {
    previousReceipt:{commit:base, path, sha256:hash(original)},
    changed, added, runtimeChanged,
    sourceChanged:{},
    previousPackageFingerprint,
    packageFingerprint:hash(JSON.stringify(receipt.packageInputs)),
    previousSourceFingerprint,
    sourceFingerprint:hash(JSON.stringify(receipt.sourceHashes)),
    review:{scope:CONSOLIDATION_REVIEW.scope, nativeChecks:CONSOLIDATION_REVIEW.nativeChecks, document:CONSOLIDATION_REVIEW.document},
  };
  const bytes = Buffer.from(JSON.stringify(receipt, null, 2) + '\n');
  files.set(path, bytes);
  requirements.units[id].promotion = {receipt:path, sha256:hash(bytes)};
  audit.push({unit:id, changed:Object.keys(changed), added:Object.keys(added), runtimeChanged:Object.keys(runtimeChanged), receiptSHA256:hash(bytes)});
}
files.set(REQUIREMENTS, Buffer.from(JSON.stringify(requirements, null, 2) + '\n'));

const catalog = JSON.parse(read('port/contracts/map-selection.json'));
const worldIds = [...new Set([...(Array.isArray(catalog.maps) ? catalog.maps.map(entry => typeof entry === 'string' ? entry : entry.id) : Object.keys(catalog.maps ?? {})),
  'parallax-observatory', 'vesper-viaduct', 'abyssal-pressureworks', 'stormglass-causeway'])];
const verified = productionResources({
  read: path => files.get(path) ?? read(path),
  has:existsSync,
  worldIds,
  strict:false,
});
assert.deepEqual(verified.pending, [], 'Every promoted unit must verify after the consolidation advance');
for (const [path, bytes] of files) writeFileSync(path, bytes);
console.log(JSON.stringify({base, pending:verified.pending, units:audit}, null, 1));
