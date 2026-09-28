// Shared artifact validator for an already-extracted native Linux/Windows package.
//
// The single source of truth is the package's own `manifest.json` plus the git
// objects at the commits that manifest records. Nothing here reads
// COCS_SOURCE_DERIVATIVE, the repository's ambient derivative selection, or the
// caller's working directory: an explicit package path and repository path are
// always supplied. `tools/godot-package/verify.py` shells out to this CLI and
// `tools/godot-package/verify_linux.mjs` imports it, so both use one validator.
//
// It deliberately does not require fields the current builder does not yet
// write (for example a future Cinderwake stage inventory). Unknown fields are
// ignored, supported schema versions are listed explicitly, and anything else
// fails closed.
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {existsSync, lstatSync, readdirSync, readFileSync} from 'node:fs';
import {join, relative, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';

// The repository that contains this module, not the process working directory.
export const REPO_ROOT = fileURLToPath(new URL('../../', import.meta.url));
// Audited manifest versions. Adding one is an explicit, reviewed change; an
// unknown/newer version fails closed rather than guessing at its shape.
export const SUPPORTED_SCHEMA_VERSIONS = Object.freeze([1]);
export const TARGET_KINDS = Object.freeze({
  linux: 'private-local-linux-prototype',
  windows: 'windows-playable-demo',
});
export const SOURCE_LOCK = 'port/contracts/source-lock.json';
export const DERIVATIVE_CONTRACT = 'port/contracts/lattice-catalog-derivative.json';
// Root launcher helpers copied beside the executable. `settings_path.mjs` is the
// shared menu/route preference-path helper; it must ship with every package.
export const LAUNCHER_HELPERS = Object.freeze(['run.mjs', 'options.mjs', 'settings_path.mjs', 'endpoint.mjs']);
export const WINDOWS_LAUNCHERS = Object.freeze([
  'Play.cmd', 'Demo Menu.cmd', 'Operator Preview.cmd', 'Graphics Showcase.cmd',
  'Native Deathmatch.cmd', 'Domination.cmd', 'Cheats.cmd',
]);
export const LINUX_LAUNCHERS = Object.freeze(['Domination.sh', 'Cheats.sh']);

const HEX40 = /^[0-9a-f]{40}$/;
const HEX64 = /^[0-9a-f]{64}$/;
const SOURCE_MODULE = /^(?:server|game)\/.+\.mjs$/;
const ADAPTER_MODULE = /^port\/.+\.mjs$/;
const DATA_FILE = /^godot\/.+\.json$/;
const WS_PREFIX = 'runtime/node_modules/ws/';
const MAX_BUFFER = 512 * 1024 * 1024;

export class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
  }
}

export function require_(condition, message) {
  if (!condition) throw new ValidationError(message);
}

function plainObject(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value)
    && (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null);
}

export function sha256(data) {
  return createHash('sha256').update(data).digest('hex');
}

export function sha256File(path) {
  return sha256(readFileSync(path));
}

function assertRelPath(value, label) {
  require_(typeof value === 'string' && value.length > 0, `${label} must be a non-empty string`);
  require_(!value.includes('\\'), `${label} must use POSIX separators: ${value}`);
  require_(!value.startsWith('/'), `${label} must be relative: ${value}`);
  const parts = value.split('/');
  require_(!parts.includes('..'), `${label} must not contain '..': ${value}`);
  require_(!parts.includes(''), `${label} must not contain empty segments: ${value}`);
}

// Enumerate ordinary files under a directory, rejecting symlinks and other
// non-file entries. Returned paths are relative POSIX strings.
function walkFiles(directory, base = directory, out = []) {
  for (const entry of readdirSync(directory, {withFileTypes: true})) {
    const absolute = join(directory, entry.name);
    const stats = lstatSync(absolute);
    if (stats.isSymbolicLink() || entry.isSymbolicLink()) {
      throw new ValidationError(`Symlink in package: ${relative(base, absolute).split(sep).join('/')}`);
    }
    if (stats.isDirectory()) walkFiles(absolute, base, out);
    else if (stats.isFile()) out.push(relative(base, absolute).split(sep).join('/'));
    else throw new ValidationError(`Unexpected file type: ${relative(base, absolute).split(sep).join('/')}`);
  }
  return out;
}

function git(repo, args, {binary = false} = {}) {
  try {
    const result = execFileSync('git', args, {
      cwd: repo,
      encoding: binary ? null : 'utf8',
      maxBuffer: MAX_BUFFER,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return binary ? result : result.trim();
  } catch (error) {
    const detail = (error.stderr ? error.stderr.toString() : error.message).trim();
    throw new ValidationError(`git ${args.join(' ')} failed in ${repo}: ${detail}`);
  }
}

function gitObjectHash(repo, commit, path) {
  return sha256(git(repo, ['show', `${commit}:${path}`], {binary: true}));
}

function requireSortedEqual(actual, expected, label) {
  const left = [...actual].sort();
  const right = [...expected].sort();
  require_(JSON.stringify(left) === JSON.stringify(right),
    `${label} mismatch: manifest ${JSON.stringify(left)} != closure ${JSON.stringify(right)}`);
}

// Validate the manifest's own shape and return a normalized identity.
export function normalizeManifest(manifest) {
  require_(plainObject(manifest), 'Manifest must be a JSON object');
  const version = manifest.schema_version;
  require_(Number.isInteger(version), 'Manifest schema_version must be an integer');
  require_(SUPPORTED_SCHEMA_VERSIONS.includes(version),
    `Unsupported manifest schema_version ${version}; supported: ${SUPPORTED_SCHEMA_VERSIONS.join(', ')}`);
  const target = manifest.target;
  require_(target === 'linux' || target === 'windows', 'Manifest target must be linux or windows');
  require_(TARGET_KINDS[target] === manifest.kind,
    `Manifest kind ${JSON.stringify(manifest.kind)} does not match target ${target}`);
  require_(typeof manifest.godot_version === 'string' && manifest.godot_version.length > 0,
    'Manifest godot_version must be a non-empty string');
  require_(HEX40.test(manifest.source_commit ?? ''), 'Manifest source_commit must be a 40-hex commit');
  require_(HEX40.test(manifest.port_commit ?? ''), 'Manifest port_commit must be a 40-hex commit');
  require_(typeof manifest.release_ready === 'boolean', 'Manifest release_ready must be a boolean');

  require_(plainObject(manifest.files) && Object.keys(manifest.files).length > 0,
    'Manifest files inventory must be a non-empty object');
  for (const [path, hash] of Object.entries(manifest.files)) {
    assertRelPath(path, 'Manifest files path');
    require_(HEX64.test(hash), `Manifest files hash must be 64-hex: ${path}`);
  }

  if (manifest.operator_models !== undefined) {
    require_(manifest.operator_models === 'source-operators',
      `Unsupported operator_models ${JSON.stringify(manifest.operator_models)}; the candidate/baseline staging is retired`);
  }
  if (manifest.staged_native_overrides !== undefined) {
    require_(plainObject(manifest.staged_native_overrides) && Object.keys(manifest.staged_native_overrides).length === 0,
      'staged_native_overrides must be an empty object; staged overrides are never silent');
  }
  if (manifest.launchers !== undefined) {
    require_(Array.isArray(manifest.launchers) && manifest.launchers.every(name => typeof name === 'string' && name.length > 0),
      'Manifest launchers must be a list of non-empty names');
    for (const name of manifest.launchers) {
      assertRelPath(name, 'Manifest launcher');
      require_(name !== 'manifest.json' && Object.hasOwn(manifest.files, name),
        `Manifest launcher is not in the files inventory: ${name}`);
    }
  }

  const derivativeCommit = manifest.source_derivative_commit ?? null;
  const derivativeHash = manifest.source_derivative_sha256 ?? null;
  require_((derivativeCommit === null) === (derivativeHash === null),
    'Derivative commit and hash must both be recorded or both be absent');
  if (derivativeCommit !== null) {
    require_(HEX40.test(derivativeCommit), 'Manifest source_derivative_commit must be a 40-hex commit');
    require_(HEX64.test(derivativeHash), 'Manifest source_derivative_sha256 must be a 64-hex digest');
  }

  const closure = runtimeClosure(manifest);
  return {
    manifest,
    schema_version: version,
    target,
    kind: manifest.kind,
    godot_version: manifest.godot_version,
    source_commit: manifest.source_commit,
    port_commit: manifest.port_commit,
    release_ready: manifest.release_ready,
    files: manifest.files,
    derivativeCommit,
    derivativeHash,
    ...closure,
  };
}

// Resolve the runtime closure that must ship. It comes from the manifest's own
// `server_closure` (written by the dynamic `discover.mjs` traversal), so a new
// source module such as Cinderwake's horde-stages path is included without any
// hardcoded allowlist here. Older schema-v1 manifests that predate the embedded
// closure fall back to the explicit per-path inventories.
function runtimeClosure(manifest) {
  let sourceModules;
  let adapters;
  let dataFiles;
  let identityDataFiles;
  let hordeDataFiles;

  if (manifest.server_closure !== undefined) {
    const closure = manifest.server_closure;
    require_(plainObject(closure), 'server_closure must be an object');
    require_(plainObject(closure.modules), 'server_closure.modules must be an object');
    require_(plainObject(closure.adapterModules), 'server_closure.adapterModules must be an object');
    sourceModules = Object.keys(closure.modules);
    adapters = Object.keys(closure.adapterModules);
    dataFiles = closure.dataFiles ?? [];
    identityDataFiles = closure.identityDataFiles ?? [];
    // Optional discovery family from the Cinderwake lane; absent on older
    // builders and therefore an empty list, never a required field.
    hordeDataFiles = closure.hordeDataFiles ?? [];
  } else {
    require_(plainObject(manifest.source_runtime_sha256) && Object.keys(manifest.source_runtime_sha256).length > 0,
      'Manifest has neither server_closure nor source_runtime_sha256');
    sourceModules = Object.keys(manifest.source_runtime_sha256);
    adapters = Object.keys(manifest.port_adapter_sha256 ?? {});
    dataFiles = Object.keys(manifest.native_arena_data_sha256 ?? {});
    identityDataFiles = Object.keys(manifest.identity_arena_data_sha256 ?? {});
    hordeDataFiles = Object.keys(manifest.horde_map_data_sha256 ?? {});
  }

  for (const path of sourceModules) assertRelPath(path, 'Source module');
  for (const path of sourceModules) require_(SOURCE_MODULE.test(path), `Source module must be game/ or server/: ${path}`);
  for (const path of adapters) assertRelPath(path, 'Adapter module');
  for (const path of adapters) require_(ADAPTER_MODULE.test(path), `Adapter module must be under port/: ${path}`);
  for (const path of [...dataFiles, ...identityDataFiles, ...hordeDataFiles]) {
    assertRelPath(path, 'Runtime data file');
    require_(DATA_FILE.test(path), `Runtime data file must be a godot/ JSON path: ${path}`);
  }
  require_(new Set(sourceModules).size === sourceModules.length, 'Duplicate source modules in closure');
  require_(new Set(adapters).size === adapters.length, 'Duplicate adapters in closure');
  require_(!sourceModules.some(path => adapters.includes(path)), 'Source modules and adapters must not overlap');

  // Cross-check the explicit inventories when the builder wrote them.
  if (manifest.source_runtime_sha256 !== undefined) {
    requireSortedEqual(Object.keys(manifest.source_runtime_sha256), sourceModules, 'source_runtime_sha256');
  }
  if (manifest.port_adapter_sha256 !== undefined) {
    requireSortedEqual(Object.keys(manifest.port_adapter_sha256), adapters, 'port_adapter_sha256');
  }
  if (manifest.native_arena_data_sha256 !== undefined) {
    requireSortedEqual(Object.keys(manifest.native_arena_data_sha256), dataFiles, 'native_arena_data_sha256');
  }
  if (manifest.identity_arena_data_sha256 !== undefined) {
    requireSortedEqual(Object.keys(manifest.identity_arena_data_sha256), identityDataFiles, 'identity_arena_data_sha256');
  }
  if (manifest.horde_map_data_sha256 !== undefined) {
    requireSortedEqual(Object.keys(manifest.horde_map_data_sha256), hordeDataFiles, 'horde_map_data_sha256');
  }
  return {sourceModules, adapters, dataFiles, identityDataFiles, hordeDataFiles};
}

// Every packaged byte must be in the manifest and every manifest byte on disk.
export function validatePackageInventory(packageDir, identity) {
  const onDisk = walkFiles(packageDir)
    .filter(path => path !== 'manifest.json');
  const inventory = Object.keys(identity.files);
  for (const path of onDisk) {
    require_(Object.hasOwn(identity.files, path), `Unexpected file in package: ${path}`);
  }
  for (const path of inventory) {
    require_(onDisk.includes(path), `Missing packaged file: ${path}`);
  }
  require_(!inventory.includes('manifest.json'), 'manifest.json must not list itself');
  require_(existsSync(join(packageDir, 'manifest.json')), 'Package manifest.json is missing');
  for (const [path, hash] of Object.entries(identity.files)) {
    const actual = sha256File(join(packageDir, ...path.split('/')));
    require_(actual === hash, `File hash mismatch: ${path}`);
  }
  return onDisk;
}

function requireInventoryFile(packageDir, identity, name) {
  require_(Object.hasOwn(identity.files, name), `Required package entry missing from inventory: ${name}`);
  require_(existsSync(join(packageDir, ...name.split('/'))), `Required package file missing: ${name}`);
}

// Static structure checks for each target. Windows execution is owner-run; this
// proves the shipped layout without launching the engine.
export function validateTargetStructure(packageDir, identity) {
  const {manifest, target, files} = identity;
  const required = [
    ...LAUNCHER_HELPERS, 'catalog.json', 'README.md', 'cocs.pck',
    'licenses/Godot-LICENSE.txt', 'licenses/Godot-COPYRIGHT.txt',
  ];
  if (target === 'windows') {
    required.push('cocs.exe', 'node.exe', 'licenses/Node-LICENSE.txt', ...WINDOWS_LAUNCHERS);
  } else {
    required.push('cocs.x86_64', ...LINUX_LAUNCHERS);
  }
  for (const name of required) requireInventoryFile(packageDir, identity, name);

  const read = name => readFileSync(join(packageDir, ...name.split('/')), 'utf8');
  require_(read('README.md').trim().length > 0, 'README.md must not be empty');
  require_(/export function settingsPath/.test(read('settings_path.mjs')),
    'settings_path.mjs must export the shared settingsPath helper');

  if (target === 'windows') {
    for (const [name, marker] of [['Domination.cmd', /--experience=identity-zones/], ['Cheats.cmd', /COCS_DEBUG=1/]]) {
      const text = read(name);
      require_(text.trim().length > 0, `${name} must not be empty`);
      require_(marker.test(text), `${name} must reach its reviewed route`);
    }
    const menu = read('Demo Menu.cmd');
    for (const name of ['Domination.cmd', 'Cheats.cmd']) {
      require_(menu.includes(name), `${name} must be reachable from Demo Menu.cmd`);
    }
    const bundled = manifest.bundled_node;
    require_(plainObject(bundled), 'windows manifest must record bundled_node provenance');
    require_(typeof bundled.version === 'string' && bundled.version.length > 0, 'bundled_node.version missing');
    require_(typeof bundled.url === 'string' && bundled.url.startsWith('https://'), 'bundled_node.url missing');
    require_(HEX64.test(bundled.archive_sha256 ?? ''), 'bundled_node.archive_sha256 missing');
    require_(HEX64.test(bundled.executable_sha256 ?? ''), 'bundled_node.executable_sha256 missing');
    const nodeHash = sha256File(join(packageDir, 'node.exe'));
    require_(nodeHash === bundled.executable_sha256, 'Bundled node.exe differs from bundled_node.executable_sha256');
    require_(nodeHash === files['node.exe'], 'node.exe inventory hash differs from bundled_node');
  } else {
    for (const [name, marker] of [['Domination.sh', /--experience=identity-zones/], ['Cheats.sh', /COCS_DEBUG=1/]]) {
      const text = read(name);
      require_(text.trim().length > 0, `${name} must not be empty`);
      require_(marker.test(text), `${name} must reach its reviewed route`);
      if (process.platform !== 'win32') {
        require_((lstatSync(join(packageDir, name)).mode & 0o111) !== 0, `${name} must be executable`);
      }
    }
  }
}

// The runtime tree must be exactly the discovered closure plus the locked ws
// package. There is deliberately no per-route allowlist here.
export function validateRuntimeClosure(packageDir, identity) {
  const closurePaths = [
    ...identity.sourceModules.map(path => `runtime/${path}`),
    ...identity.adapters.map(path => `runtime/${path}`),
    ...identity.dataFiles.map(path => `runtime/${path}`),
    ...identity.identityDataFiles.map(path => `runtime/${path}`),
    ...identity.hordeDataFiles.map(path => `runtime/${path}`),
  ];
  const allowed = new Set(closurePaths);
  for (const path of closurePaths) {
    require_(Object.hasOwn(identity.files, path), `Runtime closure file missing from inventory: ${path}`);
    require_(existsSync(join(packageDir, ...path.split('/'))), `Runtime closure file missing: ${path}`);
  }
  const runtimeFiles = Object.keys(identity.files).filter(path => path.startsWith('runtime/'));
  for (const path of runtimeFiles) {
    if (allowed.has(path) || path.startsWith(WS_PREFIX)) continue;
    throw new ValidationError(`Uninventoried runtime file: ${path}`);
  }
  for (const path of runtimeFiles) {
    require_(!path.endsWith('.test.mjs') && !path.includes('/tests/'),
      `Test/observer module must not ship in the runtime closure: ${path}`);
  }
  const wsFiles = runtimeFiles.filter(path => path.startsWith(WS_PREFIX));
  require_(wsFiles.length > 0, 'Locked ws dependency is missing from the runtime closure');
  require_(wsFiles.includes(`${WS_PREFIX}LICENSE`), 'ws LICENSE missing from the runtime closure');
  require_(wsFiles.includes(`${WS_PREFIX}package.json`), 'ws package.json missing from the runtime closure');
  for (const path of runtimeFiles.filter(path => path.startsWith('runtime/node_modules/'))) {
    require_(path.startsWith(WS_PREFIX), `Unexpected bundled dependency: ${path}`);
  }
  const portRuntime = runtimeFiles.filter(path => path.startsWith('runtime/port/'))
    .map(path => path.slice('runtime/'.length));
  requireSortedEqual(portRuntime, identity.adapters.filter(path => path.startsWith('port/')), 'runtime/port adapter');
}

// Re-derive the strict source-tree contract that `tools/godot-export/semantic.mjs`
// enforces, anchored to the manifest's recorded source commit and derivative.
export function verifySourceState(repo, sourceCommit, derivative) {
  require_(HEX40.test(sourceCommit), 'source_commit must be pinned');
  require_(git(repo, ['merge-base', sourceCommit, 'HEAD']) === sourceCommit,
    'Repository is not based on the manifested source commit');
  const tracked = git(repo, ['ls-tree', '-r', '--name-only', sourceCommit])
    .split('\n')
    .filter(path => /^(game\/|server\/|assets\/|public\/|package.*json$)/.test(path));
  const changed = tracked.length
    ? git(repo, ['diff', '--name-only', sourceCommit, '--', ...tracked]).split('\n').filter(Boolean)
    : [];
  if (!derivative) {
    require_(changed.length === 0, `Locked source differs from the repository tree: ${changed.join(', ')}`);
    return;
  }
  require_(derivative.schema_version === 1, 'Derivative schema_version must be 1');
  require_(derivative.source_commit === sourceCommit, 'Derivative source_commit differs from the manifested source_commit');
  require_(HEX40.test(derivative.derivative_commit ?? ''), 'Derivative derivative_commit must be a 40-hex commit');
  require_(git(repo, ['merge-base', derivative.derivative_commit, 'HEAD']) === derivative.derivative_commit,
    'Derivative commit is not in the repository ancestry');
  const runtimeFiles = derivative.runtime_files;
  require_(plainObject(runtimeFiles) && Object.keys(runtimeFiles).length > 0,
    'Derivative runtime inventory is missing');
  // Mirror tools/godot-export/semantic.mjs: a reviewed derivative may introduce
  // new source modules as well as modify locked files, and both kinds must
  // appear in the recorded runtime inventory.
  const added = git(repo, ['diff', '--name-only', '--diff-filter=A', sourceCommit, 'HEAD',
    '--', 'game', 'server', 'assets', 'public', 'package.json', 'package-lock.json'])
    .split('\n').filter(path => path && !path.endsWith('.test.mjs'));
  const actual = [...new Set([...changed, ...added])].filter(path => !path.endsWith('.test.mjs')).sort();
  requireSortedEqual(actual, Object.keys(runtimeFiles), 'Derivative source inventory');
  for (const [path, hash] of Object.entries(runtimeFiles)) {
    require_(/^(game|server)\/[a-z0-9-]+\.mjs$/.test(path), `Invalid derivative source entry: ${path}`);
    require_(tracked.includes(path) || added.includes(path), `Derivative source is not present at the source commit: ${path}`);
    require_(HEX64.test(hash), `Derivative source hash must be 64-hex: ${path}`);
    require_(gitObjectHash(repo, derivative.derivative_commit, path) === hash, `Derivative source byte mismatch: ${path}`);
    require_(sha256File(join(repo, ...path.split('/'))) === hash, `Derivative working-tree byte mismatch: ${path}`);
  }
}

// Load and bind the derivative contract from the repository, checking it against
// the manifest's recorded commit and hash. Ambient selection is never consulted.
function loadDerivative(repo, identity) {
  if (identity.derivativeCommit === null) return null;
  const path = join(repo, ...DERIVATIVE_CONTRACT.split('/'));
  require_(existsSync(path), `Recorded derivative contract is missing from the repository: ${DERIVATIVE_CONTRACT}`);
  const bytes = readFileSync(path);
  require_(sha256(bytes) === identity.derivativeHash,
    'Derivative metadata mismatch: repository contract hash differs from manifest source_derivative_sha256');
  const derivative = JSON.parse(bytes.toString('utf8'));
  require_(derivative.derivative_commit === identity.derivativeCommit,
    'Derivative metadata mismatch: contract derivative_commit differs from manifest source_derivative_commit');
  require_(derivative.source_commit === identity.source_commit,
    'Derivative metadata mismatch: contract source_commit differs from manifest source_commit');
  return derivative;
}

export function verifyGitIdentity(repo, identity, packageDir) {
  require_(existsSync(repo), `Repository path does not exist: ${repo}`);
  const lockPath = join(repo, ...SOURCE_LOCK.split('/'));
  require_(existsSync(lockPath), `Repository source lock is missing: ${SOURCE_LOCK}`);
  const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
  require_(lock.source_commit === identity.source_commit,
    `Manifest source_commit ${identity.source_commit} differs from repository source lock ${lock.source_commit}`);
  require_(lock.godot_version === identity.godot_version,
    'Manifest godot_version differs from the repository source lock');

  const derivative = loadDerivative(repo, identity);
  verifySourceState(repo, identity.source_commit, derivative);
  const derivativeFiles = derivative ? derivative.runtime_files : {};

  for (const path of identity.sourceModules) {
    const commit = Object.hasOwn(derivativeFiles, path) ? derivative.derivative_commit : identity.source_commit;
    const expected = gitObjectHash(repo, commit, path);
    const actual = sha256File(join(packageDir, 'runtime', ...path.split('/')));
    require_(expected === actual, `Runtime source differs from ${commit}: ${path}`);
  }
  for (const path of identity.adapters) {
    const expected = gitObjectHash(repo, identity.port_commit, path);
    const actual = sha256File(join(packageDir, 'runtime', ...path.split('/')));
    require_(expected === actual, `Runtime adapter differs from port_commit: ${path}`);
  }
  for (const path of [...identity.dataFiles, ...identity.identityDataFiles, ...identity.hordeDataFiles]) {
    const expected = gitObjectHash(repo, identity.port_commit, path);
    const actual = sha256File(join(packageDir, 'runtime', ...path.split('/')));
    require_(expected === actual, `Runtime data differs from port_commit: ${path}`);
  }
}

export function validateArtifact({packageDir, repoRoot = REPO_ROOT, manifest = null, manifestPath = null} = {}) {
  require_(packageDir, 'validateArtifact requires a package directory');
  const resolvedPackage = resolve(packageDir);
  const resolvedRepo = resolve(repoRoot);
  require_(existsSync(resolvedPackage), `Package directory does not exist: ${resolvedPackage}`);
  const loaded = manifest ?? JSON.parse(readFileSync(manifestPath ?? join(resolvedPackage, 'manifest.json'), 'utf8'));
  const identity = normalizeManifest(loaded);
  validatePackageInventory(resolvedPackage, identity);
  validateTargetStructure(resolvedPackage, identity);
  validateRuntimeClosure(resolvedPackage, identity);
  verifyGitIdentity(resolvedRepo, identity, resolvedPackage);
  const wsFiles = Object.keys(identity.files).filter(path => path.startsWith(WS_PREFIX)).length;
  return {
    status: 'passed',
    target: identity.target,
    kind: identity.kind,
    package: resolvedPackage,
    repo: resolvedRepo,
    port_commit: identity.port_commit,
    source_commit: identity.source_commit,
    derivative_commit: identity.derivativeCommit,
    derivative_sha256: identity.derivativeHash,
    files: Object.keys(identity.files).length,
    source_modules: identity.sourceModules.length,
    adapters: identity.adapters.length,
    data_files: identity.dataFiles.length,
    identity_data_files: identity.identityDataFiles.length,
    horde_data_files: identity.hordeDataFiles.length,
    ws_files: wsFiles,
  };
}

function parseArgs(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--package' || argument === '--repo' || argument === '--manifest') {
      options[argument.slice(2)] = argv[++index];
    } else if (argument === '--json') {
      options.json = true;
    } else if (argument === '--help' || argument === '-h') {
      options.help = true;
    } else {
      throw new ValidationError(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
    return;
  }
  if (options.help) {
    console.log('usage: manifest_validation.mjs --package <extracted-package> [--repo <checkout>] [--manifest <file>] [--json]');
    return;
  }
  try {
    require_(options.package, '--package is required');
    const summary = validateArtifact({
      packageDir: options.package,
      repoRoot: options.repo ?? REPO_ROOT,
      manifestPath: options.manifest ?? null,
    });
    if (options.json) console.log(JSON.stringify(summary, null, 2));
    else console.log(`MANIFEST_VALIDATION_OK target=${summary.target} files=${summary.files} source_modules=${summary.source_modules} adapters=${summary.adapters}`);
  } catch (error) {
    const failure = {
      status: 'failed',
      name: error.name,
      error: error.message,
      package: options.package ?? null,
      repo: options.repo ?? REPO_ROOT,
    };
    if (options.json) console.log(JSON.stringify(failure, null, 2));
    else console.error(`MANIFEST_VALIDATION_FAILED ${error.message}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
