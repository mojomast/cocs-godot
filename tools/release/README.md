# Release pipeline

One command from a frozen tree to a verified published build:

```sh
node tools/release/release.mjs --tag=<new-tag>            # dry run: plans every step
node tools/release/release.mjs --tag=<new-tag> --execute  # performs the six steps
```

Six ordered steps, each with a hard stop and a machine-readable record:

| # | Step | What it does | Hard stop on |
|---|---|---|---|
| 1 | `preflight` | records HEAD, proves the tree is frozen, checks `GODOT_BIN` against the source lock, SHA-512-verifies the pinned toolchain archives, proves the tag/release do not exist, reads the notes file and title, parses the publication remote | dirty tracked files, untracked **runtime** files, lane-owned build state inside the checkout, version or archive mismatch, an existing tag or release, a notes file with no title, a publication remote whose frozen commit is missing (execute mode) |
| 2 | `verification` | generates the GLB probes the verifier imports when a fresh checkout lacks them (the same `browser-export.mjs` calls as the hosted Linux workflow), then runs `python3 tools/godot-dev/verify.py` with `GODOT_BIN`, `PORT=0`, `TMPDIR=/tmp/opencode` and `XDG_*` redirected into the state dir | any non-zero exit, a `status != passed` report, or any failing gate |
| 3 | `package` | `python3 tools/godot-package/build.py --target <target> --operator-models source-operators` with a fresh state directory | builder failure, a re-hashed archive that disagrees with the builder, a mismatched `.sha256` sidecar or manifest, a recorded port commit that is not the frozen HEAD |
| 4 | `publish` | `gh release create <tag> <archive> <archive>.sha256 --prerelease --notes-file ...` | an existing tag or release, changed archive bytes, missing assets after creation, a release that is not a prerelease |
| 5 | `verify` | `gh workflow run windows-demo.yml -f tag=<tag>`, then polls the newest matching `workflow_dispatch` run to completion | dispatch failure, no run appearing within the timeout, any conclusion other than `success`, a run still going at the timeout |
| 6 | `push` | `git push <publication-remote> <frozen-commit>:refs/heads/<publish-branch>` | a hosted run that has not succeeded, a non-fast-forward update that was not explicitly allowed |

## Safety model

- **Dry run by default.** `build.py`, `gh release create`, `gh workflow run` and
  `git push` are printed and skipped unless `--execute` is passed. Read-only probes
  (git, `gh release view`, archive hashing, the pinned Godot `--version`) always run,
  so a dry run fails for the same reasons an execute run would until the first side
  effect.
- **Nothing is deleted or overwritten.** The state directory is append-only:
  `state.json` is written once, every invocation adds `runs/<run-id>/summary.json`,
  `release.log`, `steps/*.json` and `logs/*.log`, and an existing unowned directory is
  refused. An existing tag or release is always refused.
- **One frozen commit.** Preflight records HEAD; every later step re-checks HEAD and the
  tracked tree before acting, and refuses to continue if the tree moved. The push pushes
  the recorded commit, not whatever the branch happens to be. A detached HEAD (a tag or
  CI checkout) is accepted and recorded with a warning; naming a branch with `--branch`
  and then being detached is refused.
- **Resume, never restart.** `--resume-from=<step>` reloads the earlier step records from
  the state directory. A step can only back a continuation when it actually ran: a
  dry-run record cannot back an `--execute` resume, a failed record cannot be skipped,
  and `--verification=never` cannot be resumed past.
- **Exit codes.** `0` success, `1` hard stop, `2` stopped after `--stop-after`.

### What is deliberately strict

- Tracked files must be committed. The only exempt path is `port/reports/**`, because
  `verify.py` rewrites its own gate reports; every exempt modification is listed in the
  step record.
- Untracked files under `godot/`, `game/`, `server/`, `port/`, `tools/`, `package.json`
  or `package-lock.json` refuse the run (they could enter the build closure or the
  recorded worktree status) — except `port/**/evidence/**`, `port/reports/**` and
  `port/handoffs/**`, which are recorded and warned about but cannot be shipped:
  they are not in the build closure and the builder independently refuses uncommitted
  runtime bytes. `port/handoffs/procedural-model-generation-llm-research.md` is
  allow-listed by default; add more with `--allow-untracked=<path>`. Untracked files
  anywhere else are also recorded and warned about, never silently ignored.
- A build state marker (`.cocs-package-state`, `.cocs-release-state`, `cocs-release-*`,
  `cocs-rebuild-*`, `cocs-package-*`) anywhere inside the checkout refuses the run.
- `godot/content/**` is gitignored, and the aggregate verifier imports two GLB probes
  from it (`content/probes/axis-weapon/world.glb`, `content/probes/meridian-exchange/world.glb`).
  A fresh clone therefore cannot pass `verify.py` on its own: the hosted Linux workflow
  generates those probes first, and the verification step does the same before running
  the aggregate. That needs the locked `npm ci` dependencies and a Playwright Chromium
  (`npx playwright install chromium`); `PLAYWRIGHT_BROWSERS_PATH` is honoured, and the
  host's `$HOME/.cache/ms-playwright` is used when it exists. `--prepare=never` skips
  generation and lets the `glb-import` gate fail. The generated bytes are gitignored, so
  the tracked tree stays frozen.
- `gh` must be authenticated (`gh auth status`) with `workflow` and `repo` scopes: the
  pipeline creates the prerelease and dispatches the hosted workflow.

## Options

```sh
node tools/release/release.mjs --tag=<tag> \
  [--target=windows|linux] [--notes-file=<path>] [--title=<title>] \
  [--state=<dir>] [--godot-bin=<path>] [--archive-directory=<dir>] \
  [--publication-remote=godot] [--publish-branch=main] [--branch=<name>] \
  [--repository=<owner/repo>] [--workflow=windows-demo.yml] [--workflow-ref=<ref>] \
  [--push-ref=<src>:<dst>] [--resume-from=<step>] [--stop-after=<step>] \
  [--verification=auto|always|never] [--prepare=auto|never] \
  [--verify-timeout=<s>] [--package-timeout=<s>] \
  [--hosted-timeout=<s>] [--poll-seconds=<s>] [--allow-untracked=<path>] \
  [--allow-tag-behind-head] [--allow-non-fast-forward] [--execute] [--help]
```

`--help` prints the same list with the defaults. The important ones:

- `--state` (default `/tmp/opencode/cocs-release-<tag>`) must live outside the checkout
  and is never reused by a second release.
- `--verification=always` rehearses `verify.py` even in a dry run (about six minutes
  here). The default `auto` runs it only with `--execute`.
- `--stop-after=<step>` rehearses a partial run and exits 2. Its records are complete,
  so `--resume-from=<next-step>` continues exactly there.
- `--allow-tag-behind-head` publishes when the frozen commit is **not** yet on the
  publication remote. Without it that situation is refused, because the release tag
  would otherwise point at the previously published branch head instead of the frozen
  commit. The checkout's current state matters: `godot/main` is one commit behind the
  local release branch, so the next release either pushes the branch before publishing
  or passes this flag and tags the published head.

## Layout of the state directory

```
/tmp/opencode/cocs-release-<tag>/
  state.json                     written once: schema, tag, creation time
  package-state/                 build.py's own state (its marker, builds/<ns>/...)
  runs/<timestamp>-<pid>/
    summary.json                 machine-readable run summary (steps, status, exit code)
    release.log                  full console transcript for that run
    steps/01-preflight.json …    one record per step: status, timing, commands, detail
    logs/01-preflight.json …     raw subprocess output per step
    evidence/                    verification.json, manifest.json, archive.sha256, build result
    runtime/                     XDG data/config/cache for the verification run
```

Every step record lists the exact commands with `executed`, `planned`, `exit_code` and
`duration_seconds`, so a dry-run plan and a real run are directly comparable.

## Manual fallback

The pipeline automates exactly the steps in
`port/combat-expansion/RELEASE_CHECKLIST.md`. If it cannot run (for example `gh` is
unavailable), the manual sequence is:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export PORT=0 TMPDIR=/tmp/opencode
python3 tools/godot-dev/verify.py                    # must print all gates passed, exit 0
python3 tools/godot-package/build.py --target windows \
  --state /tmp/opencode/cocs-rebuild-<date> \
  --archive-directory /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain
# record the printed archive, size, SHA256, manifest SHA256 and port commit
gh release create <tag> <archive> <archive>.sha256 --repo mojomast/cocs-godot \
  --title "<title>" --notes-file port/combat-expansion/RELEASE_NOTES.md --prerelease --target <commit>
gh workflow run windows-demo.yml --repo mojomast/cocs-godot -f tag=<tag>
gh run watch <run-id> --repo mojomast/cocs-godot
git push godot <frozen-commit>:refs/heads/main
```

The pipeline adds no behaviour of its own beyond ordering, freezes, refusals and the
records; every manual command above is exactly what a step runs.

## Tests

```sh
node --test tools/release/options.test.mjs tools/release/release.test.mjs
```

The pipeline's dangerous calls go through an injectable runner, so the tests exercise
the full state machine — dry-run suppression, the dirty-tree and existing-tag refusals,
resume after a failed publish, resume refusals, hosted-verification failure, push
gating, append-only state — without touching git, GitHub or the builder. The real
`gh`/`git` invocations only happen behind `--execute` in `release.mjs`.
### What has not been exercised for real

- Steps 3–6 have never been run against live infrastructure: no release was created,
  no workflow dispatched and nothing was pushed by this tool yet. Their commands are
  asserted by tests and printed by dry runs, and steps 4–6 are refusals-first by
  construction. The first real release should be run with the owner watching
  `gh run watch` and the release URL.
- `--verification=always` was exercised (see `port/native-release-pipeline/`), so the
  verifier wiring, log capture and gate parsing are proven against the real checkout.
- The hosted workflow checks out the *remote* branch while the tag points at the release
  asset, so step 5 verifies the published artifact, not the local branch bytes. The
  pipeline records `remote_head_matches` and warns when the checkout lags the frozen
  commit; the branch is pushed only afterwards, by design.
