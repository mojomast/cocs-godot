# Fresh checkout and native CI

The native workflow starts from repository history, locked npm dependencies,
the official pinned Linux editor, and newly generated content. Its entry point
is [`.github/workflows/godot-native.yml`](../../.github/workflows/godot-native.yml).

## Reproduce on Linux x86_64

Requirements: Git, Bash, curl, `sha256sum`, Python 3, Node.js 22.13+ and npm.
CI uses Ubuntu 24.04 and Node 22. Playwright's `--with-deps` installs Chromium's
OS libraries and may request sudo on a developer machine.

```bash
git clone https://github.com/mojomast/cocs-godot.git
cd cocs-godot
# Optionally: git checkout <commit-under-test>
# A normal clone has the history required by the source and evidence gates.

state="$(mktemp -d "${TMPDIR:-/tmp}/cocs-native-ci.XXXXXX")"
bash tools/godot-dev/ci_bootstrap.sh "$state"
source "$state/environment.sh"
npm ci
npx --no-install playwright install --with-deps chromium

node tools/godot-export/semantic.mjs
node tools/godot-export/browser-export.mjs
node tools/godot-export/browser-export.mjs meridian-exchange

# verify.py performs the headless editor import before its native test gates.
python3 tools/godot-dev/verify.py
git diff --check

# Optional interactive native session after successful verification:
PORT=0 node tools/godot-dev/launch.mjs --play --setup
```

For an explicit import-only diagnosis, after the three exports run:

```bash
"$GODOT_BIN" --headless --path godot --editor --import
```

Keep `state` outside the checkout and retain it while diagnosing failures. The
helper downloads the exact archive every time, checks its pinned SHA256 before
extracting the named executable, sets mode 0755, then requires
`4.5.2.stable.official.6ce3de25a`. The hash comes from the official GitHub release
asset's SHA256 digest and was independently checked against the official
SHA512 manifest; [toolchain provenance](evidence/toolchain.json) records both.
No machine-local editor is selected implicitly. Linux export templates are not
needed for these editor/headless gates.

## Fresh-checkout dependencies and paths

- **Full Git history:** `semantic.mjs` checks ancestry and locked source against
  `51289b79c627a26a381ba556b92bab71f93f3732`; health evidence tests also read
  historical files via `git show fe29ac3:...`. A source ZIP or shallow checkout
  cannot satisfy those checks. For an existing shallow clone, first run
  `git fetch --unshallow`. Actions uses `fetch-depth: 0`.
- **Ignored GLB probes:** `godot/tests/import.gd` requires
  `godot/content/probes/axis-weapon/world.glb` and
  `godot/content/probes/meridian-exchange/world.glb`. Semantic export alone
  creates neither. Run both existing `browser-export.mjs` commands above.
  They use locked Vite, Three.js, and Playwright/Chromium to convert source
  content into native import fixtures. This browser is a build dependency of
  the native verifier; the workflow does not run the web application suite.
- **Clean Godot data:** a fresh clone has no `godot/.godot`, generated semantic
  content, or GLB probes. Create a new checkout to repeat the clean-import test.
  Never copy `.godot` from another machine as a bootstrap step.
- **npm dependencies:** use `npm ci`, including development dependencies. Native
  loopback authority gates need `ws`; GLB generation needs the locked export
  tooling. `npm run build` is the web/deployment build and is not part of this
  path. A local dependency symlink is not proof of a fresh install.
- **Owned runtime:** the helper supplies absolute `GODOT_BIN`, `TMPDIR`,
  `PLAYWRIGHT_BROWSERS_PATH`, all three XDG homes, and a mode-0700
  `XDG_RUNTIME_DIR`, with `PORT=0`. Loopback servers choose free ports.
  `launch.mjs` and `two-clients.mjs` override the three XDG homes with the
  checkout's ignored `.port-runtime` directories; this is expected and remains
  isolated in a fresh checkout. Source the environment file in each new shell.
- **Other demo helpers:** `GUEST_NODE_MODULES` is set to this checkout's
  `node_modules` for helpers that use a temporary project. Some graphical
  evidence/demo helpers outside this workflow hard-code `/tmp/opencode` and
  need Xvfb. The combined verifier and its required GLB exporters do not require
  that machine-specific directory or a desktop/Xvfb.

## Workflow boundaries and evidence

The integrated snapshot now has an independently observed successful
[GitHub-hosted 50-gate run](../reports/native-ci-hosted/README.md). The original
agent's local fresh-checkout evidence below remains scoped to its earlier base.

Triggers are pushes to `main`, pull requests, and manual dispatch. Permissions
are `contents: read`; checkout does not persist credentials. The job has a
30-minute timeout, and a newer run cancels an older run on the same ref.
Checkout/setup-node retain the existing workflow's `@v4` versions;
upload-artifact uses the supported `@v4` major.

The final steps attempt `git diff --check` and upload evidence on success or
failure. Each artifact contains at most 80 current-run files of at most 128 KiB
each (10 MiB plus the small manifest), retained for seven days. Oversized files
are clearly named `*.tail.txt`, and the manifest records original sizes and
truncation. Historical tracked reports are excluded by the run start marker;
the upload does not include caches, generated content, dependency trees, or
downloaded binaries. Setup failure logs are included even before native gates
start. Runner termination or a hard job timeout can prevent finalization.

`port/reports/verification.json` describes the implemented gates; successful
execution does not establish complete gameplay or visual acceptance. For
observed local results and the distinction from a hosted Actions run, see
[validation evidence](evidence/README.md).

## Suggested root README addition (unapplied)

Add after the **Verification** heading:

> For a fresh clone, follow the [native CI bootstrap](port/native-ci/README.md)
> first. Verification needs full Git history and both generated GLB probes in
> addition to semantic map export. The bootstrap pins and checks the official
> Godot editor and documents the required Chromium build dependency.
