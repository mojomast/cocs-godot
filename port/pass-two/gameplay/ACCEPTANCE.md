# Acceptance handoff — READY FOR ENGINE

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-pass-two-gameplay-evidence-20261002`

**No Godot, Blender, import, render, export, or nested-agent run occurred in this
pass.** The exclusive heavy slot was not granted. Resume only after the parent
explicitly grants it; the native launchers require
`PLAYER_GAMEPLAY_ENGINE_GRANTED=1` in addition to the pinned binary.

## Completed source/code checks

| Check | Result / evidence |
|---|---|
| Seven actual Match input journeys + seven negative controls | PASS; `source-final.log`, `source/*.json`, source-derived test oracle |
| Another-player rope boarding / ride / expiration and no-X control | PASS; `source/shared-rope-positive.json`, `source/shared-rope-negative.json` |
| Real protocol owner + guest, owner reconnect, ordinary-fire owner death | PASS; `wire-1.log`, `wire/report.json`, redacted `wire/trace.json` |
| Reproducible source-generated second-pass oracle | PASS; `source-reproducibility.log` |
| Existing movement / operator verbs / ability VFX tests | **75/75 PASS**; `source-regressions.log` |
| Existing source-generated gameplay catalog and first-pass fixtures `--check` | PASS |
| New Node module syntax checks | PASS (`source.mjs` executes; `wire.mjs` executes; both native runners `node --check`) |
| Frozen source + reviewed derivative verifier | PASS; `source-lock-check.json`, core `58ff1b9c…` |
| Git whitespace check | PASS |

Source repro commands (Node only):

```sh
node tools/port/pass-two-gameplay/source.mjs --check
node tools/port/pass-two-gameplay/wire.mjs
node port/next-port/gameplay/catalog.mjs --check
node port/next-port/gameplay/fixtures.mjs --check
node --test game/movement.test.mjs game/operator-verbs.test.mjs game/ability-vfx.test.mjs
```

The worktree uses a `node_modules` symlink to the parent checkout. No package or
lockfile changes were needed.

## Retained failures / investigations

- `source-legacy-exchange-probe/` retains successful early legacy-map probes;
  these are explicitly **not** canonical native-map evidence.
- `source-canonical.log` retains the first canonical-roof assertion failure:
  the source grounded on the roof but ended reeling with `blocked`, not `arrive`.
  `source-canonical-2.log` and final logs retain the corrected source-physics
  interpretation. No source changes were made.
- Initial `ws` import was unavailable until the permitted parent dependency
  symlink was installed. This was an environment discovery, not a gameplay fail.
- There are no native failures to report because native execution has not begun.
  Preserve every upcoming failed run in a distinct evidence subdirectory.

## Parent's next serial engine checks

Use Godot **4.5.2**, `LP_NUM_THREADS=1`, and an explicitly granted slot. Native
scripts and generated oracle remain under `godot/tests/`; current export preset
excludes `tests/*`. No production script loads these test fixtures.

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export LP_NUM_THREADS=1
export PLAYER_GAMEPLAY_ENGINE_GRANTED=1
export EVIDENCE=/home/mojo/.tmp-on-disk/cocs-pass-two-gameplay-evidence-20261002

# First compile/import as required by the parent, then run serially:
"$GODOT_BIN" --headless --path godot --script res://tests/player_gameplay/test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/player_gameplay/second_pass_test.gd
EVIDENCE_DIR="$EVIDENCE/native-seven-1" node tools/port/pass-two-gameplay/native.mjs
SHARED_SCENARIO=death EVIDENCE_DIR="$EVIDENCE/native-shared-death-1" node tools/port/pass-two-gameplay/native-shared.mjs
SHARED_SCENARIO=expiration EVIDENCE_DIR="$EVIDENCE/native-shared-expiration-1" node tools/port/pass-two-gameplay/native-shared.mjs
SHARED_SCENARIO=reconnect EVIDENCE_DIR="$EVIDENCE/native-shared-reconnect-1" node tools/port/pass-two-gameplay/native-shared.mjs
```

The launchers use one Xvfb Godot process at a time, Dummy audio and llvmpipe.
Seven-operator runs cap native runtime at 35s / process at 50s. Shared-rope
scenarios cap native runtime at 65s / process at 80s. These are scripted software
rendering runs; keep them distinct from owner/human/hardware-GPU evidence.

Then run existing combat controls, Experience combined/session/native journeys,
and campaign session regression using the parent release's established commands.
The new signal-on-change behavior and richer hint text specifically need the
Experience checks. Rebuild/package/canonical/platform gates stay with the parent.

## Required inspection before native acceptance

1. Verify each native source event and actor witness, not merely process exit or
   screenshot presence. Check real wire Q requests and accepted events, airborne
   resources, held grapple X, resolved ledge, final grounded roof, guest rope ID
   and movement, source death/expiration, and clean transport suspend/resume.
2. Inspect wide and 960×600 compact screenshots with Experience active for long
   Grok/grapple/rope hints, clipping, overlapping readouts and readable world cues.
   The shared runner captures the guest ride and cleanup; the Node owner role
   must remain explicit in evidence labels.
3. Capture/inspect a short movement/boarding clip after grant. Screenshot files
   alone cannot establish animation quality or continuous cable behavior. No clip
   or human-inspection claim is made now.
4. Exercise F9 Low/High/Extreme and reduced motion in the composed runtime;
   check actual channel/burst/cable caps and no old channels on death, focus loss,
   pause, missing actors, round reset and resumed transport.
5. Record native parse/runtime errors, failed runs and fixes before rerunning.
   Update this document with evidence paths and actual outcomes; do not inherit
   the first release's all-pass status for this code.

Readiness is **source/code prepared, READY FOR ENGINE**, not release acceptance.
