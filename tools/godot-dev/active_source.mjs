#!/usr/bin/env node
// One reviewed active-source selection shared by dev, package and verification.
//
// The descriptor names the derivative contract that the current checkout ships
// (port/contracts/active-source.json). Historical derivatives stay immutable
// evidence: point COCS_SOURCE_DERIVATIVE at one to verify that frozen candidate.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export const ACTIVE_SOURCE_CONTRACT = 'port/contracts/active-source.json';
export const REPOSITORY_ROOT = resolve(fileURLToPath(import.meta.url), '../../..');

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

// Resolve the reviewed active descriptor, fail closed on descriptor or
// derivative drift. Returns {path, contract, sha256, explicit}.
export function activeSource(repositoryRoot = REPOSITORY_ROOT) {
  const descriptor = readJson(resolve(repositoryRoot, ACTIVE_SOURCE_CONTRACT));
  if (descriptor.schema_version !== 1 || typeof descriptor.derivative !== 'string') {
    throw Error('Unsupported active-source descriptor');
  }
  const path = resolve(repositoryRoot, descriptor.derivative);
  const bytes = readFileSync(path);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  if (shadowed(descriptor.derivative_sha256) && sha256 !== descriptor.derivative_sha256) {
    throw Error(`Active source derivative drift: ${descriptor.derivative}`);
  }
  return {path, contract: JSON.parse(bytes.toString('utf8')), sha256, explicit: false};
}

// An explicit COCS_SOURCE_DERIVATIVE keeps the historical verification path.
export function resolveActiveDerivative(explicit, repositoryRoot = REPOSITORY_ROOT) {
  if (!explicit) return activeSource(repositoryRoot);
  const path = resolve(repositoryRoot, explicit);
  const bytes = readFileSync(path);
  return {
    path,
    contract: JSON.parse(bytes.toString('utf8')),
    sha256: createHash('sha256').update(bytes).digest('hex'),
    explicit: true,
  };
}

function shadowed(value) {
  return typeof value === 'string' && value.length > 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const selection = resolveActiveDerivative(process.argv[2]);
  process.stdout.write(`${JSON.stringify({
    path: selection.path,
    sha256: selection.sha256,
    derivative_commit: selection.contract.derivative_commit,
    explicit: selection.explicit,
  })}\n`);
}
