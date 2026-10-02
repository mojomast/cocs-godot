# READY FOR BLENDER — awaiting explicit grant

Slot status: Parallax owns the heavy slot. This lane has run Node and Python AST
checks only. No Blender, Godot, imports, bakes, rendering or exports have run.
No master or GLB exists yet. This is source-ready staged implementation, not a
published or visually accepted map.

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-expansion-three-vesper-evidence-20261002/`

## Passed source gates

Commands:

```sh
node tools/godot-multiplayer/new-maps/vesper-viaduct/build.mjs
node tools/godot-multiplayer/new-maps/vesper-viaduct/build.mjs --check
node godot/tests/new_maps/vesper_viaduct/rounds.mjs
python3 -c "import ast,pathlib; ast.parse(pathlib.Path('tools/godot-multiplayer/new-maps/vesper-viaduct/author_blender.py').read_text())"
sha256sum game/core.mjs
```

* Schema valid; deterministic source and runtime envelope.
* 1,558 triangular walls; 209 terrain/roof surfaces; 21 rooms in seven interiors.
* 19 routes in both directions: 29,276 actual `moveActor` ticks, no coordinate
  writes after each route's initial setup. Additional continuous spawn-to-square
  and pickup journeys passed. All six spawns, six pickups, three objectives and
  591 authored navigation samples have support and body clearance.
* Source-generated navigation: all 2,143 nodes form a connected graph; all 15
  spawn/pickup/objective targets have a reachable node within two metres.
* Exhaustive rectangular walkable-footprint overlap rejection, source-void canal,
  bridge support, upper/lower floor heights and non-walkable roofs checked.
* Six seconds of sustained contact against a nine-metre triangular wall and its
  eye ray; sill body/ray, true open window, open doorway, roof ray and jump ceiling
  checks passed. Maximum jump foot height under courtyard roof: 23.0856 m.
* Controlled source **full scored rounds** using ordinary `Match.step` inputs:

| Mode | Result | End | Source seconds |
|---|---|---|---:|
| DM | 1 legitimate player frag, leading actor | time | 60.0167 |
| TDM | 1 team frag, team 0 wins | time | 60.0167 |
| CTF | 3 physically carried captures, team 0 wins | capture | 240.3000 |
| Domination | 1 capture, 12 scored objective seconds | objective | 20.3833 |
| KOTH | 2 captures, 12 scored objective seconds | objective | 47.1833 |
| Uplink | 3 captured stages | objective | 37.0333 |

DM/TDM place two human-controlled seats only at setup, walk the player to contact,
fire source weapons, then finish the timed round. DM's source snapshot reports
leaders and a null team winner. Other modes start from constructor team spawns;
CTF alternates lower/upper outward flanks and returns through civic interiors.
Zone rounds use score limit 12; CTF uses limit 3. Uplink records captures rather
than objective-time score. No target damage, score or position writes occur after
setup. These are controlled source-input fixtures, not bots, networked native
clients or human playtesting.

Evidence: `build.json`, `source-rounds.jsonl`. Geometry hash:
`1e9ad354a2d4f474f783289043380cd7ea046ca5631cd829715c627d0bc37548`.
Recipe hash:
`378dc48a9be28a3f2a75be5a08f4c860917c8f71ef0362afa6f544fbe6950f93`.

## Preserved development failures

The first schema check assumed an object result; actual validator returns an
error array. Initial routes exposed the clock tower blocking civic street and
the central gallery lacking its north/south portal; both geometry faults were
corrected. An initial window probe hit an authored mullion; the open-aperture
probe was moved into the actual window. Initial stair riser walls blocked walking
and were removed from collision (treads remain real source support). Round tests
were corrected for DM's null team winner, source ending CTF within the 1.3 m home
radius, and uplink's capture-only score statistics. These attempts remain recorded
here and in session tool output; the successful evidence files are separate.

## Exact grant-dependent commands

Verify pinned binaries exist before use. Serialize jobs with `LP_NUM_THREADS=1`.

```sh
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender --background --python tools/godot-multiplayer/new-maps/vesper-viaduct/author_blender.py -- build
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender --background --python tools/godot-multiplayer/new-maps/vesper-viaduct/author_blender.py -- reopen-export
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender --background --python tools/godot-multiplayer/new-maps/vesper-viaduct/author_blender.py -- inspect
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/new_maps/vesper_viaduct/collision.gd
```

The native collision script is authored but has not been engine-parsed/run.
Blender script has passed Python syntax only, not Blender API execution.

## Remaining acceptance

* Generate editable master outside Godot; reopen it and export real art/provenance.
* Inspect overview, canal, civic, concourse and arcade eye-level images. Revise
  actual architecture, roof support, readability and facade depth as needed.
* Resolve parent art path, compare native/source rays and sustained native body
  collision, and inspect openings/ceilings after import.
* Connected ordinary-input hosted objective journeys with all advertised modes.
* Full 1280×800 and compact 760×520/UI150 HUDs, traversal capture, clip counter,
  measured GLB/triangle/object budgets and captured frame cadence.
* Parent shared registration, package gates and publication. No GPU/human feel
  acceptance is claimed by this lane's source evidence or future software renders.
