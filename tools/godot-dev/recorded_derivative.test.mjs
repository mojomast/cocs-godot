import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {recordedDerivative} from './recorded_derivative.mjs';
import {resolveActiveDerivative, REPOSITORY_ROOT} from './active_source.mjs';
import {resolveReviewedDerivative, CONTACT_CONTRACT, CONTACT_COMMIT, CONTACT_CONTRACT_SHA} from '../godot-package/contact_derivative.mjs';

const selected = (explicit, root = REPOSITORY_ROOT) => recordedDerivative(explicit, root);
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const git = (...args) => execFileSync('git', args, {cwd: REPOSITORY_ROOT, encoding: 'utf8'}).trim();

// Walk the recorded derivative's overlay chain exactly as verifySource does, so
// this test judges the same inventory the launcher and package build verify.
function resolvedInventory(contract) {
  return resolveReviewedDerivative(contract,
    path => readFileSync(resolve(REPOSITORY_ROOT, path)),
    (rev, path) => execFileSync('git', ['show', `${rev}:${path}`], {cwd: REPOSITORY_ROOT}),
    (a, b) => git('merge-base', a, b) === a).runtime_files;
}

// This checkout selects the reviewed contact overlay, so default resolution must
// record a real derivative commit rather than null.
test('default resolution records the reviewed active derivative, never null', () => {
  const resolved = resolveActiveDerivative();
  assert.equal(resolved.explicit, false);
  const recorded = selected(undefined);
  assert.notEqual(recorded, null);
  assert.match(recorded.commit, /^[0-9a-f]{40}$/);
  assert.equal(recorded.commit, resolved.contract.derivative_commit);
  // The recorded commit is the one the descriptor pins by content hash.
  assert.equal(recorded.commit, CONTACT_COMMIT);
  assert.deepEqual(recorded.contract, resolved.contract);
});

test('recorded derivative pins the exact changed runtime bytes journeys load', () => {
  // Journeys import game/ and server/ modules in-process. The recorded
  // derivative is the selection that pins the runtime bytes which differ from
  // the locked source; unchanged runtime modules stay covered by source-lock.json.
  // Either way the record is only truthful if the resolved inventory matches the
  // working-tree bytes those modules are actually read from.
  const {contract} = selected(undefined);
  const inventory = resolvedInventory(contract);
  assert.ok(Object.keys(inventory).length, 'resolved derivative inventory is non-empty');
  for (const path of Object.keys(inventory)) {
    assert.match(path, /^(game|server)\/[a-z0-9-]+\.mjs$/, `${path} is a runtime module`);
    assert.equal(sha256(readFileSync(resolve(REPOSITORY_ROOT, path))), inventory[path],
      `${path} matches the recorded derivative checksum`);
    assert.equal(sha256(execFileSync('git', ['show', `${contract.derivative_commit}:${path}`],
      {cwd: REPOSITORY_ROOT})), inventory[path],
      `${path} matches the recorded derivative commit`);
  }
});

test('an explicit COCS_SOURCE_DERIVATIVE still overrides the active selection', () => {
  const explicit = 'port/contracts/lattice-catalog-derivative.json';
  const recorded = selected(explicit);
  assert.equal(recorded.explicit, true);
  assert.equal(recorded.commit, resolveActiveDerivative(explicit).contract.derivative_commit);
  assert.notEqual(recorded.commit, CONTACT_COMMIT, 'explicit path selects a different candidate');
});

test('a checkout with no active-source descriptor records null instead of inventing provenance', () => {
  const empty = mkdtempSync(join(tmpdir(), 'cocs-no-descriptor-'));
  try {
    assert.equal(selected(undefined, empty), null);
  } finally {
    rmSync(empty, {recursive: true, force: true});
  }
});

test('descriptor byte drift fails closed rather than recording stale provenance', () => {
  const drifted = mkdtempSync(join(tmpdir(), 'cocs-drift-'));
  try {
    mkdirSync(join(drifted, 'port/contracts'), {recursive: true});
    writeFileSync(join(drifted, 'port/contracts/active-source.json'), JSON.stringify({
      schema_version: 1,
      status: 'reviewed-active-source',
      source_lock: 'port/contracts/source-lock.json',
      derivative: 'port/contracts/x-derivative.json',
      derivative_sha256: '0'.repeat(64),
    }));
    writeFileSync(join(drifted, 'port/contracts/x-derivative.json'), JSON.stringify({
      schema_version: 1, source_commit: '0'.repeat(40), derivative_commit: '1'.repeat(40),
    }));
    assert.throws(() => selected(undefined, drifted), /Active source derivative drift/);
  } finally {
    rmSync(drifted, {recursive: true, force: true});
  }
});

test('the active descriptor pins exactly the reviewed contact contract bytes', () => {
  // Guards the fixture expectations above against a contract or descriptor edit.
  const bytes = readFileSync(resolve(REPOSITORY_ROOT, CONTACT_CONTRACT));
  assert.equal(sha256(bytes), CONTACT_CONTRACT_SHA);
  assert.equal(JSON.parse(bytes).derivative_commit, CONTACT_COMMIT);
});