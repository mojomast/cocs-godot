# Release pipeline lane

Owner objective: make the release path routine — one command from a frozen tree to a
verified published build. This lane delivered `tools/release/**` and recorded the
rehearsals in `evidence/`.

## What shipped

| Path | Purpose |
|---|---|
| `tools/release/release.mjs` | the six-step pipeline (preflight, verification, package, publish, verify, push) |
| `tools/release/options.mjs` | argument parsing, defaults, `--help` |
| `tools/release/options.test.mjs` | 6 argument tests |
| `tools/release/release.test.mjs` | 14 state-machine tests with an injectable stub runner |
| `tools/release/README.md` | usage, safety model, state layout, manual fallback, what is not yet exercised |

The pipeline calls `tools/godot-dev/verify.py` and `tools/godot-package/build.py` and
modifies neither. `tools/godot-dev/verify.py` remains lead-owned; the release lane only
runs it with the pinned environment (`GODOT_BIN`, `PORT=0`, `TMPDIR=/tmp/opencode`) and
redirects `XDG_*` into its own state directory so the checkout stays clean.

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

| File | Proves |
|---|---|
| `evidence/unit-tests.log` | all 20 tests pass (argument parsing, dry-run suppression, refusals, resume, hosted-verify failure, push gating, append-only state) |
| `evidence/dry-run-console.log` + `dry-run-*.txt` + `state-runs/` | the end-to-end dry run on the frozen checkout, with its own step records and summary |
| `evidence/refusal-dirty-tree*` | a real refusal: two lanes' uncommitted runtime files blocked preflight before any side effect |
| `evidence/refusal-existing-tag*` | a real refusal: the published `combat-expansion-2026-09-22` tag/release cannot be reused |
| `evidence/resume-*` | a resume after a partial run, from its own records only |
| `evidence/package-rehearsal-*` | (when exercised) the real builder path: verification, package hashes, manifest and port commit |

## Honest limits

- No release was created, no workflow dispatched and nothing pushed by this lane. Steps
  4–6 are proven by tests and by dry-run plans, not by a live publication. Their first
  live use should be watched by the owner.
- The hosted workflow checks out the remote branch, not the frozen commit, so step 5
  proves the published asset rather than the branch bytes; the branch is pushed after it
  by design and the pipeline records when the two differ.
- The pipeline is the same code path the manual checklist describes; if `gh` is
  unavailable, `tools/release/README.md` lists the exact commands to run by hand.
