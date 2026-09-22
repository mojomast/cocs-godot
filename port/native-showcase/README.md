# Prism Foundry

A new, standalone Godot-native first-person exploration map. Enter a 36 m reactor atrium, climb either ramp to its four-metre upper loop, explore the turbine hall and coolant garden, and walk onto the cantilevered Salt Reach observation deck.

**Entry:** `res://showcase/demo.tscn`

**Launch/build/CI and optional visual rig hooks:** [HANDOFF.md](HANDOFF.md)

The default experience is walking with native collision. WASD moves, the mouse looks, Shift sprints, Space jumps, Escape releases the cursor, clicking recaptures it, and R returns to arrival. F1 shows compact help. P enters optional photo viewpoints, `[` / `]` change views, and P returns to the physical explorer. F2 hides the HUD.

## Verification

Pinned Godot **4.5.2.stable.official.6ce3de25a**, native **GL Compatibility**, Mesa **llvmpipe (LLVM 20.1.8, 256 bits)**. Tests use isolated HOME/XDG directories and a private Xvfb with TCP and filesystem Unix listeners disabled. No gallery/server service is involved.

* [Final physics / native input / smoke summary](evidence/run-frjb31yu/summary.json): all pass. **49 native physics/lifecycle checks**, including a complete walking route through both ramps, every side of the upper loop, all rooms, exterior guards, walls, sprint, jump, an actual gravity fall outside the platform followed by reset, lateral bounds, R, focus clearing, photo return, stable node count, freed map/player/cameras, released cursor and restored caller viewport MSAA.
* [Actual X11 input evidence](evidence/run-frjb31yu/native-input.json): eight checks using OS-delivered keys, relative mouse and native window focus changes. Focus is removed while W/Shift are held; position then remains stable, keys clear, and mouse capture releases. Click, look, jump, Escape, R, P and next-view input work through the native window.
* [Final native gallery](evidence/run-sozpvb9r/summary.json): six views at each of **960×640 and 1280×800**, all dimension assertions pass. All twelve final images were opened with the image-read tool and inspected. The last change after the input run only aligns the non-colliding foundation's visible lower wall seam.
* [Project import and complete preceding run](evidence/run-biio2y4s/summary.json): import, parser checks, physics, smoke, native input and both image sizes pass. Later changes restore viewport MSAA on teardown and refine non-colliding foundation visuals; the applicable checks were repeated afterward.

Reproduce with:

```sh
python3 port/native-showcase/verify.py
```

Use `--steps=parse,physics,smoke,native-input` or `--steps=gallery` for a focused rerun. All test captures assert their actual image dimensions. A native renderer is required for input tests: the headless display backend does not implement captured mouse mode.

The physics route runs native X11 Godot with fixed 1/60 s physics and the render loop disabled to accelerate collision verification. The smoke, OS input observer and gallery all render through native GL. Accepted logs contain the expected llvmpipe V-Sync warning and no script, shader or resource errors.

## Final images — actually inspected

| View | 960×640 | 1280×800 |
|---|---|---|
| Arrival / actual first-person camera | [Image](evidence/run-sozpvb9r/spawn-960x640.png) | [Image](evidence/run-sozpvb9r/spawn-1280x800.png) |
| Reactor and upper loop | [Image](evidence/run-sozpvb9r/atrium-960x640.png) | [Image](evidence/run-sozpvb9r/atrium-1280x800.png) |
| Turbine hall / eye level | [Image](evidence/run-sozpvb9r/turbine-960x640.png) | [Image](evidence/run-sozpvb9r/turbine-1280x800.png) |
| Coolant garden / eye level | [Image](evidence/run-sozpvb9r/garden-960x640.png) | [Image](evidence/run-sozpvb9r/garden-1280x800.png) |
| Salt Reach / deck eye level | [Image](evidence/run-sozpvb9r/vista-960x640.png) | [Image](evidence/run-sozpvb9r/vista-1280x800.png) |
| Exterior overview | [Image](evidence/run-sozpvb9r/overview-960x640.png) | [Image](evidence/run-sozpvb9r/overview-1280x800.png) |

Inspection findings:

* Arrival frames the cyan faceted engine and copper rings between the two obvious ramps. The floor title and the small HUD remain readable at 960×640.
* The upper view exposes the continuous catwalk, sloped treads, truss shadows, moat, knees and room portals. Concrete mottling and the metal grid texture remain visible without dominant neon texture patterns.
* Turbine views show curved brushed-metal casings and copper bands contrasting with the rough floor and dark rotor blades. The hall is visibly more enclosed and warmer than the atrium.
* The garden is a bright, open pergola with alternating slat shadows, narrow planted islands and visibly distinct blue coolant surfaces. Its distant 3D title is subtle at 960×640; the zone HUD supplies the readable area name.
* The deck frames the distant solar receiver and layered low-poly mesas. The final overview shows the foundation seated in the salt bed, the roof's open central strip, the pergola and the genuinely cantilevered observation deck. The previously overlapping foundation/floor seam is gone.

## Runtime bounds and rough rendering cost

Final scene: **405 nodes, 92 static collision bodies, 996 repeated/static box instances in 12 MultiMesh batches, three animated rings, two turbine rotors, 48 CPU particles, one shadow-casting directional light, and three unshadowed omni lights**. No per-frame node creation. Moth materials are shared, and all animations update existing transforms or shader time.

Native gallery measurements below are **mean wall time between rendered frames across 12 samples**, including engine/driver work. They are llvmpipe observations, not hardware-GPU acceptance or a GPU-only benchmark. Short-window software timing varies; the 960×640 vista sample is slower than the larger capture and is retained as measured.

| View | 960×640 ms/frame | 1280×800 ms/frame | 1280×800 draw calls |
|---|---:|---:|---:|
| Arrival | 85.4 | 105.1 | 709 |
| Upper atrium | 85.7 | 106.7 | 550 |
| Turbine hall | 55.9 | 80.3 | 179 |
| Garden | 41.1 | 58.5 | 324 |
| Vista | 72.7 | 35.7 | 72 |
| Overview | 68.4 | 72.8 | 477 |

Full counters: [960×640](evidence/run-sozpvb9r/gallery-960x640.json), [1280×800](evidence/run-sozpvb9r/gallery-1280x800.json). Rendered primitive counters range from about 69k to 249k at 1280×800, including render passes. The [final four-second smoke](evidence/run-frjb31yu/smoke.log) sampled 36 frames after initial warmup with an 84.4 ms mean at 960×640. Compared with the first capture, native static batching reduced the arrival draw counter from 1,196 to 709 while the authored geometry gained detail.

## Visual iteration and retained failures

All evidence is retained, including unsuccessful attempts:

* `run-0j05k56i`: initial harness invocation was interrupted by an accidentally short tool timeout. Its two-line import log is incomplete, not accepted.
* `run-7u8utxym` and `run-2edndqn2`: initial environment reflection enum names were invalid. The first scene could not start and timed out; its early summary only covers import. The native log also records ALSA fallback errors. Fixed by using the sky-background reflection default and explicitly selecting the dummy audio driver for this silent scene.
* `run-5fqnxrpa`: parser rejected inferred Variant weak references in the test. Fixed with explicit `WeakRef` typing.
* `run-0wu0zs51`: attempted headless capture/input verification failed. Replaced with native X11 capture, retaining actual CharacterBody physics and physical-key event delivery. The separate XTest driver then verifies real OS events.
* `run-7ys_hq7n`: native traversal found center piers obstructing the direct room portals. Piers were moved to the portal edges. The test's sprint measurement was corrected to account for acceleration, and its garden route was changed to use the walkway around a raised basin.
* `run-autdl5_5`: the guard test walked into the telescope before reaching the rail. The final route explicitly walks around the solid telescope, then reaches and tests the exterior guard.
* `run-evi3t36z`: first image set revealed washed-out surfaces, smooth cone-like scenery, coarse reeds, and low-contrast HUD text. Images were opened and used to reduce sun intensity, refine roof shading, strata, planting and HUD backgrounds.
* `run-p1hhfne3` and `run-7zpz0crq`: intermediate captures document the resulting architecture/material improvements, reduced draw calls, flat-faceted core and improved signage.
* `run-biio2y4s`: lowering sky fog contribution exposed a dark ground-sky band and made the missing visible foundation obvious in the overview. The final sky ground color is horizon-matched, and the building now has a foundation extending into the salt bed.
* `run-0nf9296n`: final overview inspection found coincident foundation/floor side faces. The foundation tops were aligned exactly with the floor bottoms to remove that seam; the final gallery was recaptured.

## Scope and known limits

This delivery is unarmed local exploration. It makes no combat, campaign, networking, source-authority or nine-map simulation acceptance claim. Existing source maps/catalog/session code and reserved weapon/player assets are outside this delivery. The lead applies the separate experience launcher and package hooks.

The landscape is deliberately low-poly background scenery; only the foundry is walkable. Coolant is an opaque animated surface, not a fluid simulation. The scene is silent. Directional shadow edges show some software-renderer aliasing, and the sunlit garden is intentionally high-key. Photo viewpoints are fixed cameras, not a replacement for traversal. Hardware-GPU performance, exported packages and launcher integration still need lead-side acceptance.
