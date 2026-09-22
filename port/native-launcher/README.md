# One launcher for the current native experiences

`tools/godot-dev/launch.mjs` starts an owned loopback source server and routes to
the selected native scene. It runs interactively until the client closes or
Ctrl+C is pressed. It does not impose the acceptance helpers' short deadlines.
The server is shut down after the client exits. Source match timing is unchanged.

After the normal semantic export/Godot import setup, with `GODOT_BIN` set:

```sh
PORT=0 node tools/godot-dev/launch.mjs --play --setup
PORT=0 node tools/godot-dev/launch.mjs --experience=sports --map=ion-speedway
PORT=0 node tools/godot-dev/launch.mjs --experience=sports --map=aurora-stadium
PORT=0 node tools/godot-dev/launch.mjs --experience=objectives --map=tidal-citadel
PORT=0 node tools/godot-dev/launch.mjs --experience=objectives --map=sunscar-convoy
PORT=0 node tools/godot-dev/launch.mjs --experience=lattice --map=asterion-relay --mode=cocs
PORT=0 node tools/godot-dev/launch.mjs --experience=lattice --map=monsoon-foundry --mode=cocs-coop
PORT=0 node tools/godot-dev/launch.mjs --experience=lattice-world --map=asterion-relay --mode=cocs
```

Sports mode is fixed by the map; objectives likewise select CTF or Payload.
Sports additionally accepts ordinary host options `--time-limit=60..900` and
`--round-target=N` (1..10 laps for Ion, 1..15 goals for Aurora). The launcher
rejects out-of-range/non-integer values instead of silently changing them.
LATTICE defaults to PvP (`cocs`); Connect / start remains an explicit native UI
action. No new map/mode is enabled in the infantry setup menu. Omitting all
arguments still opens the offline map viewer. `--help` works without a Godot
binary or server startup and lists default maps and supported options.

The launcher rejects unknown flags and incompatible standalone map/mode pairs
before allocating a server. Combat's existing native capability validation
remains the authority for its setup. The external lobby integration will need
to register its new `--lobby-menu` flag here when delivered.

## Verification

```sh
node --test tools/godot-dev/launch_options.test.mjs
python3 -B port/native-launcher/verify.py
```

The five routing regressions cover all supported standalone map/mode pairs,
actual scene-file existence, unchanged viewer/combat/smoke arguments, defaults,
invalid/missing/duplicate options, legal sports round limits and locked-catalog exclusion.

Startup evidence: [`1790041833825798250`](evidence/1790041833825798250/summary.json).
All **six standalone maps passed** against the actual launcher and pinned native
editor, with zero Godot errors, owned editor process gone and server port closed.
The probe wraps the real editor only to add `--headless --quit-after 180`, records
the exact executed args and retains per-map output. It changes no source rules.
LATTICE startup remains disconnected, awaiting its normal Connect action.

These are bounded headless **startup/cleanup checks**, not new graphical,
interaction, long-session, result or recording-completion acceptance. Existing
independent graphical gameplay evidence for each scene remains separately scoped.
The combined **51-gate verifier passes** with the new routing gate and the
existing real combat transport, session and lifecycle launcher paths.

Later world integration adds `--experience=lattice-world`, keeping `lattice`
as the command board. `python3 -B port/native-launcher/verify.py --lattice-world`
independently passed all four new map/mode routes through the actual launcher:
[`1790045153865842451`](evidence/1790045153865842451/summary.json).
The latest combined run passes **62 gates**; original startup evidence above
remains scoped to its historical build.
