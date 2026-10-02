# Abyssal acceptance — 2026-10-02

## Actual result: READY FOR BLENDER

No heavy-slot grant has been received. No Blender/Godot process, import, bake,
render or export has run in this lane. Python AST parsing and Node source work
are complete.

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-expansion-three-abyssal-evidence-20261002/`.

### Checks run

```sh
node tools/godot-multiplayer/new-maps/abyssal-pressureworks/build.mjs
node tools/godot-multiplayer/new-maps/abyssal-pressureworks/build.mjs --check
node --test tests/new_maps/abyssal_pressureworks/source.test.mjs
python3 -c "import ast,pathlib; ast.parse(pathlib.Path('tools/godot-multiplayer/new-maps/abyssal-pressureworks/blender_author.py').read_text())"
sha256sum game/core.mjs
```

Latest source suite: **12/12 passed**, 0 failures, about 3.23 s total in the tool
run. This is not a native frame-time measurement.

| Check | Actual evidence |
|---|---|
| Schema / deterministic recipe | Source validator passes; stable identity and geometry |
| Route traversal | All 17 routes, both directions, ordinary `moveActor`; no jump/sprint requirement |
| Navigation | 935 nodes, 2,943 undirected edges, one component; source A* between every spawn/flag/objective pair |
| Shell collision | Sustained standing input against all 58 full shell segments, plus source rays |
| Openings / ceilings | 34 portal apertures and all 12 chamber crowns ray-tested |
| Glazing | Source rays cross declared transparent observation pane; no exterior floor |
| Vertical support | 29 walkable polygons; sampled interior nonoverlap; 20 m relief |
| Counterfire | Reciprocal ray visibility between raised control approach and reactor floor |
| CTF | Physical enemy flag pickup, carried return and capture-limit round win via `Match.step` |
| KOTH / Domination / Holdout | Physical source-input approach, presence capture and objective round wins; no timeout tiebreak |
| Autonomous source bots | 15 simulated seconds in each of six candidate modes; bots move >8 m from spawn and remain supported |
| Python authoring | AST syntax check passed; Blender API execution pending |
| Source pin | Core SHA-256 matches BRIEF exactly |

Current authority payload: 154 terrain surfaces, 404 individual wall triangles,
142 AABB solids, 451 authored nav seeds; 2,512 total native-equivalent source
collision triangles including AABB faces. Blender/native budgets are unmeasured.

### Preserved early attempt

The first five-case source run passed traversal, graph connectivity and collision
but reported two **fixture** failures: the schema validator returns an array
rather than `{errors}`, and the return walker kept requesting input after CTF
had already ended at the source capture radius. Corrected both assertions/control
loops; source gameplay rules and map collision were not loosened. Subsequent
5-, 9-, 11- and 12-case runs passed. A final architecture review attached the
equalizer's cap to its casing and gave it exact source collision; the final
12-case rerun passed and is saved as `source-final.tap`. See `attempts.json`.

## Grant-dependent next commands

Run from the lane worktree only after parent assigns the exclusive slot:

```sh
test -x /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 --python tools/godot-multiplayer/new-maps/abyssal-pressureworks/blender_author.py
```

Then reopen the saved master in Blender and inspect named editable components;
validate emitted GLB/provenance, actual batch counts and geometry. Use the pinned
Godot executable from BRIEF after parent integrates the catalog entry. Finish:

1. Native overview, three route eye views and all district interiors; revise
   architecture if sightlines, pressure-shell depth or equipment density fail.
2. Native/source body, portal, ceiling and window collider agreement.
3. Hosted ordinary-input CTF/zone journeys, separate from these source fixtures.
4. Readable 1280×800 and 760×520 at UI150 HUD captures.
5. Continuous representative walkthrough with actual capture cadence and
   measured frame/draw/triangle budgets; record GPU backend without inference.
6. Parent registration, production packaging/export and final mode approval.

No editable-master reopen, native visual quality, human feel, GPU performance,
recorded walkthrough or production release acceptance is claimed yet.
