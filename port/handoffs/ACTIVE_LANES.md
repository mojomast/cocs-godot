# Parallel development ownership

Coordination snapshot after `013ad65`. This is an ownership record, not evidence
that an in-progress feature has passed acceptance. The lead integrates commits,
updates root documentation/shared verification and owns publication.

| Lane | Owner / baseline | Reserved files |
|---|---|---|
| LATTICE in-world command panel | Delivered `7439f05`, integrated `511bb8d`; independent suite PASS | World panel and tests; lead owns integration/docs |
| Native KOTH / Domination | Delivered `2b3d758` + `7238c9d`, integrated `8344544` + `c95f5ca`; independent acceptance PASS | New `godot/zone_modes/`, `godot/tests/zone_modes/`, `port/native-zone-modes/` |
| Independent zone acceptance | Delivered `60ebf1c`; both capture/scoring/results/restart runs PASS | `port/reports/zone-modes-independent/`; lead corrected helper partial-pass and provenance issues |
| LATTICE world co-op window | Delivered `e5d862e`, integrated `163e528`; both natural-window/expired-consent cases PASS | `port/native-lattice-world-coop/`, `godot/tests/lattice/world_coop_*`; no runtime change |
| Native Arms Race | Integrated `2335279` / `99e4413`; independent `a7cbc12` integrated `879342e` | Native scene plus eight-route common/package hooks; full ladder victory open |
| Player-facing usability audit | Delivered `29b0a59`, integrated `2af744f` | `port/native-usability-audit/`; lead fixed setup copy; sports bearing correction delegated |
| Sports bearing correction | Delivered `99c0a93` / `6350cc4`, integrated `0b820c9` / `e1defc0` | Camera-projection regression896; real two-sided images inspected; exported startup PASS,73 aggregate gates PASS |
| LATTICE world usability | Delivered `dfe7432` / `6667569`, integrated locally;24 contracts and77 aggregate gates PASS | World control-state guidance and public approach/progress cues; agent's failed resized click remains disclosed |
| Payload approach guidance | Delivered `20f85f2`, integrated locally; lead823 guidance/99 HUD and current-renderer historical replay PASS | Objective bearing/radius/role guidance;3792 historical snapshot matches, not new full-delivery acceptance; package update pending |
| Race victory / soccer practice | Delivered `33f5257`, integrated `8a58c97`; independent race victory/local goal PASS | Sports coaching/tests; zero-bot practice blocked by source |
| Sunscar combined-arms vehicle slice | Delivered `1126a08` + `613dc92`, integrated `88cd514` + `fc5795c` | New `godot/combined_arms/`, `godot/tests/combined_arms/`, `port/native-combined-arms/` |
| Independent combined-arms acceptance | Delivered `9b1cdcd`, integrated `51f555f`; full Puma route PASS | `port/reports/combined-arms-independent/`; lead strengthened receipt-set validator |
| Multiplayer lobby / leave / retry | `3b96206` integrated locally as `ddf166a`; original absent external evidence remains unrecovered | Opt-in lobby; lead owns nine-route launcher and endpoint ownership integration; package acceptance pending |
| Independent lobby review / layout follow-up | Original reviews integrated; `f762639` / `c8c1513` / `12e770d` integrated as `bd20785` / `e88b5a6` / `5a87f19`; bounded lifecycle PASS | Original failed/partial evidence preserved;75 actual-scene geometry checks per size |
| Active spectator notice repair | `f92b0ef` / `de6f9f9` integrated as `17d3657` / `96542c2`; review `e9ed72f` integrated `1a00d90`;80 aggregate PASS | Strict validated informational notice and read-only state; lead31 actual-scene and75×2 layout checks PASS |
| Exported lobby focus triage | Delivered `c3a9067` / `7f703a1`, integrated; lead194-assertion replay PASS for HOLD verdict | Release embedded-popup cleanup reproduced14 errors vs debug0 with identical72 actions; no generic focus-call workaround accepted |
| Popup-free lobby selectors | `9a816ff` / `f212a8c` / `ee64535` integrated; lead63 graphical checks,80 aggregate,14 package cases and clean full exported lobby flow PASS | Inline choices replace only lobby popups; other menus untouched; original release failures preserved |
| Pulse rifle preview | Existing external reservation | Preserve its preview/asset paths; no accepted delivery yet |
| Player/operator model improvement | Recovery `72a58c9` integrated as source/evidence `e396106`; user requested a playable Windows candidate demo; builder enables models only in explicit candidate staging | `godot/player_models/`, `godot/tests/player_models/`, `port/native-player-models/`; default replacement still held for distance readability/render cost; pulse-rifle reservation remains separate |
| Native Horde survival | Event/kill fix `c64762a`, evidence `2b0fbf5` delivered; lead isolated50 tests and exact810event/378snapshot replay PASS | Local adapter accepted for bounded integration; full10waves/boss/defeat/upgrades remain OPEN |
| Horde common/package integration | Delivered `24d2e4a` / `f29ef21`, integrated `de138d8` / `fda4f32`; lead87 gates,16 launcher cases,6 exported Horde startups PASS | Ten routes/nine scenes;84 locked source +2 adapter modules;881 public startup snapshots; full10wave completion remains OPEN |

The LATTICE command and physical-input lanes are delivered and integrated at
`658b4e7` and `aca52f5`. The projectile navigation follow-up is integrated at
`cb908db`. Their current evidence remains separate from future gameplay work.
The external objective slice is delivered as `91ce0bd` and integrated at
`d498479`; its original tools/evidence stay preserved during follow-up work.
The native CI lane is delivered as `3d6de79` and integrated at `a12d89f`.
The LATTICE tactical map is delivered as `596325d`, integrated at `c982d25` and
independently accepted through both Map and original List native-input paths.
The lead owns common launcher routing, verification, root docs and publication.
The sports progression lane is delivered as `0a07f5c` and integrated at
`e76acdb`; the lead is reproducing full-lap and round-lifecycle claims separately.
That independent sports verification passed. Objective progression is integrated
at `ffa6aac` and independently passes CTF return/capture and Payload contest/
checkpoint/results/restart. GLB-side repair at `0149cbb` / `0af3c51` independently
passes all-nine export/import and matched-camera review.
Soccer targeting is integrated at `e561f99` / `4eb0e36`; independent two-resolution
visual checks and archived source-goal audit pass. Local-driver scoring remains
unaccepted after two bounded agent attempts; seven bot/own goals are preserved.
Co-op recruitment is integrated at `642c615`; independent natural-window purchases
pass on both maps, with prior Map/List regressions intact.
Objective completion is integrated at `1228369` / `2077911` / `db0c3ee`;
independent full Payload rollback/delivery and CTF pass/settled restart pass.
World traversal is integrated at `6116f12`; both independent graphical cases
and all four common-launcher startup routes pass. Native strategy commands
within that world and an editor-free Linux prototype build are now delegated.
The Linux package lane is delivered at `0c2dc2b` / `47c0ba2`, integrated as
`7f694ce` / `1b0949b`. The lead owns independent rebuild/extraction/launch
verification and documentation; generated local artifacts remain outside git.
The independent package rebuild and fresh-directory exported startup/cleanup
passed; the exact local archive and report are recorded in
`port/reports/linux-package-independent/README.md`.

## Resumed development batch

The owner requested renewed parallel acceleration after the 63-gate status
update. Three fresh worktrees now tackle disjoint gameplay gaps alongside the
existing in-world command panel:

- KOTH/Domination: actual source-controlled zone capture/scoring and readable
  native markers/HUD, with Meridian and Verdant as the initial acceptance cases.
- Sports: genuine lap-target victory; an explicit source-valid zero-bot soccer
  practice preset and bounded attempts at an attributable local-driver goal.
  Prior failed scoring attempts remain unchanged; practice acceptance is separate.
- Combined arms: ordinary Sunscar infantry approach, mount, authoritative vehicle
  motion and dismount, with clean transitions back to infantry controls.

These lanes may propose launcher/package routes but do not edit shared session,
network, common launcher, package pipeline, verifier, locked source or contracts.
The lead reviews integration hooks, reproduces important live claims, updates
evidence and rebuilds the Linux artifact after accepted runtime changes.

## Graphics restoration batch — owner requested parallel implementation

Baseline `b0ac0b5`. Four isolated agents are implementing this batch; the lead
owns shared runtime composition, package/CI hooks, integration review and release.

| Lane | Worktree / branch | Exclusive implementation paths |
|---|---|---|
| Baked Moth registry/materials | `/tmp/opencode/cocs-graphics-moth`, `graphics/moth` | `tools/godot-moth/`, `godot/moth/`, `godot/tests/moth/`, `port/native-moth-graphics/` |
| First-person weapon rig | `/tmp/opencode/cocs-graphics-viewmodels`, `graphics/viewmodels` | `tools/godot-weapons/`, `godot/first_person/`, `godot/tests/first_person/`, `port/native-first-person/` |
| Map atmosphere/lighting | `/tmp/opencode/cocs-graphics-atmosphere`, `graphics/atmosphere` | `godot/graphics_atmosphere/`, `godot/tests/graphics_atmosphere/`, `port/native-atmosphere/` |
| Source-event Moth effects | `/tmp/opencode/cocs-graphics-vfx`, `graphics/vfx` | `godot/graphics_fx/`, `godot/tests/graphics_fx/`, `port/native-moth-vfx/` |
| New native showcase map | `/tmp/opencode/cocs-graphics-showcase`, `graphics/showcase` | `godot/showcase/`, `godot/tests/showcase/`, `port/native-showcase/` |
| Aurora Basin map | `/tmp/opencode/cocs-graphics-aurora-map`, `graphics/aurora-map` | `godot/aurora_basin/`, matching tests and `port/native-aurora-basin/` |
| Cinder Array map | `/tmp/opencode/cocs-graphics-cinder-map`, `graphics/cinder-map` | `godot/cinder_array/`, matching tests and `port/native-cinder-array/` |
| Massive particle lab | `/tmp/opencode/cocs-graphics-particle-lab`, `graphics/particle-lab` | `godot/particle_lab/`, matching tests and `port/native-particle-lab/` |
| Moth shader lab | `/tmp/opencode/cocs-graphics-shader-lab`, `graphics/shader-lab` | `godot/shader_lab/`, matching tests and `port/native-shader-lab/` |
| Existing-map Moth scenery | `/tmp/opencode/cocs-graphics-moth-scenery`, `graphics/moth-scenery` | `godot/moth_scenery/`, matching tests and `port/native-moth-scenery/` |
| Native-only launch routes | `/tmp/opencode/cocs-graphics-native-routes`, `graphics/native-routes` | Package/dev option and launcher modules, new native route tests, Graphics Showcase.cmd; lead retains build.py/verify.py |

Initial lanes delivered and cherry-picked: Moth `606192a` → `a95f856`, world FX
`6cd1643` → `8a9abce`, atmosphere `45f3d5c` → `7bfb473`, first person
`8336be3` → `b9ad0e6`. Shared composition acceptance is in progress.
The expanded maps/labs are additive native exploration scenes, independent of
the locked nine-map source simulation. Lead owns `godot/exploration/walker.gd`.

Launcher delivery `ecd2592` integrated as `508c2fc`. Completed first-wave and
launcher worktrees were removed after clean-status checks to reclaim temporary
storage; branches, committed files and evidence remain. All active map/lab/scenery
worktrees are retained. Two narrowly scoped follow-ups work in primary directly:

- Combined-arms graphics agent: `godot/combined_arms/demo.gd`, optional new
  `graphics.gd`, new `godot/tests/combined_arms/graphics.gd`, and
  `port/native-combined-arms-graphics/` only.
- Depth convention agent: `godot/moth/surface.gdshader` only if a real graphical
  fixture proves the correction, new `godot/tests/graphics_depth/`, and
  `port/native-graphics-depth/` only.

These agents must commit only their exact owned paths; all other primary work
and report files belong to the lead.

Expanded deliveries are now integrated: Prism `9a1d5c8` → `4a5ddee`, Aurora
`302c4e2` → `08ac73a`, Cinder `f16282d` → `4b3ce01`, particle lab `6a1af42` →
`23bbe04`, shader lab `fab8f7d` → `e184026`, scenery `1684f89` → `b3da71c`.
Shared map/lab/menu integration is `f9c45dd`; independent native input review is
`e5d6fd3`. Combined-arms and depth follow-ups completed as `87ea91f`/`fecc5f0`.
Clean completed map/particle/scenery worktrees were reclaimed. Shader worktree
retains untracked import-generated UIDs and was left intact.

Cinder production-controller junction follow-up completed as `f812c23`, with
1,246 assertions and both full circuits passing. All graphics implementation and
review lanes have completed. Lead retains aggregate/package/release ownership.
User research remains untracked.

Graphics batch released as `graphics-demo-2026-09-22` at source tag target
`e4a8b186a4563cc8576be84c57d1b69f15affc47`. Hosted 105-gate run `35715376755`
and exact-asset Windows run `35714103892` pass. No graphics lane remains active.
See `port/graphics-batch/README.md` for artifact hashes, launch instructions and
the preserved earlier failures; Windows graphics/audio and hardware acceptance
remain open.

The existing source/baked assets are read-only. No generation service is needed.
The first-person lane may read/export source weapon geometry, including weapon0;
it does not edit the separately reserved external pulse-rifle preview or assets.
The player-model candidate remains separate. Agents return shared composition
hooks unapplied, commit their owned paths, and preserve actual failures/evidence.

Moth interchange contract: `res://moth/generated/{textures,normals,sky}/<key>.png`,
`materials/<key>-{r,t}.png`, `effects/<key>-<zero-based-index>.png`, plus a hashed
`manifest.json`. `res://moth/library.gd` supplies cached texture/normal/sky/effect/
material_lut lookups. Other graphics lanes accept injected textures/resources.
Node authority, collision/support geometry, all nine maps and campaign deferral
remain the integration constraints. Final evidence must distinguish fixtures,
normal-rate live operation, graphical review and Windows package execution.

## Combat expansion — second parallel pass

Owner requested showcase shields/effects in real combat, additional weapon effects,
massive in-match particles (million-particle lab ran smoothly on their GPU), rigged
and aligned ADS, barrel-tip presentation, and deathmatch on all three new maps.
Baseline `64da4bc`. These agents work in primary with **exclusive path ownership**;
each must commit only its own paths. Lead owns integration/review/package rebuilds.

| Lane | Owned paths |
|---|---|
| ADS and sight/weapon rig | `godot/first_person/`, `tools/godot-weapons/`, `godot/tests/first_person/`, `port/native-ads/` |
| Showcase shields and actor effects | New `godot/combat_shields/`, matching tests, `port/native-combat-shields/` |
| Massive in-game particles | New `godot/combat_particles/`, matching tests, `port/native-combat-particles/` |
| Muzzle/weapon effects | New `godot/weapon_effects/`, matching tests, `port/native-weapon-effects/` |
| Combat pickup assets | Visual-only `godot/world/pickups.gd`, new `godot/combat_pickup_assets/`, matching tests and report |
| Original Three.js operator import | New `tools/godot-operators/`, `godot/source_operators/`, matching tests, `port/native-source-operators/`; original geometry/joints/LOD and native animation proof, requested as a better route than candidate art iteration |
| Complete input/ADS controls | `godot/world/session.gd`, new `combat_actions.gd`, Horde demo aim hook, combined-arms controls/demo/graphics aim hooks, Arms Race input, LATTICE neutral input, shared HUD hints; new action tests/report |
| Native DM geometry | `godot/native_arenas/maps/`, `generated/`, geometry tests, `tools/godot-native-arenas/`, `port/native-arena-geometry/`; Prism demo map-only seam if needed |
| Native DM authority | `port/native-arenas/`; optional native-arena client and protocol tests |
| Native DM scene | `godot/native_arenas/{demo.gd,demo.tscn,catalog.gd,hud.gd}`, session tests, `port/native-arena-session/` |
| Native DM launchers | Common/package launchers/options, package discovery, new native-arena tests, `Native Deathmatch.cmd`, `port/native-arena-launchers/` |

Lead reserves `godot/world/combat_feedback.gd`, new shared FX composition/settings,
package build/export/Windows verification, aggregate gates, release docs and final
live acceptance. Shared session/combined-arms hooks are integrated **after** the
input lane completes. Do not overwrite another lane or stage unrelated primary work.

### Integration assignments after component delivery

- ADS `da6a8ab`, controls `b7b9e09`, weapon effects `6a4fea5`, particles `91d4982`,
  pickups `2a43136`, shields `c8cae07`, authority `435b276`, launchers `4dd1f08`.
- Lead ADS/FOV integration and actual OS-input acceptance: `642acb0`.
- Independent review `f80c93c`: ADS checks pass; shield pool starvation with
  unprotected actors ahead of a protected actor fixed in `d27f594`. Independent
  ordering/depth checks pass after separating bounded observation from shell slots.
- **Shared combat integration agent now owns** `combat_feedback.gd`,
  `combat_quality.gd`, `combat_overlay.gd`, `projectiles.gd`, new semantic occlusion
  helper, and its new tests/report. It inherits the lead's pending composition
  edits and connects all three effect systems without duplicate legacy rendering.
  Delivered `9370275`; ownership released to lead. 1,013 contracts, 12 Combined Arms
  checks and live production OS-input/quality/FX review pass.
- **Native contract integration agent now owns** the completed launcher/options
  paths and native scene/catalog/HUD/session-test paths. Reconcile endpoint
  `/native-arenas` and actual source bot bounds 1–7, then run live smoke.
  Delivered `f6427dd`; ownership released to lead. Prism and subsequent lead Cinder
  live smoke pass; Aurora cold navigation construction is assigned to geometry.
- Native geometry owner retains maps/generated/exporter through canonical-hash,
  strict schema and actual source-round acceptance. No other lane may rewrite
  those outputs while the owner is reconciling the delivered authority contract.
  The geometry lane hit its usage limit after measuring the Aurora candidate:
  unchanged exact geometry plus source `nextGen` spatial navigation and 3 m
  authored route chords gives 303 connected nodes / 2,230 edges in 1.9 s cold
  navigation versus 948 / 17,166 / 39 s. That one-line schema adoption and the
  regenerated assets are lead-integrated now.
- Original-operator production integration **landed** (`36337075`, no push): actual
  source third-person weapons exported for all ten (`source_operators/generated/world_weapons/`),
  `presentation.gd` defaults to the imported source operators, post-pose hand grips
  solve against the real weapon contacts (450 source cases, 3.77e-7 max grip error),
  and live dual-peer sessions show four remote actors walking/firing with correct
  reloads, results and clean unload. Lead inspected `evidence/live-07/` captures:
  genuine source operator with the mounted rocket launcher. Lead rewrote the
  `entity_visuals.gd` actor section for the articulated hierarchy (48 checks; team
  bars 2 red / 4 blue, feet -0.9, body height inside the 1.79-2.03 m envelope,
  instance-isolated team armor, weapon swap and grip residuals asserted).
  Package consequences (candidate staging, Windows marker, source-operator data
  closure) were handed to the route/package lane.
- Original-operator production integration (superseded note, kept for history): the prior lane exported the roster and authored tools.
  The prior agent hit its usage limit after exporting the full nine-operator
  roster (`4f05b4c`) and authoring, but never running, the third-person weapon
  exporter (`tools/godot-operators/world-weapons.mjs`) and the source post-pose
  grip helper (`godot/source_operators/hand_grips.gd`). `presentation.gd` is not
  yet switched, so gameplay still renders the legacy actor visual.
- Visual-identity trilogy **prototype** merged from
  `external/visual-identity-three-maps` (`8b2a33c9`, base `642acb0a`) as an additive
  merge. Delivered artifacts: `godot/identity_maps/` (recipes, map-only builder,
  inspection scene), `godot/tests/identity_maps/`, `tools/godot-identity-maps/`,
  `port/native-identity-maps/` (source factories, ray oracle, bounded normal-rate
  runs, six research/report documents, 45 dimension-verified renders). Lead visual
  review of the 1280×800 landmark/combat/worst captures: three genuinely distinct
  identities (chalk-indigo-copper split resonator; vermilion folded ribbons over
  jade; pale nacre vault over ultramarine) with first-pass flat art, no textures,
  baked lighting, trim or signature FX. Vermilion's fold silhouettes are visibly
  jagged. This is prototype art, not identity acceptance.
- **Prototype integration is not accepted and no route is exposed.** Mode/launcher/
  package hooks remain parent-owned and unwritten: the native-arena schema accepts
  only its three existing maps and Deathmatch, zone modes reject unknown IDs, and
  the Horde adapter validates only its three maps. The handoff's own performance
  hold also stands: exact high-detail walls cause 2.95–14.83 s cold source-match
  construction, which must be replaced by a simplified source-compatible collision
  representation with independently verified ray/visible-cover parity before any
  integration acceptance.
- Independent arena review `33b650cc` (own harnesses, 98 files) passed geometry,
  real-source rounds, launcher matrix and graphical captures, and found:
  - **High — wall-contact trap on both Prism ramps.** A bot landed 0.06 m inside a
    ramp edge and was immobile for 71 s of a 180 s round; mirror case on the east
    ramp. Escaping requires geometry change, not a source edit. A dedicated
    **trap-fix lane** now owns the three arena builders + `tools/godot-native-arenas/**`
    and must reproduce, fix, regenerate hashes, re-run mover/actual-map/live gates
    and refresh stale/missing arena evidence. The route lane was carved out of those
    files.
  - **Medium — stale Aurora evidence images** (old hash 909daa29, pre-navigation)
    and **Low — missing post-fix Prism images**; both assigned to the trap-fix lane.
  - **Cinder residual fixed in `5ebef3b0`** (re-accepted by lead): causeway safety walls
    and service covers carry walkable caps, low thin guard bands are trimmed to a
    jump-clearable lip, burial tolerance rises to 0.45, and Cinder opts into the source
    spatial navigation (Aurora precedent; the caps would otherwise bake isolated nav
    islands and pruning removes exactly those). Band counts: prism 590→580,
    aurora 4,849→4,842, cinder 848→138. Audits: 0 landed locks on Cinder at 4 seeds,
    prism 3, aurora 2, kills/respawns/results/restart intact. Accepted consequences,
    recorded deliberately: a player can now hop a thin guard rail (previously an
    unrecoverable trap), and one 3.5 s bouncing window remains at the bore causeway lip
    (seed 777, maxRadius 0.04, one-hop escape, no landed lock) because removing that band
    would open a fall-through hole into the sealed bore. Linux/llvmpipe measurements.
  - **Trap fix delivered and accepted** (`bdfa4203`): compiler now buries/terraces/
    overhangs movement bands and Prism+Aurora guard rails carry walkable caps, so the
    contact band cannot strand an actor; visible geometry and ray collision unchanged,
    Cinder keeps its safety walls. Lead re-ran the real launcher smoke on the new hashes
    (prism `1901d0ae…` ack16, aurora `8457812f…` ack13, cinder `2d5e5cfa…` ack17) and
    `actual-maps.mjs` 3/3; the flagged `probe.gd` sealed-volume retarget is reviewed and
    accepted. Residual Cinder caldera-step locks at seed 20260922 (97.5 s / 22 s / ≤2 s,
    pre-existing natural-terrain class) went back to the same lane for authored terrain
    reshaping and is a release blocker if it cannot be bounded below 1.5 s.
  - **Low — unknown authority options silently ignored and readiness answering on
    any path**; assigned to the route lane as cheap strictness work.
  - **Low — concurrent operator-lane import noise** in review runs, expected to
    clear once that lane commits.
- Owner has asked for the identity maps to be populated with assets, shaders and
  effects and made playable for the next Windows release. Sequencing (wave 1 active):
  - **Identity art/performance lane** owns `godot/identity_maps/**`,
    `tools/godot-identity-maps/**`, `godot/tests/identity_maps/**`,
    `port/native-identity-maps/**`. Must first cut cold source-match construction to
    <=1.5s per map (hard ceiling 3s) via a simplified source-compatible collision
    representation with ray/visible parity, then deliver the three material
    identities, bounded signature effects, and verified 960x640/1280x800/1920x1080
    renders with honest cost comparisons.
  - **Identity route/package lane** owns `port/native-arenas/**`,
    `godot/native_arenas/**`, `tools/godot-dev/launch*.mjs`,
    `tools/godot-package/{options,run,discover}.mjs`, `build.py`, `verify_windows.mjs`,
    `*.cmd`, plus `port/native-identity-dm/**`. Extends the registry/schema/factory,
    the Godot composition and the launcher/package closure for **Deathmatch** on all
    three identity maps, keeping the existing three arenas byte-compatible.
  - Envelope and canonical-hash contract is fixed in both prompts; the route lane
    validates strictly and re-runs after art hashes are regenerated.
  - **Identity route/package lane landed** (`2c80979f` + follow-ups): identity
    family in the native registry with a strict second schema (mode/palette/art/
    cameras/landmarks, `objectiveZones`, `teamSpawns`), source `Match` construction
    per identity map, `demo.tscn` loading `identity_maps/map.gd`, six-map Deathmatch
    cards with one sun/environment each, launcher `--map=` acceptance, hashed
    identity JSON in the package closure and menus. Verified: 32/32 arena tests,
    175/175 tool tests, 6/6 launcher smokes, 12 visually audited Xvfb captures,
    detached package probe and smoke. Authority strictness items done (unknown
    options reject; readiness `GET /` only).
  - **Release blocker (expected):** the release build refuses uncommitted runtime
    data, and the art lane has not yet committed `godot/identity_maps/**` and
    `godot/native_arenas/generated/**`. Re-run the package build only after their
    commit; the same flow already passes from a staging snapshot.
  - Wave 2 (later, one lane per mode): Domination on Vermilion Fold through
    `zone_modes` (zone composition route, domination authority path, team spawns,
    capture/loss acceptance) and Horde on Nacre Engine through the native Horde
    adapter (reviewed static map/factory hook under its loopback/single-human/epoch
    contract, plus wave/defeat/boss/endless acceptance). Both remain unstarted.
  - Wave 3: full aggregate verification, Windows package rebuild and publication.
    Toolchain archives for the build are present and SHA-512 verified locally.
- Owner asked for more effects before the build; two pre-release FX lanes are
  active while the art lane finishes (both must land before packaging):
  - **Weapon-handling FX** owns `godot/first_person/**`, `tools/godot-weapons/**`,
    `godot/tests/first_person/**`, `port/native-weapon-handling/**`: authored
    `Ejection`/bolt/magazine/heat anchors for all ten weapons, cyclic bolt/slide
    animation, authoritative reload magazine handling, pooled casings, barrel heat
    that never occludes the sight picture.
  - **Impact + player-state FX** owns `godot/world/combat_overlay.gd`,
    `godot/world/combat_feedback.gd`, new `godot/player_fx/**`,
    `godot/tests/player_fx/**`, `port/native-player-fx/**`: directional damage
    indicator, bounded low-health state, authority-backed shield-break cue,
    death/respawn feedback, material-aware pooled impacts, all inside the existing
    F9/F10 quality and lifecycle drains.
  - Hard rule for both: existing gates stay green, no unverified commits, and each
    reports what it left out rather than trading correctness for scope.
- **Third-person weapon detail landed** (`11b7bb5f`, `52eb21b0`): all ten world weapons
  carry the shared six-channel identity vocabulary — 6,240 → 19,640 triangles across the
  set, 20 → 40 draws, 220 KB → 928 KB, bounded at 4 batches each (roster cost +64 draws,
  ~+3.9 %). Verified: **0.0 m anchor drift**, pinned-anchor gate 1e-4, 450 grip fixture
  cases at 3.77e-7 m unchanged, exact hand-clearance analysis with **0 triangle contacts**,
  byte-identical re-export, and a live 4-bot session at both resolutions with grips
  attached and clean results/restart. One divergence reported rather than hidden: the
  rocket launcher's foregrip channel is answered with a flush handguard because the fixed
  left palm presses flat on the receiver face and a protruding grip would break the
  zero-intersection gate. Two evidence refreshes the lane left outside its ownership were
  committed by lead (`3cd4bafa`).
- Owner asked to add detail polygons to the weapons and make the ten weapons
  visually distinct. Two coordinated pre-release lanes: **first-person weapon detail**
  (owns `tools/godot-weapons/**`, `godot/first_person/**`, `godot/tests/first_person/**`,
  `port/native-weapon-detail/**`; target 3,000–6,000 tris, ≤8 batches, writes
  `WEAPON_IDENTITY.md` as the single source of truth) and **third-person weapon detail**
  (owns `tools/godot-operators/world-weapons.mjs`,
  `godot/source_operators/generated/world_weapons/**`, `godot/tests/source_operators/**`,
  `port/native-weapon-detail-world/**`; target 1,200–2,500 tris, ≤4 batches, must match the
  identity document). Shared six-channel identity framework: receiver massing, feed
  identity, muzzle device, stock/grip treatment, sight family, accent + signature greeble.
  Hard invariants: anchors within 1e-4, satisfied 0.0 px sight alignment with 0 opaque
  target-gap pixels, no hand/grip intersection, hip framing clearance, byte-identical
  re-export, and every existing ADS/handling/weapon-effects/combat-integration gate green.
  Source `game/**` stays locked and read-only; both lanes must report per-weapon if a
  design cannot pass rather than trading correctness for detail.
- Owner asked for massive particle blood spurts on hits and a messy death splatter
  that stains surroundings. **Blood/fluid FX lane** owns NEW `godot/blood_fx/**`,
  `godot/tests/blood_fx/**`, `port/native-blood-fx/**` and must not touch the
  integration file (`godot/world/combat_feedback.gd`) that the player-state lane
  currently holds — it delivers a `configure/apply_state/apply_events/reset/
  set_quality/snapshot` controller and lead performs the single wiring call.
  Requirements recorded in the lane brief: authoritative health-damage only (no
  bleed on shield/armor-only hits, derived as `amount - shield`), directional
  spurts scaled by real damage, death burst with ramp/airborne-correct surface
  staining, compatibility-safe pooled stain quads (no Decal nodes) that never pass
  through walls, bounded totals inside the existing Low/High/Extreme vocabulary,
  lifecycle drains and dedup, and a documented single-point fluid override (default
  crimson blood) since the operators are armored machines. Every other pre-release
  lane is untouched; the identity art lane's own commit (`e140e489`, `e17d6022`)
  is landed with cold construction at 27/19/39 ms per map.
- Lead test repairs for the pickup-asset and integrated-effects contracts:
  `round_boundaries.gd`, `entity_visuals.gd` pickup section, `combined_arms/graphics.gd`.
  The `entity_visuals.gd` actor section must be rewritten against the source
  operator hierarchy once presentation switches; it currently still asserts the
  legacy direct-child `Helmet`/`Muzzle`/primitive-bounds contract.
- Original Three.js operator import proof remains its own active lane.
- Lead retains package discovery/build/Windows verification, aggregate checks,
  final integrated review and release. The visual-identity trilogy prompt is
  delivered (`f1dd672`); those three additional maps have not been commissioned
  into this checkout's active ownership by this lead.

### Agreed contracts

- `session.aim_requested()` gives eligible local ADS intent; source `controls.ads`
  already exists. Rig owns animated/FOV response. Weapon selection being disabled
  (Arms Race) must not hide the rig or disable ADS.
- Native DM uses `--experience=native-dm --map=prism-foundry|aurora-basin|cinder-array`.
  Original exploration routes stay available. Existing nine-map catalog stays
  source-locked; the native arenas use a separate registry and port-owned authority.
- Generated arena envelope: `schemaVersion:1`, `id`, `name`, `geometryHash`,
  `arena` (source-consumable geometry/spawns/pickups/nav), `spawnPoints`, `routes`.
  Files: `godot/native_arenas/generated/<id>.json`.
- Map-only wrappers: `godot/native_arenas/maps/<id>.gd`, `build()`,
  `get_spawn_points()`, `get_arena_id()`. Gameplay cameras use source actor poses.
- Source Match uses highest-floor XZ navigation. DM variants deliberately author
  compatible routes and **visible** under-deck infill; a collider dump must not
  claim unsupported multi-layer traversal. Preserve exploration layouts separately.
- Source shots already ray-test camera→simulation muzzle→target. Visual muzzle
  effects attach to animated barrel anchors and converge to source-confirmed paths;
  they must not manufacture hits, ignore near-wall obstruction or change damage.
- Particle quality is explicit and bounded across the whole live pool, with an
  extreme setting up to one million. Report actual allocated/emitting counts and
  rendered performance, distinguishing fixtures, normal live sessions and hardware.

No campaign work, paid generation, edits to locked source simulation, external
pulse-rifle assets, user research, or shared-service changes are part of this pass.

## Deferred campaign

The owner wants a campaign remake, then explicitly deferred it for substantial
planning and research. **No campaign implementation is authorized by this lane
record and no campaign agent was launched.** `external-native-campaign-remake.md`
is retained only as an inactive preliminary draft; its architecture and mission
count are not agreed requirements. Schedule a dedicated planning task later.

`external-native-horde.md` is the replacement ready-to-copy development task.
Horde is an existing standalone source mode, separate from campaign design.

External tasks have complete scope/commands in
`external-native-objective-gameplay.md` and
`external-native-multiplayer-lobby.md`. They can be executed sequentially by
harnesses without subagents. No lane should change another owner's files,
silently merge shared branches, restart shared services or publish independently.

Published repository: <https://github.com/mojomast/cocs-godot>.
Screenshot gallery: <http://100.125.104.79:43595/> (Tailscale, screenshots only).
