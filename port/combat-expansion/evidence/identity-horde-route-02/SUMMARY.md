# Identity Horde route — lead startup check

`python3 tools/godot-dev/xvfb_run.py node tools/godot-dev/launch.mjs --experience=horde --map=nacre-engine`

- The owned authority started: `Owned local server ready at ws://127.0.0.1:<ephemeral>; horde`.
- Godot loaded `res://native_arenas/identity_horde_demo.tscn` under a private Xvfb on
  llvmpipe, Compatibility, and ran for the full 90 s bounded window (exit 124 = my
  timeout, expected for a live match).
- **0 script errors, 0 parse errors.** Audio fell back to the dummy driver because this
  container has no sound card; that is host configuration, not a product failure.
- Option-level rejections verified separately: a wrong mode
  (`--mode=deathmatch`) and an unknown map are refused, and the three source Horde maps
  still resolve to `res://horde/demo.tscn`.

**Scope:** this is a routing and startup check, not gameplay acceptance. Wave, victory,
defeat and peak-load acceptance for Nacre Engine belongs to the Horde lane and is recorded
in `port/native-identity-horde/HANDOFF.md` with its own runs, observer harness and
corridors. Two earlier lead attempts are retained: `identity-horde-route-01/` shows the
`--mute` rejection (pre-existing rule for standalone scenes) and the windowed launch with
no display; both were my harness mistakes, fixed by dropping `--mute` and adding a private
display.
