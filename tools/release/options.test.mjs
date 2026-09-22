import test from 'node:test';
import assert from 'node:assert/strict';
import {parseArgs, STEPS, DEFAULT_LANDING_ZONE, UsageError} from './options.mjs';

test('release requires a safe tag and refuses to guess one', () => {
  assert.throws(() => parseArgs([]), /--tag is required/);
  assert.throws(() => parseArgs(['--tag=']), /--tag needs a value/);
  for (const tag of ['../escape', 'has space', '-leading-dash', 'has/slash', 'a..b', 'x'.repeat(129)]) {
    assert.throws(() => parseArgs([`--tag=${tag}`]), /not a safe git tag/, tag);
  }
  for (const tag of ['combat-expansion-2026-09-22', 'v2.0.0-rc1', 'graphics-demo_2026.09.22']) {
    assert.equal(parseArgs([`--tag=${tag}`]).tag, tag);
  }
});

test('release is a dry run unless --execute is explicit and never both', () => {
  const planned = parseArgs(['--tag=t']);
  assert.equal(planned.execute, false);
  assert.equal(planned.dryRun, true);
  assert.equal(parseArgs(['--tag=t', '--dry-run']).dryRun, true);
  assert.equal(parseArgs(['--tag=t', '--execute']).dryRun, false);
  assert.throws(() => parseArgs(['--tag=t', '--execute', '--dry-run']), /mutually exclusive/);
  assert.throws(() => parseArgs(['--tag=t', '--execute', '--execute']), /more than once/);
});

test('defaults pin the toolchain, notes, landing zone and publication remote', () => {
  const options = parseArgs(['--tag=combat-expansion-2026-09-22']);
  assert.equal(options.target, 'windows');
  assert.equal(options.publicationRemote, 'godot');
  assert.equal(options.publishBranch, 'main');
  assert.equal(options.workflow, 'windows-demo.yml');
  assert.equal(options.workflowRef, 'main');
  assert.equal(options.notesFile, 'port/combat-expansion/RELEASE_NOTES.md');
  assert.equal(options.state, `${DEFAULT_LANDING_ZONE}/cocs-release-combat-expansion-2026-09-22`);
  assert.match(options.godotBin, /Godot_v4\.5\.2-stable_linux\.x86_64$/);
  assert.equal(options.archiveDirectory, options.godotBin.replace(/\/[^/]+$/, ''));
  assert.equal(options.verification, 'auto');
  assert.deepEqual(options.allowUntracked, []);
  assert.equal(options.resumeFrom, null);
  assert.equal(options.pushRef, null);
});

test('resume, stop-after and verification modes are validated before any work', () => {
  assert.equal(parseArgs(['--tag=t', '--resume-from=package']).resumeFrom, 'package');
  assert.equal(parseArgs(['--tag=t', '--stop-after=verification']).stopAfter, 'verification');
  for (const step of STEPS) assert.equal(parseArgs(['--tag=t', `--resume-from=${step}`]).resumeFrom, step);
  assert.throws(() => parseArgs(['--tag=t', '--resume-from=publishh']), /--resume-from must be one of/);
  assert.throws(() => parseArgs(['--tag=t', '--stop-after=done']), /--stop-after must be one of/);
  assert.throws(() => parseArgs(['--tag=t', '--stop-after=preflight', '--resume-from=publish']), /would stop before/);
  assert.equal(parseArgs(['--tag=t', '--verification=never']).verification, 'never');
  assert.throws(() => parseArgs(['--tag=t', '--verification=maybe']), /--verification must be one of/);
  assert.equal(parseArgs(['--tag=t']).prepare, 'auto');
  assert.equal(parseArgs(['--tag=t', '--prepare=never']).prepare, 'never');
  assert.throws(() => parseArgs(['--tag=t', '--prepare=sometimes']), /--prepare must be one of/);
});

test('targets, timeouts, list flags and unknown options are rejected or collected', () => {
  assert.equal(parseArgs(['--tag=t', '--target=linux']).target, 'linux');
  assert.throws(() => parseArgs(['--tag=t', '--target=macos']), /--target must be one of/);
  assert.equal(parseArgs(['--tag=t', '--verify-timeout', '120']).verifyTimeout, 120);
  assert.throws(() => parseArgs(['--tag=t', '--poll-seconds=0']), /positive integer/);
  assert.throws(() => parseArgs(['--tag=t', '--poll-seconds=1']), /at least 2/);
  const allowed = parseArgs(['--tag=t', '--allow-untracked=port/a.md', '--allow-untracked=port/handoffs/b.md']);
  assert.deepEqual(allowed.allowUntracked, ['port/a.md', 'port/handoffs/b.md']);
  assert.throws(() => parseArgs(['--tag=t', '--allow-untracked=/etc/passwd']), /clean relative path/);
  assert.throws(() => parseArgs(['--tag=t', '--allow-untracked=../x']), /clean relative path/);
  for (const args of [['--tag=t', '--unknown'], ['--tag=t', 'positional'], ['-x'], ['--tag=t', '--target']]) {
    assert.throws(() => parseArgs(args), UsageError, args.join(' '));
  }
  assert.throws(() => parseArgs(['--tag=t', '--repository=just-a-name']), /owner\/repo/);
  assert.throws(() => parseArgs(['--tag=t', '--push-ref=nocolon']), /<src>:<dst>/);
  assert.equal(parseArgs(['--tag=t', '--push-ref=HEAD:refs/heads/main']).pushRef, 'HEAD:refs/heads/main');
});

test('help parses without a tag and does not throw', () => {
  const options = parseArgs(['--help']);
  assert.equal(options.help, true);
  assert.equal(options.state, null);
});
