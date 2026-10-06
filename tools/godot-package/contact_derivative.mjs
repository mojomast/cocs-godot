// Additive contact/attribution overlay chain (2026-10-06 audit F08 promotion).
// The receipt-pinned movement and racing resolvers stay byte-identical: this
// layer resolves on top of the exact reviewed racing contract, and every
// historical contract still delegates unchanged.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {RACING_COMMIT, RACING_CONTRACT, resolveReviewedDerivative as resolveRacing} from './racing_derivative.mjs';

export const CONTACT_CONTRACT = 'port/contracts/contact-candidate-derivative.json';
export const CONTACT_COMMIT = '6ce98a65821fe6b550ca4d9929d32f32491cc3ab';
export const CONTACT_CONTRACT_SHA = 'df082342aa6cb24c7085f2ba859ae9a9bab15f106edc181bf7412e2e8327ef13';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export function resolveReviewedDerivative(contract, read, gitRead, isAncestor) {
  if (!contract?.runtime_overrides) return contract;
  if (contract.derivative_commit !== CONTACT_COMMIT) return resolveRacing(contract, read, gitRead, isAncestor);
  const {runtime_files: resolved, ...overlay} = contract;
  const candidate = JSON.parse(read(CONTACT_CONTRACT));
  assert.equal(hash(read(CONTACT_CONTRACT)), CONTACT_CONTRACT_SHA, 'Exact reviewed contact contract');
  assert.deepEqual(overlay, candidate, 'Recorded contact overlay differs');
  assert.equal(candidate.derivative_commit, CONTACT_COMMIT);
  assert.equal(candidate.status, 'source-candidate-not-native-acceptance');
  assert.equal(candidate.parent_contract, RACING_CONTRACT);
  assert.equal(candidate.parent_derivative_commit, RACING_COMMIT);
  const parent = resolveRacing(JSON.parse(read(RACING_CONTRACT)), read, gitRead, isAncestor);
  assert.equal(candidate.source_commit, parent.source_commit, 'Contact source revision differs');
  assert.ok(isAncestor(RACING_COMMIT, CONTACT_COMMIT), 'Contact candidate ancestry');
  const runtime = {...parent.runtime_files};
  for (const [path, change] of Object.entries(contract.runtime_overrides)) {
    assert.equal(hash(gitRead(contract.baseline_commit, path)), change.before, 'Contact predecessor: ' + path);
    assert.equal(hash(gitRead(contract.derivative_commit, path)), change.after, 'Contact candidate: ' + path);
    runtime[path] = change.after;
  }
  if (resolved) assert.deepEqual(resolved, runtime, 'Resolved contact inventory differs');
  return {...contract, runtime_files: runtime};
}
