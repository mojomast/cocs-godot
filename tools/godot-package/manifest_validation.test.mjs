// Fixture tests for the shared package manifest validator.
//
// Each fixture builds a tiny real git repository plus a fake extracted package
// whose bytes are copied from that repository's committed objects. Artifact
// checks must only ever read those committed objects, so the tests also prove
// that an advanced HEAD, a dirty working tree, a planted ambient contract and a
// bogus COCS_SOURCE_DERIVATIVE do not affect a valid older artifact. No engine,
// server or network is involved.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, unlinkSync, writeFileSync} from 'node:fs';
import {dirname, join, relative, resolve, sep} from 'node:path';
import {tmpdir} from 'node:os';
import {DERIVATIVE_CONTRACT, REPO_ROOT, ValidationError, derivativeContractPath, sha256, validateArtifact} from './manifest_validation.mjs';
import {MOVEMENT_COMMIT, MOVEMENT_CONTRACT} from './source_derivative.mjs';
import {RACING_COMMIT, RACING_CONTRACT} from './racing_derivative.mjs';
import {CONTACT_COMMIT, CONTACT_CONTRACT} from './contact_derivative.mjs';

// A faithful-enough stand-in for the real discover.mjs: it derives the closure
// from the committed `.mjs` tree it is given, so an omitted module is not
// discoverable from a manifest or a scan of the ambient checkout.
const DISCOVER_STUB = `import {readdirSync, existsSync} from 'node:fs';
import {join} from 'node:path';
const root = process.argv[2];
const walk = (dir, out = []) => { if (!existsSync(join(root, dir))) return out; for (const e of readdirSync(join(root, dir), {withFileTypes: true})) { const rel = dir + '/' + e.name; if (e.isDirectory()) walk(rel, out); else if (rel.endsWith('.mjs')) out.push(rel); } return out; };
const all = [...walk('game'), ...walk('server'), ...walk('port')].sort();
const modules = {}, adapterModules = {};
for (const path of all) (path.startsWith('port/') ? adapterModules : modules)[path] = [];
const family = dir => existsSync(join(root, dir)) ? readdirSync(join(root, dir)).filter(name => name.endsWith('.json')).sort().map(name => dir + '/' + name) : [];
console.log(JSON.stringify({entry: 'server/game-server.mjs', modules, adapterModules,
  dataFiles: family('godot/native_arenas/generated'), identityDataFiles: family('godot/identity_maps/generated'),
  hordeDataFiles: family('godot/horde_maps/generated'), campaignDataFiles: family('godot/campaign/generated'), worldDataFiles: family('godot/multiplayer_worlds/generated'), edgeDataFiles: family('port/edge-effects')}));
`;

const HELPERS = {
  'run.mjs': '// run\n',
  'options.mjs': '// options\n',
  'settings_path.mjs': 'export function settingsPath(){ return "x"; }\n',
  'endpoint.mjs': '// endpoint\n',
  'discover.mjs': DISCOVER_STUB,
  'Domination.sh': '#!/bin/sh\nnode run.mjs --experience=identity-zones\n',
  'Cheats.sh': '#!/bin/sh\nCOCS_DEBUG=1 node run.mjs\n',
};
const COMMANDS = {
  'Play.cmd': 'node run.mjs\n',
  'Operator Preview.cmd': 'node run.mjs\n',
  'Graphics Showcase.cmd': 'node run.mjs\n',
  'Native Deathmatch.cmd': 'node run.mjs\n',
  'Demo Menu.cmd': 'choice /c 12\nDomination.cmd\nCheats.cmd\n',
  'Domination.cmd': 'node run.mjs --experience=identity-zones\n',
  'Cheats.cmd': 'set COCS_DEBUG=1\nnode run.mjs\n',
};
const crlf = text => text.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n');

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

function buildFixture({
  target = 'linux', derivative = false, data = false, hordeData = false, campaignData = false, worldData = false, edgeData = false,
  derivativeAdded = null, extraSource = {}, extraTestModule = null,
  dropAddedFromContract = false, contractSourceCommitOverride = null,
} = {}) {
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
  if (extraTestModule) sourceFiles[extraTestModule] = 'export const t = 1;\n';
  const adapterFiles = {'port/native-horde/authority.mjs': "import '../../game/cocs.mjs';\n"};
  if (edgeData) adapterFiles['port/edge-effects/structure-rays.mjs'] = '// committed facade adapter\n';
  const edgeDataFiles = edgeData ? {'port/edge-effects/structure-faces.json':'{"faces":[]}\n'} : {};
  const dataFiles = data ? {'godot/native_arenas/generated/prism-foundry.json': '{"ok":true}\n'} : {};
  const hordeDataFiles = hordeData ? {'godot/horde_maps/generated/cinderwake-drydock.json': '{"map":"cinderwake"}\n'} : {};
  const campaignDataFiles = campaignData ? Object.fromEntries(['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array'].map(id => [`godot/campaign/generated/${id}.json`, JSON.stringify({id})+'\n'])) : {};
  const worldDataFiles = worldData ? Object.fromEntries(['switchyard-ward','rainmarket-exchange','breakwater-exchange','thermal-divide','sirocco-circuit','copper-bowl','tern-archipelago'].map(id => [`godot/multiplayer_worlds/generated/${id}.json`, JSON.stringify({id})+'\n'])) : {};
  // A reviewed derivative may add a source module, not only modify locked files.
  const addedModules = derivativeAdded ? {[derivativeAdded]: 'export const stages = [];\n'} : {};

  for (const [path, content] of Object.entries({...sourceFiles, ...adapterFiles, ...dataFiles, ...hordeDataFiles, ...campaignDataFiles, ...worldDataFiles, ...edgeDataFiles})) {
    write(repo, path, content);
  }
  for (const [name, content] of Object.entries(HELPERS)) write(repo, `tools/godot-package/${name}`, content);
  for (const [name, content] of Object.entries(COMMANDS)) write(repo, `tools/godot-package/${name}`, content);
  if (campaignData) write(repo, 'tools/godot-package/Campaign.cmd', 'node run.mjs --experience=campaign\n');
  write(repo, 'port/contracts/map-selection.json', '{}\n');
  write(repo, 'port/native-linux-package/PLAY.md', 'linux readme\n');
  write(repo, 'port/native-windows-package/PLAY.md', 'windows readme\n');
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
    if (dropAddedFromContract) {
      for (const path of Object.keys(addedModules)) delete derivativeRuntime[path];
    }
    const contract = {
      schema_version: 1,
      source_commit: contractSourceCommitOverride ?? sourceCommit,
      derivative_commit: derivativeCommit,
      runtime_files: derivativeRuntime,
    };
    write(repo, 'port/contracts/lattice-catalog-derivative.json', JSON.stringify(contract, null, 2) + '\n');
    git(repo, 'add', '.');
    git(repo, 'commit', '-qm', 'derivative-contract');
  }
  const portCommit = git(repo, 'rev-parse', 'HEAD');
  const revisionFor = path => {
    if (!derivative) return sourceCommit;
    if (Object.hasOwn(addedModules, path)) return derivativeCommit;
    return Object.hasOwn(derivativeRuntime, path) ? derivativeCommit : sourceCommit;
  };
  const show = (commit, path) => execFileSync('git', ['show', `${commit}:${path}`], {cwd: repo});

  const packageDir = join(base, target === 'windows' ? 'cocs-native-windows' : 'cocs-native-linux');
  mkdirSync(packageDir, {recursive: true});
  write(packageDir, target === 'windows' ? 'cocs.exe' : 'cocs.x86_64', 'executable\n');
  write(packageDir, 'cocs.pck', 'pck\n');
  for (const name of ['run.mjs', 'options.mjs', 'settings_path.mjs', 'endpoint.mjs']) {
    write(packageDir, name, show(portCommit, `tools/godot-package/${name}`));
  }
  write(packageDir, 'catalog.json', show(portCommit, 'port/contracts/map-selection.json'));
  write(packageDir, 'README.md', show(portCommit, target === 'windows' ? 'port/native-windows-package/PLAY.md' : 'port/native-linux-package/PLAY.md'));
  write(packageDir, 'licenses/Godot-LICENSE.txt', 'godot license\n');
  write(packageDir, 'licenses/Godot-COPYRIGHT.txt', 'godot copyright\n');
  const launcherSet = target === 'windows' ? Object.keys(COMMANDS) : ['Domination.sh', 'Cheats.sh'];
  if (target === 'windows') {
    if (campaignData) write(packageDir, 'Campaign.cmd', crlf(show(portCommit, 'tools/godot-package/Campaign.cmd').toString('utf8')));
    write(packageDir, 'node.exe', 'node-binary\n');
    write(packageDir, 'licenses/Node-LICENSE.txt', 'node license\n');
    for (const name of Object.keys(COMMANDS)) {
      write(packageDir, name, crlf(show(portCommit, `tools/godot-package/${name}`).toString('utf8')));
    }
  } else {
    for (const name of ['Domination.sh', 'Cheats.sh']) {
      write(packageDir, name, show(portCommit, `tools/godot-package/${name}`), 0o755);
    }
  }
  const sourceModules = [...Object.keys(sourceFiles), ...Object.keys(addedModules)];
  for (const path of sourceModules) write(packageDir, `runtime/${path}`, show(revisionFor(path), path));
  for (const path of Object.keys(adapterFiles)) write(packageDir, `runtime/${path}`, show(portCommit, path));
  for (const path of [...Object.keys(dataFiles), ...Object.keys(hordeDataFiles), ...Object.keys(campaignDataFiles), ...Object.keys(worldDataFiles), ...Object.keys(edgeDataFiles)]) write(packageDir, `runtime/${path}`, show(portCommit, path));
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
    launchers: [...Object.keys(HELPERS).filter(name => name.endsWith('.mjs') && name !== 'discover.mjs'), 'catalog.json', 'README.md', ...launcherSet],
    server_closure: {
      entry: 'server/game-server.mjs',
      hordeEntry: 'port/native-horde/authority.mjs',
      modules: Object.fromEntries(sourceModules.map(path => [path, []])),
      adapterModules: Object.fromEntries(Object.keys(adapterFiles).map(path => [path, []])),
      dataFiles: Object.keys(dataFiles),
      identityDataFiles: [],
      hordeDataFiles: Object.keys(hordeDataFiles),
      ...(campaignData ? {campaignDataFiles:Object.keys(campaignDataFiles)} : {}),
      ...(worldData ? {worldDataFiles:Object.keys(worldDataFiles)} : {}),
      ...(edgeData ? {edgeDataFiles:Object.keys(edgeDataFiles)} : {}),
      external: ['ws'],
    },
    source_runtime_sha256: Object.fromEntries(sourceModules
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    port_adapter_sha256: Object.fromEntries(Object.keys(adapterFiles)
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    native_arena_data_sha256: Object.fromEntries(Object.keys(dataFiles)
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    horde_map_data_sha256: Object.fromEntries(Object.keys(hordeDataFiles)
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))])),
    ...(campaignData ? {campaign_data_sha256:Object.fromEntries(Object.keys(campaignDataFiles)
      .map(path => [path, sha256(readFileSync(join(packageDir, 'runtime', ...path.split('/'))))]))} : {}),
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
  const save = () => writeFileSync(join(packageDir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  save();
  return {
    base, repo, packageDir, manifest, save, sourceCommit, portCommit, earlyCommit, derivativeCommit,
    cleanup: () => rmSync(base, {recursive: true, force: true}),
  };
}

function refreshInventory(fixture) {
  fixture.manifest.files = inventory(fixture.packageDir);
  fixture.save();
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
  assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).target, 'windows');
}));

test('campaign facade data is verified against recorded Git bytes even with a forged inventory', () => withFixture({edgeData:true}, fixture => {
  assert.equal(validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}).status,'passed');
  write(fixture.packageDir,'runtime/port/edge-effects/structure-faces.json','{"tampered":true}\n');
  refreshInventory(fixture);
  fails(()=>validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}),/Runtime data differs from port_commit/);
}));

test('facade adapter cannot ship with its JSON omitted or redirected', () => withFixture({edgeData:true}, fixture => {
  fixture.manifest.server_closure.edgeDataFiles=[];fixture.save();
  fails(()=>validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}),/Campaign facade data closure/);
  fixture.manifest.server_closure.edgeDataFiles=['port/edge-effects/other.json'];fixture.save();
  fails(()=>validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}),/Campaign facade data closure/);
}));

test('seven multiplayer world files are bound to the recorded discovery and Git bytes', () => withFixture({worldData:true}, fixture => {
  assert.equal(validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}).world_data_files,7);
  const path=fixture.manifest.server_closure.worldDataFiles[0];
  write(fixture.packageDir,`runtime/${path}`,'{"tampered":true}\n');
  refreshInventory(fixture);
  fails(()=>validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}),/Runtime data differs from port_commit/);
}));

test('world closure cannot omit a packaged file or hide a file recorded by discovery', () => withFixture({worldData:true}, fixture => {
  const path=fixture.manifest.server_closure.worldDataFiles.pop();
  fixture.save();
  fails(()=>validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}),/Uninventoried runtime file/);
  unlinkSync(join(fixture.packageDir,'runtime',path));
  refreshInventory(fixture);
  fails(()=>validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}),/Committed discovery multiplayer world data files/);
}));

test('a career-capable recorded launcher requires its committed helper even if the inventory is forged', () => withFixture({}, fixture => {
  const launcher = "import {acquireCareer} from './career_path.mjs';\nexport {acquireCareer};\n";
  const helper = 'export function acquireCareer(){ return {}; }\n';
  write(fixture.repo, 'tools/godot-package/run.mjs', launcher);
  write(fixture.repo, 'tools/godot-package/career_path.mjs', helper);
  git(fixture.repo, 'add', '.');
  git(fixture.repo, 'commit', '-qm', 'durable career launcher');
  fixture.manifest.port_commit = git(fixture.repo, 'rev-parse', 'HEAD');
  write(fixture.packageDir, 'run.mjs', launcher);
  write(fixture.packageDir, 'career_path.mjs', helper);
  refreshInventory(fixture);
  assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).status, 'passed');
  write(fixture.packageDir, 'career_path.mjs', '// forged persistence\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /career_path\.mjs differs/);
  unlinkSync(join(fixture.packageDir, 'career_path.mjs'));
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Required package entry missing.*career_path\.mjs/);
}));

test('a genuinely new source module (Cinderwake horde-stages style) is discovered dynamically', () => withFixture(
  {extraSource: {'server/horde-stages.mjs': 'export const stages = [];\n'}}, fixture => {
    const summary = validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo});
    assert.equal(summary.source_modules, 3);
  }));

test('a valid older artifact still passes from an advanced, dirty checkout with a bogus ambient contract', () => withFixture({}, fixture => {
  write(fixture.repo, 'game/cocs.mjs', 'export const value = 50;\n');
  git(fixture.repo, 'add', '.');
  git(fixture.repo, 'commit', '-qm', 'advance');
  write(fixture.repo, 'game/cocs.mjs', 'export const value = 99;\n'); // dirty tracked source
  write(fixture.repo, 'port/contracts/lattice-catalog-derivative.json', '{bogus ambient contract}\n');
  const previous = process.env.COCS_SOURCE_DERIVATIVE;
  process.env.COCS_SOURCE_DERIVATIVE = '/nonexistent/ambient.json';
  try {
    assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).status, 'passed');
  } finally {
    if (previous === undefined) delete process.env.COCS_SOURCE_DERIVATIVE;
    else process.env.COCS_SOURCE_DERIVATIVE = previous;
  }
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
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Manifest launcher is not in the files inventory: run\.mjs/);
}));

test('a shipped test module fails even when the closure claims it', () => withFixture({extraTestModule: 'server/evil.test.mjs'}, fixture => {
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

test('a forged launcher and forged file hash cannot claim the recorded commit', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'run.mjs', '// forged launcher\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /run\.mjs differs/);
}));

test('a forged catalog.json cannot claim the recorded map selection', () => withFixture({}, fixture => {
  write(fixture.packageDir, 'catalog.json', '{"forged":true}\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /catalog\.json differs/);
}));

test('dropping a module from disk, manifest and closure fails committed discovery', () => withFixture({}, fixture => {
  unlinkSync(join(fixture.packageDir, 'runtime/game/cocs.mjs'));
  delete fixture.manifest.server_closure.modules['game/cocs.mjs'];
  delete fixture.manifest.source_runtime_sha256['game/cocs.mjs'];
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Committed discovery source modules/);
}));

test('a provided manifest that disagrees with the package manifest fails', () => withFixture({}, fixture => {
  fails(() => validateArtifact({
    packageDir: fixture.packageDir, repoRoot: fixture.repo,
    manifest: {...fixture.manifest, port_commit: fixture.earlyCommit},
  }), /does not match the package manifest/);
}));

test('a provided manifestPath that disagrees with the package manifest fails', () => withFixture({}, fixture => {
  const other = join(fixture.base, 'other-manifest.json');
  writeFileSync(other, '{}\n');
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo, manifestPath: other}),
    /does not match the package manifest/);
}));

test('a wrong port commit fails against the recorded commit', () => withFixture({}, fixture => {
  fixture.manifest.port_commit = fixture.earlyCommit;
  fixture.save();
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /git show|source lock|differs/);
}));

test('a wrong source commit fails against the recorded source lock', () => withFixture({}, fixture => {
  fixture.manifest.source_commit = fixture.earlyCommit;
  fixture.save();
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /differs from the recorded source lock/);
}));

test('missing source metadata fails closed', () => withFixture({}, fixture => {
  delete fixture.manifest.source_commit;
  fixture.save();
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /source_commit/);
}));

test('a future manifest schema version fails closed', () => withFixture({}, fixture => {
  fixture.manifest.schema_version = 2;
  fixture.save();
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Unsupported manifest schema_version/);
}));

test('optional fields a future lane might add are not required', () => withFixture({}, fixture => {
  delete fixture.manifest.operator_models;
  delete fixture.manifest.staged_native_overrides;
  delete fixture.manifest.launchers;
  delete fixture.manifest.source_runtime_sha256;
  fixture.manifest.cinderwake_stages = ['outpost', 'citadel'];
  fixture.save();
  assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).status, 'passed');
}));

test('a valid derivative-bound package passes', () => withFixture({derivative: true}, fixture => {
  assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).derivative_commit, fixture.derivativeCommit);
}));

test('each reviewed derivative commit selects the contract that pins it', () => {
  for (const [commit, contract] of [[CONTACT_COMMIT, CONTACT_CONTRACT], [RACING_COMMIT, RACING_CONTRACT], [MOVEMENT_COMMIT, MOVEMENT_CONTRACT]]) {
    assert.equal(derivativeContractPath(commit), contract);
    assert.equal(JSON.parse(readFileSync(resolve(REPO_ROOT, contract))).derivative_commit, commit);
  }
  assert.equal(derivativeContractPath('0'.repeat(40)), DERIVATIVE_CONTRACT);
});

test('a derivative that adds a reviewed source module passes', () => withFixture(
  {derivative: true, derivativeAdded: 'game/horde-stages.mjs'}, fixture => {
    assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).derivative_commit, fixture.derivativeCommit);
  }));

test('a derivative-added source module outside runtime_files fails', () => withFixture(
  {derivative: true, derivativeAdded: 'game/horde-stages.mjs', dropAddedFromContract: true}, fixture => {
    fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /Derivative source inventory/);
  }));

test('a tampered recorded committed contract hash fails', () => withFixture({derivative: true}, fixture => {
  fixture.manifest.source_derivative_sha256 = 'f'.repeat(64);
  fixture.save();
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /committed contract hash differs/);
}));

test('a tampered recorded contract source commit fails', () => withFixture(
  {derivative: true, contractSourceCommitOverride: 'deadbeef'}, fixture => {
    fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /contract source_commit differs/);
  }));

test('a mismatched recorded derivative commit fails', () => withFixture({derivative: true}, fixture => {
  fixture.manifest.source_derivative_commit = fixture.portCommit;
  fixture.manifest.source_derivative_sha256 = sha256(readFileSync(join(fixture.repo, 'port/contracts/lattice-catalog-derivative.json')));
  fixture.save();
  fails(() => validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}), /contract derivative_commit differs/);
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
  fixture.save();
  assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).horde_data_files, 0);
}));

for (const target of ['linux','windows']) test(`${target}: campaign data family is shipped and anchored`, () => withFixture({target,campaignData:true}, fixture => {
  assert.equal(validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}).campaign_data_files,4);
}));

test('campaign data tampering fails despite refreshed file hashes', () => withFixture({campaignData:true}, fixture => {
  write(fixture.packageDir,'runtime/godot/campaign/generated/rootfall-verge.json','{"tampered":true}\n');
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}), /Runtime data differs from port_commit/);
}));

test('omitting a campaign chapter from every inventory fails committed discovery', () => withFixture({campaignData:true}, fixture => {
  const path='godot/campaign/generated/crown-array.json';
  unlinkSync(join(fixture.packageDir,'runtime',path));
  fixture.manifest.server_closure.campaignDataFiles=fixture.manifest.server_closure.campaignDataFiles.filter(p=>p!==path);
  delete fixture.manifest.campaign_data_sha256[path];
  refreshInventory(fixture);
  fails(() => validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}), /Committed discovery campaign data files/);
}));

test('older manifests without campaign fields continue to validate', () => withFixture({}, fixture => {
  assert.equal(validateArtifact({packageDir:fixture.packageDir,repoRoot:fixture.repo}).campaign_data_files,0);
}));

test('validation is independent of the caller working directory', () => withFixture({}, fixture => {
  const previous = process.cwd();
  try {
    process.chdir(tmpdir());
    assert.equal(validateArtifact({packageDir: fixture.packageDir, repoRoot: fixture.repo}).status, 'passed');
  } finally {
    process.chdir(previous);
  }
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
