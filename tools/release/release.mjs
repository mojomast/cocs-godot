#!/usr/bin/env node
// COCS release pipeline: one command from a frozen tree to a verified published build.
//
// Six ordered steps (preflight, verification, package, publish, verify, push) with a
// hard stop and a machine-readable record at every failure. Dry run is the default:
// build, release creation, workflow dispatch and push are printed and skipped unless
// --execute is passed. The state directory is append-only; nothing is deleted or
// overwritten. See tools/release/README.md for the manual fallback.
import {createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
import {createReadStream, existsSync} from 'node:fs';
import {copyFile, mkdir, readFile, readdir, stat, writeFile} from 'node:fs/promises';
import {dirname, join, relative, resolve, sep} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {parseArgs, STEPS, HELP, DEFAULT_LANDING_ZONE, DEFAULT_WORKFLOW, UsageError} from './options.mjs';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const RUNTIME_PREFIXES = ['godot/', 'game/', 'server/', 'port/', 'tools/'];
export const RUNTIME_FILES = ['package.json', 'package-lock.json'];
export const DEFAULT_ALLOW_UNTRACKED = ['port/handoffs/procedural-model-generation-llm-research.md'];
const STATE_MARKERS = ['.cocs-package-state', '.cocs-release-state'];
const WALK_SKIP = new Set(['.git', 'node_modules', '.godot', '.next', 'build', 'dist', '__pycache__']);

export class ReleaseError extends Error {
  constructor(code, message, hint = null) {
    super(message);
    this.name = 'ReleaseError';
    this.code = code;
    this.hint = hint;
  }
}

// ---------------------------------------------------------------- small helpers

function iso(ms) {
  return new Date(ms).toISOString();
}

function seconds(ms) {
  return Math.round(ms / 10) / 100;
}

function quote(value) {
  const text = String(value);
  return /^[A-Za-z0-9_./:=@+-]+$/.test(text) ? text : JSON.stringify(text);
}

function printable(command, args) {
  return [command, ...args].map(quote).join(' ');
}

export async function hashFile(path, algorithm = 'sha256') {
  const hash = createHash(algorithm);
  await new Promise((settle, reject) => {
    createReadStream(path, {highWaterMark: 8 * 1024 * 1024})
      .on('data', chunk => hash.update(chunk))
      .on('error', reject)
      .on('end', settle);
  });
  return hash.digest('hex');
}

// The pinned archive table lives in build.py so the pipeline and the builder can
// never disagree about which toolchain bytes are authorised.
export function parsePinnedArchives(buildPyText) {
  const table = /ARCHIVES\s*=\s*\{([\s\S]*?)\n\}/.exec(buildPyText);
  if (!table) throw new ReleaseError('archive-table-missing', 'tools/godot-package/build.py has no ARCHIVES table');
  const archives = {};
  const entry = /"([^"]+)"\s*:\s*\(\s*f?"([^"]+)"\s*,\s*"([0-9a-f]{128})"\s*\)/g;
  for (const match of table[1].matchAll(entry)) archives[match[1]] = {official: match[2], sha512: match[3]};
  if (!Object.keys(archives).length) throw new ReleaseError('archive-table-empty', 'build.py ARCHIVES table could not be parsed');
  return archives;
}

export function parseLsRemote(text) {
  const refs = {};
  for (const line of String(text).split('\n')) {
    const [sha, ref] = line.trim().split(/\s+/);
    if (sha && ref) refs[ref] = sha;
  }
  return refs;
}

export function remoteSlug(url) {
  const text = String(url).trim();
  const match = /^(?:https?:\/\/|ssh:\/\/)?(?:[^@/]+@)?github\.com[/:]([^/]+)\/([^/]+?)(?:\.git)?\/?$/.exec(text);
  if (!match) throw new ReleaseError('remote-unparsed', `cannot derive owner/repo from ${text}`, 'pass --repository=<owner/repo>');
  return `${match[1]}/${match[2]}`;
}

export function firstHeading(text) {
  for (const line of String(text).split('\n')) {
    const match = /^#\s+(\S.*)$/.exec(line.trim());
    if (match) return match[1].trim();
  }
  return null;
}

function isExemptPath(path) {
  return path.startsWith('port/reports/') || path.startsWith('port/handoffs/') || /^port\/[^/]+\/[^/]*evidence\//.test(path);
}

function isRuntimePath(path) {
  return RUNTIME_PREFIXES.some(prefix => path.startsWith(prefix)) || RUNTIME_FILES.includes(path);
}

function inside(parent, child) {
  return child === parent || child.startsWith(parent + sep);
}

// ---------------------------------------------------------------- process exec

export function createExec() {
  return async function exec(spec) {
    if (spec.sideEffect && spec.dryRun) return {planned: true, code: 0, stdout: '', stderr: ''};
    return new Promise(settle => {
      const started = Date.now();
      const child = spawn(spec.command, (spec.args ?? []).map(String), {
        cwd: spec.cwd, env: spec.env, stdio: ['ignore', 'pipe', 'pipe'],
      });
      let stdout = '';
      let stderr = '';
      let timedOut = false;
      const timer = spec.timeout ? setTimeout(() => {
        timedOut = true;
        child.kill('SIGKILL');
      }, spec.timeout) : null;
      child.stdout.on('data', chunk => { stdout += chunk; });
      child.stderr.on('data', chunk => { stderr += chunk; });
      child.on('error', error => {
        clearTimeout(timer);
        settle({planned: false, code: null, stdout, stderr: `${stderr}${error.message}\n`, launchError: error.message,
          timedOut, durationSeconds: seconds(Date.now() - started)});
      });
      child.on('close', code => {
        clearTimeout(timer);
        settle({planned: false, code, stdout, stderr, timedOut, durationSeconds: seconds(Date.now() - started)});
      });
    });
  };
}

// ---------------------------------------------------------------- state on disk

async function prepareState(ctx) {
  const {options, root, emit} = ctx;
  const state = resolve(options.state);
  if (inside(root, state)) {
    throw new ReleaseError('state-inside-checkout', `state directory ${state} is inside the checkout`,
      `generated state must live outside ${root}; use ${DEFAULT_LANDING_ZONE}/...`);
  }
  const marker = join(state, 'state.json');
  if (existsSync(marker)) {
    const meta = JSON.parse(await readFile(marker, 'utf8'));
    if (meta.schema_version !== 1 || meta.tag !== options.tag) {
      throw new ReleaseError('state-owned-by-other-run', `${state} belongs to ${meta.tag ?? 'another tag'}`,
        'choose a different --state or tag; the pipeline never rewrites another run\'s state');
    }
    if (!options.resumeFrom) {
      throw new ReleaseError('state-exists', `state directory already exists: ${state}`,
        `pass --resume-from=<step> to continue that run instead of starting a second one`);
    }
    emit(`  state    ${state} (resuming, append-only)`);
  } else if (existsSync(state)) {
    const entries = await readdir(state);
    if (entries.length) {
      throw new ReleaseError('state-unowned', `refusing the existing unowned directory ${state}`,
        'point --state at a free path; existing directories are never taken over or deleted');
    }
    await writeFile(marker, `${JSON.stringify({
      schema_version: 1, kind: 'cocs-release-state', tag: options.tag,
      created_at: new Date().toISOString(), created_by: 'tools/release/release.mjs',
    }, null, 2)}\n`);
    emit(`  state    ${state} (created, append-only)`);
  } else {
    await mkdir(state, {recursive: true});
    await writeFile(marker, `${JSON.stringify({
      schema_version: 1, kind: 'cocs-release-state', tag: options.tag,
      created_at: new Date().toISOString(), created_by: 'tools/release/release.mjs',
    }, null, 2)}\n`);
    emit(`  state    ${state} (created, append-only)`);
  }
  const runs = join(state, 'runs');
  await mkdir(runs, {recursive: true});
  const stamp = new Date(ctx.now()).toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z');
  let runId = `${stamp}-${process.pid}`;
  for (let counter = 2; existsSync(join(runs, runId)); counter += 1) runId = `${stamp}-${process.pid}-${counter}`;
  const runDir = join(runs, runId);
  await mkdir(join(runDir, 'steps'), {recursive: true});
  await mkdir(join(runDir, 'logs'), {recursive: true});
  await mkdir(join(runDir, 'evidence'), {recursive: true});
  ctx.state = state;
  ctx.runDir = runDir;
  ctx.runId = runId;
  return runDir;
}

async function loadPriorRecords(runs) {
  const prior = new Map();
  if (!existsSync(runs)) return prior;
  for (const runId of (await readdir(runs)).sort()) {
    const stepsDir = join(runs, runId, 'steps');
    if (!existsSync(stepsDir)) continue;
    for (const file of (await readdir(stepsDir)).sort()) {
      const path = join(stepsDir, file);
      try {
        const record = JSON.parse(await readFile(path, 'utf8'));
        if (STEPS.includes(record.step)) prior.set(record.step, {record, path, run_id: runId});
      } catch {
        // A torn record never becomes authority: ignore and keep the previous one.
      }
    }
  }
  return prior;
}

// ---------------------------------------------------------------- command layer

async function runCommand(ctx, spec) {
  const command = spec.command;
  const args = (spec.args ?? []).map(String);
  const entry = {
    command, args, side_effect: !!spec.sideEffect, executed: false, planned: false,
    exit_code: null, duration_seconds: null, timed_out: false,
  };
  ctx.stepCommands.push(entry);
  const line = printable(command, args);
  if (spec.sideEffect && ctx.dryRun) {
    entry.planned = true;
    ctx.emit(`  DRY-RUN  ${line}`);
    ctx.stepLog.push(`DRY-RUN ${line}\n`);
    return {planned: true, code: 0, stdout: '', stderr: ''};
  }
  const started = ctx.now();
  const result = await ctx.exec({
    command, args, cwd: ctx.root, env: spec.env ?? ctx.baseEnv, timeout: spec.timeout ?? null,
    sideEffect: !!spec.sideEffect, dryRun: ctx.dryRun, label: spec.label ?? null,
  });
  entry.executed = true;
  entry.exit_code = result.code ?? null;
  entry.timed_out = !!result.timedOut;
  entry.duration_seconds = result.durationSeconds ?? seconds(ctx.now() - started);
  const text = `$ ${line}\n${result.stdout ?? ''}${result.stderr ?? ''}`;
  ctx.stepLog.push(text.endsWith('\n') ? text : `${text}\n`);
  if (result.planned) {
    entry.planned = true;
    return result;
  }
  if (result.launchError) {
    throw new ReleaseError('command-launch-failed', `${line}: ${result.launchError}`, 'check the executable and PATH');
  }
  if (result.timedOut) {
    throw new ReleaseError('command-timeout', `${line} exceeded ${spec.timeout} ms`,
      'inspect the step log; raise the matching --*-timeout only if the work is genuinely still running');
  }
  if (result.code !== 0 && !spec.allowFailure) {
    const tail = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim().split('\n').slice(-25).join('\n');
    throw new ReleaseError('command-failed', `${line} exited ${result.code}`, tail);
  }
  return result;
}

async function git(ctx, args, spec = {}) {
  const result = await runCommand(ctx, {
    command: 'git', args, label: spec.label ?? null, allowFailure: spec.allowFailure ?? false, timeout: spec.timeout ?? 120000,
  });
  return result.planned ? {planned: true, code: 0, stdout: ''} : {...result, stdout: (result.stdout ?? '').trim()};
}

async function gitOrThrow(ctx, args, message, hint) {
  const result = await git(ctx, args, {allowFailure: true});
  if (result.planned) return '';
  if (result.code !== 0) throw new ReleaseError('git-failed', `${message}: git ${args.join(' ')}`, hint ?? (result.stderr ?? '').trim());
  return result.stdout;
}

async function readGitStatus(ctx) {
  // Porcelain v1 keeps a leading space for work-tree-only changes; never trim the
  // raw output before slicing the two status columns.
  const result = await runCommand(ctx, {
    command: 'git', args: ['status', '--porcelain=v1', '-uall'], timeout: 120000, label: 'status',
  });
  if (result.planned) return {modified: [], untracked: []};
  const text = String(result.stdout ?? '');
  const modified = [];
  const untracked = [];
  for (const line of String(text).split('\n')) {
    if (!line.trim()) continue;
    const code = line.slice(0, 2);
    let path = line.slice(3);
    const arrow = path.indexOf(' -> ');
    if (arrow !== -1) path = path.slice(arrow + 4);
    if (path.startsWith('"') && path.endsWith('"')) path = path.slice(1, -1);
    if (path.includes('"') || path.includes('\\')) {
      throw new ReleaseError('unparsed-path', `cannot parse git path: ${line}`, 'rename the path to plain ASCII');
    }
    if (code === '??') untracked.push(path);
    else modified.push(path);
  }
  return {modified, untracked};
}

async function walkForStateMarkers(root, limit = {depth: 4, entries: 20000}) {
  const hits = [];
  let seen = 0;
  const queue = [{dir: root, depth: 0}];
  while (queue.length) {
    const {dir, depth} = queue.shift();
    if (depth > limit.depth) continue;
    let entries;
    try {
      entries = await readdir(dir, {withFileTypes: true});
    } catch {
      continue;
    }
    for (const entry of entries) {
      seen += 1;
      if (seen > limit.entries) return hits;
      const path = join(dir, entry.name);
      if (STATE_MARKERS.includes(entry.name)) {
        hits.push(relative(root, path));
        continue;
      }
      if (entry.isDirectory()) {
        if (WALK_SKIP.has(entry.name)) continue;
        if (/^cocs-(release|rebuild|package)-/.test(entry.name)) {
          hits.push(relative(root, path));
          continue;
        }
        queue.push({dir: path, depth: depth + 1});
      }
    }
  }
  return hits;
}

// ---------------------------------------------------------------- shared checks

async function assertStillFrozen(ctx, where) {
  const head = await gitOrThrow(ctx, ['rev-parse', 'HEAD'], 'cannot read HEAD');
  const recorded = ctx.results.get('preflight')?.head;
  if (ctx.dryRun) {
    // Nothing to protect in a plan, but a long --verification=always rehearsal must
    // not silently report a plan for a tree that moved under it.
    if (recorded && head !== recorded) {
      const note = `  warn     ${where}: HEAD moved from ${recorded} to ${head} during this dry run; the plan describes the earlier commit`;
      ctx.emit(note);
      ctx.stepLog.push(`${note}\n`);
    }
    return;
  }
  if (recorded && head !== recorded) {
    throw new ReleaseError('tree-moved', `${where}: HEAD moved from ${recorded} to ${head} since preflight`,
      'aborting before any side effect; re-run the pipeline on the new commit');
  }
  const status = await readGitStatus(ctx);
  const blockers = status.modified.filter(path => !isExemptPath(path));
  if (blockers.length) {
    throw new ReleaseError('tree-changed', `${where}: tracked runtime files changed after preflight: ${blockers.slice(0, 8).join(', ')}`,
      'commit or revert the change and re-run; the release ships one frozen tree');
  }
  const allowed = new Set([...DEFAULT_ALLOW_UNTRACKED, ...ctx.options.allowUntracked]);
  const untracked = status.untracked.filter(path => isRuntimePath(path) && !isExemptPath(path) && !allowed.has(path));
  if (untracked.length) {
    throw new ReleaseError('tree-changed', `${where}: new untracked runtime files: ${untracked.slice(0, 8).join(', ')}`,
      'commit or remove them, or allow them explicitly with --allow-untracked');
  }
  ctx.emit(`  freeze   ${head.slice(0, 12)} unchanged since preflight`);
}

// ---------------------------------------------------------------- the six steps

async function stepPreflight(ctx) {
  const {options} = ctx;
  const detail = {};
  const head = await gitOrThrow(ctx, ['rev-parse', 'HEAD'], 'cannot read HEAD');
  if (!/^[0-9a-f]{40}$/.test(head)) {
    throw new ReleaseError('no-commit', 'git rev-parse HEAD did not return a commit', 'run the pipeline from the repository checkout');
  }
  const branchRef = await gitOrThrow(ctx, ['rev-parse', '--abbrev-ref', 'HEAD'], 'cannot read the branch');
  let branch = branchRef;
  if (branchRef === 'HEAD') {
    // A tag or CI checkout is a legal release source: the freeze is the commit.
    if (options.branch) {
      throw new ReleaseError('branch-mismatch', `--branch=${options.branch} was requested but HEAD is detached`,
        'check out that branch, or drop --branch to release the detached commit');
    }
    branch = null;
    detail.detached = true;
    ctx.emit('  warn     HEAD is detached; releasing the commit directly (no local branch recorded)');
  } else if (options.branch && options.branch !== branchRef) {
    throw new ReleaseError('branch-mismatch', `expected branch ${options.branch} but HEAD is on ${branchRef}`,
      'release from the branch you named, or drop --branch');
  }
  detail.head = head;
  detail.branch = branch;
  ctx.emit(`  HEAD     ${head.slice(0, 12)}${branch ? ` on ${branch}` : ' (detached)'}`);

  const shallow = await gitOrThrow(ctx, ['rev-parse', '--is-shallow-repository'], 'cannot read the repository depth');
  if (shallow !== 'false') {
    throw new ReleaseError('shallow-repository', 'the checkout is a shallow clone',
      'the builder verifies locked source bytes against history; use a full clone');
  }
  const packageState = join(ctx.state, 'package-state');
  if (!inside(DEFAULT_LANDING_ZONE, packageState) || packageState === DEFAULT_LANDING_ZONE) {
    throw new ReleaseError('state-outside-landing-zone', `the package state ${packageState} is outside ${DEFAULT_LANDING_ZONE}`,
      `build.py refuses build state elsewhere; pass --state=${DEFAULT_LANDING_ZONE}/cocs-release-<tag>`);
  }
  detail.package_state = packageState;

  const remoteUrl = await gitOrThrow(ctx, ['remote', 'get-url', options.publicationRemote], `publication remote ${options.publicationRemote} is missing`,
    'add the remote or pass --publication-remote=<name>');
  const repository = options.repository ?? remoteSlug(remoteUrl);
  detail.publication_remote = options.publicationRemote;
  detail.remote_url = remoteUrl;
  detail.repository = repository;

  // The tag/release check is cheap and it is the most common refusal on a re-run, so
  // it fires before the toolchain hashes.
  const localTag = (await git(ctx, ['tag', '--list', options.tag])).stdout;
  if (localTag) throw new ReleaseError('tag-exists', `local tag ${options.tag} already exists`, 'releases are never overwritten; choose a new tag');
  const remoteTag = await gitOrThrow(ctx, ['ls-remote', '--tags', options.publicationRemote, `refs/tags/${options.tag}`], 'cannot list remote tags');
  if (remoteTag) {
    throw new ReleaseError('tag-exists', `tag ${options.tag} already exists on ${options.publicationRemote}`,
      'releases are never overwritten; choose a new tag');
  }
  const view = await runCommand(ctx, {
    command: 'gh', args: ['release', 'view', options.tag, '--repo', repository, '--json', 'tagName'],
    allowFailure: true, label: 'release-lookup', timeout: 60000,
  });
  if (view.code === 0) {
    throw new ReleaseError('release-exists', `release ${options.tag} already exists in ${repository}`,
      'releases are never overwritten; choose a new tag');
  }
  if (!/not found/i.test(`${view.stdout}${view.stderr}`)) {
    throw new ReleaseError('release-lookup-failed', `cannot confirm that ${options.tag} is free in ${repository}`,
      `${(view.stderr ?? '').trim()} — check gh authentication`);
  }
  detail.tag = {name: options.tag, free: true};
  ctx.emit(`  tag      ${options.tag} is free on ${options.publicationRemote} and in ${repository}`);

  const status = await readGitStatus(ctx);
  const allowed = new Set([...DEFAULT_ALLOW_UNTRACKED, ...options.allowUntracked]);
  const modified = status.modified.filter(path => !isExemptPath(path));
  const exempted = status.modified.filter(path => isExemptPath(path));
  const blocked = path => isRuntimePath(path) && !isExemptPath(path) && !allowed.has(path);
  const untrackedBlocking = status.untracked.filter(blocked);
  const untrackedWarn = status.untracked.filter(path => !allowed.has(path) && !blocked(path));
  if (modified.length) {
    throw new ReleaseError('dirty-tree', `tracked files are modified: ${modified.slice(0, 8).join(', ')}${modified.length > 8 ? ` (+${modified.length - 8} more)` : ''}`,
      'commit or revert them; the package build refuses uncommitted runtime bytes');
  }
  if (untrackedBlocking.length) {
    throw new ReleaseError('dirty-tree', `untracked runtime files: ${untrackedBlocking.slice(0, 8).join(', ')}`,
      'commit or remove them, or allow an intentional non-runtime file with --allow-untracked=<path>');
  }
  detail.tree = {modified: [], exempted, untracked: status.untracked, allowed: [...allowed]};
  if (untrackedWarn.length) ctx.emit(`  warn     ${untrackedWarn.length} untracked non-runtime path(s) recorded: ${untrackedWarn.slice(0, 4).join(', ')}${untrackedWarn.length > 4 ? ' …' : ''}`);
  ctx.emit(`  tree     clean (${exempted.length} verification report file(s) exempt, ${status.untracked.length} untracked recorded)`);

  const laneState = await walkForStateMarkers(ctx.root);
  if (laneState.length) {
    throw new ReleaseError('lane-state-in-checkout', `lane-owned build state inside the checkout: ${laneState.join(', ')}`,
      'move generated state to /tmp/opencode; the checkout must stay free of build state');
  }
  const portRuntime = existsSync(join(ctx.root, '.port-runtime'));
  if (portRuntime) {
    ctx.emit('  warn     .port-runtime exists (gitignored verification default); this run overrides XDG_* into its own state');
  }
  detail.tree.port_runtime_present = portRuntime;

  const lock = JSON.parse(await readFile(join(ctx.root, 'port/contracts/source-lock.json'), 'utf8'));
  const binary = resolve(ctx.root, options.godotBin);
  if (!existsSync(binary)) {
    throw new ReleaseError('godot-missing', `GODOT_BIN not found: ${binary}`, 'install the pinned toolchain or pass --godot-bin');
  }
  if (!((await stat(binary)).mode & 0o111)) {
    throw new ReleaseError('godot-not-executable', `${binary} is not executable`, `chmod +x ${binary}`);
  }
  const version = (await runCommand(ctx, {command: binary, args: ['--version'], label: 'godot-version', timeout: 30000})).stdout.trim();
  if (version !== lock.godot_version) {
    throw new ReleaseError('godot-version-mismatch', `Godot reports ${version}, the source lock requires ${lock.godot_version}`,
      'point --godot-bin at the pinned 4.5.2 editor');
  }
  detail.godot_bin = binary;
  detail.godot_version = version;
  ctx.emit(`  godot    ${version} (${binary})`);

  const pinned = parsePinnedArchives(await readFile(join(ctx.root, 'tools/godot-package/build.py'), 'utf8'));
  const archives = {};
  for (const [local, expected] of Object.entries(pinned)) {
    const path = resolve(options.archiveDirectory, local);
    if (!existsSync(path)) {
      throw new ReleaseError('archive-missing', `toolchain archive missing: ${path}`,
        'run tools/godot-dev/install-toolchain.py or point --archive-directory at the verified archive directory');
    }
    const digest = await hashFile(path, 'sha512');
    if (digest !== expected.sha512) {
      throw new ReleaseError('archive-hash-mismatch', `${path} sha512 ${digest} does not match the pinned ${expected.sha512}`,
        'the toolchain bytes are not the verified ones; reinstall the pinned archives');
    }
    archives[local] = {path, bytes: (await stat(path)).size, sha512: digest, official: expected.official};
    ctx.emit(`  archive  ${local} ${(archives[local].bytes / 1048576).toFixed(1)} MiB sha512 ✓`);
  }
  detail.toolchain = {archives};

  const notesPath = resolve(ctx.root, options.notesFile);
  if (!existsSync(notesPath)) {
    throw new ReleaseError('notes-missing', `release notes not found: ${notesPath}`, 'pass --notes-file=<path>');
  }
  const notes = await readFile(notesPath, 'utf8');
  if (!notes.trim()) throw new ReleaseError('notes-empty', `release notes are empty: ${notesPath}`);
  const title = options.title ?? firstHeading(notes);
  if (!title) throw new ReleaseError('title-missing', 'no title found in the notes file', 'pass --title=<title>');
  detail.notes = {
    path: relative(ctx.root, notesPath), title, bytes: Buffer.byteLength(notes), sha256: await hashFile(notesPath),
  };
  ctx.emit(`  notes    ${detail.notes.path} (${detail.notes.bytes} bytes) title "${title}"`);

  const workflowPath = join(ctx.root, '.github/workflows', options.workflow);
  if (!existsSync(workflowPath)) {
    throw new ReleaseError('workflow-missing', `hosted verification workflow not found: ${workflowPath}`, 'pass --workflow=<file>');
  }
  const workflow = await readFile(workflowPath, 'utf8');
  if (!/workflow_dispatch:/.test(workflow) || !/^\s+tag:/m.test(workflow)) {
    throw new ReleaseError('workflow-input-missing', `${options.workflow} has no workflow_dispatch tag input`,
      'the hosted verification must accept the release tag');
  }
  if (options.target === 'linux' && options.workflow === DEFAULT_WORKFLOW) {
    throw new ReleaseError('workflow-target-mismatch',
      `${DEFAULT_WORKFLOW} verifies the Windows ZIP, not the ${options.target} archive`,
      'pass --workflow=<file> with a workflow that can verify this target, or release deliberately with --stop-after=publish');
  }
  detail.workflow = {file: options.workflow, ref: options.workflowRef};
  ctx.emit(`  workflow ${options.workflow} on ref ${options.workflowRef} (tag input present)`);

  const remoteHeads = parseLsRemote(await gitOrThrow(ctx, ['ls-remote', '--heads', options.publicationRemote], 'cannot list remote branches'));
  const remoteHead = remoteHeads[`refs/heads/${options.publishBranch}`] ?? null;
  let headOnRemote = false;
  for (const sha of Object.values(remoteHeads)) {
    if (!/^[0-9a-f]{40}$/.test(sha)) continue;
    if (sha === head) { headOnRemote = true; break; }
    const known = await git(ctx, ['cat-file', '-e', `${sha}^{commit}`], {allowFailure: true});
    if (known.code !== 0) continue;
    const ancestor = await git(ctx, ['merge-base', '--is-ancestor', head, sha], {allowFailure: true});
    if (ancestor.code === 0) { headOnRemote = true; break; }
  }
  detail.remote = {
    publish_branch: options.publishBranch, remote_head: remoteHead, head_on_remote: headOnRemote,
    tag_target: headOnRemote ? head : `refs/heads/${options.publishBranch}`,
  };
  if (!headOnRemote) {
    const note = `frozen commit ${head.slice(0, 12)} is not on ${options.publicationRemote} yet; ` +
      `the tag would target refs/heads/${options.publishBranch} instead`;
    if (options.execute && !options.allowTagBehindHead) {
      throw new ReleaseError('tag-target-behind-head', note,
        'push the commit first (git push ' + options.publicationRemote + ' ' + head.slice(0, 12) +
        ':refs/heads/' + options.publishBranch + ') or pass --allow-tag-behind-head to tag the published branch head');
    }
    ctx.emit(`  warn     ${note}`);
  } else {
    ctx.emit(`  remote   ${options.publicationRemote}/${options.publishBranch} at ${(remoteHead ?? '').slice(0, 12)} (fast-forward)`);
  }
  return detail;
}

async function stepVerification(ctx) {
  const {options} = ctx;
  if (options.verification === 'never') {
    ctx.emit('  skipped  verification disabled by --verification=never');
    return {planned: false, skipped: 'never'};
  }
  const runtime = join(ctx.runDir, 'runtime');
  const env = {
    ...ctx.baseEnv,
    GODOT_BIN: ctx.results.get('preflight').godot_bin,
    PORT: '0',
    TMPDIR: DEFAULT_LANDING_ZONE,
    XDG_DATA_HOME: join(runtime, 'data'),
    XDG_CONFIG_HOME: join(runtime, 'config'),
    XDG_CACHE_HOME: join(runtime, 'cache'),
  };
  for (const dir of [env.XDG_DATA_HOME, env.XDG_CONFIG_HOME, env.XDG_CACHE_HOME]) await mkdir(dir, {recursive: true});
  ctx.emit(`  env      GODOT_BIN, PORT=0, TMPDIR=${DEFAULT_LANDING_ZONE}, XDG_* under ${relative(ctx.runDir, runtime)}`);
  // Redirecting XDG_CACHE_HOME moves Playwright's default browser cache, so probe
  // generation must be told where the browsers actually are (CI sets this explicitly).
  const playwrightBrowsers = env.PLAYWRIGHT_BROWSERS_PATH
    ?? (env.HOME && existsSync(join(env.HOME, '.cache/ms-playwright')) ? join(env.HOME, '.cache/ms-playwright') : null);
  const prepareEnv = playwrightBrowsers ? {...env, PLAYWRIGHT_BROWSERS_PATH: playwrightBrowsers} : env;
  if (playwrightBrowsers) ctx.emit(`  prepare  Playwright browsers: ${playwrightBrowsers}`);
  // The aggregate verifier imports GLB probes under godot/content, which .gitignore
  // excludes; the hosted Linux workflow generates them with browser-export.mjs before
  // verify.py. Mirror that here so a frozen tree really is verifiable from one command.
  const probes = [{id: 'axis-weapon', args: []}, {id: 'meridian-exchange', args: ['meridian-exchange']}];
  const missing = probes.filter(probe => !existsSync(join(ctx.root, 'godot/content/probes', probe.id, 'world.glb')));
  const prepared = [];
  if (missing.length && options.prepare === 'never') {
    ctx.emit(`  warn     GLB probes missing (${missing.map(probe => probe.id).join(', ')}) and --prepare=never; glb-import will fail`);
  }
  for (const probe of missing.filter(() => options.prepare === 'auto')) {
    const args = ['tools/godot-export/browser-export.mjs', ...probe.args];
    ctx.emit(`  prepare  generating the missing ${probe.id} GLB probe (as the CI workflow does)`);
    const generated = await runCommand(ctx, {command: 'node', args, env: prepareEnv, sideEffect: true, timeout: 600000, label: 'prepare'});
    if (!generated.planned && !existsSync(join(ctx.root, 'godot/content/probes', probe.id, 'world.glb'))) {
      throw new ReleaseError('probe-generation-failed', `browser-export.mjs ran but did not write the ${probe.id} probe`,
        'regenerate with `node tools/godot-export/browser-export.mjs`, install the browser with `npx playwright install chromium`, ' +
        'or pass --prepare=never and accept a failing glb-import gate');
    }
    prepared.push({probe: probe.id, planned: !!generated.planned, command: printable('node', args)});
  }
  if (prepared.length) ctx.emit(`  prepare  ${prepared.map(entry => entry.probe).join(', ')} ready`);
  // auto runs the verifier only with --execute; always rehearses it even in a dry run.
  const result = await runCommand(ctx, {
    command: 'python3', args: ['tools/godot-dev/verify.py'], env, sideEffect: options.verification === 'auto',
    timeout: options.verifyTimeout * 1000, label: 'verify', allowFailure: true,
  });
  if (result.planned) {
    return {planned: true, command: 'python3 tools/godot-dev/verify.py'};
  }
  const reportPath = join(ctx.root, 'port/reports/verification.json');
  const report = existsSync(reportPath) ? JSON.parse(await readFile(reportPath, 'utf8')) : null;
  if (report) await copyFile(reportPath, join(ctx.runDir, 'evidence/verification.json'));
  const gates = Array.isArray(report?.gates) ? report.gates : [];
  const failed = gates.filter(gate => !gate.passed);
  const passed = gates.length - failed.length;
  const detail = {
    exit_code: result.code, status: report?.status ?? 'missing', gates_total: gates.length, gates_passed: passed,
    failing_gates: failed.map(gate => ({gate: gate.gate, reason: gate.failure_reason ?? null})),
    source_commit: report?.source_commit ?? null, report: report ? 'evidence/verification.json' : null,
    probes_prepared: prepared,
  };
  if (result.code !== 0 || report?.status !== 'passed' || failed.length) {
    const why = failed.length
      ? `${failed.length} gate(s) failed: ${failed.map(gate => gate.gate).join(', ')}`
      : report ? `report status ${report.status}` : 'no port/reports/verification.json written';
    throw Object.assign(new ReleaseError('verification-failed', `verify.py exit ${result.code}; ${why}`,
      'the frozen tree is not verifiable; fix or revert and re-run. Reports live in port/reports/.'), {detail});
  }
  const changed = (await readGitStatus(ctx)).modified.filter(path => path.startsWith('port/reports/'));
  detail.reports_rewritten = changed.length;
  ctx.emit(`  gates    ${passed}/${gates.length} passed on source ${String(report.source_commit ?? '').slice(0, 12)} (${changed.length} report files rewritten)`);
  return detail;
}

function parseBuildResult(text) {
  const start = text.lastIndexOf('\n{');
  const candidate = text.slice(start === -1 ? 0 : start + 1);
  try {
    return JSON.parse(candidate);
  } catch {
    throw new ReleaseError('build-result-unparsed', 'cannot find the build.py JSON result in its output',
      'the captured log holds the full builder output');
  }
}

async function stepPackage(ctx) {
  const {options} = ctx;
  const buildState = join(ctx.state, 'package-state');
  const args = ['tools/godot-package/build.py', '--target', options.target, '--state', buildState,
    '--archive-directory', options.archiveDirectory, '--operator-models', 'source-operators'];
  ctx.emit(`  state    ${buildState}`);
  const result = await runCommand(ctx, {
    command: 'python3', args, sideEffect: true, timeout: options.packageTimeout * 1000, label: 'package',
  });
  if (result.planned) {
    return {planned: true, target: options.target, command: printable('python3', args)};
  }
  const summary = parseBuildResult(result.stdout);
  const archive = summary.archive;
  if (!archive || !existsSync(archive)) {
    throw new ReleaseError('archive-missing-after-build', `build.py reported ${archive} but the file is not there`);
  }
  const size = (await stat(archive)).size;
  const archiveSha = await hashFile(archive);
  if (archiveSha !== summary.archive_sha256) {
    throw new ReleaseError('archive-hash-mismatch', `recomputed ${archiveSha} != build.py ${summary.archive_sha256}`,
      'the archive changed after the build; do not publish it');
  }
  const sidecarPath = `${archive}.sha256`;
  if (!existsSync(sidecarPath)) throw new ReleaseError('checksum-missing', `${sidecarPath} was not written`);
  const sidecar = (await readFile(sidecarPath, 'utf8')).trim().split(/\s+/)[0];
  if (sidecar !== archiveSha) {
    throw new ReleaseError('checksum-mismatch', `${sidecarPath} does not match the archive (${sidecar} != ${archiveSha})`);
  }
  const manifestPath = join(summary.package, 'manifest.json');
  if (!existsSync(manifestPath)) throw new ReleaseError('manifest-missing', `${manifestPath} was not written`);
  const manifestSha = await hashFile(manifestPath);
  if (summary.manifest_sha256 && manifestSha !== summary.manifest_sha256) {
    throw new ReleaseError('manifest-mismatch', `recomputed manifest ${manifestSha} != build.py ${summary.manifest_sha256}`);
  }
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const preflight = ctx.results.get('preflight');
  if (manifest.port_commit !== preflight.head) {
    throw new ReleaseError('package-commit-mismatch', `the package recorded port commit ${manifest.port_commit}, the frozen tree is ${preflight.head}`,
      'the package was built from another commit; do not publish it');
  }
  if (manifest.target !== options.target) {
    throw new ReleaseError('package-target-mismatch', `the package target is ${manifest.target}, requested ${options.target}`);
  }
  await copyFile(sidecarPath, join(ctx.runDir, 'evidence/archive.sha256'));
  await copyFile(manifestPath, join(ctx.runDir, 'evidence/manifest.json'));
  await writeFile(join(ctx.runDir, `evidence/build-result-${options.target}.json`), `${JSON.stringify(summary, null, 2)}\n`);
  const detail = {
    target: options.target, archive, archive_bytes: size, archive_sha256: archiveSha,
    manifest_sha256: manifestSha, port_commit: manifest.port_commit, source_commit: manifest.source_commit,
    inputs_sha256: summary.inputs_sha256 ?? null, generated_resources_sha256: summary.generated_resources_sha256 ?? null,
    build: summary.build ?? null, command: printable('python3', args),
    evidence: ['evidence/build-result-' + options.target + '.json', 'evidence/manifest.json', 'evidence/archive.sha256'],
  };
  ctx.emit(`  archive  ${archive}`);
  ctx.emit(`  size     ${(size / 1048576).toFixed(1)} MiB  sha256 ${archiveSha.slice(0, 16)}…`);
  ctx.emit(`  manifest sha256 ${manifestSha.slice(0, 16)}…  port ${String(manifest.port_commit).slice(0, 12)}`);
  return detail;
}

async function stepPublish(ctx) {
  const {options} = ctx;
  const preflight = ctx.results.get('preflight');
  const built = ctx.results.get('package');
  const plannedPackage = !built || !built.archive || !built.archive_sha256;
  if (plannedPackage && !ctx.dryRun) {
    throw new ReleaseError('missing-artifact', 'cannot publish without a packaged archive',
      'resume from package with --execute so the archive actually exists');
  }
  ctx.emit(`  archive  ${plannedPackage ? '(planned by the package step; no bytes to publish in a dry run)' : built.archive}`);
  if (!plannedPackage) {
    if (!existsSync(built.archive)) {
      throw new ReleaseError('archive-missing', `the packaged archive is gone: ${built.archive}`,
        'resume from package to rebuild it; the pipeline never republishes a missing archive');
    }
    const archiveSha = await hashFile(built.archive);
    if (archiveSha !== built.archive_sha256) {
      throw new ReleaseError('archive-changed', `${built.archive} is no longer the built archive`,
        'resume from package; do not publish changed bytes');
    }
    const localTag = (await git(ctx, ['tag', '--list', options.tag])).stdout;
    if (localTag) throw new ReleaseError('tag-exists', `local tag ${options.tag} already exists`);
    const remoteTag = await gitOrThrow(ctx, ['ls-remote', '--tags', options.publicationRemote, `refs/tags/${options.tag}`], 'cannot list remote tags');
    if (remoteTag) {
      throw new ReleaseError('tag-exists', `tag ${options.tag} appeared on ${options.publicationRemote} during the run`,
        'another release used this tag; never overwrite an existing release');
    }
  }
  const target = preflight.remote.tag_target;
  const assets = plannedPackage
    ? ['cocs-native-<target>.zip', 'cocs-native-<target>.zip.sha256']
    : [built.archive, `${built.archive}.sha256`];
  const args = ['release', 'create', options.tag, ...assets,
    '--repo', preflight.repository, '--title', preflight.notes.title, '--notes-file', resolve(ctx.root, options.notesFile),
    '--prerelease', '--target', target];
  ctx.emit(`  target   ${target === preflight.head ? `frozen commit ${target.slice(0, 12)}` : target}`);
  const result = await runCommand(ctx, {command: 'gh', args, sideEffect: true, timeout: 600000, label: 'publish'});
  if (result.planned) return {planned: true, tag: options.tag, command: printable('gh', args), assets};

  const view = await runCommand(ctx, {
    command: 'gh', args: ['release', 'view', options.tag, '--repo', preflight.repository,
      '--json', 'tagName,name,isPrerelease,url,targetCommitish,assets'],
    timeout: 60000, label: 'release-view',
  });
  const release = JSON.parse(view.stdout);
  const names = (release.assets ?? []).map(asset => asset.name);
  const expectedAssets = [built.archive.split('/').pop(), `${built.archive.split('/').pop()}.sha256`];
  for (const expected of expectedAssets) {
    if (!names.includes(expected)) {
      throw new ReleaseError('release-asset-missing', `release ${options.tag} has no ${expected} asset`,
        'the release was created but is incomplete; do not dispatch hosted verification');
    }
  }
  if (!release.isPrerelease) {
    throw new ReleaseError('release-not-prerelease', `release ${options.tag} is marked as a full release`,
      'the pipeline only publishes prereleases');
  }
  const tagSha = await gitOrThrow(ctx, ['ls-remote', '--tags', options.publicationRemote, `refs/tags/${options.tag}`], 'cannot read the published tag');
  const detail = {
    tag: options.tag, title: release.name ?? preflight.notes.title, url: release.url, prerelease: true,
    tag_commit: tagSha.split(/\s+/)[0] ?? null, target_commitish: release.targetCommitish ?? target,
    assets: (release.assets ?? []).map(asset => ({name: asset.name, size: asset.size ?? null})),
  };
  ctx.emit(`  release  ${detail.url}`);
  ctx.emit(`  assets   ${names.join(', ')}`);
  return detail;
}

async function stepHostedVerify(ctx) {
  const {options} = ctx;
  const preflight = ctx.results.get('preflight');
  const published = ctx.results.get('publish');
  const ref = options.workflowRef;
  const dispatchArgs = ['workflow', 'run', options.workflow, '--repo', preflight.repository, '--ref', ref, '-f', `tag=${options.tag}`];
  if (!published || !published.url) {
    if (!ctx.dryRun) {
      throw new ReleaseError('missing-artifact', 'cannot dispatch hosted verification without a published prerelease',
        'resume from publish with --execute so the release actually exists');
    }
    await runCommand(ctx, {command: 'gh', args: dispatchArgs, sideEffect: true, timeout: 120000, label: 'dispatch'});
    ctx.emit('  note     dry run: the hosted run URL only exists after an --execute publish');
    return {planned: true, workflow: options.workflow, ref, inputs: {tag: options.tag}, command: printable('gh', dispatchArgs)};
  }
  const dispatchedAt = ctx.now();
  // Pin the remote head the run must have been created from, so a concurrent
  // dispatch of the same workflow cannot be mistaken for ours.
  const headsBefore = parseLsRemote(await gitOrThrow(ctx, ['ls-remote', '--heads', options.publicationRemote], 'cannot read the remote branch before dispatching'));
  const expectedHead = headsBefore[`refs/heads/${ref}`] ?? preflight.head;
  const dispatch = await runCommand(ctx, {command: 'gh', args: dispatchArgs, sideEffect: true, timeout: 120000, label: 'dispatch'});
  if (dispatch.planned) {
    return {planned: true, workflow: options.workflow, ref, inputs: {tag: options.tag}, command: printable('gh', dispatchArgs)};
  }
  ctx.emit(`  dispatch ${options.workflow} on ${ref} with tag=${options.tag}`);

  const listArgs = ['run', 'list', '--repo', preflight.repository, '--workflow', options.workflow,
    '--event', 'workflow_dispatch', '--branch', ref, '--limit', '20',
    '--json', 'databaseId,createdAt,headSha,event,headBranch,status,conclusion,url'];
  let run = null;
  const deadline = ctx.now() + options.hostedTimeout * 1000;
  while (!run) {
    if (ctx.now() > deadline) {
      throw new ReleaseError('verify-run-not-found', `no hosted run appeared for ${options.workflow} on ${ref} within ${options.hostedTimeout}s`,
        'check `gh run list` manually; the dispatch may have failed silently');
    }
    const listed = await runCommand(ctx, {command: 'gh', args: listArgs, timeout: 60000, label: 'run-list'});
    const runs = JSON.parse(listed.stdout).filter(candidate =>
      candidate.event === 'workflow_dispatch' && candidate.headBranch === ref &&
      Date.parse(candidate.createdAt) >= dispatchedAt - 120000);
    runs.sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
    run = runs.find(candidate => candidate.headSha === expectedHead) ?? runs[0] ?? null;
    if (!run) await ctx.sleep(Math.min(options.pollSeconds, 10) * 1000);
  }
  ctx.emit(`  run      ${run.url} (id ${run.databaseId})`);

  let latest = run;
  while (latest.status !== 'completed') {
    if (ctx.now() > deadline) {
      throw new ReleaseError('verify-timeout', `hosted run ${latest.databaseId} is still ${latest.status} after ${options.hostedTimeout}s`,
        `watch it manually: gh run watch ${latest.databaseId} --repo ${preflight.repository}`);
    }
    await ctx.sleep(options.pollSeconds * 1000);
    const viewArgs = ['run', 'view', String(latest.databaseId), '--repo', preflight.repository,
      '--json', 'databaseId,status,conclusion,url,headSha,createdAt'];
    latest = JSON.parse((await runCommand(ctx, {command: 'gh', args: viewArgs, timeout: 60000, label: 'run-view'})).stdout);
  }
  const detail = {
    workflow: options.workflow, ref, run_id: latest.databaseId, run_url: latest.url,
    status: latest.status, conclusion: latest.conclusion, head_sha: latest.headSha,
    dispatched_at: iso(dispatchedAt), remote_head_at_dispatch: expectedHead,
    run_matches_remote_head: latest.headSha === expectedHead,
    remote_head_matches: preflight.remote.remote_head === preflight.head,
  };
  if (!detail.remote_head_matches) {
    ctx.emit(`  warn     the hosted checkout is ${String(preflight.remote.remote_head ?? '').slice(0, 12)}, not the frozen ${preflight.head.slice(0, 12)}; verification proves the release asset, not the branch bytes`);
  }
  if (!detail.run_matches_remote_head) {
    ctx.emit(`  warn     the selected run was built from ${String(latest.headSha ?? '').slice(0, 12)}, not the ${expectedHead.slice(0, 12)} read at dispatch`);
  }
  if (latest.conclusion !== 'success') {
    throw Object.assign(new ReleaseError('hosted-verify-failed', `hosted run ${latest.databaseId} concluded ${latest.conclusion}`,
      `open ${latest.url}; the branch is not pushed on failure`), {detail});
  }
  ctx.emit(`  result   ${latest.conclusion} (${latest.url})`);
  return detail;
}

async function stepPush(ctx) {
  const {options} = ctx;
  const preflight = ctx.results.get('preflight');
  const hosted = ctx.results.get('verify');
  const refspec = options.pushRef ?? `${preflight.head}:refs/heads/${options.publishBranch}`;
  if (!hosted || hosted.conclusion !== 'success') {
    if (!ctx.dryRun) {
      throw new ReleaseError('hosted-verification-required', 'refusing to push before a successful hosted verification',
        'resume from verify with --execute; the branch is pushed only after the hosted run passes');
    }
    await runCommand(ctx, {command: 'git', args: ['push', options.publicationRemote, refspec], sideEffect: true, timeout: 600000, label: 'push'});
    ctx.emit('  note     dry run: the push above is planned and only happens after a passing hosted run');
    return {planned: true, remote: options.publicationRemote, refspec, commit: preflight.head};
  }
  const remoteHeads = parseLsRemote(await gitOrThrow(ctx, ['ls-remote', '--heads', options.publicationRemote], 'cannot list remote branches'));
  const remoteHead = remoteHeads[`refs/heads/${options.publishBranch}`] ?? null;
  let fastForward = remoteHead === preflight.head;
  if (!fastForward && remoteHead) {
    const known = await git(ctx, ['cat-file', '-e', `${remoteHead}^{commit}`], {allowFailure: true});
    if (known.code === 0) {
      fastForward = (await git(ctx, ['merge-base', '--is-ancestor', remoteHead, preflight.head], {allowFailure: true})).code === 0;
    }
  }
  if (!fastForward && !options.allowNonFastForward) {
    throw new ReleaseError('non-fast-forward', `pushing ${preflight.head.slice(0, 12)} would not fast-forward ${options.publicationRemote}/${options.publishBranch} (${String(remoteHead ?? 'missing').slice(0, 12)})`,
      'the publication branch moved; re-verify on top of it, or pass --allow-non-fast-forward deliberately');
  }
  ctx.emit(`  refspec  ${refspec} (${fastForward ? 'fast-forward' : 'non-fast-forward, explicitly allowed'})`);
  const result = await runCommand(ctx, {
    command: 'git', args: ['push', options.publicationRemote, refspec], sideEffect: true, timeout: 600000, label: 'push',
  });
  if (result.planned) return {planned: true, remote: options.publicationRemote, refspec, commit: preflight.head};
  const after = parseLsRemote(await gitOrThrow(ctx, ['ls-remote', '--heads', options.publicationRemote], 'cannot re-read remote branches'));
  const detail = {
    remote: options.publicationRemote, refspec, commit: preflight.head,
    branch_before: remoteHead, branch_after: after[`refs/heads/${options.publishBranch}`] ?? null,
    hosted_run: hosted.run_url,
  };
  ctx.emit(`  pushed   ${options.publicationRemote}/${options.publishBranch} -> ${String(detail.branch_after ?? '').slice(0, 12)}`);
  return detail;
}

const STEPS_IMPL = {
  preflight: stepPreflight,
  verification: stepVerification,
  package: stepPackage,
  publish: stepPublish,
  verify: stepHostedVerify,
  push: stepPush,
};

// ---------------------------------------------------------------- orchestration

export async function runPipeline({
  argv,
  env = process.env,
  exec = createExec(),
  print = line => console.log(line),
  root = ROOT,
  now = Date.now,
  sleep = ms => new Promise(settle => setTimeout(settle, ms)),
} = {}) {
  const options = parseArgs(argv);
  if (options.help) {
    print(HELP);
    return {exitCode: 0, summaryPath: null, options, records: []};
  }
  const transcript = [];
  const emit = line => {
    transcript.push(line);
    print(line);
  };
  const ctx = {
    options, root, exec, now, sleep, emit, dryRun: options.dryRun,
    baseEnv: env, results: new Map(), stepLog: [], stepCommands: [],
    state: null, runDir: null, runId: null,
  };
  emit(`COCS release pipeline — tag=${options.tag} target=${options.target} mode=${options.dryRun ? 'DRY-RUN' : 'EXECUTE'}`);
  try {
    await prepareState(ctx);
  } catch (error) {
    if (!(error instanceof ReleaseError)) throw error;
    emit(`HARD STOP ${error.code}: ${error.message}`);
    if (error.hint) emit(`  hint: ${error.hint}`);
    return {exitCode: 1, summaryPath: null, summary: null, records: [], options, error};
  }
  emit(`  run      ${relative(ctx.state, ctx.runDir)}`);
  const prior = await loadPriorRecords(join(ctx.state, 'runs'));
  const resumeIndex = options.resumeFrom ? STEPS.indexOf(options.resumeFrom) : 0;
  const records = [];
  let exitCode = 0;
  let stoppedAfter = null;
  let failure = null;

  for (const [index, name] of STEPS.entries()) {
    if (index < resumeIndex) {
      const reused = prior.get(name);
      const record = {
        schema_version: 1, step: name, index: index + 1, status: 'skipped-resume', dry_run: options.dryRun,
        started_at: iso(now()), finished_at: iso(now()), duration_seconds: 0,
        reused_from: reused ? relative(ctx.state, reused.path) : null, commands: [], detail: reused?.record.detail ?? {},
      };
      if (!reused) {
        failure = new ReleaseError('resume-missing-record', `--resume-from=${name} but no earlier record of the ${name} step exists in ${ctx.state}`,
          'start a new run without --resume-from, or pick a state directory that holds the earlier steps');
      } else if (reused.record.status === 'failed') {
        failure = new ReleaseError('resume-after-failure', `the previous ${name} record failed; resume from ${name} itself or from an earlier step`,
          `record: ${relative(ctx.state, reused.path)}`);
      } else if (reused.record.status === 'skipped-option') {
        failure = new ReleaseError('resume-after-skip', `the previous ${name} step was skipped by option and cannot back a continuation`,
          're-run without --verification=never');
      } else if (reused.record.status === 'skipped-dry-run' && !options.dryRun) {
        failure = new ReleaseError('resume-planned-only', `the previous ${name} step was only planned (dry run)`,
          `resume from ${name} with --execute so it actually runs`);
      }
      records.push(record);
      ctx.results.set(name, record.detail ?? {});
      if (failure) {
        exitCode = 1;
        break;
      }
      emit(`[${index + 1}/6] ${name} — resumed from ${record.reused_from ?? 'prior run'} (${reused.record.status})`);
      continue;
    }
    emit(`[${index + 1}/6] ${name}`);
    ctx.stepLog = [];
    ctx.stepCommands = [];
    const record = {
      schema_version: 1, step: name, index: index + 1, status: 'running', dry_run: options.dryRun,
      started_at: iso(now()), finished_at: null, duration_seconds: null, commands: [], detail: {},
    };
    const startedAt = now();
    try {
      if (index > 0) await assertStillFrozen(ctx, `before ${name}`);
      const detail = await STEPS_IMPL[name](ctx);
      record.detail = detail ?? {};
      record.status = detail?.planned ? 'skipped-dry-run' : (detail?.skipped ? 'skipped-option' : 'ok');
      ctx.results.set(name, record.detail);
      exitCode = 0;
    } catch (error) {
      record.status = 'failed';
      record.error = {code: error.code ?? 'error', message: error.message, hint: error.hint ?? null, detail: error.detail ?? null};
      failure = error;
    }
    record.commands = ctx.stepCommands;
    record.finished_at = iso(now());
    record.duration_seconds = seconds(now() - startedAt);
    await writeFile(join(ctx.runDir, 'steps', `${String(index + 1).padStart(2, '0')}-${name}.json`), `${JSON.stringify(record, null, 2)}\n`);
    await writeFile(join(ctx.runDir, 'logs', `${String(index + 1).padStart(2, '0')}-${name}.log`), ctx.stepLog.join(''));
    records.push(record);
    if (failure) {
      exitCode = 1;
      break;
    }
    emit(`  ${record.status === 'ok' ? '✔' : '○'} ${name} ${record.duration_seconds}s (${record.status})`);
    if (options.stopAfter === name) {
      stoppedAfter = name;
      exitCode = 2;
      emit(`  stopped after ${name} as requested (--stop-after)`);
      break;
    }
  }

  const summary = {
    schema_version: 1, kind: 'cocs-release-run', run_id: ctx.runId, tag: options.tag, target: options.target,
    mode: options.dryRun ? 'dry-run' : 'execute', dry_run: options.dryRun, argv: [...argv],
    state: ctx.state, resume_from: options.resumeFrom, stop_after: options.stopAfter,
    started_at: records[0]?.started_at ?? iso(now()), finished_at: iso(now()),
    status: failure ? 'failed' : stoppedAfter ? `stopped-after-${stoppedAfter}` : 'ok',
    exit_code: exitCode, head: ctx.results.get('preflight')?.head ?? null,
    branch: ctx.results.get('preflight')?.branch ?? null,
    steps: records.map(record => ({
      step: record.step, status: record.status, duration_seconds: record.duration_seconds,
      detail: record.detail, error: record.error ?? null, reused_from: record.reused_from ?? null,
    })),
  };
  await writeFile(join(ctx.runDir, 'summary.json'), `${JSON.stringify(summary, null, 2)}\n`);
  transcript.push('', JSON.stringify(summary, null, 2));
  await writeFile(join(ctx.runDir, 'release.log'), `${transcript.join('\n')}\n`);
  if (failure) {
    emit('');
    emit(`HARD STOP [${records.at(-1).step}] ${failure.code}: ${failure.message}`);
    if (failure.hint) emit(`  hint: ${failure.hint}`);
    emit(`  step log: ${relative(ctx.state, join(ctx.runDir, 'logs', `${String(records.length).padStart(2, '0')}-${records.at(-1).step}.log`))}`);
    emit(`  summary:  ${relative(ctx.state, join(ctx.runDir, 'summary.json'))}`);
    emit(`  resume with: --resume-from=${records.at(-1).step} --state=${ctx.state}${options.dryRun ? '' : ' --execute'}`);
  } else if (stoppedAfter) {
    emit('');
    emit(`Stopped after ${stoppedAfter} as requested. Resume with:`);
    emit(`  node tools/release/release.mjs --tag=${options.tag} --state=${ctx.state} --resume-from=<next-step>${options.dryRun ? '' : ' --execute'}`);
  } else if (options.dryRun) {
    emit('');
    emit(`DRY RUN complete — no build, release, workflow dispatch or push was performed.`);
    emit(`Re-run with --execute to perform the ${STEPS.length} steps.`);
  } else {
    emit('');
    emit('Release pipeline complete.');
  }
  emit(`summary: ${join(ctx.runDir, 'summary.json')}`);
  return {exitCode, summaryPath: join(ctx.runDir, 'summary.json'), summary, records, options};
}

export async function main(argv = process.argv.slice(2), io = {}) {
  const {print = line => console.log(line), report = line => console.error(line)} = io;
  try {
    const result = await runPipeline({argv, print});
    return result.exitCode;
  } catch (caught) {
    if (caught instanceof UsageError) {
      report(`${caught.message}\n`);
      report(HELP);
      return 1;
    }
    if (caught instanceof ReleaseError) {
      report(`HARD STOP ${caught.code}: ${caught.message}`);
      if (caught.hint) report(`  hint: ${caught.hint}`);
      return 1;
    }
    throw caught;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exitCode = await main();
}
