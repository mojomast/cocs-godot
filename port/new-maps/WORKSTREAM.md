# Three new Blender-authored complex multiplayer maps

An additional owner-requested fan-out now includes **Vesper Viaduct**, **Abyssal
Pressureworks**, and a robot/prop asset ensemble in a [separate workstream](../expansion-three/WORKSTREAM.md).
The three original maps and their revision/acceptance queue below remain active.
**Stormglass Causeway**, a source-compatible Puma racing map, is also in
[the newest Astra workstream](../expansion-four/WORKSTREAM.md).

Owner requests another explicit Astra fan-out to design and build **brand-new,
very complex and unique maps using Blender**. Three `openai/gpt-6-astra` agents
start from `4ae4e5b7` in isolated worktrees. This map workstream runs alongside
the [source-feature pass](../next-port/WORKSTREAM.md); the owner's authorized
second feature pass starts after that first pass's verified release.

## Map briefs and ownership

| Map | Spatial and visual identity | Target modes, subject to acceptance | Agent |
|---|---|---|---|
| **Helix Conservatory** (`helix-conservatory`) | Terraced botanical arcology; open lightwell, spiral garden ramps, split ring balconies, seed archives and irrigation passages | DM, TDM, Arsenal, Juggernaut, CTF, Domination, KOTH | `ses_f055b8ad4ffeGterKBoxtnk2Q3` |
| **Gravemill Foundry** (`gravemill-foundry`) | Canyon-scale ore refinery; crusher drums, furnace towers, rail gantries, cooling galleries and a ground vehicle/service loop | DM, TDM, Payload, Assault, Combined Arms, Domination | `ses_f055b00c7ffe1uQyo7QsXqA0gC` |
| **Parallax Observatory** (`parallax-observatory`) | Coastal cliff astronomy institute; folded telescope dishes, calibration courts, instrument vaults, arc bridges and a cistern route | DM, TDM, CTF, KOTH, Uplink, Holdout | `ses_f055a6b41ffe42yCL8AxbOL676` |

These are design targets, not shipped mode capabilities. Agents must prove source
support and complete player journeys before a pair is advertised.

Worktrees under `/home/mojo/.tmp-on-disk/`:

- `cocs-new-map-conservatory-20261002` / `maps/conservatory-20261002`
- `cocs-new-map-foundry-20261002` / `maps/foundry-20261002`
- `cocs-new-map-observatory-20261002` / `maps/observatory-20261002`

Evidence uses the corresponding `cocs-new-map-<lane>-evidence-20261002/` directory.
Each map owns `port/new-maps/<map-id>/{DESIGN,ACCEPTANCE}.md`, its named recipe,
Blender authoring scripts, editable master, GLB, native data and focused tests.

## Design and implementation requirements

- Distinct architecture, materials and silhouettes, with at least three macro
  routes, connected elevation bands, interior districts and useful crosslinks.
- Complex traversal must remain readable: safe spawn exits, recognizable
  landmarks, flank routes and counters to elevated firing positions.
- Blender authors the final geometry. Retain the `.blend` master, exported GLB,
  reproducible scripts/seed and provenance.
- One reviewed recipe drives authoritative geometry and native presentation.
  Validate floor/ceiling support and underpasses against actual source movement;
  visible openings must not hide enclosing shot-blocking boxes.
- Preserve the frozen source lock and reviewed derivative. Existing source rules
  own combat, vehicles and objectives.
- Parent owns final shared map/mode catalogs, generators, selectors, package
  closure and verification inventories. Shared hooks from agents must be separate
  integration commits; map assets/tests remain isolated by map ID.

## Verification and resource queue

**Current grant: combined native integration**, `FINISH-COMBINED-NATIVE-20261002-A`,
owned by `ses_f0294303bffed6Fb8UJLKe4ZDz`. Foundry revision 3 explicitly released
all owned processes. Parent accepted its revised architecture after reviewing
overview, crusher, cooling/assay interiors, furnace and compact payload view.
Branch through `32c156ea` merged at `4febce4d`; both new map registrations survive.
Regenerated routing/closure/options checks pass 30/30 after retaining the initial
ordering failures. Foundry's six hosted mode proofs remain scoped to its lane;
combined feature/package acceptance is next. Production details and software
capture cadence are in `gravemill-foundry/REVISION3-PRODUCTION.md`.

Helix completed revision 2 and
explicitly released all owned processes. Parent inspected its overview, four
district views and compact CTF result, accepted the distinct architectural forms
for integration, and merged `a2377512` + `63a6244d` with their prerequisites at
`c8432fcb`. The revised art remains stylized, with sparse peripheral areas and
distant steel-edge aliasing; package/native-composition acceptance remains pending.

Helix revision-2 proof: five hosted modes (DM/TDM/CTF/Domination/KOTH), 15 source
checks, 16 routing/options checks, reopened master and native geometry/contact
agreement. Art is 138,580 triangles/25 surfaces/10 materials; collision uses 37,056
triangles/7,562 shapes. The continuous CTF sample captures 1,530 frames across
118.548 seconds (12.90 Hz, maximum gap 207 ms), below the requested 15 Hz target
on llvmpipe. Historical bot-CTF timeout and source-only Arsenal/Juggernaut remain.
Parent reran package/options checks, world-resource closure and generated-scene
consistency after merge. Exact reports: `helix-conservatory/revision-2/FINAL.md`.

Foundry's revision-3 production grant is complete. Fighting art agents remain
source-only; the integration owner may run asset-independent core engine gates.
The following queue text records the earlier grants and prototype checkpoints.

**Parallax Observatory now owns the exclusive Blender/Godot slot.** Foundry
released all owned processes after six hosted mode rounds and its production
checkpoint. Parallax received an explicit grant and must merge verified runtime
`e731fd53` first. Helix's architectural revision is ready for another production
slot; Foundry is preparing its own deeper revision through code/source checks.
Map agents must return `READY FOR BLENDER` and receive an explicit parent grant
before Blender, import, bake, rendering or Godot runs. Use serial heavy processes
and `LP_NUM_THREADS=1`; no nested agents.

Acceptance requires source movement along actual routes, spawn/objective/nav
connectivity, cover/opening checks, mode-specific source outcomes, native geometry
agreement, real-input connected journeys and inspected overview/eye-level images
plus walkthrough footage. Record asset budgets and observed timings. Separate
controlled fixtures from natural play balance and real-GPU performance. Preserve
failed attempts and earlier releases.

## Design/source checkpoints

- **Helix Conservatory — `0eb5401b`, ready for Blender.** Deterministic 240 m
  radial plan, elevations 0/8/16/24 m and fifteen authored routes. Five source
  tests passed, including 27,544 real movement ticks, open/blocked shot and
  ceiling checks, and a connected 2,554-node navigation graph. Authoring script
  is prepared; no `.blend`, GLB, native rendering or hosted mode acceptance yet.
  Art starts from 1,338 explicit parts / 5,034 triangles / six materials.
- Source movement selects the highest walkable surface at each X/Z. Helix uses
  non-overlapping terraces, with non-walkable aqueducts and ceilings, to provide
  vertical routes without incorrectly claiming overlapping playable decks.
- Helix remains on its isolated map branch until Blender/native verification;
  its advertised `modeBindings` remains empty pending actual mode journeys.
- **Parallax Observatory — `408ed002`, ready for Blender.** Three major routes
  and three crosslinks over 0/12/24 m tiers, two through-interiors and a real
  water void. All 689 navigation nodes and 21 gameplay targets are connected;
  six routes passed source movement in both directions with zero measured
  floor-height error. Physical CTF journeys and a three-capture round passed,
  alongside controlled DM/TDM/KOTH/Uplink/Holdout fixtures. Blender/native art,
  screenshots, footage and hosted native acceptance remain pending.
- Parent is reviewing the shared [integration requirements](INTEGRATION.md).
- **Helix objective follow-up — `3549c4a1`: seven source rounds passed.** DM,
  TDM, Arsenal, Juggernaut, CTF, Domination and KOTH ended through source scoring.
  After initial controlled setup, the fixtures use inputs without actor/score
  writes: 30,134 source frames, 2,915.536 m walked and zero falls. CTF includes
  interact-drop/return and three physically carried captures. Combat uses explicit
  rail-start/unlimited-ammunition settings and shortened targets. These are
  scripted source fixtures; native, autonomous-bot and human acceptance remain
  pending. Geometry is unchanged and `modeBindings` is still pending.
- **Gravemill Foundry — `32cbf30f`, ready for Blender.** All eight routes passed
  movement in both directions; 3,711 navigation nodes connect 22 gameplay
  targets. A mounted Puma completed a 767.64 m service loop with zero observed
  collisions. Payload traversed 363.60 m through three checkpoints and delivery;
  all six controlled source rounds passed, including mount/drive/dismount/zone
  capture in Combined Arms. Blender assets and native checks remain pending.
- **Cross-map collision follow-up:** Foundry proved that untriangulated vertical
  wall quads can fail standing-player movement collision in the frozen source,
  despite blocking weapon rays. It emits individual wall triangles. Helix and
  Parallax agents are now checking actual movement contacts and updating their
  recipes/hashes where necessary before Blender production.
- **Helix wall-contact audit — `a491c5a8`: four tests passed.** All 712 production
  walls were already triangles. Twelve continuous-input contacts from both sides
  over four elevations stopped 0.426150481 m from the face (actor radius 0.42 m).
  Ramp, low-parapet, open-portal and underpass cases passed. A test-only merged-quad
  negative control penetrated the same pier despite identical shot blocking,
  proving the movement test detects the reported defect. Geometry hash and prior
  route/full-round provenance remain unchanged.
- **Parallax wall correction — `9107216d`:** 844 quads converted to 1,688 wall
  triangles with identical rendered geometry. Tall-wall regression contacts
  changed from crossing to stopping 0.4213 m from the face. Existing low parapets
  already blocked correctly. Real vault-wall contacts, open passages, underpass
  and three ceiling undersides pass; all routes, pickups, CTF and six source
  rounds passed again with 689/689 connected nav nodes. New geometry hash:
  `916164f0417369f37506e3908e940c961ea142aa349dcda3226ca1f316a040eb`.

## Helix functional checkpoint and parent art review

- `becef6b4` supplies the Blender master, GLB, source/native collision/mesh checks
  and hosted mode evidence; `96174a63` separately supplies shared map bindings.
  Accepted runtime `e731fd53` was merged before production. Five hosted native
  modes completed: DM, TDM, CTF, Domination and KOTH, using ordinary sampled input
  over production WebSockets without actor/score/flag injection. Arsenal and
  Juggernaut remain source-only and unadvertised.
- Functional-checkpoint geometry hash:
  `6afb8d0f8f749b0318c31f5684e1f2a23117b7b7b3823ff2b84e2f38e375ee3c`.
  Art: 40,462 triangles, eight materials, 22 mesh surfaces. Source/native visual
  comparison found no missing/extra recipe triangles (maximum error 0.084381 mm).
  All sixteen source checks and sixteen routing/options checks passed. Four-bot
  Domination scored a victory; four-bot CTF timed out 0:0 despite objective use.
- Parent inspected the overview, archive portal, lightwell and CTF result.
  **Functional acceptance does not satisfy the owner's architectural brief yet.**
  The large sparse concentric terraces, thin framing and two simple similar
  interiors need substantial district/volume/interior/cover development. Helix
  has been resumed for a code/source-only revision: distinct archive and irrigation
  districts, a substantial conservatory volume, central landmark, structural
  framing and purposeful planting/cover. Changes require new hashes and affected
  acceptance; old evidence stays attached to its original geometry.
- The inspected 640×400 gameplay clip is sampled at approximately one image per
  second, not full-motion footage. Small-screen inherited help/kit clipping and
  software-renderer steering cost remain documented. Future acceptance requires
  the standard wide/compact UI views and improved footage where feasible.
- These map commits remain on the isolated map branch pending architectural
  revision and parent package acceptance. They are not in the published release.
- Public checkpoint images: [overview](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/helix-prototype-overview.png),
  [archive](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/helix-prototype-archive.png),
  [CTF result](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/helix-prototype-ctf-result.png).
  The gallery's `helix-prototype-provenance.json` explicitly records the pending
  art revision and the sampled cadence of `helix-prototype-sampled-gameplay.mp4`.

## Helix architectural revision 2 — source candidate

- **`4c486a9e`, ready for a second Blender pass.** Candidate architecture adds a
  three-bay archive crescent with research/service aisles, asymmetric filtration
  works with machinery and maintenance routes, glazed germination pavilion,
  central double-helix specimen landmark, terraced botanical banks and deeper
  structural crown. Four tiers and fifteen primary routes remain; five new
  interior/service variants bring tested traversal to twenty routes.
- **15/15 source checks passed:** 29,619 actual movement ticks, connected
  2,573-node navigation graph, seven source-scored rounds, sustained body/ray wall
  contacts, transparent facade/portal and terrain-following inlay checks. These
  are candidate source results; historical native proof does not transfer.
- Candidate hash:
  `f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2`.
  Planned art is 137,928 recipe triangles, ten materials and 22 batches plus
  labels; actual import, draw cost and rendered quality remain unmeasured.
- Floor diagnosis found 49 old inlay triangles crossing the floor. Revision 2
  clips broad inlays to terrain and removes the fine masonry lattice implicated
  in distance aliasing. Source clearance passed; visual improvement is unverified.
- Revision 2 is staged under `port/new-maps/helix-conservatory/revision-2/` and
  leaves functional-checkpoint runtime geometry and evidence intact. Test probes
  moved to `godot/tests/new_maps/helix_conservatory/`; they must be retargeted to
  the candidate before new native acceptance. No Blender/Godot ran for this
  revision. Parallax now holds the slot; Helix awaits another
  explicit grant for export, visual review and affected native revalidation.

## Foundry functional checkpoint and parent art review

- **`afbe57dc` assets/proof + `ec041aee` shared bindings:** Blender master reopened,
  GLB imported, six source fixtures and six hosted production-native rounds passed.
  Payload delivered all three checkpoints; Combined Arms mounted, drove 76.88 m
  through a bend, dismounted and captured a zone for a 50-point win. DM/TDM,
  Assault and Domination also completed source-scored rounds. Setup and passive/
  retreating opposition are controlled; no actor/score/position injection.
- Production collision checks passed 908 support rays, 908 standing capsules,
  160 wall-contact moves and window/gallery/ceiling/underside checks. Geometry:
  `357e2ef998a52135d273a30e2638392a8dececf1fa15f0b17f33c612976d853e`.
  Art: 66,284 triangles, eight batches; 2,808 authoritative collision triangles.
  Static inspection counted 4,914 nodes and 8 base art draws (38–40 with shadows).
- Autonomous observation is separate: Domination victory; payload advanced
  144.41 m and one checkpoint in 120 seconds without completing delivery.
  Walkthrough/payload clips contain roughly 9.42/9.77 captured frames per second,
  timestamp-resampled to 15 fps. They are short samples (4.46/3.891 seconds), not
  native-15fps capture, long full-round footage or dedicated-GPU measurements.
- Parent inspected overview, crusher, cooling, assay and crown views. **Functional
  proof is accepted; architectural sufficiency remains pending.** The large open
  yard, isolated machines, regular grid and near-identical gallery interiors need
  substantial district/building development. Foundry is preparing a staged
  revision: crusher house, furnace district, differentiated cooling/assay interiors,
  integrated fractured geology and distinct payload encounters, retaining tested
  vehicle clearance and source-compatible traversal.
- Existing checkpoint assets/results stay on the isolated branch. Revised
  geometry will require new hashes, source checks, Blender review and native
  acceptance; it must not inherit these results. Parent package acceptance is
  pending and the published game does not yet contain Foundry.
- Published prototype evidence: [overview](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/foundry-prototype-overview.png),
  [crusher approach](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/foundry-prototype-crusher.png),
  [cooling gallery](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/foundry-prototype-cooling.png).
  `foundry-prototype-provenance.json` labels the pending revision and the short
  resampled cadence of `foundry-prototype-payload-sample.mp4`.

## Foundry architectural revision 3 — source candidate

- **`8d248904`, ready for the next Blender pass.** Staged design wraps the drums
  in a substantial crusher house, adds a covered angled transfer passage and
  diagonal service cut, builds a kiln/service/loading furnace district, and
  differentiates enclosed cooling machinery spaces from a steep-roofed,
  partitioned assay building. Unequal geological benches replace perimeter teeth.
- Candidate source checks passed all ten routes in both directions, a connected
  3,698-node graph and all 22 gameplay markers, the mounted 767.64 m Puma loop
  with zero collisions, and all six controlled rounds. New sustained body/ray
  contacts, ceilings, inspection-window openings and lintels passed as well.
- Candidate geometry:
  `8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f`.
  Files remain isolated under the map's `revision3/` authoring directory; old
  runtime wrappers, master and GLB are byte-identical to the functional checkpoint.
  Native drivers moved under `godot/tests/new_maps/gravemill_foundry/`.
- No Blender/Godot/import/render ran for this revision. Parallax retains the
  current slot, followed by Helix's second production pass, then Foundry's next
  explicit grant. Required gates include actual architectural review, native
  collision and hosted-mode revalidation, 760×520/UI150 HUD inspection and a
  longer continuous walkthrough with measured capture cadence.
