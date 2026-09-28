import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const workflow = readFileSync(new URL('../../.github/workflows/godot-native.yml', import.meta.url), 'utf8');

test('native push CI covers the integration branch', () => {
  const branches = workflow.match(/^  push:\n    branches: \[([^\]]+)\]/m)?.[1].split(',').map(branch => branch.trim());
  assert.ok(branches, 'expected an explicit push branch list');
  assert.ok(branches.includes('main'));
  assert.ok(branches.includes('port/lattice-flagship-next'));
});

test('native verify job exports the frozen derivative to semantic export and verification', () => {
  const jobEnv = workflow.match(/^    env:\n((?:      [^\n]+\n)+)    steps:/m)?.[1];
  assert.ok(jobEnv, 'expected a job-level environment shared by export and verification steps');
  assert.match(jobEnv, /^      COCS_SOURCE_DERIVATIVE: \$\{\{ github\.workspace \}\}\/port\/contracts\/lattice-catalog-derivative\.json$/m);
  assert.match(workflow, /^          node tools\/godot-export\/semantic\.mjs\b/m);
  assert.match(workflow, /^          python3 tools\/godot-dev\/verify\.py\b/m);
});
