// Exercises the release state machine without touching git, GitHub or the builder:
// every dangerous call goes through an injectable stub runner. The real gh/git
// invocations only ever happen behind --execute in release.mjs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {existsSync} from 'node:fs';
import {mkdir, mkdtemp, readFile, readdir, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {runPipeline, hashFile} from './release.mjs';

const GODOT_VERSION = '4.5.2.stable.official.6ce3de25a';
const HEAD = 'a'.repeat(40);
const REMOTE_HEAD = 'b'.repeat(40);
const TAG = 'rehearsal-2026-09-22';

const sha512 = bytes => createHash('sha512').update(bytes).digest('hex');

async function fixture(overrides = {}) {
  const base = await mkdtemp(join(tmpdir(), 'cocs-release-test-'));
  const root = join(base, 'checkout');
  const state = join(base, 'state');
  const toolchain = join(base, 'toolchain');
  for (const dir of ['port/contracts', 'port/combat-expansion', 'port/reports', 'tools/godot-package', '.github/workflows', toolchain]) {
    await mkdir(dir.startsWith('/') ? dir : join(root, dir), {recursive: true});
  }
  const table = [];
  for (const name of ['editor.zip', 'templates.tpz']) {
    const bytes = Buffer.from(`${name}-fixture`);
    await writeFile(join(toolchain, name), bytes);
    table.push(`    "${name}": (f"${name}.official", "${sha512(bytes)}"),`);
  }
  await writeFile(join(root, 'tools/godot-package/build.py'), `VERSION = "4.5.2"\nARCHIVES = {\n${table.join('\n')}\n}\n`);
  await writeFile(join(root, 'port/contracts/source-lock.json'), JSON.stringify({godot_version: GODOT_VERSION}));
  await writeFile(join(root, 'port/combat-expansion/RELEASE_NOTES.md'), '# Rehearsal release title\n\nBody.\n');
  await writeFile(join(root, '.github/workflows/windows-demo.yml'),
    'name: Windows demo verification\non:\n  workflow_dispatch:\n    inputs:\n      tag:\n        type: string\njobs:\n  x:\n    runs-on: windows-latest\n');
  const godotBin = join(base, 'Godot_v4.5.2-stable_linux.x86_64');
  await writeFile(godotBin, '#!/bin/sh\necho stub\n', {mode: 0o755});

  const world = {
    tag: TAG,
    status: '',
    remoteHeads: [{sha: HEAD, ref: 'refs/heads/main'}],
    isAncestor: (a, b) => a === REMOTE_HEAD && b === HEAD,
    tagExists: false,
    release: false,
    releaseFails: false,
    publishFails: false,
    dispatchFails: false,
    verificationExit: 0,
    verificationReport: {status: 'passed', source_commit: 'c'.repeat(40), gates: [{gate: 'a', passed: true}, {gate: 'b', passed: true}]},
    runStatus: 'completed',
    conclusion: 'success',
    outputs: [],
    ...overrides,
  };
  const calls = [];
  const done = (code, stdout = '', stderr = '') => ({planned: false, code, stdout, stderr, timedOut: false, durationSeconds: 0});

  const exec = async spec => {
    const {command, args} = spec;
    calls.push({command, args: [...args], sideEffect: !!spec.sideEffect, dryRun: !!spec.dryRun});
    if (command === godotBin) return done(0, `${GODOT_VERSION}\n`);
    if (command === 'git') return gitStub(world, args);
    if (command === 'gh') return ghStub(world, args);
    if (command === 'python3' && args[0] === 'tools/godot-dev/verify.py') {
      await writeFile(join(spec.cwd, 'port/reports/verification.json'), JSON.stringify(world.verificationReport));
      return done(world.verificationExit, 'gates ran\n');
    }
    if (command === 'python3' && args[0] === 'tools/godot-package/build.py') {
      if (world.publishFails && false) return done(1, 'nope\n');
      const stateDir = args[args.indexOf('--state') + 1];
      const target = args[args.indexOf('--target') + 1];
      const packageDir = join(stateDir, 'builds/1', `cocs-native-${target}`);
      await mkdir(packageDir, {recursive: true});
      const archive = join(stateDir, 'builds/1', `cocs-native-${target}.zip`);
      await writeFile(archive, `zip-bytes-${target}`);
      const archiveSha = await hashFile(archive);
      await writeFile(`${archive}.sha256`, `${archiveSha}  ${archive.split('/').pop()}\n`);
      await writeFile(join(packageDir, 'manifest.json'), JSON.stringify({port_commit: HEAD, target, source_commit: 'c'.repeat(40)}));
      return done(0, JSON.stringify({
        archive, archive_sha256: archiveSha, manifest_sha256: await hashFile(join(packageDir, 'manifest.json')),
        package: packageDir, build: join(stateDir, 'builds/1'), inputs_sha256: 'd'.repeat(64),
        generated_resources_sha256: 'e'.repeat(64),
      }));
    }
    throw new Error(`unexpected command: ${command} ${args.join(' ')}`);
  };
  const gitStub = async (world, args) => {
    if (args[0] === 'status') return done(0, world.status);
    if (args[0] === 'rev-parse' && args[1] === 'HEAD') return done(0, `${HEAD}\n`);
    if (args[0] === 'rev-parse' && args[1] === '--abbrev-ref') return done(0, 'port/godot-destinations\n');
    if (args[0] === 'remote' && args[1] === 'get-url') return done(0, 'https://github.com/mojomast/cocs-godot.git\n');
    if (args[0] === 'tag' && args[1] === '--list') return done(0, world.tagExists ? `${world.tag}\n` : '');
    if (args[0] === 'ls-remote' && args[1] === '--tags') return done(0, world.tagExists ? `${HEAD}\trefs/tags/${world.tag}\n` : '');
    if (args[0] === 'ls-remote' && args[1] === '--heads') {
      return done(0, world.remoteHeads.map(head => `${head.sha}\t${head.ref}\n`).join(''));
    }
    if (args[0] === 'cat-file') return done(world.remoteHeads.some(head => args[2].startsWith(head.sha)) ? 0 : 1, '');
    if (args[0] === 'merge-base') return done(world.isAncestor(args[2], args[3]) ? 0 : 1, '');
    if (args[0] === 'push') {
      if (world.pushFails) return done(1, 'rejected\n');
      world.remoteHeads = [{sha: HEAD, ref: 'refs/heads/main'}];
      return done(0, '');
    }
    throw new Error(`unexpected git: ${args.join(' ')}`);
  };
  const ghStub = async (world, args) => {
    if (args[0] === 'release' && args[1] === 'view') {
      if (world.releaseFails) return done(1, '', 'HTTP 503\n');
      if (!world.release) return done(1, '', 'release not found\n');
      return done(0, JSON.stringify({
        tagName: world.tag, name: 'Rehearsal release title', isPrerelease: true,
        url: `https://github.com/mojomast/cocs-godot/releases/tag/${world.tag}`,
        targetCommitish: 'main',
        assets: [{name: 'cocs-native-windows.zip', size: 1234}, {name: 'cocs-native-windows.zip.sha256', size: 90}],
      }));
    }
    if (args[0] === 'release' && args[1] === 'create') {
      if (world.publishFails) return done(1, '', 'release create failed\n');
      world.release = true;
      world.tagExists = true;
      return done(0, '');
    }
    if (args[0] === 'workflow' && args[1] === 'run') {
      if (world.dispatchFails) return done(1, '', 'dispatch refused\n');
      world.dispatched = true;
      return done(0, '');
    }
    if (args[0] === 'run' && args[1] === 'list') {
      const runs = world.dispatched ? [runSummary(world, 'in_progress', null)] : [];
      return done(0, JSON.stringify(runs));
    }
    if (args[0] === 'run' && args[1] === 'view') {
      if (!world.dispatched) return done(1, '', 'not found\n');
      return done(0, JSON.stringify(runSummary(world, world.runStatus, world.conclusion)));
    }
    throw new Error(`unexpected gh: ${args.join(' ')}`);
  };
  const runSummary = (world, status, conclusion) => ({
    databaseId: 4242, createdAt: new Date().toISOString(), headSha: world.remoteHeads[0]?.sha ?? HEAD,
    event: 'workflow_dispatch', headBranch: 'main', status, conclusion,
    url: 'https://github.com/mojomast/cocs-godot/actions/runs/4242',
  });

  const run = (argv, extra = {}) => runPipeline({
    root,
    argv: [`--state=${state}`, `--godot-bin=${godotBin}`, `--archive-directory=${toolchain}`, ...argv],
    exec, print: line => world.outputs.push(line),
    sleep: async () => {}, env: {PATH: '/usr/bin:/bin'}, ...extra,
  });
  const sideEffects = () => calls.filter(call => call.sideEffect && !call.dryRun);
  const cleanup = () => rm(base, {recursive: true, force: true});
  const readSummary = async result => JSON.parse(await readFile(result.summaryPath, 'utf8'));
  return {base, root, state, toolchain, world, calls, run, sideEffects, cleanup, readSummary, outputs: world.outputs};
}

test('dry run plans all six steps, writes records and performs no side effect', async () => {
  const fx = await fixture();
  try {
    const result = await fx.run([`--tag=${TAG}`]);
    assert.equal(result.exitCode, 0, fx.outputs.join('\n'));
    const summary = await fx.readSummary(result);
    assert.equal(summary.mode, 'dry-run');
    assert.equal(summary.status, 'ok');
    assert.deepEqual(summary.steps.map(step => step.step),
      ['preflight', 'verification', 'package', 'publish', 'verify', 'push']);
    assert.equal(summary.steps[0].status, 'ok');
    for (const step of summary.steps.slice(1)) assert.equal(step.status, 'skipped-dry-run', step.step);
    assert.equal(fx.sideEffects().length, 0, 'dry run executed a side effect');
    for (const name of ['01-preflight', '02-verification', '03-package', '04-publish', '05-verify', '06-push']) {
      assert.ok(existsSync(join(result.summaryPath, '..', 'steps', `${name}.json`)), name);
      assert.ok(existsSync(join(result.summaryPath, '..', 'logs', `${name}.log`)), name);
    }
    assert.ok(fx.outputs.some(line => line.includes('DRY-RUN') && line.includes('build.py')));
    assert.ok(fx.outputs.some(line => line.includes('DRY-RUN') && line.includes('release create')));
    assert.ok(fx.outputs.some(line => line.includes('DRY-RUN') && line.includes('workflow run')));
    assert.ok(fx.outputs.some(line => line.includes('DRY-RUN') && line.includes('git push')));
    assert.ok(fx.outputs.some(line => line.includes('no build, release, workflow dispatch or push was performed')));
  } finally {
    await fx.cleanup();
  }
});

test('preflight refuses a dirty runtime tree before anything else', async () => {
  const fx = await fixture({status: ' M godot/world/session.gd\n'});
  try {
    const result = await fx.run([`--tag=${TAG}`]);
    assert.equal(result.exitCode, 1);
    const summary = await fx.readSummary(result);
    assert.equal(summary.status, 'failed');
    assert.equal(summary.steps.length, 1);
    assert.equal(summary.steps[0].error.code, 'dirty-tree');
    assert.match(summary.steps[0].error.message, /godot\/world\/session\.gd/);
    assert.equal(fx.sideEffects().length, 0);
    assert.equal(fx.calls.filter(call => call.command === 'gh').length, 0, 'gh must not run after a dirty-tree refusal');
  } finally {
    await fx.cleanup();
  }
});

test('preflight refuses an untracked runtime file but records a non-runtime one', async () => {
  const fx = await fixture({status: '?? godot/benchmark/frame_stats.gd\n?? reports/notes.md\n'});
  try {
    const refused = await fx.run([`--tag=${TAG}`]);
    assert.equal(refused.exitCode, 1);
    assert.equal((await fx.readSummary(refused)).steps[0].error.code, 'dirty-tree');
    const allowed = await fx.run([`--tag=${TAG}`, '--allow-untracked=godot/benchmark/frame_stats.gd', '--resume-from=preflight']);
    assert.equal(allowed.exitCode, 0);
    const detail = (await fx.readSummary(allowed)).steps[0].detail;
    assert.deepEqual(detail.tree.untracked, ['godot/benchmark/frame_stats.gd', 'reports/notes.md']);
  } finally {
    await fx.cleanup();
  }
});

test('an existing tag or release refuses even in a dry run', async () => {
  const existing = await fixture({tagExists: true});
  try {
    const result = await existing.run([`--tag=${TAG}`]);
    assert.equal(result.exitCode, 1);
    const summary = await existing.readSummary(result);
    assert.equal(summary.steps[0].error.code, 'tag-exists');
    assert.equal(existing.calls.filter(call => call.command === 'gh').length, 0);
  } finally {
    await existing.cleanup();
  }
  const released = await fixture({release: true});
  try {
    const result = await released.run([`--tag=${TAG}`]);
    assert.equal(result.exitCode, 1);
    assert.equal((await released.readSummary(result)).steps[0].error.code, 'release-exists');
  } finally {
    await released.cleanup();
  }
});

test('an unowned or second state directory is never taken over', async () => {
  const fx = await fixture();
  try {
    await mkdir(fx.state, {recursive: true});
    await writeFile(join(fx.state, 'someone-elses-file.txt'), 'keep me\n');
    const refused = await fx.run([`--tag=${TAG}`]);
    assert.equal(refused.exitCode, 1);
    assert.match(fx.outputs.join('\n'), /HARD STOP state-unowned/);
    assert.ok(existsSync(join(fx.state, 'someone-elses-file.txt')));
    const clean = await fixture();
    try {
      const first = await clean.run([`--tag=${TAG}`]);
      assert.equal(first.exitCode, 0);
      const second = await clean.run([`--tag=${TAG}`]);
      assert.equal(second.exitCode, 1);
      assert.match(clean.outputs.join('\n'), /HARD STOP state-exists/);
      const runs = await readdir(join(clean.state, 'runs'));
      assert.equal(runs.length, 1, 'the second run must not add or delete state');
      assert.ok(existsSync(first.summaryPath));
    } finally {
      await clean.cleanup();
    }
  } finally {
    await fx.cleanup();
  }
});

test('a corrupted toolchain archive refuses preflight', async () => {
  const fx = await fixture();
  try {
    await writeFile(join(fx.toolchain, 'templates.tpz'), 'tampered');
    const result = await fx.run([`--tag=${TAG}`]);
    assert.equal(result.exitCode, 1);
    assert.equal((await fx.readSummary(result)).steps[0].error.code, 'archive-hash-mismatch');
  } finally {
    await fx.cleanup();
  }
});

test('a behind remote warns in a dry run and refuses an execute tag target', async () => {
  const behind = {remoteHeads: [{sha: REMOTE_HEAD, ref: 'refs/heads/main'}]};
  const planned = await fixture(behind);
  try {
    const result = await planned.run([`--tag=${TAG}`]);
    assert.equal(result.exitCode, 0);
    const detail = (await planned.readSummary(result)).steps[0].detail;
    assert.equal(detail.remote.head_on_remote, false);
    assert.equal(detail.remote.tag_target, 'refs/heads/main');
    assert.match(planned.outputs.join('\n'), /is not on godot yet/);
  } finally {
    await planned.cleanup();
  }
  const execute = await fixture(behind);
  try {
    const result = await execute.run([`--tag=${TAG}`, '--execute']);
    assert.equal(result.exitCode, 1);
    assert.equal((await execute.readSummary(result)).steps[0].error.code, 'tag-target-behind-head');
    assert.equal(execute.sideEffects().length, 0);
    const allowed = await execute.run([`--tag=${TAG}`, '--execute', '--allow-tag-behind-head', '--resume-from=preflight']);
    assert.equal(allowed.exitCode, 0, execute.outputs.join('\n'));
  } finally {
    await execute.cleanup();
  }
});

test('execute walks verification, package, publish, hosted verify and push in order', async () => {
  const fx = await fixture();
  try {
    const result = await fx.run([`--tag=${TAG}`, '--execute', '--verification=always']);
    assert.equal(result.exitCode, 0, fx.outputs.join('\n'));
    const summary = await fx.readSummary(result);
    assert.equal(summary.status, 'ok');
    assert.deepEqual(summary.steps.map(step => step.status), ['ok', 'ok', 'ok', 'ok', 'ok', 'ok']);
    const labels = {
      'python3 tools/godot-dev/verify.py': call => call.command === 'python3' && call.args[0] === 'tools/godot-dev/verify.py',
      'python3 tools/godot-package/build.py': call => call.command === 'python3' && call.args[0] === 'tools/godot-package/build.py',
      'gh release create': call => call.command === 'gh' && call.args[0] === 'release' && call.args[1] === 'create',
      'gh workflow run': call => call.command === 'gh' && call.args[0] === 'workflow' && call.args[1] === 'run',
      'git push': call => call.command === 'git' && call.args[0] === 'push',
    };
    const order = fx.calls.filter(call => !call.dryRun)
      .map(call => Object.keys(labels).find(name => labels[name](call))).filter(Boolean);
    assert.deepEqual(order, [
      'python3 tools/godot-dev/verify.py',
      'python3 tools/godot-package/build.py',
      'gh release create',
      'gh workflow run',
      'git push',
    ]);
    const packageDetail = summary.steps[2].detail;
    assert.match(packageDetail.archive_sha256, /^[0-9a-f]{64}$/);
    assert.equal(packageDetail.port_commit, HEAD);
    assert.equal(summary.steps[3].detail.url, `https://github.com/mojomast/cocs-godot/releases/tag/${TAG}`);
    assert.equal(summary.steps[4].detail.conclusion, 'success');
    assert.equal(summary.steps[5].detail.commit, HEAD);
    assert.deepEqual(summary.steps[5].detail.branch_after, HEAD);
    assert.ok(existsSync(join(result.summaryPath, '..', 'evidence/manifest.json')));
  } finally {
    await fx.cleanup();
  }
});

test('a failed publish stops the pipeline and resume repeats only the publish', async () => {
  const fx = await fixture({publishFails: true});
  try {
    const first = await fx.run([`--tag=${TAG}`, '--execute']);
    assert.equal(first.exitCode, 1);
    const failed = await fx.readSummary(first);
    assert.equal(failed.status, 'failed');
    assert.equal(failed.steps.at(-1).step, 'publish');
    assert.equal(failed.steps.at(-1).error.code, 'command-failed');
    assert.deepEqual(failed.steps.slice(0, 3).map(step => step.status), ['ok', 'ok', 'ok']);
    assert.equal(fx.calls.filter(call => call.command === 'gh' && call.args[1] === 'create').length, 1);

    fx.world.publishFails = false;
    const second = await fx.run(['--tag=' + TAG, '--execute', '--resume-from=publish']);
    assert.equal(second.exitCode, 0, fx.outputs.join('\n'));
    const resumed = await fx.readSummary(second);
    assert.deepEqual(resumed.steps.map(step => step.status),
      ['skipped-resume', 'skipped-resume', 'skipped-resume', 'ok', 'ok', 'ok']);
    assert.equal(fx.calls.filter(call => call.command === 'python3' && call.args[0].endsWith('build.py')).length, 1, 'package must not repeat');
    assert.equal(fx.calls.filter(call => call.command === 'python3' && call.args[0].endsWith('verify.py')).length, 1, 'verification must not repeat');
    assert.equal(fx.calls.filter(call => call.command === 'gh' && call.args[1] === 'create').length, 2);
  } finally {
    await fx.cleanup();
  }
});

test('a dry-run record cannot back an execute resume and a failed step cannot be skipped', async () => {
  const fx = await fixture();
  try {
    const planned = await fx.run([`--tag=${TAG}`]);
    assert.equal(planned.exitCode, 0);
    const attempted = await fx.run([`--tag=${TAG}`, '--execute', '--resume-from=package']);
    assert.equal(attempted.exitCode, 1, fx.outputs.join('\n'));
    assert.match(fx.outputs.join('\n'), /HARD STOP \[verification\] resume-planned-only/);
    assert.equal(fx.sideEffects().length, 0);
  } finally {
    await fx.cleanup();
  }
  const failing = await fixture({verificationExit: 1, verificationReport: {
    status: 'failed', source_commit: 'c'.repeat(40), gates: [{gate: 'a', passed: true}, {gate: 'broken', passed: false, failure_reason: 'engine-error'}],
  }});
  try {
    const first = await failing.run([`--tag=${TAG}`, '--execute']);
    assert.equal(first.exitCode, 1);
    const summary = await failing.readSummary(first);
    assert.equal(summary.steps.at(-1).error.code, 'verification-failed');
    const resumed = await failing.run([`--tag=${TAG}`, '--execute', '--resume-from=package']);
    assert.equal(resumed.exitCode, 1);
    assert.match(failing.outputs.join('\n'), /HARD STOP \[verification\] resume-after-failure/);
  } finally {
    await failing.cleanup();
  }
});

test('a failing hosted verification is a hard stop and the branch is not pushed', async () => {
  const fx = await fixture({conclusion: 'failure'});
  try {
    const result = await fx.run([`--tag=${TAG}`, '--execute']);
    assert.equal(result.exitCode, 1);
    const summary = await fx.readSummary(result);
    assert.equal(summary.steps.at(-1).step, 'verify');
    assert.equal(summary.steps.at(-1).error.code, 'hosted-verify-failed');
    assert.equal(fx.sideEffects().some(call => call.command === 'git' && call.args[0] === 'push'), false);
    assert.equal(summary.steps.at(-1).error.detail.conclusion, 'failure');
    assert.ok(summary.steps.at(-1).error.detail.run_url.endsWith('/4242'));
  } finally {
    await fx.cleanup();
  }
});

test('stop-after resumes cleanly, and push is refused until a hosted run succeeds', async () => {
  const fx = await fixture({conclusion: 'failure'});
  try {
    const partial = await fx.run([`--tag=${TAG}`, '--execute', '--verification=always', '--stop-after=publish']);
    assert.equal(partial.exitCode, 2, fx.outputs.join('\n'));
    assert.equal((await fx.readSummary(partial)).status, 'stopped-after-publish');

    // The hosted verification never ran, so a resume at push has nothing to stand on.
    const unreached = await fx.run([`--tag=${TAG}`, '--execute', '--resume-from=push']);
    assert.equal(unreached.exitCode, 1);
    assert.match(fx.outputs.join('\n'), /HARD STOP \[verify\] resume-missing-record/);

    // A failed hosted run is a hard stop, and the branch is not pushed.
    const failed = await fx.run([`--tag=${TAG}`, '--execute', '--resume-from=verify']);
    assert.equal(failed.exitCode, 1);
    assert.equal((await fx.readSummary(failed)).steps.at(-1).error.code, 'hosted-verify-failed');
    assert.equal(fx.sideEffects().some(call => call.command === 'git' && call.args[0] === 'push'), false);

    // A failed verify record cannot back a later step either.
    const blocked = await fx.run([`--tag=${TAG}`, '--execute', '--resume-from=push']);
    assert.equal(blocked.exitCode, 1);
    assert.match(fx.outputs.join('\n'), /HARD STOP \[verify\] resume-after-failure/);

    fx.world.conclusion = 'success';
    const completed = await fx.run([`--tag=${TAG}`, '--execute', '--resume-from=verify']);
    assert.equal(completed.exitCode, 0, fx.outputs.join('\n'));
    assert.equal(fx.sideEffects().filter(call => call.command === 'git' && call.args[0] === 'push').length, 1);
  } finally {
    await fx.cleanup();
  }
});

test('resume without earlier records refuses and never invents state', async () => {
  const fx = await fixture();
  try {
    const result = await fx.run([`--tag=${TAG}`, '--resume-from=verify']);
    assert.equal(result.exitCode, 1);
    assert.match(fx.outputs.join('\n'), /HARD STOP \[preflight\] resume-missing-record/);
    assert.equal(fx.sideEffects().length, 0);
  } finally {
    await fx.cleanup();
  }
});

test('every run is appended, never overwritten, and keeps its own evidence', async () => {
  const fx = await fixture();
  try {
    const first = await fx.run([`--tag=${TAG}`, '--stop-after=verification']);
    assert.equal(first.exitCode, 2);
    const second = await fx.run([`--tag=${TAG}`, '--resume-from=package']);
    assert.equal(second.exitCode, 0);
    const runs = (await readdir(join(fx.state, 'runs'))).sort();
    assert.equal(runs.length, 2);
    for (const run of runs) {
      assert.ok(existsSync(join(fx.state, 'runs', run, 'summary.json')));
      assert.ok(existsSync(join(fx.state, 'runs', run, 'release.log')));
      const summary = JSON.parse(await readFile(join(fx.state, 'runs', run, 'summary.json'), 'utf8'));
      assert.equal(summary.tag, TAG);
      assert.equal(summary.kind, 'cocs-release-run');
    }
    const marker = JSON.parse(await readFile(join(fx.state, 'state.json'), 'utf8'));
    assert.equal(marker.tag, TAG);
    assert.equal(marker.kind, 'cocs-release-state');
  } finally {
    await fx.cleanup();
  }
});
