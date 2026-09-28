// Fixture tests for the shared package manifest validator.
//
// Every fixture builds a tiny real git repository plus a fake extracted package
// whose runtime bytes are copied from that repository. No engine, server or
// network is involved. The tests prove tamper detection (changed bytes, added
// files, deleted files), source-identity anchoring (wrong commit, missing
// metadata, derivative mismatch), ambient-independence (COCS_SOURCE_DERIVATIVE
// and the caller's cwd are ignored) and both target structures.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, unlinkSync, writeFileSync} from 'node:fs';
import {dirname, join, relative, resolve, sep} from 'node:path';
import {tmpdir} from 'node:os';
import {LAUNCHER_HELPERS, ValidationError, sha256, validateArtifact} from './manifest_validation.mjs';

function git(repo, ...args) {
  return execFileSync('git', args, {cwd: repo, encoding: 'utf8'}).trim();
}

function write(root, rel, content, mode) {
  const absolute = join(root, ...rel.split('/'));
  mkdirSync(dirname(absolute), {recursive: true});
  writeFileSync(absolute, content);
  if (mode !== undefined) chmodSync(absolute, mode);
  return absolute;
}

function inventory(dir) {
  const out = {};
  const walk = current => {
    for (const entry of readdirSync(current, {withFileTypes: true})) {
      const absolute = join(current, entry.name);
      if (entry.isDirectory()) walk(absolute);
      else if (entry.isFile()) {
        const rel = relative(dir, absolute).split(sep).join('/');
        if (rel !== 'manifest.json') out[rel] = sha256(readFileSync(absolute));
      }
    }
  };
  walk(dir);
  return out;
}

function buildFixture({target = 'linux', derivative = false, data = false, hordeData = false, derivativeAdded = null, extraSource = {}} = {}) {
  const base = mkdtempSync(join(tmpdir(), 'manifest-validation '));
  const repo = join(base, 'repo');
  mkdirSync(repo, {recursive: true});
  git(repo, 'init', '-q');
  git(repo, 'config', 'user.name', 'Fixture');
  git(repo, 'config', 'user.email', 'fixture@example.invalid');
  write(repo, 'README.md', 'fixture\n');
  // A stale adapter byte at the early commit lets the wrong-commit fixture
  // reproduce a real adapter/anchor mismatch rather than a missing object.
  write(repo, 'port/native-horde/authority.mjs', '// early adapter placeholder\n');
  git(repo, 'add', '.');
  git(repo, 'commit', '-qm', 'early');
  const earlyCommit = git(repo, 'rev-parse', 'HEAD');

  const sourceFiles = {
    'server/game-server.mjs': "import '../game/cocs.mjs';\n",
    'game/cocs.mjs': 'export const value = 1;\n',
    ...extraSource,
  };
  const adapterFiles = {'port/native-horde/authority.mjs': "import '../../game/cocs.mjs';\n"};
  const dataFiles = data ? {'godot/native_arenas/generated/prism-foundry.json': '{"ok":true}\n'} : {};
  const hordeDataFiles = hordeData ? {'godot/horde_maps/generated/cinderwake-drydock.json': '{"map":"cinderwake","schemaVersion":1}\n'} : {};
  // A derivative may add a reviewed source module, not only modify locked files.
  const addedModules = derivativeAdded ? {[derivativeAdded]: 'export const stages = [];\n'} : {};
  for (const [path, content] of Object.entries({...sourceFiles, ...adapterFiles, ...dataFiles, ...hordeDataFiles})) write(repo, path, content);
  git(repo, 'add', '.');
  git(repo, 'commit', '-qm', 'source');
  const sourceCommit = git(repo, 'rev-parse', 'HEAD');

  write(repo, 'port/contracts/source-lock.json',
    JSON.stringify({schema_version: 1, source_commit: sourceCommit, godot_version: '4.5.2.stable.official.fixture'}, null, 2) + '\n');
  git(repo, 'add', '.');
  git(repo, 'commit', '-qm', 'lock');

  let derivativeCommit = null;
  let derivativeRuntime = {};
  if (derivative) {
    write(repo, 'game/cocs.mjs', 'export const value = 2;\n');
    for (const [path, content] of Object.entries(addedModules)) write(repo, path, content);
    git(repo, 'add', '.');
    git(repo, 'commit', '-qm', 'derivative');
    derivativeCommit = git(repo, 'rev-parse', 'HEAD');
    derivativeRuntime = {'game/cocs.mjs': sha256(readFileSync(join(repo, 'game/cocs.mjs')))};
    for (const path of Object.keys(addedModules)) {
      derivativeRuntime[path] = sha256(readFileSync(join(repo, ...path.split('/'))));
    }
    write(repo, 'port/contracts/lattice-catalog-derivative.json',
      JSON.stringify({schema_version: 1, source_commit: sourceCommit, derivative_commit: derivativeCommit,
        runtime_files: derivativeRuntime}, null, 2) + '\n');
    git(repo, 'add', '.');
    git(repo, 'commit', '-qm', 'derivative-contract');
  }
  const portCommit = git(repo, 'rev-parse', 'HEAD');
  const revisionFor = path => Object.hasOwn(derivativeRuntime, path) ? derivativeCommit : sourceCommit;

  const packageDir = join(base, target === 'windows' ? 'cocs-native-windows' : 'cocs-native-linux');
  mkdirSync(packageDir, {recursive: true});
  const launcherSet = target === 'windows'
    ? ['Play.cmd', 'Demo Menu.cmd', 'Operator Preview.cmd', 'Graphics Showcase.cmd', 'Native Deathmatch.cmd', 'Domination.cmd', 'Cheats.cmd']
    : ['Domination.sh', 'Cheats.sh'];
  write(packageDir, target === 'windows' ? 'cocs.exe' : 'cocs.x86_64', 'executable\n');
  write(packageDir, 'cocs.pck', 'pck\n');
  write(packageDir, 'run.mjs', '// run\n');
  write(packageDir, 'options.mjs', '// options\n');
  write(packageDir, 'settings_path.mjs', 'export function settingsPath(){ return "x"; }\n');
  write(packageDir, 'endpoint.mjs', '// endpoint\n');
  write(packageDir, 'catalog.json', '{}\n');
  write(packageDir, 'README.md', 'readme\n');
  write(packageDir, 'licenses/Godot-LICENSE.txt', 'godot license\n');
  write(packageDir, 'licenses/Godot-COPYRIGHT.txt', 'godot copyright\n');
  if (target === 'windows') {
    write(packageDir, 'node.exe', 'node-binary\n');
    write(packageDir, 'licenses/Node-LICENSE.txt', 'node license\n');
    write(packageDir, 'Domination.cmd', 'node run.mjs --experience=identity-zones\r\n');
    write(packageDir, 'Cheats.cmd', 'set COCS_DEBUG=1\r\nnode run.mjs\r\n');
    write(packageDir, 'Demo Menu.cmd', 'choice /c 12\r\nDomination.cmd\r\nCheats.cmd\r\n');
    for (const name of ['Play.cmd', 'Operator Preview.cmd', 'Graphics Showcase.cmd', 'Native Deathmatch.cmd']) {
      write(packageDir, name, 'node run.mjs\r\n');
    }
  } else {
    write(packageDir, 'Domination.sh', '#!/bin/sh\nnode run.mjs --experience=identity-zones\n', 0o755);
    write(packageDir, 'Cheats.sh', '#!/bin/sh\nCOCS_DEBUG=1 node run.mjs\n', 0o755);
  }
  for (const path of [...Object.keys(sourceFiles), ...Object.keys(addedModules)]) {
    write(packageDir, `runtime/${path}`, execFileSync('git', ['show', `${revisionFor(path)}:${path}`], {cwd: repo}));
  }
  for (const path of Object.keys(adapterFiles)) {
    write(packageDir, `runtime/${path}`, execFileSync('git', ['show', `${portCommit}:${path}`], {cwd: repo}));
  }
  for (const path of [...Object.keys(dataFiles), ...Object.keys(hordeDataFiles)]) {
    write(packageDir, `runtime/${path}`, execFileSync('git', ['show', `${portCommit}:${path}`], {cwd: repo}));
  }
  write(packageDir, 'runtime/node_modules/ws/LICENSE', 'ws license\n');
  write(packageDir, 'runtime/node_modules/ws/package.json', '{"name":"ws"}\n');
  write(packageDir, 'runtime/node_modules/ws/index.js', 'module.exports = {};\n');

  const manifest = {
    schema_version: 1,
    kind: target === 'windows' ? 'windows-playable-demo' : 'private-local-linux-prototype',
    target,
    godot_version: '4.5.2.stable.official.fixture',
    source_commit: sourceCommit,
    port_commit: portCommit,
    release_ready: false,
    operator_models: 'source-operators',
    staged_native_overrides: {},
    launchers: [...LAUNCHER_HELPERS, 'catalog.json', 'README.md', ...launcherSet],
    server_closure: {
      entry: 'server/game-server.mjs',
      hordeEntry: 'port/native-horde/authority.mjs',
      modules: Object.fromEntries([...Object.keys(sourceFiles), ...Object.keys(addedModules)].map(path => [path, []])),
      adapterModules: Object.fromEntries(Object.keys(adapterFiles).map(path => [path, []])),
      dataFiles: Object.keys(dataFiles),
      identityDataFiles: [],
      hordeDataFiles: Object.keys(hordeDataFiles),
      external: ['ws'],
    },
    source_runtime_sha256: Object.fromEntries([...Object.keys(sourceFiles), ...Object.keys(addedModules)]
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    port_adapter_sha256: Object.fromEntries(Object.keys(adapterFiles)
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    native_arena_data_sha256: Object.fromEntries(Object.keys(dataFiles)
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    horde_map_data_sha256: Object.fromEntries(Object.keys(hordeDataFiles)
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    source_derivative_commit: derivative ? derivativeCommit : null,
    source_derivative_sha256: derivative
      ? sha256(readFileSync(join(repo, 'port/contracts/lattice-catalog-derivative.json'))) : null,
  };
  if (target === 'windows') {
    manifest.bundled_node = {
      version: '22.22.0',
      url: 'https://nodejs.org/dist/v22.22.0/node-v22.22.0-win-x64.zip',
      archive_sha256: 'a'.repeat(64),
      executable_sha256: sha256(readFileSync(join(packageDir, 'node.exe'))),
    };
  }
  manifest.files = inventory(packageDir);
  writeFileSync(join(packageDir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  return {
    base, repo, packageDir, manifest, sourceCommit, portCommit, earlyCommit, derivativeCommit,
    cleanup: () => rmSync(base, {recursive: true, force: true}),
  };
}

function refreshInventory(fixture) {
  fixture.manifest.files = inventory(fixture.packageDir);
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
}

function withFixture(options, run) {
  const fixture = buildFixture(options);
  try {
    return run(fixture);
  } finally {
    fixture.cleanup();
  }
}

function fails(action, pattern) {
  assert.throws(action, error => error instanceof ValidationError && pattern.test(error.message), String(pattern));
}

test('valid Linux package passes end to end', () => withFixture({}, fixture => {
  const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
  assert.equal(summary.status, 'passed');
  assert.equal(summary.target, 'linux');
  assert.equal(summary.source_modules, 2);
  assert.equal(summary.adapters, 1);
  assert.equal(summary.files, Object.keys(fixture.manifest.files).length);
}));

test('valid Windows package structure passes without executing the engine', () => withFixture({target: 'windows'}, fixture => {
  const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
  assert.equal(summary.target, 'windows');
}));

test('a genuinely new source module (Cinderwake horde-stages style) is discovered dynamically', () => withFixture(
  {extraSource: {'server/horde-stages.mjs': 'export const stages = [];\n'}}, fixture => {
    const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
    assert.equal(summary.source_modules, 3);
    assert.ok(Object.hasOwn(fixture.manifest.files, 'runtime/server/horde-stages.mjs'));
  }));

test('changed runtime bytes fail the exact inventory', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'runtime/game/cocs.mjs', 'export const value = 99;\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /File hash mismatch/);
}));

test('changed runtime bytes with a refreshed manifest fail the git anchor', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'runtime/game/cocs.mjs', 'export const value = 99;\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Runtime source differs from/);
}));

test('an extra file not in the manifest fails', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'runtime/extra.mjs', 'export const extra = 1;\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Unexpected file in package/);
}));

test('an uninventoried runtime file inside the inventory fails', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'runtime/extra.mjs', 'export const extra = 1;\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Uninventoried runtime file/);
}));

test('an extra bundled dependency fails', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'runtime/node_modules/other/index.js', 'module.exports = {};\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Uninventoried runtime file/);
}));

test('a missing packaged file fails', () => withFixture({}, fixture => {
  unlinkSync(join(fixture.packageDir, 'run.mjs'));
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Required package entry missing|Required package file missing/);
}));

test('a shipped test module fails even when the closure claims it', () => withFixture({}, fixture => {
  write(fixture.repo, 'server/evil.test.mjs', 'export const evil = 1;\n');
  write(fixture.packageDir, 'runtime/server/evil.test.mjs', 'export const evil = 1;\n');
  fixture.manifest.server_closure.modules['server/evil.test.mjs'] = [];
  fixture.manifest.source_runtime_sha256['server/evil.test.mjs'] = sha256(readFileSync(join(fixture.packageDir, 'runtime/server/evil.test.mjs')));
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Test\/observer module/);
}));

test('a missing ws LICENSE fails', () => withFixture({}, fixture => {
  unlinkSync(join(fixture.packageDir, 'runtime/node_modules/ws/LICENSE'));
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /ws LICENSE missing/);
}));

test('a missing settings_path helper fails', () => withFixture({}, fixture => {
  unlinkSync(join(fixture.packageDir, 'settings_path.mjs'));
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /settings_path\.mjs/);
}));

test('a settings_path helper without the shared export fails', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'settings_path.mjs', 'export const notTheHelper = 1;\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /settingsPath/);
}));

test('a wrong port commit fails the adapter anchor', () => withFixture({}, fixture => {
  fixture.manifest.port_commit = fixture.earlyCommit;
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Runtime adapter differs from port_commit/);
}));

test('a wrong source commit fails against the repository lock', () => withFixture({}, fixture => {
  fixture.manifest.source_commit = fixture.earlyCommit;
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /differs from repository source lock/);
}));

test('missing source metadata fails closed', () => withFixture({}, fixture => {
  delete fixture.manifest.source_commit;
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /source_commit/);
}));

test('a future manifest schema version fails closed', () => withFixture({}, fixture => {
  fixture.manifest.schema_version = 2;
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Unsupported manifest schema_version/);
}));

test('optional fields a future lane might add are not required', () => withFixture({}, fixture => {
  delete fixture.manifest.operator_models;
  delete fixture.manifest.staged_native_overrides;
  delete fixture.manifest.launchers;
  delete fixture.manifest.source_runtime_sha256;
  fixture.manifest.cinderwake_stages = ['outpost', 'citadel'];
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
  assert.equal(summary.status, 'passed');
}));

test('a valid derivative-bound package passes', () => withFixture({derivative: true}, fixture => {
  const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
  assert.equal(summary.derivative_commit, fixture.derivativeCommit);
}));

test('a derivative that adds a reviewed source module passes', () => withFixture(
  {derivative: true, derivativeAdded: 'game/horde-stages.mjs'}, fixture => {
    const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
    assert.equal(summary.derivative_commit, fixture.derivativeCommit);
    assert.ok(Object.hasOwn(fixture.manifest.files, 'runtime/game/horde-stages.mjs'));
  }));

test('a derivative-added source module outside runtime_files fails', () => withFixture(
  {derivative: true, derivativeAdded: 'game/horde-stages.mjs'}, fixture => {
    const contractPath = join(fixture.repo, 'port/contracts/lattice-catalog-derivative.json');
    const contract = JSON.parse(readFileSync(contractPath, 'utf8'));
    delete contract.runtime_files['game/horde-stages.mjs'];
    write(fixture.repo, 'port/contracts/lattice-catalog-derivative.json', JSON.stringify(contract, null, 2) + '\n');
    fixture.manifest.source_derivative_sha256 = sha256(readFileSync(contractPath));
    writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
    fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Derivative source inventory/);
  }));

test('the optional horde-map data family is hashed, anchored and shipped', () => withFixture({hordeData: true}, fixture => {
  const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
  assert.equal(summary.horde_data_files, 1);
  assert.ok(Object.hasOwn(fixture.manifest.files, 'runtime/godot/horde_maps/generated/cinderwake-drydock.json'));
}));

test('a tampered horde-map data byte fails the port-commit anchor', () => withFixture({hordeData: true}, fixture => {
  write(fixture.packageDir, 'runtime/godot/horde_maps/generated/cinderwake-drydock.json', '{"map":"tampered"}\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Runtime data differs from port_commit/);
}));

test('an absent hordeDataFiles closure field stays valid on the baseline', () => withFixture({}, fixture => {
  delete fixture.manifest.server_closure.hordeDataFiles;
  delete fixture.manifest.horde_map_data_sha256;
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).horde_data_files, 0);
}));

test('a derivative metadata hash mismatch fails', () => withFixture({derivative: true}, fixture => {
  write(fixture.repo, 'port/contracts/lattice-catalog-derivative.json',
    JSON.stringify({schema_version: 1, source_commit: fixture.sourceCommit, derivative_commit: fixture.derivativeCommit,
      runtime_files: {'game/cocs.mjs': sha256(readFileSync(join(fixture.repo, 'game/cocs.mjs'))), 'game/extra.mjs': 'b'.repeat(64)}}, null, 2) + '\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Derivative metadata mismatch/);
}));

test('a recorded derivative without a repository contract fails', () => withFixture({derivative: true}, fixture => {
  unlinkSync(join(fixture.repo, 'port/contracts/lattice-catalog-derivative.json'));
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /derivative contract is missing/);
}));

test('a derivative metadata commit mismatch fails', () => withFixture({derivative: true}, fixture => {
  fixture.manifest.source_derivative_commit = fixture.portCommit;
  fixture.manifest.source_derivative_sha256 = sha256(readFileSync(join(fixture.repo, 'port/contracts/lattice-catalog-derivative.json')));
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /contract derivative_commit differs/);
}));

test('the ambient COCS_SOURCE_DERIVATIVE environment is never consulted', () => withFixture({}, fixture => {
  const previous = process.env.COCS_SOURCE_DERIVATIVE;
  try {
    process.env.COCS_SOURCE_DERIVATIVE = '/nonexistent/ambient-derivative.json';
    assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).status, 'passed');
    process.env.COCS_SOURCE_DERIVATIVE = join(fixture.repo, 'port/contracts/source-lock.json');
    assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).status, 'passed');
  } finally {
    if (previous === undefined) delete process.env.COCS_SOURCE_DERIVATIVE;
    else process.env.COCS_SOURCE_DERIVATIVE = previous;
  }
}));

test('validation is independent of the caller working directory', () => withFixture({}, fixture => {
  const previous = process.cwd();
  try {
    process.chdir(tmpdir());
    const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
    assert.equal(summary.status, 'passed');
  } finally {
    process.chdir(previous);
  }
}));

test('a Windows package missing a launcher fails', () => withFixture({target: 'windows'}, fixture => {
  unlinkSync(join(fixture.packageDir, 'Play.cmd'));
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Play\.cmd/);
}));

test('a Windows bundled node hash mismatch fails', () => withFixture({target: 'windows'}, fixture => {
  fixture.manifest.bundled_node.executable_sha256 = 'c'.repeat(64);
  writeFileSync(join(fixture.packageDir, 'manifest.json'), JSON.stringify(fixture.manifest, null, 2) + '\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /node\.exe differs/);
}));

test('the CLI reports JSON and a nonzero exit on failure', () => withFixture({}, fixture => {
  const cli = resolve(import.meta.dirname, 'manifest_validation.mjs');
  const ok = execFileSync(process.execPath,
    [cli, '--package', fixture.packageDir, '--repo', fixture.repo, '--json'], {encoding: 'utf8'});
  assert.equal(JSON.parse(ok).status, 'passed');
  write(fixture.packageDir, 'runtime/extra.mjs', 'export const extra = 1;\n');
  let failed = null;
  try {
    execFileSync(process.execPath, [cli, '--package', fixture.packageDir, '--repo', fixture.repo, '--json'],
      {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
  } catch (error) {
    failed = JSON.parse(error.stdout);
  }
  assert.equal(failed.status, 'failed');
}));
