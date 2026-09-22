# Prototype inspection and reproduction

This is NOT the completed three-mode playable release. Production authority, session, menus and packages do not yet recognize these map IDs. Do not rename modes on the existing native-DM launcher and assume that provides Horde/Domination. Source-mode tests below run unchanged source Match in-process; they are not Godot-client play tests.

Worktree: /tmp/opencode/cocs-identity-maps
Branch: external/visual-identity-three-maps
Pinned Godot: /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64

## Inspect the actual Godot maps

From the worktree, with a graphical display:

```sh
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --rendering-method gl_compatibility \
  res://identity_maps/inspection.tscn -- --map=lacuna-court
```

Tab changes map; 1–5 select fixed cameras; Esc quits. The overlay explicitly says inspection, not playable release. This adds no combat controller. Headless startup was exercised; actual visible input controls still need graphical review.

## Reproduce owned checks

```sh
node tools/godot-identity-maps/compile.mjs
node port/native-identity-maps/graybox.test.mjs
node port/native-identity-maps/ray-oracle.mjs
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --script res://tests/identity_maps/rays.gd
"$GODOT_BIN" --headless --path godot --script res://tests/identity_maps/lifecycle.gd
python3 tools/godot-identity-maps/capture.py --sizes=960x640,1280x800,1920x1080
node port/native-identity-maps/normal-rate.mjs
```

Normal-rate test can take several minutes; it uses fixed-step source Match with a five-step capped wall-clock backlog, ordinary controls, and a three-wave Horde acceptance preset. It records public snapshots/events and the exact recipe. No WebSocket service, graphical actor scene, authority-state mutation or local damage simulation is involved. It may record an incomplete second round at its deadline; consult the actual per-map report, not just process exit zero. Map collision wall complexity currently makes construction expensive.

## Current image evidence

Latest inspected-by-code capture set (pixels NOT reviewed):
port/native-identity-maps/evidence/render-1790081900090569141/

Each resolution directory contains entrance, landmark, combat, objective and worst-sector PNGs for all three maps plus actual renderer/cadence counters. No actors or particles are present; a filename containing combat/objective identifies a camera location, NOT observed combat/capture evidence. Earlier capture sets are retained and not silently replaced.

## Integration and packaging

See HANDOFF.md for explicit shared hooks requiring parent approval. No exported game package, downloadable release or live test link is claimed. No existing release, source registry, shared server, primary checkout or external weapon reservation was modified.
