# Observed validation — 2026-09-21 local / 2026-09-22 UTC

**Local fresh-worktree reproduction passed all 46 gates. No GitHub-hosted job
was run or observed.** The deliverable was not pushed.

## Checkout and environment

- Base: `aca52f5e33e211a6b6181e33eba41abca445f0fe`.
- Isolated worktree: `/tmp/opencode/cocs-native-ci-aca52f5`, branch
  `agent/native-ci-aca52f5`, with full local repository history.
- Bootstrap state: `/tmp/opencode/cocs-native-ci-state`.
- Host: Ubuntu 25.10 x86_64; Node `v22.23.1`, npm `10.9.8`, Python `3.13.7`.
- `npm ci` actually ran and installed 630 packages; no dependency symlink or
  shared `node_modules` was used. The registry was `https://registry.npmjs.org/`,
  scripts were enabled, and no dependency groups were omitted. The repository's
  `.npmrc` uses `.sites-runtime/npm-cache` and disables audit/fund output.
- The bootstrap downloaded the official editor itself. Its archive SHA256 and
  extracted executable SHA256 are in [toolchain.json](toolchain.json).
- Playwright 1.55.0 downloaded Chromium `140.0.7339.16`, build 1187, into the
  isolated state directory. On this Ubuntu 25.10 host it selected its Ubuntu
  24.04 fallback. Local OS libraries were already present, so the local command
  was `npx --no-install playwright install chromium`. The workflow's
  `--with-deps` Ubuntu 24.04 package installation has not been exercised here.

The worktree was created using:

```bash
git worktree add -b agent/native-ci-aca52f5 \
  /tmp/opencode/cocs-native-ci-aca52f5 aca52f5
```

## Preserved failure and successful correction

The initial run used the new official toolchain and fresh npm install, with no
generated content copied from another workspace:

```bash
npm ci
bash tools/godot-dev/ci_bootstrap.sh /tmp/opencode/cocs-native-ci-state
source /tmp/opencode/cocs-native-ci-state/environment.sh
npx --no-install playwright install chromium
python3 tools/godot-dev/verify.py
```

It exited **1** at `glb-import`, reporting:

```text
ERROR: Can't open file at path "res://content/probes/axis-weapon/world.glb"
ERROR: GLB import failed: axis-weapon
```

See [the output](fresh-without-glb-probes.log) (final blank line trimmed; raw
output is in the archive) and
[the failed gate report](fresh-without-glb-probes.json). This was a real
fresh-checkout dependency failure, not a synthetic test.

After preserving the failure, only this worktree's newly created
`godot/.godot` and `godot/content/generated` were removed;
`godot/content/probes` was confirmed absent. Then:

```bash
source /tmp/opencode/cocs-native-ci-state/environment.sh
node tools/godot-export/semantic.mjs
node tools/godot-export/browser-export.mjs
node tools/godot-export/browser-export.mjs meridian-exchange
python3 tools/godot-dev/verify.py
git diff --check
```

All commands exited **0**. The verifier imported the fresh native project and
passed **46/46** gates in **84.616 seconds** of summed gate runtime. Its stdout
prints 44 gate lines; the JSON also includes the toolchain version and
release-refusal checks. See [verification.json](verification.json),
[verify.log](verify.log), and [reproduction.json](reproduction.json), including
hashes of the dependency lock, generated manifest, both GLBs, and log archive.

The root clone/export/import/verify recipe is in [the parent guide](../README.md).
The successful run did not use a supplied editor or preexisting GLB/cache data.

## Workflow/helper checks

- `actionlint` **1.7.7** accepted `.github/workflows/godot-native.yml`.
- PyYAML **6.0.2** parsed the YAML; assertions confirmed `main`-only pushes,
  read-only contents permission, full checkout history, and the 30-minute limit.
- `bash -n tools/godot-dev/ci_bootstrap.sh` and Python compilation passed.
- The real bootstrap succeeded, checked the official SHA256, restored executable
  permissions, and observed the exact version string.
- An explicitly synthetic corrupt-download test replaced only `curl` in a
  private temporary PATH. The unchanged bootstrap exited **1** on the SHA256
  mismatch, without extracting an executable or publishing an environment file.
- A relative-state-path rejection also exited **1** as expected.
- A synthetic artifact test supplied 81 oversized files: the collector retained
  exactly 80 tails of 128 KiB, retained their terminal bytes, and recorded one
  omitted file plus truncation metadata. Its private test directory was removed.
- `git diff --check` passed after verification. Tracked generated reports were
  preserved under this evidence directory and then restored in the isolated
  worktree so the deliverable contains only the assigned new paths.
  Staging the evidence exposed a final blank line in the copied failure log;
  that display copy was trimmed before the final staged whitespace check.

Command outputs are retained in [checks.log](checks.log). These checks validate
the configuration and local behavior; they do not establish hosted Actions
success or full visual/gameplay acceptance.

## Retained logs

[verification-logs.tar.gz](verification-logs.tar.gz) contains the collector's
actual bounded artifact: **58 files**, none omitted or truncated. It includes
the current run's gate logs and reports, download/bootstrap output, fresh npm
install output, Chromium download output, export logs, and the clearly labeled
initial missing-probes failure. The 16,642-byte archive contains only logs and
reports; `artifact/manifest.json` lists the original sizes and truncation flags.
Inspect without extracting:

```bash
tar -tzf port/native-ci/evidence/verification-logs.tar.gz
tar -xOzf port/native-ci/evidence/verification-logs.tar.gz artifact/manifest.json
```

Absolute `/tmp/opencode/...` paths in these records describe this observed local
run. The workflow instead uses `$RUNNER_TEMP/godot-native` and requires no
machine-local path or credentials.
