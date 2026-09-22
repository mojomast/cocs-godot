// Argument parsing for the release pipeline. Pure: no filesystem, git or network.
export const STEPS = ['preflight', 'verification', 'package', 'publish', 'verify', 'push'];
export const TARGETS = ['windows', 'linux'];
export const VERIFICATION_MODES = ['auto', 'always', 'never'];
export const PREPARE_MODES = ['auto', 'never'];
export const DEFAULT_NOTES_FILE = 'port/combat-expansion/RELEASE_NOTES.md';
export const DEFAULT_PUBLICATION_REMOTE = 'godot';
export const DEFAULT_PUBLISH_BRANCH = 'main';
export const DEFAULT_WORKFLOW = 'windows-demo.yml';
export const DEFAULT_LANDING_ZONE = '/tmp/opencode';
export const DEFAULT_PINNED_GODOT =
  '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';

export const HELP = `COCS release pipeline — one command from a frozen tree to a verified published build.

Usage:
  node tools/release/release.mjs --tag=<tag> [options]

The pipeline runs six ordered steps and stops hard at the first failure:
  1 preflight     git freeze, pinned Godot, toolchain hashes, tag/release free, notes
  2 verification  python3 tools/godot-dev/verify.py (GODOT_BIN, PORT=0, TMPDIR)
  3 package       python3 tools/godot-package/build.py --target <target>
  4 publish       gh release create <tag> ... --prerelease (refuses an existing tag)
  5 verify        gh workflow run windows-demo.yml -f tag=<tag>, watched to completion
  6 push          git push the frozen commit to the publication remote

Dry run is the default: build, release, workflow dispatch and push are printed and
skipped. Pass --execute to perform them. Nothing is ever deleted or overwritten: a
failed run is continued with --resume-from=<step> against the same --state directory,
which is append-only.

Required:
  --tag=<tag>                 release tag; also the hosted workflow input

Options:
  --target=windows|linux      package target (default windows)
  --notes-file=<path>         release notes (default ${DEFAULT_NOTES_FILE})
  --title=<title>             release title (default: first heading of the notes file)
  --state=<dir>               append-only run state (default ${DEFAULT_LANDING_ZONE}/cocs-release-<tag>)
  --godot-bin=<path>          pinned editor (default $GODOT_BIN or the pinned 4.5.2 path)
  --archive-directory=<dir>   verified editor.zip/templates.tpz source
                              (default: the directory holding --godot-bin)
  --publication-remote=<name> git remote that owns the release (default ${DEFAULT_PUBLICATION_REMOTE})
  --publish-branch=<name>     branch the release tag targets (default ${DEFAULT_PUBLISH_BRANCH})
  --branch=<name>             local branch expected at HEAD (default: the current one)
  --repository=<owner/repo>   GitHub repository (default: parsed from the publication remote)
  --workflow=<file>           hosted verification workflow (default ${DEFAULT_WORKFLOW})
  --workflow-ref=<ref>        remote ref the workflow runs on (default: --publish-branch)
  --push-ref=<src>:<dst>      explicit git push refspec (default: the frozen commit → publish branch)
  --resume-from=<step>        continue a failed run at <step>: ${STEPS.join('|')}
  --stop-after=<step>         rehearsal aid: stop after <step> with exit code 2
  --verification=auto|always|never
                              auto (default) runs verify.py only with --execute;
                              always runs it in dry runs too; never skips it
  --prepare=auto|never        generate the GLB probes the verifier needs when a
                              fresh checkout lacks them (default auto, as CI does);
                              never leaves a missing probe to fail the glb-import gate
  --verify-timeout=<seconds>  local verifier timeout (default 3600)
  --package-timeout=<seconds> package build timeout (default 3600)
  --hosted-timeout=<seconds>  hosted verification timeout (default 1800)
  --poll-seconds=<seconds>    hosted verification poll interval (default 15)
  --allow-untracked=<path>    allow one untracked non-runtime path (repeatable)
  --allow-tag-behind-head     permit a tag target that is not the frozen commit
  --allow-non-fast-forward    permit a non-fast-forward branch push
  --dry-run                   explicit dry run (the default)
  --execute                   perform build/release/dispatch/push side effects
  --help                      print this help

Exit codes: 0 success, 1 hard stop, 2 stopped after --stop-after.
`;

class UsageError extends Error {
  constructor(message) {
    super(message);
    this.name = 'UsageError';
  }
}

export {UsageError};

const FLAGS = {
  '--tag': {key: 'tag', kind: 'value'},
  '--target': {key: 'target', kind: 'value'},
  '--notes-file': {key: 'notesFile', kind: 'value'},
  '--title': {key: 'title', kind: 'value'},
  '--state': {key: 'state', kind: 'value'},
  '--godot-bin': {key: 'godotBin', kind: 'value'},
  '--archive-directory': {key: 'archiveDirectory', kind: 'value'},
  '--publication-remote': {key: 'publicationRemote', kind: 'value'},
  '--publish-branch': {key: 'publishBranch', kind: 'value'},
  '--branch': {key: 'branch', kind: 'value'},
  '--repository': {key: 'repository', kind: 'value'},
  '--workflow': {key: 'workflow', kind: 'value'},
  '--workflow-ref': {key: 'workflowRef', kind: 'value'},
  '--push-ref': {key: 'pushRef', kind: 'value'},
  '--resume-from': {key: 'resumeFrom', kind: 'value'},
  '--stop-after': {key: 'stopAfter', kind: 'value'},
  '--verification': {key: 'verification', kind: 'value'},
  '--prepare': {key: 'prepare', kind: 'value'},
  '--verify-timeout': {key: 'verifyTimeout', kind: 'number'},
  '--package-timeout': {key: 'packageTimeout', kind: 'number'},
  '--hosted-timeout': {key: 'hostedTimeout', kind: 'number'},
  '--poll-seconds': {key: 'pollSeconds', kind: 'number'},
  '--allow-untracked': {key: 'allowUntracked', kind: 'list'},
  '--execute': {key: 'execute', kind: 'boolean'},
  '--dry-run': {key: 'dryRun', kind: 'boolean'},
  '--allow-tag-behind-head': {key: 'allowTagBehindHead', kind: 'boolean'},
  '--allow-non-fast-forward': {key: 'allowNonFastForward', kind: 'boolean'},
  '--help': {key: 'help', kind: 'boolean'},
};

function valueFor(flag, raw, inline) {
  if (inline !== null) {
    if (raw.kind === 'boolean') throw new UsageError(`${flag} does not take a value`);
    if (inline === '') throw new UsageError(`${flag} needs a value`);
    return inline;
  }
  return undefined; // caller consumes the next argv entry
}

export function parseArgs(argv) {
  const options = {
    tag: null,
    target: 'windows',
    notesFile: null,
    title: null,
    state: null,
    godotBin: null,
    archiveDirectory: null,
    publicationRemote: DEFAULT_PUBLICATION_REMOTE,
    publishBranch: DEFAULT_PUBLISH_BRANCH,
    branch: null,
    repository: null,
    workflow: DEFAULT_WORKFLOW,
    workflowRef: null,
    pushRef: null,
    resumeFrom: null,
    stopAfter: null,
    verification: 'auto',
    prepare: 'auto',
    verifyTimeout: 3600,
    packageTimeout: 3600,
    hostedTimeout: 1800,
    pollSeconds: 15,
    allowUntracked: [],
    execute: false,
    dryRun: null,
    allowTagBehindHead: false,
    allowNonFastForward: false,
    help: false,
  };
  const seen = new Set();
  for (let index = 0; index < argv.length; index += 1) {
    const raw = argv[index];
    if (typeof raw !== 'string' || !raw.startsWith('--')) throw new UsageError(`unexpected argument: ${String(raw)}`);
    const eq = raw.indexOf('=');
    const flag = eq === -1 ? raw : raw.slice(0, eq);
    const inline = eq === -1 ? null : raw.slice(eq + 1);
    const spec = FLAGS[flag];
    if (!spec) throw new UsageError(`unknown option: ${flag}`);
    if (seen.has(flag) && spec.kind !== 'list') throw new UsageError(`${flag} given more than once`);
    seen.add(flag);
    if (spec.kind === 'boolean') {
      valueFor(flag, spec, inline);
      options[spec.key] = true;
      continue;
    }
    let value = valueFor(flag, spec, inline);
    if (value === undefined) {
      index += 1;
      if (index >= argv.length) throw new UsageError(`${flag} needs a value`);
      value = argv[index];
    }
    if (spec.kind === 'number') {
      if (!/^[0-9]+$/.test(value) || Number(value) < 1) throw new UsageError(`${flag} must be a positive integer`);
      value = Number(value);
    }
    if (spec.kind === 'list') options[spec.key].push(value);
    else options[spec.key] = value;
  }
  validate(options);
  options.dryRun = !options.execute;
  if (options.help) return options;
  if (!options.tag) throw new UsageError('--tag is required (for example --tag=combat-expansion-r2)');
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(options.tag) || options.tag.includes('..') || options.tag.endsWith('.')) {
    throw new UsageError(`--tag is not a safe git tag: ${options.tag}`);
  }
  options.state ??= `${DEFAULT_LANDING_ZONE}/cocs-release-${options.tag.replace(/[^A-Za-z0-9._-]/g, '_')}`;
  options.notesFile ??= DEFAULT_NOTES_FILE;
  options.godotBin ??= process.env.GODOT_BIN || DEFAULT_PINNED_GODOT;
  options.archiveDirectory ??= options.godotBin.replace(/[/\\][^/\\]*$/, '');
  options.workflowRef ??= options.publishBranch;
  options.pushRef ??= null;
  return options;
}

function validate(options) {
  if (!TARGETS.includes(options.target)) throw new UsageError(`--target must be one of ${TARGETS.join('|')}`);
  if (!VERIFICATION_MODES.includes(options.verification)) {
    throw new UsageError(`--verification must be one of ${VERIFICATION_MODES.join('|')}`);
  }
  if (!PREPARE_MODES.includes(options.prepare)) {
    throw new UsageError(`--prepare must be one of ${PREPARE_MODES.join('|')}`);
  }
  if (options.resumeFrom && !STEPS.includes(options.resumeFrom)) {
    throw new UsageError(`--resume-from must be one of ${STEPS.join('|')}`);
  }
  if (options.stopAfter && !STEPS.includes(options.stopAfter)) {
    throw new UsageError(`--stop-after must be one of ${STEPS.join('|')}`);
  }
  if (options.resumeFrom && options.stopAfter && STEPS.indexOf(options.stopAfter) <= STEPS.indexOf(options.resumeFrom)) {
    throw new UsageError(`--stop-after=${options.stopAfter} would stop before --resume-from=${options.resumeFrom}`);
  }
  if (options.pushRef && !/^[^:]+:[^:]+$/.test(options.pushRef)) {
    throw new UsageError('--push-ref must look like <src>:<dst>');
  }
  if (options.publishBranch.includes('..') || options.publishBranch.startsWith('/')) {
    throw new UsageError(`--publish-branch is not a plain branch name: ${options.publishBranch}`);
  }
  if (options.repository && !/^[^/\s]+\/[^/\s]+$/.test(options.repository)) {
    throw new UsageError('--repository must look like owner/repo');
  }
  if (options.pollSeconds < 2) throw new UsageError('--poll-seconds must be at least 2');
  if (options.execute && options.dryRun === true) throw new UsageError('--execute and --dry-run are mutually exclusive');
  for (const value of options.allowUntracked) {
    if (!value || value.startsWith('/') || value.includes('..')) {
      throw new UsageError(`--allow-untracked must be a clean relative path: ${value}`);
    }
  }
}
