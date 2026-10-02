# Gravemill revision 3 production record

Geometry: `8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f`.
Recipe SHA-256: `3c7f9242bb7c98000871b27d58d14c719a4867e1a9fc625b106c97f7c1c608eb`.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/revision3-production/`.

## Checkpoint preservation and promotion

The original prototype remains reproducible at `afbe57dc` / `ec041aee`. Before promotion, the old GLB, editable master, source/derived wrappers and native probes were copied into `checkpoint-afbe57dc/`, SHA-256 checked, and made read-only. Existing prototype screenshot/clip directories were not reused. The old source recipe is now `checkpoint-recipe.mjs`; production `recipe.mjs` delegates to revision 3. Source game rules, server derivatives and the original seven maps' assets are unchanged.

`revision3/promote.mjs` validates the archived identities before promoting candidate geometry and assets. New probes and all native drivers live under `godot/tests/new_maps/gravemill_foundry/`; the obsolete runtime probe JSON is removed. Test scripts are not preloaded by exported art.

## Architecture and actual review

The first Blender/native revision-3 review established distinct process buildings but exposed rectangular exterior benches, unframed roof spans and a dark assay Blender view. The final art pass adds clear-span folded crusher frames, pitched assay rafters, kiln arch joints/courses, flush assay inspection instruments, and irregular faceted stratified exterior benches. Warm kiln mineral contrasts with charcoal steel and oxidized copper. Neither the gameplay geometry nor its hash changed during the cosmetic refinement.

Native inspection uses the production binder, eight material batches and its actual default environment. Interior cameras are at the source standing head height **1.45 m above support**. Crusher maintenance, cooling cross-aisle and assay inspection/room views supplement longitudinal corridor images. The cooling barrel vault and assay's pitched divided control rooms are visibly different. Blender Cycles enclosure reviews remain darker than native ambient lighting; the actual native imagery is the gameplay appearance reference.

## Exact imported art / collision proof

Godot's default mesh compression initially shifted art vertices by several millimetres. The scoped GLB import now disables mesh compression and generated LODs. At 1 mm comparison precision, **all 2,312 architectural wall triangles and 824 non-walkable surface/overhead triangles match the imported visual mesh**. Eight explicit outer map-edge containment triangles are intentionally not depicted as wall art; the geological exterior is presentation scenery.

Production collider checks pass **1,026 support rays and 1,026 standing capsules**, the original 160 mineral-wall contact steps, **600 additional contact moves from both sides of new building walls**, eight gallery/window tests, four district ceiling rays, two assay inspection-window/lintel rays, and the 13 m conveyor underside. **3,158 gameplay collision triangles**. Ground visual material inlays subdivide the same original support planes; they do not add raised floors.

Failed attempts `physics-attempt-01/02.log` preserve the quantization discovery; attempt 03 identifies the deliberately omitted boundary visual triangles. Attempt 04 passes architecture/collider matching. Attempt 05 additionally compares all **1,026 imported-art floor rays**, with maximum visual/support difference **0.035 m** from shallow trim/sleepers, and is retained as `physics-final.log`. The visual-ray test uses a temporary, isolated test-only collision layer after production checks; it does not add art collision to the shipped scene. All three serial import commands exit cleanly.

The first hosted combined-arms attempt exposed a fixture timing bug: the controller advanced beyond its last drive waypoint while waiting for the native dismount input to be acknowledged. It is now guarded at the final waypoint, and interval exceptions propagate through the fixture's `finally` teardown. The failed log is `combined-arms-failed-attempt-01.log`; no source physics or vehicle rule was changed. Process inspection after the failed attempt found no remaining owned native process.

## Source validation

All ten routes traverse in both directions; all 22 gameplay markers are reachable in **3,698 connected navigation nodes**. The mounted source Puma completes the unchanged **767.64 m, 13-segment lap with zero collisions**, then releases its seat. The 363.60 m payload path delivers all three checkpoints. All six controlled source rounds pass; architecture-specific source actor/ray/aperture checks also pass.

Separate autonomous observations use six unmodified source bots and a stationary human seat. Domination ends at 64.8 simulated seconds with one captured zone and a blue 50-point victory. Payload bots advance **156.17 m**, reach checkpoint one and record five kills in 120 seconds; that bounded autonomous payload round **does not finish**. Controlled round proof and autonomous participation are not presented as competitive-balance validation.

## Measured asset and CPU budget

Final GLB: **69,870 triangles, 8 material/mesh batches, 3,744,260 bytes**. Editable master: **40,527,432 bytes**, 7,086 editable architectural/source objects; reopened master contains 7,103 objects including eight export batches, eight cameras and the review sun. Nine material datablocks include the unused default; eight materials are used/exported.

Blender 4.5.14 generated/exported the final asset in **0.888 s** inside the process. Five 1440×900 CPU Cycles views, 16 samples / one thread, took **333.31 s total**, including generation (30.95–81.34 s per view). The saved master reopened and reported the matching geometry hash. This measures bounded software work, not GPU frame rate or physical PBR fidelity.

## Hosted native outcomes

Every row is two production-native peers, ordinary serialized input through source authority, controlled setup/passive opposition, and matching-hash result receipts from both clients.

| Mode | Source simulation time | Controller updates | Outcome |
|---|---:|---:|---|
| Payload | 150.000 s | 2,853 | All three checkpoints, delivery, 3–0 |
| Combined arms | 68.883 s | 1,294 | Mount, 77.17 m drive with bend, fire, dismount, zone capture, 50-point win |
| Deathmatch | 110.900 s | 2,104 | Five kills, completed round |
| Assault | 62.883 s | 1,178 | Three sectors, attacker victory |
| Domination | 28.800 s | 521 | Capture and 10-point victory |
| Team deathmatch | 67.100 s | 1,259 | Five kills, 5–0 victory |

Combined arms produces **132 actual source mounted shots**; both native peers receive **132 `vehicle-shot` events**. Host final acknowledgement = 1,191 / 1,191 inputs sent; guest = 1,190 / 1,190. These are actual source event receipts, not an input-only firing claim. Complete logs retain the ordinary authority snapshots and movement samples.

## Wide/compact UI and continuous clip

Both normal-input eight-stop district walkthroughs completed. Wide: **1280×800, UI100**, 114.2 simulated seconds, 808.48 m walked. Compact: **760×520, UI150**, using the real LocalSettings scale. Actual source HUD, full wrapped help text, acknowledgement progression and the existing scrollable ability card were inspected in both sizes. A further **compact rendered payload full round** also completes three-checkpoint delivery; its captures show objective role/progress text without overlap with the ability card. The only shared UI change is a Foundry-ID-scoped wrapping/width/font hook in `multiplayer_worlds/demo.gd`, committed separately.

`wide/walkthrough.mp4` is a continuous **53.229-second** crusher → cooling → assay segment, **518 captured frames**, actual **9.713 captures/s**. Median inter-frame gap **99 ms**, p95 **128 ms**, maximum **243 ms**, **zero gaps above 250 ms**. The encoded MP4 is 15 fps, resampled using measured timestamps. This does **not** claim 15 fps capture or GPU performance. Software capture uses llvmpipe, `LP_NUM_THREADS=1`, 0.75 3D scale, full-resolution UI, and disabled sun shadows; default-lighting static native views remain separate. Full-resolution district screenshots and decoded clip contact sheet were inspected. The complete unedited input walkthrough is longer than the encoded three-district segment; each is labeled separately.

Default-lighting static inspection contains **5,564 nodes**, including production's per-face collision bodies. Overview: **8 art draw calls / 69,870 submitted primitives**. Shadowed eye views: **38–40 draws**, up to **349,350 submitted primitives** including shadow passes. Ten captures plus scene construction took **6.70 s** in that logged run. This is a bounded capture workload, not an interactive frame-rate benchmark.

## Teardown and release

**EXPLICIT ENGINE/BLENDER SLOT RELEASED.** Every owned Blender, Godot, hosted journey/server, Xvfb-run child and encoder completed/stopped. Final process inspection found no Blender, Godot, journey, encoder or probe process. No further heavy work is queued by Foundry. Parent's combined-native candidate has priority over additional asset work. Final architectural acceptance remains the parent's review of the supplied actual native images.
