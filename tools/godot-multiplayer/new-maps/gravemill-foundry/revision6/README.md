# Foundry R6 — source-only finish follow-up

Base: parent `7ae3f2f5` (integrated R5), branch `astra/foundry-finish-r6-source`.
R5's independent review passed; this is a separate visual-art revision, not a
geometry repair. **R6 has not been built, imported, rendered, or visually approved.**
S remains released. Queue the build after T/Coastal and botanical heavy work;
the commands below require a newly authorized exclusive slot. No children used.

## Image-led problem → authored change

All eleven R5 candidate / accepted-before camera pairs were opened and examined.
Their immutable hashes are recorded in `source-report.json`. These are references,
not R6 evidence. The approved pack's base, v2 and v3 albedo sheets and v3 tiled/
normal sheets were examined. The v3 loader selects the corrected v2 base plus v3
overrides. In particular **copper-heat-oxide is olive/green**, copper-patina is
turquoise/brown, and **oxidized-iron is brown/rust with grey metal**. Resource names
are not used as a substitute for their actual appearance; linear albedo conversion
continues through the reviewed loader exactly once.

| R5 view | Observed problem / retained strength | R6 source response |
|---|---|---|
| overview | Giant repeated cast-seam ground pattern; many building classes similarly pale | Quiet aggregate ground, function-specific masonry/steel; existing route inlays retained |
| crusher-roofline | Green roof sheets, pale broad walls and pale frame collapse into a common treatment | Identified folded crusher roof → grey ribbed steel; main wall infill → aggregate; cast end frames; green cooling roof remains distinct |
| crusher-eye | Crusher steel shell has the same pale finish as walls | Exact `crusher-drum` / `crusher-cap` source IDs → forge steel; cast machine beds; existing copper bands retained |
| crusher-maintenance | Large bright cylinders compete with the sloped walking surface | Same whole-cylinder roles; lower normal relief; preserve maintenance floor geometry and routes |
| bunker-player | Surge bin reads as a pale solid sitting on another pale block | Identified surge/hopper shells → oxidized iron, dark hoods/discharge mechanisms, cast feet; no extra props |
| furnace-eye | Furnace façade loses its warm separation from green vessels | Identified kiln masonry → terracotta; localized service casing → steel; green tanks and exact orange inspection strips retained |
| furnace-skyline | Furnace/crusher/cooling district distinction weak | Warm kiln frame, steel crusher roof and retained copper cooling vault establish functional hierarchy |
| kiln-eye | Portal masonry and neighbouring industrial parts share flat pale treatment | Warm refractory arch/jamb roles; dark service metal; portal positions and aperture unchanged |
| cooling-eye | Lighting/guidance now readable; a useful spatial identity | Preserve copper vault, existing four lights, route and signs; mineral piers and cast splash bases |
| transfer-eye | Broad pale walls dominate a clear circulation corridor | Identified infill and kiln frame differentiated; no new freestanding objects or path decorations |
| tipple-player | Arch is visually similar to adjacent pale building | Identified tipple arch/jamb → refractory masonry; ribbed canopy and timber retained |

This is an authored hypothesis for the next image review. Palette variety and
passing tests do **not** establish that the user’s polish goal has been met.

## Implementation and ownership

- `finish.py` reads the actual immutable R5 GLB. Exact source polygon vertex
  membership recovers architectural IDs; R5 evaluated component-triangle records
  recover mechanism IDs. It never uses random face colors or alternating indices.
- `bindings.json` defines seven explicit finish roles. Existing source part
  boundaries define whole roofs, infill, end frames, beds, hoppers and machinery.
  Unidentified legacy trim uses its original **soot batch**, not every pale surface;
  vertical faces receive steel while ground/other original roles are retained.
  Ground fallback is restricted to upward/downward near-horizontal original mineral
  faces without a matched architectural ID (including exterior bench tops).
- No triangles are subdivided. There is no artificial lower-wall stripe cut through
  triangle diagonals: weathered lower treatment follows existing cast beds, sills,
  jambs and feet. Narrow original trim remains distinct from large infill.
- Pack world scale is applied as a **positive uniform UV ratio**, with the Blender/
  glTF V-origin conversion handled explicitly. No UV reflection/rotation occurs;
  original tangents remain valid. Role normal strengths are .12–.30 for restrained
  relief at player height. Texture samples and runtime readability need next-grant
  native inspection, especially whether forge-steel's ribbing is too strong.
- `author.py` opens the packed R5 master and assigns editable material slots on
  its export polygons. It saves only an R6 master. Hidden R5 mechanism sources remain
  geometry references; editable export faces own R6 finish assignments.
- `compose.py` takes only new material/image resources from Blender's intermediate
  export. It copies R5 POSITION, NORMAL, TANGENT accessors and oriented index triples
  exactly, splits indices by material role, and writes scaled UV accessors where
  needed. Embedded images are byte-deduplicated. No lossy geometry compression or
  detail reduction is involved.
- `verify.py` compares actual future R6 per-corner position/normal/tangent/UV/role
  multiplicity against the source plan, exact retained materials including orange,
  and actual exported new-material albedo/normal/roughness pixels.
- `reopen.py` checks the future freshly reopened packed master against planned
  per-corner positions, material roles and UVs. No reopen claim is made now.

## Identity and stage contract

Gameplay geometry remains
`61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879`.
The R6 stage loads the **same R5 authority file**, not a restamped copy. Collision,
nav, floor grades, routes and map ID are unchanged. There is no additional geometry
requiring scenic/collision annotations or new ray exceptions.

Visual revision is **6**, with a separately hashed actual `artHash` produced only
after the future build. `godot/tests/new_maps/gravemill_foundry/revision6/staged.gd`
requires that hash as well as geometry identity; geometry equality alone cannot
silently select the R5 finish. The art-identity file intentionally does not exist
yet. Production catalog/profile files are untouched.

The stage preserves all 18 imported material roles via the existing production
Binder, retaining accepted signs/panels and instance-owned anisotropic filtering.
It uses unchanged R5 cooling light definitions. The future capture script compares
**staged R5 before against staged R6 after**, all eleven identical cameras, with
production WeatherService and Off/Low/Full dressing/emission checks. Each capture
will record its distinct actual art hash, even though geometry hashes match.

## Source verification / future queue

Safe source commands (executed now):

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/gravemill-foundry/revision6/finish.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/gravemill-foundry/revision6/prepare_stage.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/gravemill-foundry/revision6/check.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/godot-multiplayer/new-maps/gravemill-foundry/revision6 -p test_source.py -v
```

The three tiny in-memory serializer unit fixtures test oriented geometry/basis,
per-material UV scaling, preserved orange fields, source identity and coverage
failure. They do not produce an actual R6 GLB or any PNG.

Future exclusive-grant sequence, serial with `LP_NUM_THREADS=1` / `OMP_NUM_THREADS=1`:

1. Run Blender **4.5.14** with `-b -t 1 --python-exit-code 1 --python` pointing
   to `revision6/author.py`, then `-- --authorized-r6-build`. Bound to 900 seconds.
2. Fresh Blender invocation of `revision6/reopen.py` with the same flag, 120 seconds.
3. Pinned Godot **4.5.2** headless editor import of the isolated worktree, 600 seconds.
4. Native `revision6/capture.gd` under an owned display/process group, Compatibility,
   1280×720, 210 seconds. Do a complete first run; targeted recapture requires a
   prior R6 capture report. Record actual import logs, material surfaces, bytes,
   draw calls, memory and backend cadence; archive failures rather than overwrite.
5. Independently review crusher-roofline, bunker-player and every player-height
   frame for material repetition, readability and UV scale. Reuse R5 native physics
   only as prior same-geometry evidence, never relabel its renders as R6 acceptance.

Source plan retains **87,566 triangles**. See `source-report.json` for actual planned
primitive count and surface-area composition. New material partitions may increase
draw calls: the planned primitive count is not a measured native draw-call count.
There is no 150k art ceiling and no attempt to strip detail for the byte target.
Actual R6 bytes, load time, memory, GPU cadence, exported PNG checks, native renders,
and final manual art acceptance are all **pending**. Public promotion remains pending.
