# Cinematic M — native production and installed Home

**M RELEASED 2026-10-03T08:08:16.973785Z.** Grant
`CINEMATIC-NATIVE-20261003-M`; owner `ses_f03411df4ffeEk7157dyOo57NZ`.
Existing worktree `cocs-expansion-four-trailer-20261002`, branch
`expansion-four/trailer`, adopted parent `623127c5` including packaging `d5335f8b`.
No child agents. Production rehearsal, **not a frozen final-142 receipt**.

## Actual deliverables

Evidence root: `/home/mojo/.tmp-on-disk/cocs-cinematic-M-evidence-20261003`.
Successful immutable attempt: `attempt-02`, captured at source commit `966d6d86`.

- Movie: `attempt-02/edit/quiet-relay-trailer-v3.mp4` — 45,812,911 bytes,
  SHA256 `917452e507dde60081e298163659dccf442e4f8ea0814221f9437624345bb5e0`.
- Local movie URI:
  `file:///home/mojo/.tmp-on-disk/cocs-cinematic-M-evidence-20261003/attempt-02/edit/quiet-relay-trailer-v3.mp4`.
- Retained master: `attempt-02/edit/quiet-relay-v3-master.mkv` (H264 + PCM24).
  The producer's planned delivery is MP4; no WebM was encoded.
- Actual encoded cut sheet: `attempt-02/edit/cut-continuity.png`.
- Decoded one-second visual samples spanning the full movie:
  `technical-seconds-01.png`, `technical-seconds-02.png`, `technical-seconds-03.png`.
- Original native PNGs, source records, source clocks, per-frame PNG hashes,
  nonces and post-exit proofs: `attempt-02/<shot>/` for all 16 shots.
- Candidate menu: `attempt-02/menu-native/`, 98 checks, zero failures.
- Real installed Home: `attempt-02/menu-installed/`, 91 checks, zero failures,
  including screenshots at 1280×800 and compact 760×520/UI150.
- Atomic installation proof: `attempt-02/installation/installed.json`.

## Measurements and technical review

The full 75-second, four-chapter film contains **1,800 individually rendered
1280×720 frames**, delivered at 24 fps. Each shot has a unique PNG hash for every
frame. Explicit `LIBGL_ALWAYS_SOFTWARE=1`, `LP_NUM_THREADS=1`; actual measured
per-shot draw/save cadence is **1.805–2.687 fps**, not 24-fps real-time performance.
See `capture-cadence-summary.json` and original cadence ledgers.

Full audiovisual decode, duration, dimensions and delivery loudness checks passed.
Audio is stereo AAC, 48 kHz, 75.000 seconds; measured **−18.04 LUFS**, **−4.24 dBTP**,
**5.20 LU LRA**. Existing original Relay/Warden music-only edit; no live effects or
comms capture is claimed. Technical image review covered cut boundaries and one
decoded sample per second across all 75 seconds, plus full-size native subjects
and menu screenshots. Four chapter identities, scenery, Mara/Ivo gestures, Patch,
traversal, robots and Warden are visible. Rootfall traversal briefly passes close
to Mara around 16 seconds; preserve this observation for parent review. Original
routes, camera/story timing, cast and score were not rewritten to hide it.

**Human full-speed watch/listen and publication approval remain pending.** The
desktop browser was disconnected, so an in-app playable preview could not open.
The MP4 above is complete and ready for parent static publication/local playback.
Encoder success and sampled image inspection are not human listening approval.
K's live-kick timing failure and vehicle supplemental gap remain separate; this
staged film does not convert them into native live-game acceptance.

Home checks used all eight clips / four chapters and proved live viewport changes,
clip loop cleanup, foreground routes/focus, Settings pause/resume, reduced motion,
animation preference, focus loss, route-departure stop and scene teardown.
Installed mode loaded real Home's installed data without candidate injection.

## Preserved bytes and corrections

- Before menu SHA256:
  `fb8655a717380bb96bcc9968c1b70edc52b20c8008d56f14f63002bb29cf171e`.
- Installed menu SHA256:
  `4131d80e7c78008eee4a55b59f142798f4d78102300a83f99f9fcfdfc5c5a6c7`.
- Exact rollback bytes: `attempt-02/installation/preserved-before.json`;
  separate pre-production copy `menu-before-production.json`.
- v1 and v2 movie bytes were hashed before and rechecked after production:
  `preservation-before.json`; unchanged. Earlier galleries/captures untouched.
- All **116 tracked operator `.import` hashes remained unchanged**, before and
  after imports/capture/install. `operator-imports-before.json` retains the pins.
- Fresh Godot import created 679 untracked sidecars (376 `.uid`, 303 `.import`).
  Their exact hashes are in `generated-import-inventory.json`; they remain in the
  isolated worktree for reproducibility and are not part of the installed-menu
  commit. No compression retuning or pinned runtime corrections occurred.
- `a90462ff`: reuse existing TCP Xvfb helper / bounded subreaper, process receipts,
  three-audit release adapter, current operator event recipient.
- `f57576ba`: explicit WeakRef type in menu fixture after retained parser failure.
- `966d6d86`: hide interactive debug launcher in offline capture fixture.
  `attempt-01` was interrupted through its owned process after visual discovery;
  its actual frames/logs remain immutable. Attempt-02 is freshly prepared/captured.

## Execution and release

All production invocations used the nonwaiting shared lock
`/tmp/opencode/cocs-finish-acceptance.lock`. Native commands reuse
`xvfb_run.start_server(False)` (explicit TCP) and `finish_runner.run_bounded`;
no borrowed display or duplicate raw-Xvfb implementation. Godot was pinned to
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
Imports and parser checks preceded fresh preparation. Capture bounds were serial
30-minute shots / four-hour invocation; menu checks ten minutes; encoder commands
30 minutes each. Execution argv, deadlines, source/asset identity, process-group
ownership and logs are retained for successful and failed work.

`release.json` audits **72 retained PGIDs** and worktree/evidence ownership tags;
all three audits empty at 08:08:16.282229, 08:08:16.629836 and 08:08:16.973785 UTC.
Unowned observations are recorded separately; no unrelated processes signalled.

Exact production sequence (completed):

```sh
export LP_NUM_THREADS=1 LIBGL_ALWAYS_SOFTWARE=1
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
E=/home/mojo/.tmp-on-disk/cocs-cinematic-M-evidence-20261003/attempt-02
flock -n /tmp/opencode/cocs-finish-acceptance.lock node tools/release/cinematic-v3/pipeline.mjs --prepare --output="$E"
flock -n /tmp/opencode/cocs-finish-acceptance.lock node tools/release/cinematic-v3/pipeline.mjs --capture --slot-granted --output="$E"
flock -n /tmp/opencode/cocs-finish-acceptance.lock node tools/release/cinematic-v3/pipeline.mjs --menu-check --slot-granted --output="$E"
flock -n /tmp/opencode/cocs-finish-acceptance.lock node tools/release/cinematic-v3/pipeline.mjs --edit --slot-granted --output="$E"
flock -n /tmp/opencode/cocs-finish-acceptance.lock node tools/release/cinematic-v3/pipeline.mjs --install-menu --slot-granted --output="$E"
python3 -B tools/release/cinematic-v3/release.py --evidence="${E%/*}" --grant=CINEMATIC-NATIVE-20261003-M
```

These directories cannot be overwritten/reused. Future execution needs its own
grant and new output directory. Rollback remains
`node tools/release/cinematic-v3/pipeline.mjs --rollback-menu --output="$E"`.

Parent should integrate this branch and the installed-menu commit, publish the
movie for the independent manual watch/listen gate, and use a **fresh ledger-bound
attempt** after freezing the final candidate. This production rehearsal cannot
be restamped as final acceptance. Package export and the full final matrix remain
parent-owned.

Installed-menu commit: `f7310342`. Post-commit focused source checks passed 10/10
(`post-commit-source-tests.tap`) and `--plan` passed (`post-install-plan.json`).
The full source suite had already passed before production (`source-tests.tap`).
An earlier post-install source check correctly rejected the then-uncommitted menu
as a dirty runtime dependency; its failure log is retained separately. Whitespace
check passed. Tracked changes are committed; the 679 generated native sidecars
listed above remain untracked, rather than being silently deleted or published.
