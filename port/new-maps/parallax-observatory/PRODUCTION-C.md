# Interiors v2 production — grant C

Grant: `PARALLAX-INTERIORS-PRODUCTION-20261002-C`.
Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/production-c/`.

## Parent reconciliation

Started from clean tracked `3e9bf9e5`; merged pinned parent `bb02e34b` as
`ec364095`. Catalog conflicts retain the union of parent Helix/Foundry pairs and
the six historically demonstrated Parallax pairs. `routes.json` was regenerated
from the merged route metadata. The explicit nested Parallax GLB coverage branch
and the parent's surface runtime are both retained. `f2c82794` is an ancestor.
No source game/server changes were authored. Route/options/dressing resource
tests pass (18 checks). Parent package/export closure is still parent-owned.

## Candidate isolation and dressing

Candidate build/reopen/native outputs live in the revision's ignored `output/`;
owned command logs and process receipts live in the evidence root. The previous
accepted master, GLB, manifest and dressing source-check are also copied into
`production-c/accepted-backup/`; their immutable history remains available.

The parent's refined six material bindings are retained verbatim. The previous
archive/pump wall overlays target removed flat cabinet faces. Local authoring
retires those overlays and mounts mineral strips on the continuous sill faces,
exposing the equipment anatomy. Native validation rejected four proposed cap
labels as too short to read; they were removed in favor of the existing large
entry-jamb signs. Final identity-pinned GLB validation proves all 25 backing
sample points on each of **36 mounts (26 panels, 10 signs)**. Six refined material
bindings and five mote pockets remain. No shared shader was edited.

Historical six-mode receipts remain anchored to the old accepted asset. Current
candidate receipts are separate and do not relabel historical results.

## Actual output and review

Blender 4.5.14 built the candidate and a separate process reopened the compressed
master, then exported a **byte-identical GLB**: 147,103 triangles, seven batches,
8,621,072 bytes; 24,290 editable objects. `master-reopen.json` records that result.
The geometry hash remains `906be2ae3df33f54f779df3963a5985376ac96bb75bda94578ca4d3deb6d4554`.

Actual Blender archive/pump/overview/polar PNGs were opened and inspected. Native
1280×800 Off/Full pairs show the cassette spines, shelves, retrieval crossheads,
transfer drawers and ceiling trusses in the archive; the pump has flange/volute
faces, risers/headers, motor cases and wide unequal ceiling ducts. Portal openings
are clear. Full uses the parent's warm neutral coastal profile: no lavender plate
wallpaper, luminous instrument overlay across machinery, or all-over hazard mask.
Metal and optical dishes retain distinct muted gray response; gold markers remain
coated rather than glowing. Full is softer/lower contrast than Off, but equipment
silhouettes and sightlines remain legible. The polar radial composition and exterior
mass are preserved. Parent visual acceptance remains a separate decision.

Native physics passes exact source triangle parity, all 60 block bounds, 859
support rays and capsules, both-face wall contacts and all five ceiling contacts.
Six imported-art float32 edge probes still need the documented 1 cm offset;
independent exact-center GLB support audit passes within 0.8 micrometres.

The initial headless physics log captured the rejected short-label diagnostics
and dummy-renderer exit leaks. The final graphical physics log has no test failure
or script/error diagnostic. The editor import completed resource processing but
crashed at editor startup/exit; a graphical editor retry also crashed. Both logs
are retained. Runtime validation uses the resulting imported assets and independently
loads the candidate GLB for comparison/probe evidence.

## Reproduction after promotion

Packaging contract `78826ea4` is honored: the original master remains at
`tools/godot-multiplayer/new-maps/parallax-observatory/parallax-observatory.blend`;
the revised master is committed at
`tools/godot-multiplayer/new-maps/parallax-observatory/revisions/interiors-v2/output/parallax-observatory.blend`.
The runtime GLB is promoted at its existing named art path. Current audit/profile
validation binds the revised master explicitly. Parent owns the final
`tools/godot-package/production_receipts/` promotion receipt and package closure.

The source-only adapter deliberately pins the prior accepted master and GLB.
After promotion it refuses to treat revised files as those inputs. For another
deterministic build use a separate clean checkout of `3e9bf9e5`, run its README
commands under a new grant, and use the current `reopen_candidate.py` for the
additional fresh-process re-export. Do not regenerate the original source-check
against promoted assets or weaken its identity guards. Current profile validation
uses deliberate `interiors-v2-pins.json`; `PARALLAX_CANDIDATE_DIR` allows isolated
candidate inspection with the same exact hash guards.

## Current hosted input and capture scope

The current-asset walkthrough visits archive +12, polar +24, arcade +12, pump +0
and lens +12 using ordinary native input through the production source server.
It records 1,471 input events and acknowledgement 1,131; all four wide/compact
gameplay/help checks pass. Its 1,105 sampled frame images span 390.318 seconds:
2.828 fps, median/max gaps 352/836 ms. No movie was encoded.

An additional current full deathmatch ends with five frags, using the final local
HUD hook and revised imported asset. It asserts the runtime mesh contains exactly
147,103 triangles, GLB/profile hashes match, and dressing is ready with no errors.
It records 790 input events and acknowledgement 507; wide/compact results/help
checks pass. Its 51 event-gated frame images average 0.698 fps with a 14.499-second
maximum gap; these are combat samples, not a continuous motion benchmark.

The first walkthrough exposed the parent's transient combat-quality hint at the
same screen row as this map's HUD. The final map-local hook moves it below the
HUD without disabling its controls; the original shared implementation is intact.
The walkthrough precedes that HUD-only fix; the later DM includes it.

Producer evidence in `production-c.json` binds current inputs, runtime hooks,
actual exported/master hashes, reopen/physics evidence, image hashes and both
hosted journeys. It is intentionally distinct from the parent-owned package
promotion schema.
