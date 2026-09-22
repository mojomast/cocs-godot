# Independent ADS and combat-shield review

**Result: one reproduced P2 shield allocation defect; no blocking ADS defect found in the reviewed rig.**

Reviewed deliveries: ADS `da6a8ab`, combat shields `c8cae07`. Review date: 2026-09-22.
All additions are confined to this directory and `godot/tests/combat_expansion_independent/`.

## Actionable finding — SHIELD-CAP-ORDER (P2)

**Low quality can suppress the only protected actor because unprotected actors exhaust its material slots.**

In `godot/combat_shields/controller.gd:180–199`, every valid actor acquires a render slot before its protection kind is evaluated. `_claim()` at lines 142–152 stops at the quality limit. Consequently, actors with no visible effect occupy the entire pool; a later protected actor never enters `tracks` and cannot display its shell or receive its transient events immediately.

Independent reproduction, executed and rendered at both resolutions:

1. Configure a controller and select `low`.
2. Deliver 17 valid alive actors, IDs 0–16, with local ID `-1` and a camera six metres away. Actors 0–15 have no armor/protection/pools. Actor 16 has `protection = 1`.
3. Result: **16 materials, 16 empty protection kinds, zero visible shells**.
4. Reset and reverse the exact same actor array.
5. Result: **16 materials, one visible spawn-protection shell**, actor 16 now tracked.

This is a deliberately replicated visual-capacity fixture, not a claim of a naturally played 17-player session. The size is relevant to source Horde: `game/singleplayer.mjs:22–25` permits 16 live enemies on Normal and 20/24 on Hard/Nightmare, in addition to the player.

Evidence:

- [960×640 ordering comparison](evidence/960x640/shield-order-defect-left-starved-right-reversed.png)
- [1280×800 ordering comparison](evidence/1280x800/shield-order-defect-left-starved-right-reversed.png)
- Both `report.json` files contain `observations[0]` with the exact controller states. **Left is starved; right is the same actors in reversed order.**

**Recommended fix:** decouple bounded actor observation from material ownership, or prioritize visible eligible protected actors when claiming/reassigning slots. Local, dead, seated, camera-excluded and unprotected actors should not permanently reserve the entire render budget ahead of eligible shield owners. Keep enough bounded observation state to preserve healing, respawn and damage-event semantics. Add an ordering-invariance regression with the 17-actor case; simply increasing the cap leaves the ordering problem intact.

The characterization is recorded separately from passing assertions. A successful harness exit therefore means the measured contract checks passed, **not that the identified allocation defect is fixed**.

## Executed independent checks

Pinned engine: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
Compatibility / Mesa llvmpipe LLVM 20.1.8, private TCP Xvfb, private HOME/TMPDIR/XDG paths. No shared gameplay scene or full-repository copy was used.

| Check | Result |
|---|---|
| Independent source oracle | 10 real `Match.damage` scenarios; all ten weapons actually fire; nine source reloads |
| Independent Godot API/render harness, 960×640 | **287 assertions passed**, allocation defect reproduced separately |
| Independent Godot API/render harness, 1280×800 | **287 assertions passed**, allocation defect reproduced separately |
| Supplemental delivered session-binding fixture | **18 assertions passed**; pointer, focus, stale, lifecycle, Arms Race and results gates |
| Render/resource diagnostics | No script/shader errors or resource-leak messages; reset and tree teardown release factory registrations |

The independent harness consumes fresh output from unmodified source APIs. It does not assert implementation text or merely copy the delivered measurement JSON. It compares actual imported mesh vertices with barrel-tip anchors, reprojects live muzzle transforms through an offset/rotated source camera, delivers actual source volley events, reads real framebuffer pixels, and checks controller/material lifecycle results.

### ADS API and geometry results

- All ten weapons passed hip/ADS muzzle counts, actual imported bore-rim placement, and animated world/screen reprojection. Scattergun has two tips; the others have one.
- Largest measured bore-front/anchor axial discrepancy: **0.0000002384 m**. Every tip has actual imported rim vertices on its axial plane. This checks geometry independently of the exporter metadata.
- All ten settled rear/front sight anchors reach the screen center after the caller applies the API's FOV recommendation.
- FOV recommendations match executed `game/reticle.mjs` at base FOV **55, 75 and 95** for all ten weapons. The direct rig does not write the gameplay camera.
- Actual source volleys cause exactly one recoil, including Scattergun's **8** events and Flak's **12**. Re-delivery does not retrigger. Muzzle displacement is **0.01455–0.07540 m**, then returns within 0.00001 m of its ADS rest pose.
- Nine genuine source reload snapshots reject held ADS and return the recommendation to base FOV. **Pulse has infinite ammo and no source reload**; its generic reload-state API check is explicitly synthetic.
- Scattergun's muzzle basis follows its opened break-action barrel, rather than retaining a static firing direction.
- Held aim across weapon switching lowers before entering the new scope. Health/death, spectator, vehicle ID zero, visibility/focus gating and round reset immediately clear ADS and expose the documented hidden muzzle sentinels.
- Source fire received while hidden is consumed and cannot replay as recoil when visibility returns.

**Integration status:** applying FOV and HUD reticle policy throughout the live sessions remains lead-owned verification. The lead's `session_binding.gd` FOV wiring changed while this review was running; it is not treated as a missing-feature defect. The reviewed `rig.gd`, generated weapons and combat-shield implementation still matched their delivery commits when checked. This report does not certify the in-progress combined-application wiring.

### Shield source meanings: executed damage, not inferred labels

Each case starts with sufficient health, controlled source positions and explicit private setup. Incoming damage is 40. Actor **zero is the remote target**, and actor one is the local attacker.

| Source state | Measured health loss | Native classification / result |
|---|---:|---|
| Positive spawn protection | 0 | Spawn-protection shell; no source damage event |
| Generic active harness state (tested OpenClaw setup) | 40 | No invented immunity shell |
| Overshield timer positive, absorb pool empty | 40 | No shield shell |
| Temporary pool 25 | 15 | Temporary shell; actual break event; shell gone after depletion |
| Armor 100 | 16 | Subtle armor-energy classification, not immunity |
| Juggernaut pool 25 | 15 | Juggernaut shell; `damage.shield` remains zero; actual break handled |
| Bulwark, frontal attacker | 12 | Directional reduction, not immunity |
| Bulwark, rear attacker | 56 | Actual source flank multiplier; directional visual remains frontal |
| Bulwark yaw π/2, attacker at -X | 12 | Same source facing convention after rotation |
| Armor 10, fully depleted | 30 | One actual break, shell gone |

Source event replays do not add ripples; events/snapshots remain byte-equivalent after presentation. Actual numeric actor/event zero works; string IDs do not alias numeric IDs. Genuine temporary/Juggernaut/armor depletion produces one break across event then snapshot delivery. Focus out hides visuals, focus in requires fresh state, stale state hides effects, reset frees nodes and registrations, and tree teardown also releases registrations.

### Independently measured real rendering

The transparent capture uses the actual shader on a transparent SubViewport. The depth/readability fixture then adds an opaque gold occluder, red body proxy and striped backdrop. A separate front/back render uses the source Bulwark cone and rotates the actual actor yaw.

| Measurement | 960×640 | 1280×800 |
|---|---:|---:|
| Maximum observed shield framebuffer alpha | 0.40392 | 0.39608 |
| Partially transparent pixels | 63,412 | 99,092 |
| Opaque-wall ROI changed pixels | **0** | **0** |
| Body-center mean maximum-channel RGB delta | 0.02226 | 0.02297 |
| Body-center maximum RGB delta | 0.11765 | 0.11765 |
| Front-facing Bulwark changed pixels | 39,078 | 61,103 |
| Back-facing Bulwark changed pixels | **0** | **0** |

Alpha values are measured at the tested idle phase, not an assertion that these are the shader's maximum possible values during every transient. The actual RGBA coverage stays partial, opaque cover occludes correctly, and the body remains readable. Source inspection also confirms normal depth testing, `depth_draw_never`, back-face culling, and no screen/depth texture pass.

- [960 before](evidence/960x640/shield-before.png) / [after](evidence/960x640/shield-after.png) / [alpha](evidence/960x640/shield-alpha.png)
- [1280 before](evidence/1280x800/shield-before.png) / [after](evidence/1280x800/shield-after.png) / [alpha](evidence/1280x800/shield-alpha.png)
- [960 measured report](evidence/960x640/report.json) / [1280 measured report](evidence/1280x800/report.json)

## Actual image inspection

The reviewer opened images with `functions.read`, including the delivered **960×640 and 1280×800 all-ten hip/ADS sheets**, the all-ten animated-pose sheet, shield before/after pairs at **960×640 and 1280×720**, and the independent captures linked here. Conclusions below come from rendered images as well as API checks.

| Weapons | Visual assessment |
|---|---|
| 0 Pulse, 4 Plasma, 6 Shock | Lower/right hip framing; centered open rear-notch/front-post ADS. Receiver remains below the sight line. |
| 1 Rocket | Rear exhaust ring is large but below the iron-sight aiming point; it does not masquerade as the aligned sight aperture. |
| 2 Rail Lance, 8 Marksman | Open circular scope bores, centered and visibly clear; stronger Rail magnification enlarges the optic more. Final scope reticle/HUD integration belongs to the lead. |
| 3 Scattergun | Broad twin-barrel receiver remains below the iron line; delivered recoil/reload views show the barrel motion, independently confirmed by moving tip direction. |
| 5 Grenade, 7 Flak | Heavier feeds/receivers are distinct in hip view; ADS remains clear at the front-post aiming line. |
| 9 SMG | Compact receiver/stock, clear iron notch; lower viewmodel remains inside the frame at both aspect ratios. |

All ten have plausible connected barrel/receiver placement in the inspected views. The articulated arms are visibly simplified rigid sleeves/gloves; this review finds no new floating-barrel, inverted-bore, blocked-scope or central hip obstruction defect. The delivered shield images show the actor silhouette and background grid through the cyan/violet shell, with the gold wall uninterrupted in front of it.

Independent all-ten contact sheets: [960](evidence/960x640/independent-all-ten-hip-ads.png), [1280](evidence/1280x800/independent-all-ten-hip-ads.png). Reading order is two weapon pairs per row: **0/1, 2/3, 4/5, 6/7, 8/9**; each pair is hip then ADS. These are downscaled native captures against the isolated fixture's plain background.

## Reproduction and retained attempts

```sh
python3 port/combat-expansion-independent/run.py
```

The runner generates `godot/tests/combat_expansion_independent/oracle.json`, runs the supplemental binding fixture, and renders both sizes. `--graphics-only` reuses the existing oracle when resuming an interrupted render run. Timestamped logs retain completed and failed attempts; images/reports represent the final completed independent harness.

The initial source-oracle attempt incorrectly expected Pulse to reload; the retained failure was corrected to respect its real infinite-ammo/no-reload source contract. The harness server restarted during the next expanded run after source and binding checks completed; only the unfinished graphical work was resumed. Final runs have **287 checks per size**; preceding 273-check logs predate the hidden-event and numeric-ID additions. Xvfb's llvmpipe VSync warning is retained.

Particles, weapon FX and Native Deathmatch active lanes are outside this completed review. No performance acceptance, full multiplayer integration acceptance or nine-map rendered coverage is claimed here.
