# U production handoff — partial, two geometry blockers

Grant `MOTH-BLENDER-20261003-U` is **released**. Three timestamped owned-group
audits are empty; the nonwaiting shared-lock check passed at
`2026-10-03T19:47:25.728549+00:00`. No queued heavy jobs. Pre-existing viewer/Xvfb
processes were untouched. See `evidence/release-receipt.json` and all original
attempt logs/PGIDs/start ticks in `evidence/attempts/`.

Source-only fixture checkpoint: `68e3f21e`. Later corrections are committed
separately from the actual assets. Foundation includes `32eba401`, `bce5b834`,
and `7ae3f2f5`. No public runtime/profile/catalog/packaging promotion occurred.

| Candidate | Actual GLB triangles | Result |
| --- | ---: | --- |
| Helix revision-3 | 157,166 | Packed editable master; fresh reopen; complete export geometry; native import/material pixels/Binder/Weather; 32,763 finite capsules; 8 before/after pairs pass |
| Parallax districts-v3 | 155,289 | Packed editable master and fresh export produced; expanded aperture verification blocked before native stage |
| Vesper urban-v2 | 64,383 | Packed editable master and fresh export produced; visual/collision ray discrepancy blocked before native stage |

150,000 remains advisory. These are actual exported triangle counts, not the
source estimates. No detail was removed to satisfy a ceiling. Helix retains all
5,240 decorative meshes. Build/reopen reports retain material/image lineage.

## Artifacts and evidence

- Helix master: `tools/godot-multiplayer/new-maps/helix-conservatory/masters/revision-3/helix-conservatory.blend`
- Parallax master: `tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v3/masters/parallax-observatory.blend`
- Vesper master: `tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/masters/vesper-viaduct.blend`
- GLBs: `port/new-maps/MAP/variety/REVISION/MAP.glb`
- Actual build, packed-reopen, evaluated topology and export evidence:
  `tools/godot-multiplayer/new-maps/botanical-stage/evidence/MAP/`
- Helix actual stage/native reports and full 1280×720 PNGs:
  `godot/tests/new_maps/botanical_stage/artifacts/helix-conservatory/`
- Helix collected receipt: `evidence/helix-conservatory/production-report.json`.
- Blocker receipts: `evidence/parallax-observatory/blocked-report.json` and
  `evidence/vesper-viaduct/blocked-report.json`. Both retain exact candidate,
  master, export and failed-attempt hashes. Neither has a ready native manifest.
- Rejected masters, exports, initial cameras, failed physics/native attempts and
  import crash are preserved in timestamped archives/logs under `evidence/attempts/`.

## Remaining geometry blockers

**Parallax:** `portal:court-east-entry:-0.35:0.5` starts at
`[48,12.5,-31.9]` facing `[-1,0,0]`. It hits a saltstone wall at distance zero,
with vertices `[48,-17,-33]`, `[48,16.5,-30]`, `[48,17.25,-33]`.
The broader actual aperture gate is stricter than the earlier centerline source
test. Diagnose the complete wall/aperture and finite capsule envelope before
changing geometry or camera/probe placement. The assertion was not bypassed.

**Vesper:** `solid:roof-run-1.parapet-1` sees JSON collision at approximately
0.15 m and actual exported brick at 0.10 m: a **5 cm discrepancy**, over the
4 cm maximum. The GLB hit is in `kit.authority.brick.00`, at z≈−57.775,
x∈[−72,−64], y∈[26.5,27.2]. It is not among measured new Kit component
triangles. Diagnose the legacy/source authority render contribution against the
compiled parapet. No tolerance increase or speculative acceptance was applied.

Any correction must preserve failed bytes, receive appropriate source review,
and use a **new explicit heavy grant** for rebuild/import/native work. The old U
supervisor has exited. README production commands are historical U commands,
not authority to reacquire that released grant.

## Helix visual and native scope

All eight candidate images and the complete before/after contact sheet were
inspected by the agent. Initial archive/canopy/crown/greenhouse camera views
were corrected against supported ground and rebuilt/reopened/recaptured;
discarded attempts remain archived. Final views show the complete greenhouse,
botanical shelves, grotto archwork, canopy and crown structure, with imported
surface detail. Archive-player is a sheltered corridor view with a foreground
support column; it is not claimed as an unobstructed architectural overview.
The overview is explicitly an overview, not a supported player eye.

Rendering backend is **Mesa llvmpipe / OpenGL Compatibility**, static captures.
Native reports record loading/memory/draw calls/frame cadence; those numbers are
not gameplay FPS. Audio fell back to the dummy driver during captures and was
outside this grant. Hosted modes, actor/team gameplay readability, full manual
visual acceptance and the 142-case matrix remain pending.

Final source checks: **8 harness Python + 27 existing Python + 26 Node** tests
pass, and the standalone same-Kit source checks pass for all three maps. These
source passes do not supersede either actual-export blocker. Helix native
receipts verify exact imported embedded RGBA8 pixels, full-precision geometry,
material restoration, real WorldMap collisions and unchanged authored heights.
