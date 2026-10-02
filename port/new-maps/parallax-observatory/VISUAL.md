# Parallax Observatory — inspected production presentation

Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/`.
Final GLB: `b3ea4ec57f57f6db83e1acab40dc95135562347ef884cc8f33ba067af8521bb1`.

## Actual architecture review

The final native `native-review/overview.png`, `archive-interior.png`, `pump-interior.png` and `polar-interior.png` were opened and inspected. Earlier arrival, cistern and lens views drove the facade/paving refinement; the final set is retained alongside the Blender CPU renders in `blender-review/`.

- **Overview:** connected three-tier coastal institute with substantial source-backed cliff facades, repeated instrument bays/pilasters, roof lanterns, six institute wings, two large broken-petal dishes, armillary rings and slotted domes. The deep channels expose structural depth and preserve readable crosslinks.
- **Plate archive:** metal photographic-plate wall cabinets, engaged piers/dados, ochre ceiling ribs, wall-bound source cover, broad open axial portals and calibration paving. The next outdoor junction is visible through the exit.
- **Tidal pump vault:** dark cistern paving, ochre instrument panels, pressure pipes/dials, separate low cover and a through-route to the coastal return flank. Its palette and fittings distinguish it from the archive.
- **Polar hall:** four source-clear portals, wall spectrometers, an azimuth measuring floor, radial ceiling coffers and aligned views of the main dish. The roof is inaccessible source overhead; the floor is the supported +24 m tier.
- **Arrival/instrument districts:** facade wings, deep fluted vault portals, optical arcade, source cover and survey inlays frame the route choices. Cliff windows are visibly solid-backed ornamental bays, not extra enterable rooms.

The first sparse build, intermediate flat facades, over-bright native views and overlapping decorative inlay were retained as failed/rejected review evidence. Architecture was revised from those actual images. Triangle count was used only as a budget gate.

The presentation is deliberately faceted and flat-shaded. Water is static scenery below the lethal source void. Only the source-supported routes/interiors are playable; the inaccessible roof lanterns, cliff facade bays and monumental instruments do not imply additional walkable floors. Parent visual acceptance and package/export review remain separate from these recorded local checks.

## Native UI and capture evidence

Final capture session directories are `native-walkthrough/`, `visual-ctf-final/`, `visual-koth/` and `visual-deathmatch/`. Each has a `native-journey.json`, source outcome, ordinary wire-input log, teardown receipt, full-viewport PNGs and timestamp-derived clip receipt. `visual-validation.json` indexes their actual image hashes, viewport bounds and measurements.

The viewport presets are 1280×800 / 100% UI and 760×520 / 150% UI. The scoped runtime HUD wraps objective text, provides an opaque backing, omits empty rows, and switches to the F1 route guide without stacking it over the objective block. Capture checks inspect the visible rectangle of every native Label against the logical viewport, accounting for its clipping ancestors; actual screenshots are also reviewed for wrapping, occlusion and readability. The shared ability-detail panel intentionally scrolls at compact size; release the pointer with Esc to interact with it. Its clipped contents are not claimed to be simultaneously visible.

Gameplay capture uses llvmpipe software rendering with shadows disabled and 0.65 3D scale. The viewport itself remains full-size. Reported process-frame milliseconds include this software workload. Static architecture inspection uses shadows and full-size rendering; its draw counts include shadow passes and can exceed the seven material batches.

Clips are made from actual native viewport images. `clip.json` records frame count, timestamp span, actual captured fps, median/max gaps and file size. Encoding resamples to 15 fps through frame duplication; it is not a 15 fps rendering claim. Hosted fixtures use normal native key/mouse sampling with controlled passive opposition; they are not autonomous competitive-play demonstrations.

The continuous walkthrough visits the archive (+12 m), polar hall (+24 m), optical arcade (+12 m), pump vault (+0 m) and lens dais (+12 m), all via normal input. It captured 1,567 frames across 257.848 seconds: **6.073 fps**, median gap 162 ms, maximum gap 382 ms. The CTF lower flag-carrier segment captured 444 frames across 69.698 seconds: **6.356 fps**, median gap 155 ms, maximum gap 196 ms. These are the primary motion clips.

KOTH and DM clips are supplementary event-gated samples, with real-time holds between capture bursts. KOTH has 98 frames over 72.943 seconds (**1.330 fps across the whole span**) and a 29.051-second maximum gap; it must not be described as continuous 6 fps gameplay. DM has 55 frames over 64.946 seconds (**0.831 fps across the whole span**) and a 15.821-second maximum gap. Their complete source rounds still finished through ordinary native input.

Measured software process-frame cost: walkthrough p50/p95 **133.33 / 144.44 ms**; CTF **118.41 / 138.89 ms**; KOTH **125.00 / 138.41 ms**. These are software/capture-preset observations, not hardware GPU benchmarks. Native static-view draw counts and end-of-session gameplay draw counts are recorded separately; the latter are individual sampled frames, not peak or average draw counts.

Final walkthrough gameplay/help and CTF/DM results were opened at compact 150% scale; wide KOTH results and the architecture views were also inspected. Objective instructions and final DM statistics wrap within the full viewport. The existing source has no non-null team-winner field for the DM round, so that field is omitted rather than inventing a winner. The decoded beginning/middle/end review strip from the actual walkthrough MP4 is `walkthrough-decoded-review.png` in the evidence root.
