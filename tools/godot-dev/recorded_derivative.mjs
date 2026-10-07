// Provenance recorder for native journey summaries.
//
// A journey executes derivative-governed game/ and server/ modules inside its
// own Node process (createGameServer and the derived authorities import those
// bytes directly), so when the development launcher resolves the reviewed
// active-source descriptor the journey summary must name that same derivative
// rather than record null. Reading the descriptor here reuses exactly the
// resolution the launcher, semantic export, verify.py and build.py already
// share, so the recorded commit is the reviewed selection and not a second,
// divergent lookup.
//
// Two rules keep the record truthful rather than merely populated:
//   - An explicit COCS_SOURCE_DERIVATIVE still wins, unchanged.
//   - A checkout with no active-source descriptor has no derivative to name,
//     so it keeps the historical null. Drift and malformed descriptors still
//     raise, because a failed resolution is evidence of a fault, not of an
//     absent derivative.
import {existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {ACTIVE_SOURCE_CONTRACT, REPOSITORY_ROOT, resolveActiveDerivative} from './active_source.mjs';

// Returns {contract, commit, explicit} for the derivative a run actually used,
// or null when this checkout selects none.
export function recordedDerivative(explicit = process.env.COCS_SOURCE_DERIVATIVE, repositoryRoot = REPOSITORY_ROOT) {
  if (!explicit && !existsSync(resolve(repositoryRoot, ACTIVE_SOURCE_CONTRACT))) return null;
  const selection = resolveActiveDerivative(explicit, repositoryRoot);
  return {contract: selection.contract, commit: selection.contract.derivative_commit ?? null, explicit: selection.explicit};
}