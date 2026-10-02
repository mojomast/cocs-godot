# Replay acceptance and executable next steps

**READY FOR ENGINE. Parallax retains the exclusive heavy slot.** No engine,
Blender, import, render, video or audio capture has run for this feature.

Evidence: `/home/mojo/.tmp-on-disk/cocs-expansion-four-replay-evidence-20261002/`.

## Actual source/script checks

- **78/78 Node checks passed**: fifteen adapter tests plus existing source demo,
  demo-store, demo-session and demo-playlist regressions. Command:
  `node --test tools/port/replay/adapter.test.mjs game/demo.test.mjs game/demo-store.test.mjs game/demo-session.test.mjs game/demo-playlist.test.mjs`.
- Actual source recorder files, JSON and gzip decode; source-exact seek positions,
  yaw wrap, actor birth/despawn, discrete bodyYaw, single-frame and trim semantics.
- Actual Room protocol output for seated and spectator recipients; snapshots and
  events match separate source Recorder oracles exactly. Welcome/resume credentials
  and an authority-only sentinel do not enter the clips. Meridian has no COCS
  private-intel projection: **this does not prove recording a private COCS stream**.
  Unsupported COCS capture is explicitly rejected.
- Malformed versions, non-finite coordinates, duplicate identities/events,
  non-monotonic time, excessive collections, map/mode/provenance mismatch,
  traversal/symlinks, credential/prototype keys and gzip inflation bomb rejected.
- Real authenticated loopback helper process: unauthorized call refused;
  record → frames → save → open paused → exact seek → close → discard → list.
- Read-only adapter refuses input/host/join/start/award/command/buy/script verbs.
  No authority or career runtime is imported by the four-file package closure.
- **Six GDScript files passed gdtoolkit 4.5 grammar parsing**. This is not Godot
  type checking or rendering. Native runner JavaScript passes `node --check`.
- Four-file external runtime packaging and standalone packaged adapter list were
  exercised. Final parent package integration/export verification remains pending.
- Source core/demo/map and original/reviewed derivative contract hashes match.

Retained failures: `initial-failed-tests.txt` records the first fixture's mistake
of feeding in-memory `undefined` values instead of serialized source wire/file
data. `source-tests.txt` records a later missing `three` test dependency; the
approved parent `node_modules` symlink enabled the passing rerun in
`source-tests-with-dependencies.txt`. Final expanded checks are in
`final-source-tests.txt` (78/78), with `final-grammar.txt` and the standalone
`final-replay-runtime/` package. No frozen source was changed to fix either.

## Runnable native acceptance, only after a grant

First restore/generate the existing parent-approved semantic/operator/effects
assets and apply parent entry/package closure. Do not treat a missing resource
fallback as acceptance. Run engine parse/import in the granted serialized slot.

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
COCS_REPLAY_EVIDENCE=/home/mojo/.tmp-on-disk/cocs-expansion-four-replay-evidence-20261002/native \
LP_NUM_THREADS=1 python3 tools/godot-dev/xvfb_run.py node godot/tests/replay/run.mjs
```

The prepared runner uses a normal-rate real source server and a native Session
subclass whose only setup override requests a 30-second, one-bot DM round. It
starts native recording, sends ordinary sampled input, waits for source results,
saves, starts/discards a second recording, disconnects/frees the live session,
opens the saved library clip, checks exact 1.25-second seek, play/pause/settings,
and captures 1280×800 and 760×520/UI150 images. It records all incoming authority
verb types and requires **zero authority packets after leaving for replay**.
The setup/input is scripted, not a human play-quality proof. The runner is
authored but **unexecuted** and may need engine-discovered typing/layout fixes.

## Gates still required

- Godot type/resource checks; actual native connected round and saved/reopened
  clip; read-only no-input/no-career-write audit through the shipped Home route.
- Source/native position/orientation comparison at exact seeks, projectile
  positions frozen during pause, visual family/death/birth correctness.
- Inspect wide and compact captures: readable speed/seek, no hidden controls,
  no stale active-player HUD, settings/back focus, error recovery and unknown-map
  message. Verify Home hides/stops attract while Replay is open.
- Listen to real-driver 1× cues and inspect seek/speed/pause/settings/focus clear;
  require no old burst or duplicate window events. Dummy audio is insufficient.
- Ended/pause phase, alternate speeds, drag scrub, new round and seat change,
  transport loss, queue cap/save-prefix, discard and helper teardown/orphan audit.
- Malformed import and disk-write failure must remain visible in the native UI.
- Linux/Windows package closure, helper/node discovery and source-module hash
  checks in extracted packages. No release/export/published acceptance is claimed.

Current scope gaps are explicit: one map/four combat modes; no campaign/vehicle/
private-intel replay; no bookmarks, editing timeline, deletion/retention UI,
native gzip file picker or full objective-event analysis. Native rendering reuses
existing runtime assets; no new map assets are supplied here.
