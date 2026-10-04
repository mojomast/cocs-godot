// Additive racing overlay chain. The receipt-pinned movement resolver
// (source_derivative.mjs) stays byte-identical: racing resolves on top of the
// exact reviewed movement contract, and every historical movement contract
// still delegates unchanged.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {MOVEMENT_COMMIT, MOVEMENT_CONTRACT, resolveSourceDerivative as resolveMovement} from './source_derivative.mjs';

export const RACING_CONTRACT = 'port/contracts/racing-candidate-derivative.json';
export const RACING_COMMIT = '9812edfaa3e90a3ca4204d1ec2168587d8d657fb';
export const RACING_CONTRACT_SHA = '6f10ffb8fa278fad21687655776cd04851e25bc42b398a92d0a4f44abea5ae63';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export function resolveReviewedDerivative(contract, read, gitRead, isAncestor) {
  if (!contract?.runtime_overrides) return contract;
  if (contract.derivative_commit !== RACING_COMMIT) return resolveMovement(contract, read, gitRead, isAncestor);
  const {runtime_files: resolved, ...overlay} = contract;
  const candidate = JSON.parse(read(RACING_CONTRACT));
  assert.equal(hash(read(RACING_CONTRACT)), RACING_CONTRACT_SHA, 'Exact reviewed racing contract');
  assert.deepEqual(overlay, candidate, 'Recorded racing overlay differs');
  assert.equal(candidate.derivative_commit, RACING_COMMIT);
  assert.equal(candidate.status, 'source-candidate-not-native-acceptance');
  assert.equal(candidate.parent_contract, MOVEMENT_CONTRACT);
  assert.equal(candidate.parent_derivative_commit, MOVEMENT_COMMIT);
  const parent = resolveMovement(JSON.parse(read(MOVEMENT_CONTRACT)), read, gitRead, isAncestor);
  assert.equal(candidate.source_commit, parent.source_commit, 'Racing source revision differs');
  assert.ok(isAncestor(MOVEMENT_COMMIT, RACING_COMMIT), 'Racing candidate ancestry');
  const runtime = {...parent.runtime_files};
  for (const [path, change] of Object.entries(contract.runtime_overrides)) {
    assert.equal(hash(gitRead(contract.baseline_commit, path)), change.before, 'Racing predecessor: ' + path);
    assert.equal(hash(gitRead(contract.derivative_commit, path)), change.after, 'Racing candidate: ' + path);
    runtime[path] = change.after;
  }
  if (resolved) assert.deepEqual(resolved, runtime, 'Resolved racing inventory differs');
  return {...contract, runtime_files: runtime};
}
