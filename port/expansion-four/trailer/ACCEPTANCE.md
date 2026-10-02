# V3 capture handoff

**READY FOR CAPTURE — no Godot, Blender, import, rendering or FFmpeg job ran.**
Parallax retains the heavy slot. No nested agents or production edits.

Source checks: `node --test tools/release/cinematic-v3/pipeline.test.mjs` passes
6/6. Tests cover four pinned map recipes/licensed score hashes, composed source
camera clearance, rejected stale geometry/unaccepted maps/hidden FP HUD, explicit
slot gates, real traversal/jump/combat inputs, corrupt cadence detection, and
awaited worker timeout/serial environment. Initial failed jump test diagnosed an
optional route ending before the jump; the final chain continues through the
connected condenser link and reverse exit. Native parser/visual acceptance is
pending, not inferred from Node tests.

## Lightweight commands (permitted now)

Run from the integrated checkout after committing the exact intended runtime:

```bash
node --test tools/release/cinematic-v3/pipeline.test.mjs
node tools/release/cinematic-v3/pipeline.mjs --plan
E=/home/mojo/.tmp-on-disk/cocs-expansion-four-trailer-evidence-20261002/integrated-attempt-01
node tools/release/cinematic-v3/pipeline.mjs --prepare --output="$E"
node tools/release/cinematic-v3/pipeline.mjs --edit-plan --output="$E"
```

`--prepare` runs only Node source authority; it creates fresh JSONL records,
receipts, complete dependency plan, menu candidate and its export audit. Choose a
new directory after any changed source/asset/manifest bytes. The pipeline refuses
dirty tracked runtime dependencies and changed hashes between prepare/render/edit.

## Only after explicit parent heavy-slot grant

Use the pinned Godot in the brief. Import/typecheck the integrated project first
under the granted slot. A working visible display or parent-owned Xvfb is needed.

```bash
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
# First render one complete shot to establish software cost and inspect composition.
LP_NUM_THREADS=1 node tools/release/cinematic-v3/pipeline.mjs --capture --slot-granted \
  --godot="$GODOT_BIN" --output="$E" --shot=root-reveal --deadline-seconds=1800
# Capture each remaining shot separately; do not rerun an already captured shot.
# Or use a fresh fully prepared attempt and omit --shot to capture all sequentially.
LP_NUM_THREADS=1 node tools/release/cinematic-v3/pipeline.mjs --menu-check --slot-granted \
  --godot="$GODOT_BIN" --output="$E"
# When every shot has contiguous frames and its native log passes:
LP_NUM_THREADS=1 node tools/release/cinematic-v3/pipeline.mjs --edit --slot-granted --output="$E"
```

Default capture deadlines: 30 minutes per shot, four hours per invocation; use
`--deadline-seconds` / `--budget-seconds` only within the granted slot budget.
Software rendering already uses deterministic offline frame capture, not a
real-time recorder that drops frames and later advertises resampled FPS. A timeout
preserves its partial frames/logs; use a new attempt rather than overwrite them.

## Pending native/publication gates

1. Godot import/parse/typecheck, then one 1280×720 frame sequence through production
   campaign nodes. Confirm source-clock/engine-frame cadence in `cadence.jsonl`.
2. Inspect district silhouettes, camera terrain/art clearance and six spline
   glances; source collision tests do not see decorative native-art occlusion.
3. Inspect Mara and Ivo caption/gesture visibility, Patch reaction, actual weapon
   and melee hits, active robot motion, artillery effects and current environment.
   Require HUD legibility on the ordinary-input shots. No edited victory claim.
4. Native menu candidate: two images/clip, all four maps, real event origin,
   Patch reaction, bounded terrain, one private world, full-loop cleanup,
   foreground route/focus, Settings/reduced-motion/animation/focus pause, compact
   760×520/UI150 screenshot and final scene resource disposal. Inspect both wide
   and compact images; automated pixel differences alone do not prove quality.
5. Inspect `edit/cut-continuity.png`, watch the entire MP4 and listen for transitions,
   score balance and clipping. Decode/probe/loudness checks must all pass.
6. Parent installs accepted attract bytes separately, reruns installed-menu and
   package closure gates, then publishes a **new v3** gallery/master/provenance.
   Preserve v2 and every prior/failed capture. This lane has not published anything.
