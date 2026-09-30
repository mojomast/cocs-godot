# Persistent campaign daylight composition

## Corrected ownership

`terrain.gd` builds geometry only. `av_start` binds sound and weather particles;
neither AV nor weather creates a WorldEnvironment or DirectionalLight3D. The old
temporary briefing light was therefore a real composition bug when destroyed on
start. All temporary-preview-light creation/destruction has been removed.

`demo.load_map` now builds `campaign/environment.gd` once beneath each successful
world. Its children are exactly one `WorldEnvironment` and one `DirectionalLight3D`.
Same-map starts, retries, focus changes and results leave those instances intact.
A chapter replacement frees the old world and its atmosphere, then attaches the
new world's atmosphere. Audio/particle lifecycle cannot remove or replace it.

This uses the original biome identity's explicit daylight ambient fill (0.48),
procedural sky, linear exposure and compatibility-friendly light/fog settings.
The sun uses the revised terrain gallery's warm `fff0d7`, 0.8 energy and -42/-28°
orientation, with the identity renderer's bounded 220 m four-split shadows.
Forest chapters use blue/green daylight horizons, Siltwake a warm canyon horizon,
and Emberline a cool daylight sky. Ground and horizon blends consume each real
recipe's ground/stone palette. No geometry, combat rules or shader assets change.

## Regression and capture requirements

`godot/tests/campaign/environment.gd` composes actual Demo worlds through the four
ordered chapter starts and three repeated same-map starts per chapter. AV is
deliberately absent in that probe. It checks:

- Exactly one environment/sun in the full scene, owned by the active world.
- Effective World3D environment, procedural daytime sky luminance, explicit
  daylight ambient fill, enabled sun energy and shadows.
- Persistent identities across retries and focus cycles; previous atmosphere
  retirement on map change, and zero leaked lighting after scene removal.
- Above-ground production briefing view and idempotent environment build.

The real-authority capture fixture performs the same count/effective-daylight
checks at **every screenshot**, recording energies, sky color and instance IDs.
It rejects environment replacement during briefing/start/retry/ending on a map.
The fixture supplies no lighting; it can no longer hide missing production nodes.
Its staged NPCs explicitly clear their otherwise frozen spawn protection, and
captures assert zero protection so the actual robot silhouettes remain visible.

## Parent validation commands (serialized slot; not run by this follow-up lane)

```bash
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot \
  --script res://tests/campaign/environment.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot \
  --script res://tests/campaign/session.gd
LP_NUM_THREADS=1 GODOT_BIN="$GODOT_BIN" xvfb-run -a -s '-screen 0 1280x800x24' \
  node port/campaign/live-capture.mjs --profile=compact
LP_NUM_THREADS=1 GODOT_BIN="$GODOT_BIN" xvfb-run -a -s '-screen 0 1280x800x24' \
  node port/campaign/live-capture.mjs --profile=wide
```

Then rerun final exported-PCK capture using `--pack=/absolute/path/to/game.pck`.
**Resource closure must include `res://campaign/environment.gd`** (preloaded by
the demo; no external sky texture dependency). PNG evidence remains external in
the normal `cocs-campaign-evidence-20260930/live-captures/run-*` directories.

No engine, import, render or heavyweight test was run while the parent full suite
owned the slot. Node source syntax and diff checks are the only lane checks.
