# Prototype inspection and reproduction

This is NOT the completed three-mode playable release. Production authority, session, menus and
packages do not yet recognize these map IDs. Source-mode tests below run the unchanged source Match
in-process; they are not Godot-client play tests.

Pinned Godot: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`
(4.5.2.stable.official.6ce3de25a). Use a private `HOME`/`TMPDIR` and a private Xvfb display.

## Inspect the actual Godot maps

```sh
"$GODOT_BIN" --path godot --rendering-method gl_compatibility \
  res://identity_maps/inspection.tscn -- --map=lacuna-court
```

Tab changes map; 1–5 select fixed cameras; Esc quits. The overlay explicitly says inspection, not
playable release. The scene applies each map's own sky/light/fog and a render-only horizon.

## Reproduce owned checks

```sh
node tools/godot-identity-maps/compile.mjs                 # deterministic recipes + hashes
node port/native-identity-maps/graybox.test.mjs            # movement/nav/route + cold-time gate
node port/native-identity-maps/perf.mjs                    # cold/warm build cost evidence
node port/native-identity-maps/ray-oracle.mjs              # fixtures + source/exact parity audit
"$GODOT_BIN" --headless --path godot --script res://tests/identity_maps/rays.gd        # Godot parity
"$GODOT_BIN" --headless --path godot --script res://tests/identity_maps/contract.gd    # material/collision/fx contract
"$GODOT_BIN" --headless --path godot --script res://tests/identity_maps/lifecycle.gd   # build/free cycles
python3 tools/godot-identity-maps/capture.py --sizes=960x640,1280x800,1920x1080 --label=render
python3 tools/godot-identity-maps/capture.py --sizes=960x640 --glow --label=render-glow
python3 tools/godot-identity-maps/capture.py --baseline --maps=cinder-array,prism-foundry \
  --sizes=960x640 --label=baseline
node port/native-identity-maps/normal-rate.mjs             # bounded wall-clock source exercise
```

`capture.py` asserts the real PNG dimensions and image count per size and fails the run otherwise;
`--quality=Low|High` switches the effect budget, `--graybox` renders the collision-only view. The
normal-rate exercise takes several minutes and uses fixed-step source Match with ordinary controls
and no state injection; consult its per-map report, not just the exit code.

## Current evidence

`port/native-identity-maps/evidence/README.md` indexes every artifact. The current sets are
`render-final-*` (45 PNGs, three asserted resolutions), `render-glow-*` (glow A/B), `baseline-*`
(shipped native DM maps under the same harness), `perf-*`, `ray-report-*`, `graybox-*`,
`lifecycle-*`, `contract-*`. A filename containing combat/objective identifies a camera location,
NOT observed combat/capture evidence. Images have been checked for gross defects by an agent and
still need a human pixel review.

## Integration and packaging

See HANDOFF.md for the exact seams and the changed `geometryHash` values. No exported game package,
downloadable release or live test link is claimed. No existing release, source registry, shared
server, primary checkout or external weapon reservation was modified.
