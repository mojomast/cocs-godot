# Consolidated asset production queue

**Source consolidation complete; READY FOR SERIAL BLENDER PRODUCTION after an
explicit grant. FINISHCOMBINED-A owns the current heavy slot.** No Blender, Godot,
imports, rendering, baking, video encoding or nested agents ran in this task.

The executable queue is [`ASSET_PRODUCTION.json`](ASSET_PRODUCTION.json). It keeps
every requested unit pending until real production and acceptance; none is
silently dropped to make a Windows release. This is one serial queue, not a new
asset branch fan-out. Parent may resume the original unit workers against this
consolidated source when their unit receives a grant.

## Consolidation provenance

Scenery checkpoint was clean and preserved as
`archive/scenery-source-fe3f3b5a`. Canonical `e38b3662` merged without conflicts as
`eeaae759`. Only the explicitly named source commits were cherry-picked, after
reading their stats; no preceding source dependency was missing:

| Original source / hook | Consolidated commit | Scope |
|---|---|---|
| `9b1d8b86` | `4c386257` | Vesper recipes, JSON wrappers and tests |
| `67f79981` | `79135d30` | Abyssal recipes, JSON wrappers and tests |
| `fb9715fb` | `4410a3c3` | Robot skins, six props and opt-in adapter |
| `91fb48e4` | `4ceff062` | Puma/Titan/Scout recipes and optional adapter |
| `ce739609` | `213b04b9` | Small fleet/Puma renderer hooks |
| `e723b2fd` | `f0bb6019` | Stormglass recipe, JSON wrappers and probes |
| `36358d96`, `fe3f3b5a` | already present | Scenery and isolated terrain hook |

The canonical Moth/operator/fighting/map-finish work is retained. No worker branch
was wholesale merged. Parallax revision `3e9bf9e5` was **not merged**: its exact
commit README was inspected to record original-worktree commands in the queue.
That unit must finish there, then parent reviews geometry/assets/hooks and
revalidates Moth mounts on the revised interiors.

### Minimal semantic corrections

1. Vesper's builder exported to a nested art directory, while current
   `multiplayer_worlds/map.gd` resolves recipe worlds under `art/worlds/`.
   Its new unbuilt export target now matches that loader. Editable master stays
   outside Godot. Runtime export copies are material-batched; editable originals
   retain their names. No common loader change or accepted art replacement.
2. Vesper and Abyssal previously put six design candidates in `modeBindings`.
   They now expose them as `candidateModes`, with **empty `modeBindings`**. Public
   catalogs remain identical to `e38b3662` and reject all three unaccepted maps.
3. Stormglass's wrapper used a terrain-only hash, incompatible with the current
   catalog's canonical-full-arena hash. The wrapper now follows the real API.
   Its recipe/authority JSON and geometry did not change.
4. Actual Moth-based UV finishing is connected to every queued builder. This
   changes prospective asset provenance, not authority. See below.

Admission metadata **does change Vesper/Abyssal recipe and canonical hashes**.
Old source reports remain historical; the changed recipes were regenerated and
matching source checks rerun. Comparisons against original commits prove every
other arena field remains identical, including source terrain and collision.

| Candidate | Current canonical geometry identity |
|---|---|
| Vesper | `6917cffcd39b6ba64dc3e9ada1ce33d79bd0847aa36938cc7f8e1f2dc3e07246` |
| Abyssal | `1ba0013a069d0b771e152395a2b37a5559008a8afe8107b4ce55952cfe6e9c82` |
| Stormglass | `6afb8a36ee954ff9457a5522a7412c809191fb070eb7fe9eda4d379753acce48` |

## Single actionable production order

Parent grants one unit/stage at a time after FINISHCOMBINED-A releases the slot.
Parallax's original-worker unit is external to this runner; it remains first in
the recorded queue. Units 2–7 are staged here. Every unit's exact source paths,
master/export targets, commands, timeouts, prerequisites, candidate modes, next
captures and unresolved acceptance gates are in JSON.

| Order | Unit | Real outputs required | Configured aggregate triangle ceiling, **not measured** |
|---|---|---|---:|
| 1 | Parallax interiors v2, original worktree | revised master/GLB, archive/pump inspection, source-contact gate; Moth mount revalidation | 160,000 |
| 2 | Robots | 3 skins × 3 LOD assemblies in 3 runtime GLBs; 6 prop GLBs; 9 masters; 3 skeletal reference GLBs | 102,000 |
| 3 | Vehicles | Puma/Titan/Scout × 3 LOD GLBs and 9 masters | 456,000 post-modifier cap |
| 4 | Scenery | 12 assemblies, 24 LOD GLBs, 12 masters across four production chapters | 108,000 |
| 5 | Vesper | 1 material-batched GLB, 1 editable master; six candidate native mode journeys | 250,000 |
| 6 | Abyssal | 1 batched GLB, 1 editable master; six candidate native mode journeys | 100,000 |
| 7 | Stormglass | 1 batched GLB, 1 editable master; two-native-client race and ordinary driven laps | 250,000 |

Caps cover all packaged LODs, not simultaneous draw cost. Vesper/Stormglass caps
are consolidation release ceilings; remaining caps come from source contracts.
Vehicle recipe count is 89,948 before modifiers; scenery recipe count is 13,452
across both LODs. No new GLB triangle/draw/byte or GPU measurement exists yet.

Vesper candidates: **DM, TDM, CTF, Domination, KOTH, Uplink**. Abyssal's actual
source candidates: **DM, TDM, CTF, KOTH, Domination, Holdout**. Stormglass:
**Puma Race**. None is publicly registered. During native production, use a
test-only admission seam, then parent registers only actually accepted pairs.
The hosted candidate admission/journey harnesses still need completing; source
fixtures and map probes are not substitutes for those gates.

## Preflight and bounded commands

Safe now, **no heavy tool invocation**:

```sh
python3 tools/asset-production/run.py
node --test tools/asset-production/consolidation.test.mjs
```

The preflight checks executable paths using filesystem metadata, current disk
headroom, Python AST, literal source/runtime dependencies, `ws` resolution,
actual Moth image SHA-256s, existing output counts and frozen-source identity.
It neither executes `--version` nor copies caches. A first run found missing
`ws`; an ignored symlink reuses the existing canonical worktree's `node_modules`.
No install or node_modules/cache copy was made.

Actual final source preflight at this checkpoint: both pinned binaries executable,
`ffmpeg` found, all eight selected Moth image files present, **zero missing
dependencies**, about **86.5 GiB free**, and **zero new masters/GLBs present**.
The versioned binary paths are the requested Blender 4.5.14/Godot 4.5.2; running
their version command remains part of a granted production stage.

After explicit grant, for a selected local unit:

```sh
python3 tools/asset-production/run.py --unit robots --stage build --granted
python3 tools/asset-production/run.py --unit robots --stage reopen-original --granted
python3 tools/asset-production/run.py --unit robots --stage reopen --granted
python3 tools/asset-production/run.py --unit robots --stage receipt-original --granted
python3 tools/asset-production/run.py --unit robots --stage receipt --granted
python3 tools/asset-production/run.py --unit robots --stage import --granted
python3 tools/asset-production/run.py --unit robots --stage native --granted
```

The wrapper acquires the same **nonwaiting** advisory lock as the finish runner,
sets `LP_NUM_THREADS=1`, adds Blender `--python-exit-code 1`, starts only its own
process group, and kills that group on timeout/interruption. Every stage uses a
fresh evidence directory. A completed command never marks a unit accepted.

For vehicles: run `--stage recipes`, import the baseline project, then the native
`fallback` stage **before build**, followed by build/reopen/receipt/import/native.
For scenery: build, `reopen-original`, generic reopen, receipt, import, native,
then `capture`. Vesper/Stormglass have `reopen-original`; Abyssal uses generic
`reopen`. Generic reopen independently opens all masters **and imports all GLBs**.
Generic receipt rejects absent files, flat-only materials, missing UVs/normal
maps, unsupported topology and over-budget geometry; it records actual master,
GLB, embedded image and source SHA-256s plus measured GLB triangle/surface counts.

The queue records finite per-stage limits (30–1560 seconds). Inspect/revise after
each unit rather than spending one unbounded process on every asset. Capture
stages requiring a display inherit the granted environment; no software-rendered
timing is labeled hardware/GPU acceptance.

## Moth finish integration and remaining material review

`tools/asset-production/moth_finish.py` uses four existing material-family image
pairs: brushed metal/metal normal, hex paneling, weathered concrete and rough
stucco. It generates restrained swatch-preserving albedo modulation from the
**actual images**, connects their real tangent-space normals at strength .18,
and authors fixed per-face attachment-local UVs at .65 tiles/metre. Scenery's
normalized recipe gets its reviewed physical scale for UV density. Moving
vehicles and rigid/skinned robot parts therefore carry their textures with them.
Robot vertex colors remain a multiplicative palette input; COLOR_0 + texture
export/import is a mandatory review gate, not assumed proven by Python syntax.

No map world-position shader is applied to moving assets. Glass/water/ocean and
explicit emissive/wayfinding materials are preserved. Existing team-color and
wet-original ownership remains in the vehicle adapter. Baseline Moth libraries,
operator finishing, map dressing and accepted GLBs are unchanged. The helper
caps material count and packs bounded texture resources into exports; source
image hashes and finish version are saved in editable masters.

This is a required finishing step, not an unrendered art approval. After build,
inspect UV seams, scale, normal orientation, close/combat-distance readability,
robot shield overlays, vehicle team/wet restoration, and scenery joins. The
native imported assets must actually contain and display texture detail. Reuse
existing native family/profile APIs for further **static** map finishing only
where appropriate; do not silently recolor or overhaul palettes without images.

## Actual consolidated verification and retained failures

- **43/43** focused source tests passed: robots 6, vehicles 10, scenery 6,
  Abyssal 12 and Stormglass 9.
- Vesper's source suite passed: all 19 routes both directions, **29,276 movement
  ticks**, **2,143/2,143 navigation nodes**, and all **six controlled scored rounds**.
- **4/4 consolidation contracts passed**: exact geometry preservation except
  admission metadata, canonical-wrapper compatibility, fail-closed registration,
  bounded complete queue, actual builder finishing hooks and frozen-source diff.
- Python AST and literal dependency preflight passed. Node receipt syntax passed.
  Generator freshness was checked for the three candidates and scenery.
- `game/`, `port/contracts/source-lock.json`, accepted world catalog, existing
  Moth/operator finish, material families and map dressing diff empty against
  `e38b3662`. Frozen core SHA remains `58ff1b9c…bdb9`.
- Initial preflight `ws` failure is preserved. Initial consolidation test hit
  Node's 1 MiB `git show` output limit on Stormglass; a bounded 64 MiB buffer fixed
  the fixture, with no source/geometry relaxation. Both failures remain recorded
  in this session and source evidence summary.

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/consolidation/`.
Each preflight hashes current recipe/builder inputs independently of HEAD, so
uncommitted source-check snapshots are distinguishable from committed production.
All new native/material/Blender checks are prepared and **unexecuted**.

## Windows release closure

After all units pass, parent integrates approved bindings, robot selection/prop
placements, candidate hosted routes, package resource closure and accepted map
pairs; reruns affected canonical/native checks; builds and tests the Windows
package; and publishes actual native screenshots/clips with asset hashes and
measured capture timestamps. Stage success, historical source rounds, encoded FPS
and missing-asset fallback do not close those obligations. The JSON queue remains
the explicit list of unfinished owner requests until those receipts exist.
