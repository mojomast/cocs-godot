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
| `tools/release/release.test.mjs` | 18 state-machine tests with an injectable stub runner |
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
| `unit-tests.log` | 24 tests pass (6 argument, 18 state machine) with the runner stubbed |
| `dry-run-worktree-console.log`, `dry-run-state-runs/` | the full six-step dry run: real preflight (HEAD, toolchain hashes, free tag), steps 2–6 printed and skipped, in 2.1 s, no side effect |
| `dry-run-final-console.log`, `dry-run-final-state-runs/` | the last dry run, on the final lane commit `37b1151c`: all six steps, five planned and skipped, exit 0 |
| `dry-run-primary-outcome.txt` | why the primary-checkout dry run could not be captured: no frozen window existed (16 modified files, 1252 untracked paths at the end), and refusing that tree is the required behaviour |
| `refusal-dirty-tree.log`, `.json`, `-console.log` | a real refusal: two lanes' uncommitted runtime files stopped preflight before any side effect |
| `refusal-existing-tag.*` | a real refusal: the published `combat-expansion-2026-09-22` tag/release is never reused |
| `refusal-tag-behind-head-console.log`, `refusal-tag-behind-head-state-runs/` | an `--execute` refusal because the frozen commit is not on the publication remote yet; it must be pushed first or tagged deliberately with `--allow-tag-behind-head` |
| `refusal-verification-failed-state-runs/` | a real gate failure (`gltf-sides` in a fresh worktree without `node_modules`) hard-stopped the pipeline with the failing gate named |
| `refusal-command-timeout-*` | a real hard stop: the rehearsal caught `--verify-timeout` reaching the process layer as milliseconds |
| `probe-generation-failures-state-runs/` | the three probe-generation failures that exposed finding 4: `glb-import` missing probes, then Chromium absent for the locked Playwright revision, then the redirected `XDG_CACHE_HOME` hiding it |
| `hosted-query-probe.log` | read-only proof that step 5's `gh run list`/`gh run view` fields match the real API; it also shows the last release needed three dispatches (two failures, then success), which is exactly what `--resume-from=verify` is for |
| `package-rehearsal-console.log`, `-state-runs/` | the real thing: **138/138 gates** in 424 s (both GLB probes generated first), a **76.13 MiB** Windows ZIP whose SHA-256, sidecar and manifest were re-verified by the pipeline, the frozen port commit recorded, then a dry-run resume from `publish` that reused those records |
| `run-dry-run.sh`, `run-package-rehearsal.sh` | the exact driver scripts, so every record can be reproduced |

### The measured rehearsal, in numbers

From the frozen commit `0b12f97d` (checked out clean in a worktree), one `--execute` run
with `--stop-after=package`:

| Step | Result | Time |
|---|---|---|
| preflight | HEAD recorded, 1.42 GiB of toolchain archives SHA-512 verified, tag free | 2.7 s |
| verification | **138/138 gates passed**, exit 0, source `51289b79` | 424.3 s |
| package | `cocs-native-windows.zip` 79,827,738 bytes (76.13 MiB), SHA-256 `66aac17a…`, manifest SHA-256 `48884e86…`, port commit `0b12f97d…`, inputs `99f5c868…`, generated resources `c070b980…` | 26.7 s |

Then `--resume-from=publish` in the default dry run reused those three records — and
none of the earlier work repeated — before printing the `gh release create`,
`gh workflow run` and `git push` commands it deliberately did not run.

The built archive stays outside git in the release state directory
(`/tmp/opencode/cocs-release-<tag>/package-state/builds/<ns>/`); only its hashes are
recorded here, and it is regenerable from the same commit.

### What the rehearsal found

Four real defects were found by running the pipeline rather than only testing it; all
four are fixed and covered by tests.

1. `--verify-timeout`/`--package-timeout` were passed to the process layer as
   milliseconds instead of seconds, so the verifier was killed after 3.6 s. The exact
   hard stop is preserved in `refusal-command-timeout-*`.
2. The git status parser trimmed the leading space of ` M path`, so the first dirty path
   in the refusal message was corrupted. Covered by tests that assert the named path.
3. A `--target=linux` release would have created the release and then used the Windows
   verification workflow and asset names. It now refuses at preflight unless a workflow
   is named explicitly or the run stops deliberately after `publish`.
4. The aggregate verifier is not self-contained: it imports GLB probes under
   `godot/content/probes/`, which `.gitignore` excludes, so a clean checkout dies at the
   `glb-import` gate. The verification step now runs the same `browser-export.mjs` calls
   as `.github/workflows/godot-native.yml` before the aggregate (`--prepare=never` opts
   out), which is what makes "one command from a frozen tree" true on a fresh clone.
   `refusal-verification-failed-state-runs/` is the original failure that exposed it.

### Where the rehearsal ran, and why

The primary checkout carried other lanes' in-flight runtime files for the whole
rehearsal window — at the end it held 16 modified tracked files and 1252 untracked paths
(`godot/horde/**`, `godot/moth/**`, `godot/identity_maps/**`,
`godot/native_arenas/**`, `port/native-horde/**`, the benchmark and identity lanes).
A frozen tree never existed there, so the pipeline refused it — correctly.
`refusal-dirty-tree*` is that real refusal, and `dry-run-primary-outcome.txt` records
the wait and its outcome.

The end-to-end rehearsal therefore ran from a clean worktree of the same frozen commit
(`git worktree add --detach /tmp/opencode/cocs-release-rehearsal <HEAD>`), which is the
same tree with nothing uncommitted. The primary still exercised preflight's own checks
(git status parsing, tag/release lookup, remote reads) through the refusals; the
worktree exercised everything a dry run would add, plus a real verification and build.

The worktree needed a `node_modules` symlink to the primary's locked dependency tree,
because a fresh worktree has none — the `gltf-sides` failure that exposed it is in
`refusal-verification-failed-state-runs/`.

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

A staged first release is also supported and is what the rehearsal exercised:

```sh
node tools/release/release.mjs --tag=<new-tag> --execute --stop-after=package   # steps 1-3, then stop
node tools/release/release.mjs --tag=<new-tag> --resume-from=publish --execute  # publish, verify, push
```

## Recommendations for the lead

- Register `node --test tools/release/options.test.mjs tools/release/release.test.mjs`
  as an aggregate gate group, the way the other Node suites are registered. This lane
  could not add it: `tools/godot-dev/verify.py` is lead-owned and was not modified.
- `port/combat-expansion/RELEASE_CHECKLIST.md` still records the manual sequence; the
  pipeline is that sequence with freezes, refusals and records. If the checklist is
  kept, adding a pointer to `tools/release/README.md` avoids two sources of truth.
