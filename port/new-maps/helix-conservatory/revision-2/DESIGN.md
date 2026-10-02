# Architectural revision 2 — READY FOR SECOND BLENDER PASS

**Source candidate only. No revision-2 native or visual acceptance.** Parent rejected the visual/spatial sufficiency of the functional checkpoint `becef6b4` + `96174a63`. Those commits and their GLB/native reports remain historical. This revision is staged here rather than silently replacing their runtime JSON, assets or advertised-mode registries. No Blender/Godot process was used for this revision; the slot belongs to other workstreams.

## Spatial design

The 240m radial site retains 0/8/16/24m walkable tiers and its fifteen primary circulation routes. Architecture occupies district edges, with openings where the reserved circulation ribbons intersect. Roofs are non-walkable: source support never needs to choose between overlapping decks.

* **Seed archive crescent:** 156–220 degrees, radii 44.5–70m. Three vaulted roof bays, deep outer alcoves, a warm masonry retaining enclosure, clerestory glazing and internal stack partitions. The public ring aisle connects to a narrower inner research aisle and outer service aisle. Its long curved ceramic vault/spine silhouette differs from the machinery district.
* **Filtration works:** -24–25 degrees, radii 44.5–76m. Three stepped solar sawtooth bays, a glazed facade, low retaining walls, pump-bank islands, pipe banks, settling/filter vessels and a tall pressure tower. A maintenance aisle runs inside; a second passage follows the exterior machinery edge and rejoins through a real opening in the facade wall. Water-channel detailing remains a visual-pass refinement; the asymmetric machinery layout and source-tested passage already exist.
* **North germination pavilion:** 68–96 degrees, radii 80–94. A substantial glazed curved barrel vault over the canopy route and objective, warm plinths, deep metal trusses, work benches and a separate inner chamber aisle. Glass remains shot-transparent; framing and plinths use authoritative geometry.
* **Lightwell specimen lantern:** four brick root supports branch into a gold/verdigris double helix and glazed specimen vessel, capped at approximately 25m. Ground-level supports interrupt diagonal crossfire while preserving the axial path, ring and capture area. The specimen mass is overhead; the ground is playable.
* **Terraced botanical banks:** contiguous raised soil sectors, densely folded fronds and route gaps in three radial bands. Large soil/warm masonry/verdigris floor districts replace uninterrupted pale floor fields.
* **Structural crown:** grounded bearing shoes support paired tapered I-sections, diagonal webs and gold node collars. Three substantial circumferential ties support segmented glazing and solar bays. This replaces the checkpoint's thin rib/grid treatment.

These are authored source meshes, not a render-only replacement. Every solid standing wall is emitted as individual triangles with projected full-height diagonal edges. Roof/beam surfaces block source rays but are not walkable. Glass and botanical mass have no collision. The wide district roofs deliberately occlude parts of the overview; later inspection must assess orientation and flank readability at eye level, rather than maximizing overhead visibility.

## Traversal and source acceptance

Five additional playable variants:

1. `archive-inner-research-loop`
2. `archive-outer-service-loop`
3. `irrigation-maintenance-bypass`
4. `irrigation-external-service`
5. `pavilion-inner-chamber-aisle`

**15/15 source tests pass** (`revision-2-source-05.tap`): five layout/support/movement/ray/navigation tests, three new architecture/drape/contact tests and seven controlled scoring-completed rounds. Actual `moveActor` traversal covers all twenty routes in **29,619 ticks**; graph has **2,573 nodes / 26,618 directed edges**, connecting every spawn to every objective/pickup. Tests verify route centerlines and actor clearance; they do not establish competitive passing width everywhere or human balance.

Six both-side sustained body contacts (720 ticks each) and matching shots cover archive, lab and pavilion walls. Glazed facade and maintenance portal rays pass. Every broad inlay triangle centroid clears its supporting terrain by 0.045m. Budget check asserts 100k–150k recipe triangles and fewer than 100 planned mesh surfaces. Seven controlled rounds include three CTF captures with actual walking, no post-setup actor/objective writes and zero falls. These are source fixtures, not native/network or autonomous bot results.

Earlier failures are retained: external service route intersected a vessel/machinery edge and then the facade wall; machinery/passsage were repositioned and a true portal added. The pavilion inner aisle intersected a bench; benches now occupy the outer work zone. No collision was simply disabled to make those tests pass.

## Floor-pattern diagnosis

Source measurements of the checkpoint found 7,296 fine masonry triangles at centroid clearances 8.667–12mm, with none penetrating the floor. The speckling there is consistent with thin-line/distance aliasing, not proven coplanar z-fighting. **49 of 4,480 old inlay triangles** did penetrate their floor at centroids (minimum -0.214207m); unsplit strip chords crossed changes in the radial terrain planes.

Revision 2 removes the fine masonry lattice entirely. Material zones recolor actual floor faces, so they add no coplanar duplicate surface. Inlays are 0.55m broad strips, geometrically clipped against the authoritative floor triangles and lifted 45mm. The source drape test passes; actual rasterization/aliasing improvement still requires the second Blender/Godot image review.

## Candidate identity / budget

* Geometry hash: `f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2`
* Recipe SHA-256: `6ba9c6529568836ad4b3b69663c8160b6bc8cddc201b077294136441fe03484b`
* **137,928 recipe triangles**, 10,331 editable parts, 2,864 body-wall triangles.
* **10 palette materials**, **22 planned material/authority batches + 3 labels**. Converted text triangles, native import node count, actual draw passes and frame rate are not yet measured.
* Source pins remain `515daf` / `0326`; candidate native accepted modes is empty.

Artifacts: `recipe.json`, `authority.json`, `provenance.json`, `source-validation.json` beside this document. The production runtime wrapper remains the old functional geometry until explicit parent approval to replace it.

## Reproduction and next granted pass

From the worktree root:

```sh
node tools/godot-multiplayer/new-maps/helix-conservatory/build-v2.mjs --check
HELIX_ARCHITECTURE=2 HELIX_WRITE_SOURCE_REPORT=1 node --test tools/godot-multiplayer/new-maps/helix-conservatory/acceptance.test.mjs tools/godot-multiplayer/new-maps/helix-conservatory/source-rounds.test.mjs tools/godot-multiplayer/new-maps/helix-conservatory/architecture-v2.test.mjs
```

The existing Blender author supports `-- <workspace-root> --revision=2`; it reads this candidate and writes **staged** `revision-2/art/` GLB/report and `tools/.../masters/revision-2/` editable master. Python syntax was checked using `ast.parse`, without importing `bpy`. It has not executed. Use only after a fresh exclusive grant, with `LP_NUM_THREADS=1` and Blender threads 1.

Production probes moved to `godot/tests/new_maps/helix_conservatory/{inspection,physics_probe,journey}.gd` and `journey.tscn`; runner references updated. These currently target the historical runtime wrapper and their old fixture coordinates. Before testing revision 2, explicitly stage the new runtime wrapper/GLB and update district-specific native contact/camera coordinates; do not run them against old art and claim this candidate passed. Parent export closure must exclude the test directory.

Next grant: export/reopen the candidate master; inspect overview and archive, filtration, pavilion and lightwell eye levels; refine shapes/materials based on actual images. Validate all new native contacts and routes, rerun affected hosted modes and autonomous checks, and measure draw passes/frame pacing. Target **760×520 at 150% UI**, readable objective/help/results and a smooth walkthrough **≥15fps if available on the capture budget**. The historical 640×400 clipped HUD capture does not meet this gate. Do not claim full-motion footage if sampling is necessary. Dedicated-GPU performance and human balance remain separate acceptance work. The previous four-bot CTF timeout remains historical, and no forced autonomous win is required.
