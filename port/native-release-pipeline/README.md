# Release pipeline lane

Owner objective: make the release path routine — one command from a frozen tree to a
verified published build. This lane delivered `tools/release/**` and rehearsed it against
the current checkout, recording every run under `evidence/`.

## What shipped

| Path | Purpose |
|---|---|
| `tools/release/release.mjs` | the six-step pipeline (preflight, verification, package, publish, verify, push) |
| `tools/release/options.mjs` | argument parsing, defaults, `--help` |
| `tools/release/options.test.mjs` | 6 argument tests |
| `tools/release/release.test.mjs` | 17 state-machine tests with an injectable stub runner |
| `tools/release/README.md` | usage, safety model, state layout, manual fallback, what is not yet exercised |

The pipeline calls `tools/godot-dev/verify.py` and `tools/godot-package/build.py` and
modifies neither. `tools/godot-dev/verify.py` stays lead-owned: the release lane runs it
with the pinned environment (`GODOT_BIN`, `PORT=0`, `TMPDIR=/tmp/opencode`) and redirects
`XDG_*` into its own state directory, so the checkout is left as it was found.

## The manual sequence it replaces

`port/combat-expansion/RELEASE_CHECKLIST.md` describes five manual phases: frozen-tree
verification, Windows build, hosted verification, manual smoke, publication. The
pipeline automates phases 1–3 and 5 with the ordering, refusals and records the
checklist implies, and adds the freeze, tag and resume discipline the manual flow only
had in prose:

1. `preflight` — one frozen commit, pinned Godot, SHA-512-verified toolchain archives,
   free tag/release, notes and title, publication remote and tag-target plan.
2. `verification` — the 138-gate aggregate, exit 0 required.
3. `package` — `build.py --target windows --operator-models source-operators` into a
   fresh state directory, with the archive, sidecar and manifest independently re-hashed.
4. `publish` — prerelease with the ZIP and its `.sha256`, refusing an existing tag or release.
5. `verify` — `windows-demo.yml` dispatched with the tag and watched to completion.
6. `push` — the frozen commit pushed to the publication branch only after a passing run.

## Evidence

Every file under `evidence/` is a real run against this checkout, not a fixture.

| File | Proves |
|---|---|
| `unit-tests.log` | 23 tests pass (6 argument, 17 state machine) with the runner stubbed |
| `dry-run-worktree-console.log`, `dry-run-state-runs/` | the full six-step dry run: real preflight (HEAD, toolchain hashes, free tag), steps 2–6 printed and skipped, in 2.1 s, no side effect |
| `dry-run-primary-*.log` | the same dry run on the primary working tree (see the note below) |
| `refusal-dirty-tree.log`, `.json`, `-console.log` | a real refusal: two lanes' uncommitted runtime files stopped preflight before any side effect |
| `refusal-existing-tag.*` | a real refusal: the published `combat-expansion-2026-09-22` tag/release is never reused |
| `refusal-tag-behind-head-console.log`, `refusal-tag-behind-head-state-runs/` | an `--execute` refusal because the frozen commit is not on the publication remote yet; it must be pushed first or tagged deliberately with `--allow-tag-behind-head` |
| `refusal-verification-failed-state-runs/` | a real gate failure (`gltf-sides` in a fresh worktree without `node_modules`) hard-stopped the pipeline with the failing gate named |
| `refusal-command-timeout-*` | a real hard stop: the rehearsal caught `--verify-timeout` reaching the process layer as milliseconds |
| `package-rehearsal-console.log`, `-state-runs/` | the real verifier and the real builder: 138/138 gates, ZIP + sidecar + manifest re-hashed, port commit checked, then a dry-run resume from `publish` |
| `run-dry-run.sh`, `run-package-rehearsal.sh` | the exact driver scripts, so every record can be reproduced |

### What the rehearsal found

Three real defects were found by running the pipeline rather than only testing it, and
all three are fixed and covered by tests:

1. `--verify-timeout`/`--package-timeout` were passed to the process layer as
   milliseconds instead of seconds, so the verifier was killed after 3.6 s. The exact
   hard stop is preserved in `refusal-command-timeout-*`.
2. The git status parser trimmed the leading space of ` M path`, so the first dirty path
   in the refusal message was corrupted. Covered by tests that assert the named path.
3. A `--target=linux` release would have created the release and then used the Windows
   verification workflow and asset names. It now refuses at preflight unless a workflow
   is named explicitly or the run stops deliberately after `publish`.

### Where the rehearsal ran, and why

The primary checkout carried other lanes' in-flight runtime files
(`godot/world/combat_quality.gd`, `port/native-horde/authority.mjs`, benchmark and
identity sources) for the whole rehearsal window. The pipeline is required to refuse
that, and did: `refusal-dirty-tree*` is that real refusal. The end-to-end rehearsal
therefore ran from a clean worktree of the same commit
(`git worktree add --detach /tmp/opencode/cocs-release-rehearsal <HEAD>`), which is the
same frozen tree with nothing uncommitted. The worktree needed a `node_modules`
symlink to the primary's dependency tree, because a fresh worktree has none — that is
what `refusal-verification-failed-state-runs/` records — and the final rehearsal ran
with it in place.

## Honest limits

- No release was created, no workflow dispatched and nothing pushed by this lane. Steps
  4–6 are proven by tests and by dry-run plans, not by a live publication. Their first
  live use should be watched by the owner.
- The hosted workflow checks out the remote branch, not the frozen commit, so step 5
  proves the published asset rather than the branch bytes; the branch is pushed after it
  by design, and the pipeline records when the two differ.
- `--target=linux` has no pinned hosted workflow in this repository; the pipeline
  refuses to guess one.
- The pipeline is the same code path the manual checklist describes; if `gh` is
  unavailable, `tools/release/README.md` lists the exact commands to run by hand.

## Next release, in one command

```sh
# rehearsal (no side effects)
node tools/release/release.mjs --tag=<new-tag>

# the real run, from a frozen tree
node tools/release/release.mjs --tag=<new-tag> --execute
```

If the frozen commit is not yet on `godot/main`, either push it first or pass
`--allow-tag-behind-head`. If a step fails, the printed hint names the exact
`--resume-from=<step> --state=<dir>` continuation.
