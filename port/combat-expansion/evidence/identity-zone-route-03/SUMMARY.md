# Identity zone (Domination) route — lead startup check

`python3 tools/godot-dev/xvfb_run.py node tools/godot-dev/launch.mjs --experience=identity-zones`

- The owned identity-zone authority started: `Owned local server ready at
  ws://127.0.0.1:<ephemeral>; identity-zones`, on the reviewed `/native-zones` route.
- Godot loaded `res://native_arenas/identity_zone_demo.tscn` under a private Xvfb on
  llvmpipe, Compatibility, and ran the full 85 s bounded window (exit 124 = my timeout,
  expected for a live round).
- **0 script errors, 0 parse errors.** Audio fell back to the dummy driver (no sound card
  in this container).
- Option contract verified separately: the one reviewed pair only (`vermilion-fold` /
  `domination`); a wrong map, a wrong mode, `--bots=9` and `--score-limit=0` are all
  refused. Defaults: bots 2, 120 s, score limit 30, and the packaged launcher resolves
  the same scene and authority.

**Scope:** routing and startup, not gameplay acceptance. Capture/contest/loss/recovery,
both teams scoring, results and restart, the graphical correlation (3601 samples, 24
checks, zero marker/HUD/bearing errors) and the 36-run travel table belong to the lane
and are recorded in `port/native-identity-zones/` with its own runs.

Two earlier lead attempts are retained: `identity-zone-route-01/` (the authority refused
`score`; the corrected spelling is `fragLimit`) and `identity-zone-route-02/` (the
launcher's endpoint allowlist knew only `/native-arenas`). Both were my wiring mistakes
and both are fixed in the dev and packaged launchers.
