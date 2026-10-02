# Helix Conservatory — production scene acceptance, 2026-10-02

This supersedes the READY FOR BLENDER status recorded in the historical source checkpoints. Accepted runtime `e731fd536d31d16a7014402afe6670fca644f9c1` was merged before any engine work. Blender 4.5.14 and Godot 4.5.2 ran serially under the explicitly granted exclusive slot with `LP_NUM_THREADS=1`.

## Accepted scope

**Local hosted native scene:** Deathmatch, Team Deathmatch, CTF, Domination and KOTH. All five completed real source-scored rounds through native keyboard/mouse events, the ordinary native input sampler, production WebSocket protocol, the multiplayer-world source authority and native result receipt. The native host has a controlled wire opponent. No actor positions, health, flags, scores, clocks or objective progress were injected in these hosted journeys.

**Source-only:** Full Arsenal (`arsenal`) and Juggernaut. Both pass controlled source full rounds but remain absent from native options/catalogs: this map's native scene does not yet bind the mode-expansion ModeState/HUD modules. No armsrace substitution.

These are scripted localhost tests, not human play, dedicated-GPU certification, public hosting or exported-package acceptance. Parent retains package closure, allowlist/manifest integration and all-map package verification.

## Final identities and paths

| Artifact | Identity |
| --- | --- |
| Geometry / canonical arena hash | `6afb8d0f8f749b0318c31f5684e1f2a23117b7b7b3823ff2b84e2f38e375ee3c` |
| Recipe file SHA-256 | `87228c2f40262ccbd4dcea5bb50ba4fbbeb634462e54be11abf2499d4ede106a` |
| GLB SHA-256 | `c04a1c8904aad373636b87800352d5b8144f764661875cbdb436ef1753a2b22d` |
| Editable master SHA-256 | `8fc355b529e97d57e3f4e7ab85dc3d84421673188ccb043c9126611cf98b6629` |

- Authority: `port/native-multiplayer-worlds/worlds/helix-conservatory.json`.
- Native wrapper: `godot/multiplayer_worlds/generated/helix-conservatory.json`.
- Art: `godot/multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb`.
- Master: `tools/godot-multiplayer/new-maps/helix-conservatory/masters/helix-conservatory.blend`.
- Reproducible authoring: `recipe.mjs`, `build.mjs`, `blender_author.py` in the map's tools directory.
- Reviewed Godot import: adjacent `.glb.import`, **lossy compression and auto-LOD disabled** to preserve authored geometry.
- Reports: `source-validation.json`, `wall-contact-validation.json`, `bot-validation.json`, `production-validation.json` in this directory.

Master was actually reopened in Blender: 22 editable mesh objects, including 16 recipe-part batches and six converted text labels. Per-part vertex ranges retain architectural editability. The master lives outside Godot so an editor import never tries to launch Blender implicitly.

## Authored art and inspection

The actual first GLB image pass was reviewed and rejected as too sparse. The second authored pass adds six elevated greenhouse hoops, transparent segmented glazing, folded fern fronds, radial masonry joints, all ring/ramp/promenade inlays, archive fascia and architectural wayfinding. The open lightwell, route portals and lower aqueduct paths remain open. All new opaque overhead hoops have corresponding non-walkable source ray surfaces; glass/foliage/inlays remain explicitly visual-only. Source standing-wall triangulation remains 712 individual triangles. Geometry hash changed from the historical checkpoint because reviewed art descriptors and overhead hoops changed; affected source checks were rerun.

Actually inspected final overview and eye-level views of the archive portal, both interiors, lightwell, canopy and crown. The result is a stylized low-poly conservatory, with concentric elevation contrast, gold spiral routes, verdigris radial routes and a scalloped greenhouse crown. It is not a photoreal/high-detail environment. Sparse large-arc terrain, similar opposing chamber silhouettes and long overlook sightlines remain human balance/art-review considerations.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-conservatory-evidence-20261002/`.

- `inspection-final/overview.png`
- `inspection-final/archive-portal-eye.png`
- `inspection-final/archive-eye.png`
- `inspection-final/irrigation-eye.png`
- `inspection-final/lightwell-eye.png`
- `inspection-final/canopy-eye.png`
- `inspection-final/crown-eye.png`
- `native-ctf-04/results.png`: inspected correct 1:0 result and flags returned to base.
- `native-deathmatch-01/frame-0035.png`: inspected live weapon, source frags and geometry.
- `native-domination-01/results.png`: inspected captured-zone final score.
- `helix-native-ctf-sampled.mp4`: 64-second 640×400 H.264 clip assembled from actual native framebuffer images sampled approximately once per second; encoded at 24fps by repetition. This is sampled gameplay evidence, not full-motion capture. Source time is 69.2 seconds; sample cadence/encode duration is explicitly approximate.

## Exact checks and budgets

- Source suite: **16/16** (five layout/movement/rays/graph, seven controlled rounds, four wall-contact regression checks), rerun against final geometry. Final evidence `production-source-all-02.tap`; previous passing run retained. Construction-time support sampling uses a terrain snapshot so it cannot populate the final arena's triangle cache before overhead hoops are appended; the suite asserts complete runtime triangle coverage.
- Source movement: all fifteen authored routes; four elevation bands; every spawn to flags/zones/pickups on the source graph; ground/upper standing contacts, ramp contacts, open portals, low cover and test-only quad leakage reproduction.
- Native collision probe: **11,532 unique authoritative triangles / 2,330 concave shapes**, exact recipe match at millimetre quantization. Six sustained production capsule contacts stop at gaps **0.420397–0.422203 m** (source radius 0.42 m). Native rays verify open portal/glass and blocking wall/ceiling.
- Native visual parity: **39,578 recipe triangles**, no missing/extra triangles after one-to-one matching, maximum imported vertex error **0.000084381 m**, tolerance 0.0001 m. Converted text adds 884 triangles: **40,462 visual triangles total**.
- **8 materials, 16 architectural mesh batches + 6 label nodes = 22 mesh nodes / 22 mesh surfaces**. These are static batches, not thousands of draw nodes. Editable recipe contains 8,770 parts and 52,156 pre-export recipe vertices.
- Shadowed architectural inspection at 1440×900: actual rendering counters are in `inspection-final/inspection.json`; draw/primitive counts include shadow passes, not just unique scene triangles.
- Gameplay recording uses **640×400, shadows off, software Mesa llvmpipe, one LP thread**. Successful CTF runs were around **49 ms median / 57 ms p95** render-frame intervals on this software setup (exact final values in `production-validation.json`). These are not hardware FPS claims. Result screenshot is expanded to 960×600 after gameplay stops.
- The low-resolution gameplay capture visibly clips some inherited long help/kit text at its right/bottom edges; objective ownership, carried flag state and source score remain legible. The 960×600 final CTF result is fully readable. Compact prototype-HUD polish is not claimed by this map pass.
- Source authority outcome times: DM **76.933 s**, TDM **82.233 s**, CTF **69.2 s**, Domination **28.033 s**, KOTH **29.583 s**. Limits: five frags/zone points, one hosted CTF capture. Separate source fixture retains the standard three-capture CTF round.
- Route/options parity tests: **16/16**, including idempotent generated routes and existing capability checks.

## Autonomous bot coverage, separate from fixtures

Final bounded run explicitly passes `{inputs:{}}` so **all four AI seats** execute source `botInput` without a default neutral override of seat zero. CTF: 180 seconds, two autonomous pickups, two drops, one return, 41 combat deaths, every bot traversed >1,400 m, zero falls; **no completed capture, 0:0 timeout**. Domination: two captures, one neutralization, source scoring victory at **93.1 seconds**, zero falls. This establishes autonomous route/objective engagement; it does not establish balanced autonomous CTF completion. A retained earlier run had three autonomous seats and one neutral seat, and produced a capture; it is not the final four-bot result.

## Retained failures and fixes

- Initial Godot import was interrupted by the `.blend` auto-import dependency. Master moved out of the Godot tree; explicit GLB import succeeds.
- Initial imported mesh compression shifted positions by millimetres. Per-asset compression/auto-LOD disabled. A further strict decimal-hash comparison falsely rejected Float32 values straddling rounding boundaries; final one-to-one vertex-distance comparison uses 0.1 mm and reports the maximum error.
- High-resolution software-renderer native journeys (`native-ctf-01`, `native-ctf-03`) could not keep steering responsive and timed out. Successful bounded journeys use the documented lower-cost capture preset.
- CTF result receipt initially left its text label showing the preceding live snapshot even though the renderer had final state. A **Helix-only** result-text refresh in the separate shared integration commit fixes this; final image and source/native report show 1:0 and ROUND OVER.

## Integration contract and remaining acceptance

Separate integration commit adds only Helix to source WORLDS, native MODES, dev/package option tables, route metadata and generated route choice. `map.gd` explicitly resolves this map's nested GLB and complete-surface coverage, preventing duplicate terrain. Existing seven map assets and hashes are preserved. No package allowlists or verifier scripts changed.

The runtime capability contract is those five-mode registries plus `provenance.json.modes` / `production-validation.json.acceptedNativeModes`. The historical recipe `modeBindings` remains empty; `candidateModes` is a research list, not a publication allowlist. Parent packaging should consume the accepted modes, never promote the two source-only candidates automatically.

Parent must include the new JSON/GLB/import settings in future package closure; the Blender master and authoring/test scripts remain production-source artifacts. Run the standalone `build.mjs`, not the old overhead expander. Runtime map selection is the existing `multiplayer-worlds` experience with `--map=helix-conservatory` and an accepted mode. No permanent local server is left running.

Remaining: parent exported-package/manifest acceptance; native Arsenal/Juggernaut presentation bindings; human competitive playtest; dedicated-GPU performance; proof of a four-autonomous-bot CTF capture within a bounded match. Source locks remain `515daf` / reviewed derivative `0326`.
