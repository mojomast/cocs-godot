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
- **First-person weapon detail landed** (`e1634d2f`): new `tools/godot-weapons/detail.mjs`
  adds 519 reusable primitives (**+9,280 triangles**) to the existing moving assemblies,
  bringing the ten viewmodels to 4,448–6,472 triangles at a bounded 8 batches each and
  cutting worst-case batches from 11 to 8. Six identity channels are distinct across all
  ten weapons and asserted by both `verify.mjs` and the new `first_person/detail.gd`
  (345 checks, now registered in the aggregate by lead). Invariants measured green:
  anchors 0.0 drift with identical parents, settled ADS 0.0 px and 0 opaque target-gap
  pixels, muzzle reprojection ≤8.6e-5 px, hands ≥47 mm from every detail box through the
  live animated assemblies, hip centre clear at both sizes, byte-identical re-export.
  Accepted disclosures: weapons 2 and 8 exceed the 6,000-triangle soft target because
  their locked source bodies already are 6,092 / 5,228 (no decimation), and tubular ring
  collars re-tessellate 32→16/20 segments while sight-assembly rings keep 32 so the
  magnified optic picture is unchanged. 280 captures; lead reviewed the hip/ADS contact
  sheet and confirmed ten visibly distinct weapons.
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
- **Blood wall spatter landed** (`a7fa9e91`): death bursts now cast a bounded radial fan
  (nearest the lethal direction first) and place clusters plus at most one drip tail on
  walls as well as floors; impact jets place 3–7 mark clusters streaked along the jet.
  Candidates are probed in-plane and rejected for facing, reachability or solid overlap,
  so marks never land on void/sky, a wall's far side, or under a wall footprint. Caps
  raised with measured cost (stain pool 128 → 256; live caps 48/128/224; aging a saturated
  frame 0.105 ms median, one draw call per live mark). Proof: 220 headless checks plus
  rendered cases on real map geometry at both sizes showing 19–29 wall marks per death and
  **0 changed pixels / 0 marks on the far face** in every case. No composition re-wiring
  needed; F10 gained wall/floor/slope and skip-reason counters.
- **Debug/cheat tools (owner request: god mode, damage adjustment, unlock all weapons,
  bot count and live bot modification).** Lead reconnaissance fixed the honest split before
  the lane started: the source already supports `damage` (0.5/1/1.5/2), `speed`, `gravity`,
  `respawn`, `unlimitedAmmo`, `startingWeapon`, `loadout`, `botCount` (0–8), `difficulty`
  and ~15 mutators via `normalizeConfig`; **bots read `match.difficulty` every tick so it
  changes live**, damage is read per hit through `mutators.damageMultiplier` so recomputing
  mutators changes it live, while **botCount and spawn loadouts are construction-time** and
  therefore restart-applied. **God mode has no source support at all** and is implemented as
  port-side debug reconciliation of the human seat only, labelled a debug facility rather
  than game content. Debug is **off by default, never available in the multi-human
  lobby/room**, and displays an on-screen badge. The lane owns `godot/debug/**`,
  `port/native-debug/**`, the two local authorities and `godot/world/session.gd`, and may
  add exactly one adapter module to the package allowlist, reported to lead. Domination's
  authority gets wired afterwards by lead.
- **Asset coverage pass (owner request: use far more of the Moth assets for effects, shaders,
  bump maps and textures while growing a unique design language).** Measured baseline in
  `port/native-material-language/COVERAGE-BASELINE.md`: of 69 manifest keys only ~14 are
  literally referenced — **all 13 baked normal maps are effectively unused**, along with most
  textures, 3 of 5 material LUTs and 7 of 10 effects. Two coordinated lanes:
  - **Material-language library** owns `godot/moth/**` (+ new `godot/moth/derived/**`),
    new `godot/material_language/**`, `tools/godot-moth/**`, its tests and
    `port/native-material-language/**`; publishes a six-to-eight family library
    (base + normal + roughness + LUT emissive per family), a deterministic offline
    derivation tool for missing maps, a design-language document, and a gallery scene for
    review. Must not change the 101-plane inventory that the package probes assert.
  - **Material application** owns `godot/world/{viewer,environment_style,scenery_settings}.gd`,
    `godot/native_arenas/maps/*.gd`, `godot/identity_maps/map.gd`, `godot/moth_scenery/**`,
    `godot/graphics_atmosphere/**` and `port/native-material-apply/**`; applies the families
    by surface role across the six playable maps and the locked nine-map presentation with
    real bump maps, render-only (arena geometry hashes must not change) and with
    before/after renders plus a cost table.
  - Interface contract fixed in both prompts; if the library signature shifts, the applying
    lane reports to lead rather than editing library files.
- **Identity Horde landed** (`f8c20c11`) and was routed by lead: `--experience=horde
  --map=nacre-engine` loads `res://native_arenas/identity_horde_demo.tscn` in both the dev
  and packaged launchers through a reviewed static allowlist entry (scene and modes only
  from that entry; the locked nine-map check applies to every other map). No package
  closure change: the lane kept the adapter hook inline so the shipped inventory stays as
  reviewed. Rejections verified for a wrong mode and an unknown map.
  - Acceptance: startup wave 1 (SWARM, 3 enemies, 209 correlated snapshots); 4 waves with
    3 clears, 2 upgrade offers, **victory** and clean restart; **defeat** after 3 natural
    deaths with a fresh 3-life round and no auto-capture; peak run waves 1–5 with
    **10 simultaneous NPCs** and 27 kills. Corridors verified against the real source
    capsule (radius 0.42 m): measured minimum traversed channel **1.31 m** versus the
    0.84 m requirement, visual scale factors proven presentation-only.
  - **Fixed a pre-existing shipped bug found here**: `godot/horde/controls.gd` lacked the
    `focused` flag the shared combat stack gates on, so every Horde session — including
    the three original maps — logged ~1,600 script errors and had a dead effect stack.
    Zero errors after the fix.
  - Open, stated by the lane: boss wave, endless, full ten-wave completion, and upgrade
    *selection* (protocol v3 exposes no command for it). Peak cadence 18 fps median on
    llvmpipe with 10 NPCs is not a hardware claim.
- **Release pipeline landed** (`tools/release/release.mjs`, 24 tests, now an aggregate
  gate): dry-run by default with `--execute`/`--resume-from`, append-only state, refusals
  for dirty trees and existing tags. Rehearsal proved the real path: 138/138 gates in
  424 s, a real Windows ZIP built, and a resume that reused records. Critically it found
  that **the verifier was not self-contained** — gitignored GLB probes under
  `godot/content/probes/` made a clean checkout fail at `glb-import`; the pipeline now runs
  the export prep first, which is what makes one-command releases from a fresh clone true.
  Steps 4–6 (release/dispatch/push) were never executed by the lane, by design.
- **Material coverage pass** (owner request) — two lanes, see the coverage baseline entry
  above; running.
- **UI polish fully closed** (`94c4129b`, `7da9c42f`, `5f1a532e`): setup surface
  `680x2401 → 680x524` and popup-free, status panel `620x870/620x1545 → 620x70`, shared
  board `374x354`/`694x511` and Horde board `374x294`/`694x444` clear of the vitals at both
  sizes, truthful roster wording. Scoreboard 25→45 checks, match selection 95→98, setup +6;
  nothing weakened. Lead tamed the legacy pickup caption and honoured its range cap.
- **Benchmark + presets landed** (`0eb1c914`): 33 s scripted benchmark through the session's
  own input path, `BENCHMARK_RESULT` with real median/p95, `recommended_level()` presets,
  F7 trigger. Verified monotonic on llvmpipe (Low 221.9 / High 304.1 / Extreme 499.2 ms at
  1280x800). Owner run sheet in `port/native-benchmark/README.md`.
- **Domination on Vermilion Fold** — still running.
- **Tier 1/2 push (owner request: do 1–4 together, plus 5 and 6 where possible).**
  Five parallel lanes launched with disjoint ownership, lead retains all launcher and
  package routing:
  - **Domination on Vermilion Fold** — owns `godot/zone_modes/**`, `tests/zone_modes/**`,
    new `port/native-identity-zones/**` and a separate `identity_zone_demo` scene; must
    deliver a source-backed domination authority using the validated `objectiveZones` and
    `teamSpawns`, real capture/contest/loss/restart acceptance, spawn-to-zone travel
    timings and rendered evidence.
  - **Horde on Nacre Engine** — owns `port/native-horde/**`, `godot/horde/{demo,model,
    client,controls}.gd`, `tests/horde/**`, new `port/native-identity-horde/**` and a
    separate `identity_horde_demo` scene; reviewed static map/factory hook under the
    loopback/epoch/single-human contract, plus wave/defeat/restart and peak-load
    acceptance. Boss/endless must be declared open if unproven.
  - **UI polish** — owns `godot/ui/**`, `godot/horde/scoreboard.gd`, named protocol UI
    tests and `port/native-ui-polish/**`; fixes the setup-popup obstruction, the Horde
    compact scoreboard overlap, the misleading player-count label and the oversized
    result pickup captions, each with rendered before/after evidence.
  - **Release pipeline** — owns new `tools/release/**` and `tools/godot-package/**`;
    `release.mjs` dry-run by default, `--execute` for side effects, `--resume-from`, step
    logs and refusals for dirty trees/existing tags; must not modify `verify.py`.
  - **Benchmark + presets** — owns new `godot/benchmark/**`, `tests/benchmark/**`,
    `port/native-benchmark/**` and `godot/world/combat_quality.gd`; bounded in-game
    benchmark printing `BENCHMARK_RESULT`, recommended quality presets and a Windows
    run sheet so the owner can measure real hardware.
  - Owner-facing playtest checklist written: `port/combat-expansion/PLAYTEST_2026-09-22.md`.
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

## Release `combat-expansion-2026-09-22-v2` (published and verified)

Second combat-expansion prerelease, produced by the one-command pipeline on frozen commit
`c00b370a`: **147/147 gates**, 80,197,227-byte ZIP with sha256 `1122aeee…`, hosted Windows
verification **success** (15/15 cases, 134 files re-hashed), source pushed to `godot/main`.
Contents: Domination on Vermilion Fold, Horde on Nacre Engine, debug tools (off by default),
the benchmark and quality presets, the eight-family material language with 13/13 baked
normals now used, the four UI defect fixes, plus everything from the first expansion build
(six deathmatch maps, source operators, detailed weapons, effects and blood).

Open and deliberately not claimed: Horde boss/endless/ten-wave completion and upgrade
selection; hardware-GPU and human acceptance (all measurements are llvmpipe); campaign;
full Arms Race ladder; broader LATTICE rounds; asset-rights clarity.

## Release `combat-expansion-2026-09-22-linux` (published and verified)

First Linux prerelease, produced by the same one-command pipeline on frozen commit
`3877c833`: **150/150 gates**, `cocs-native-linux.tar.gz` 40,078,745 B with sha256
`136ee02a…`, hosted `linux-demo.yml` verification **success (16/16 cases, 132 files
re-hashed)**, source pushed to `godot/main`. Evidence:
`port/combat-expansion/evidence/linux-verify-release/`.

Contents: everything in Windows v2, plus the packaging fixes that made
`--experience=identity-zones` work from an extracted package (runtime closure now
declares the identity adapters; the packaged launcher honours the already-listening
zone authority), the Domination/cheats launcher entries (`Domination.sh`,
`Cheats.sh`; Windows gets `Domination.cmd`/`Cheats.cmd` on the Demo Menu), the
absorbed-hit blood mist (`absorbed_mist_strength`, default 0.5), the rendered live
native-DM blood check (`port/native-blood-fx/live.mjs`, gate `blood-live-native`), and
launcher presence/exec checks inside both package verifiers.

Pipeline incident recorded in the evidence SUMMARY: a resume that omitted
`--target/--workflow` dispatched the Windows workflow against the Linux tag and hard-
stopped correctly; re-resuming `--resume-from=verify` with the right flags passed.

Post-release hotfix in this commit: `Domination.cmd` and `Cheats.cmd` shipped with
inverted `choice` key mappings (key `1` exited, key `0` started Standard). Both now
map `choice /c` positions in descending order like every other menu in the package
(gate `package-identity-routes` passes; text-only assertions did not catch the bug —
behavioral launcher assertions remain future work in the menu lane).

## Main menu unification (owner: lead; drafting complete, integration pending)

Owner request: stop navigating the game through four surfaces (batch menus, shell
wrappers, disjoint in-game setup screens, duplicated JS route tables) and build one
in-game main menu that reaches everything.

Design contract: `/tmp/opencode/menu-build/SPEC.md` (out-of-tree while releases freeze
the checkout). Core: one registry (`routes_meta.mjs` + generated `godot/ui/routes.json`
from `options.mjs`), one menu scene (`godot/ui/main_menu.gd`, 22 routes in 5
categories: play/native/modes/lab/cheats), and a `run.mjs` supervisor loop that boots
the menu without an authority, re-validates the menu's emitted argv through the same
`options()` parser, runs the chosen route with the usual authority, and returns to the
menu when it exits. Empty argv becomes the menu; every existing flag/marker keeps
working; `--debug-panel` gains a real router (accepts combat/horde/native-dm/identity-
zones, rejects lobby) and arms `COCS_DEBUG` itself; `--waves` becomes a validated horde
option.

Drafts (validated out-of-tree): Godot side in `/tmp/opencode/menu-build/godot/` +
`A-NOTES.md`; Node side in `/tmp/opencode/menu-build/mirror/` with `gen_routes --check`
idempotent and full `node --test` suites green vs a pristine control + `B-NOTES.md`.
Three new gates planned (`route-parity`, `main-menu-contracts`, `main-menu-smoke`),
packaged verifiers gain a `MENU_READY` case, `ui/*.json` joins both include filters.

Integration order after `combat-expansion-2026-09-22-v3` ships: copy drafts → run
Godot import once so new `.uid` sidecars are committed **before** any release run →
register gates (150 → 153) → run targeted suites → update both PLAY.md files and the
release notes for the next release → full sweep → commit.

## Moth asset uniqueness pass (2026-09-24)

Owner report: "many of the examples of bump maps are very similar". Audit (`node
tools/godot-moth/uniqueness.mjs`, new): the 13 baked normals are one quantum-noise
class — median pair similarity 0.567, six pairs above 0.90 (up to 1.000) — because
every normal job submits `style: xy`, `strength 0.25–0.55` and no `generateValues`.
The baked manifest/pixels are source-locked, so the in-game fix shipped through the
editable derived pipeline instead:

- `tools/godot-moth/derive.mjs`: NORMAL_TARGETS 2 → 12 (per-target magnitude and
  anisotropic kernel `radius: {x, y}`), directional kernels for ice cracks and
  concrete drips, broad oxide pitting; 38 derived files regenerated deterministically.
- `godot/material_language/families.gd`: 10 rebinds so families with albedo structure
  bind an albedo-derived normal (pearl default/worn, enamel stucco/crackle/damp,
  alloy circuit, oxidised default/scorched, regolith mossy, biolum matrix); all 13
  baked normals stay bound somewhere (contract: counts.normals == 13).
- Result: derived-set audit median 0.091, max 0.897, **0 near-duplicates, 0 flat**
  (was 6 near-duplicates). Before/after sheets on the gallery.
- `scripts/moth-bake.mjs`: heightGrid gained `freq`/`octaves`/`angle`/`anisotropy`
  and seeded `cells` (defaults reproduce old output) so the NEXT paid bake can be
  unique; docs/MOTH.md carries the per-job re-bake proposal (upstream manifest +
  credits required).
- Verification: material-language 989/0, material-derived 4/4, moth-resources 101
  planes, moth-scenery 9 maps, moth-export 2/2, moth-bake game suite 46/46,
  coverage floor OK. Uncommitted with the rest of the tree.

### Uniqueness comparison gallery (2026-09-24, same day)

New page `moth-uniqueness.html` (linked from `moth.html` + `index.html`): per-rebind
drag-to-compare sliders (exact shipped PNG tiles, ×8/×4 nearest), the two set sheets,
per-plane structure/twin metrics, five same-scene in-game before/after pairs plus a
byte-identical control, changed-pixel diff maps, kernel table and reproduce commands.

In-game pairs: rendered with the lane's own `gallery_capture.gd --mode=family` at
1280x800 (GL Compatibility, private Xvfb, software raster). BEFORE = throwaway copy
`/tmp/opencode/godot-before` with exactly the ten rebinds reverted (20-line diff);
AFTER = the real tree. `hazard-industrial` (no rebinds) renders **byte-identical**
before/after, proving the copy method changes nothing else; changed-pixel deltas:
pearl-ceramic 9.72%, oxidised-copper 12.73%, brushed-alloy 3.98%, regolith 2.58%,
enamel-glaze 0.88%. `bioluminescent-membrane` is pixel-identical in this view (panel
shows sorted variants[1] = fringe + default; only `matrix` was rebound).

### Correction (2026-09-24, caught while wiring the API key)

The uniqueness entry above states the normal jobs submit "no generateValues".
That is wrong. Each of the 13 normal jobs already carries a distinct
`generateValues` height grid (seeds 11-113; kinds noise/ridge/cells) and a
recorded jobId. The measured similarity (median 0.567, six pairs above 0.90)
stands; what flattens the relief is the engine/bake settings - weak
`params.strength` (0.25-0.55) over a blurred 64 px grid, a 32 px output, and
blur-core's smoothed character. The re-bake proposal is therefore reframed as
stronger per-job settings (amplitude up, output 64 px), not more seeds.

### Engine-semantic correction and live bake pilot (2026-09-24)

The paragraph above misinterpreted the engine parameter: `blur-core-v1` defines
`params.strength` as **blur amount** (0 unchanged, 1 maximum blur), and `reach`
as how nonlocal that blur is (0 local, 1 fully nonlocal). A live 64 px rock at
strength 1.0/reach 0.3 flattened further (structure standard deviation 6.66
versus 10.39 shipped). Three low-blur live variants instead produced visible
ridge, cell and directional-grain relief (structure deviations 48.46, 27.86,
41.40; pairwise max similarity 0.25). Four successful jobs cost 1 credit each;
one invalid one-axis/two-strength-list submission failed, billing unknown.
The comparison is live at `http://100.125.104.79:4371/moth-pilot.html`.
`docs/MOTH.md` now calls for low blur/reach and 64 px output; the baked 13-job
upstream pass is in progress. The shared bake request queue was integrated at
`2993a2c0`; public `mothbake` has the same mechanism, 200/200 tests and green CI.

### Current independent workstreams (2026-09-24)

| workstream | owner/worktree | exclusive edits / integration |
| --- | --- | --- |
| Alt-fire variety | `lane/alt-fire`, `/tmp/opencode/cocs-alt-fire` | Landed as `26f5a78f`: distinct cluster/mortar/mine/flak bodies, trails, impacts and voices. New `alt-fire` gate 105/0; audio-feedback 411. |
| Benchmark autostart | `lane/benchmark-autostart`, `/tmp/opencode/cocs-benchmark-autostart` | `godot/native_arenas/demo.gd`, benchmark contracts/runner/docs/evidence; landed as `002e6f2b`; lead owns its aggregate-gate registration. |
| Moth normal re-bake | nested mini-orchestrator, `lane/moth-full-pass` | 13 live jobs (13 credits), committed upstream as `2048a4f9`; byte-identical clean-lineage commit `515daf07` merged into upstream main `9a89e800` (branch CI success 36043026485). Port merge `f584d199`, source pin/export `6fa77b08`. New baked set: median 0.100, max 0.645, zero pairs >0.90. |
| Third-person weapon identity | nested mini-orchestrator, `lane/world-weapon-identity` | Landed as `0fe8df22`: all ten exported world silhouettes distinct (max side IoU 0.820 → 0.728), source grips/muzzles unchanged, four draws each; model/identity/grip gates green. |

Lead verifies and integrates lane commits, registers gates and runs the final
combined sweep before packaging the Windows and Linux releases.

The benchmark fix landed as `002e6f2b` with its rendered env-armed/unarmed
gate `d1a84373` (merged-base pass). Weapon, Moth and model gate registrations
landed as `0ddc88a6`; aggregate now counts 174 commands plus the toolchain and
release guards (176 gates). Moth gallery: `http://100.125.104.79:4371/moth-rebake.html`
(13 original/current sliders), linked from `moth.html` and the gallery index.
Upstream main's pre-existing camera-ownership CI failure belongs to the web
demo frame-cap change at `d4344d8f`; the clean-lineage source branch CI passed.
Hardware-GPU FPS/Extreme verdict and owner playtest remain pending.

### Weapon-feel prerelease shipped (2026-09-24)

Release: `https://github.com/mojomast/cocs-godot/releases/tag/weapon-feel-2026-09-24`.
The frozen/tagged port commit is `03ad5ccff66c1daaf5ec69bf0c675219ddac92c1`;
the locked source is `515daf07589150dd3241f4ae1425cc1b093912f5`.
`godot/main` was fast-forwarded to the release commit before publishing, so both
hosted workflows ran the matching verifier. The aggregate passed **176/176**
gates. The release's `release-verification.json` records hashes, commit IDs,
local Linux smoke, and hosted results:

| Platform | Archive SHA-256 | Fresh-extraction hosted check |
| --- | --- | --- |
| Windows | `4f1279e18bb7edcc57ede295bf86c4e3c27dae02d5c9ed6d3e07598633e20f3d` | [17/17 passed, run 36045856703](https://github.com/mojomast/cocs-godot/actions/runs/36045856703); 139 files re-hashed |
| Linux | `5ae88007013dbd191a2e59dcf69124b6ec80949fdb3175ed1f19c3081159896e` | [17/17 passed, run 36045856802](https://github.com/mojomast/cocs-godot/actions/runs/36045856802); 132 files re-hashed |

The archives have the same 375-resource generated hash tree, both check their
source and port commits, and Linux also passed 17/17 locally from a fresh
extraction with a space in its path. `port/release-notes/weapon-feel-2026-09-24.md`
has the owner benchmark command. This host renders with llvmpipe; the owner
still needs to send the hardware-GPU `BENCHMARK_RESULT` and map-by-map Extreme
verdicts. The upstream web-game camera CI regression remains outside this
port release and still awaits the owner's approval for a forward fix.

### Mode-parity integration after the weapon-feel prerelease

Four independent branches were integrated on the port: local render-clock
translation `127b5352`, animated muzzle/crosshair cosmetics `f30ca35c`,
authoritative Horde blood/death presentation `007e6984`, and menu diagnostics
with local 24-bot DM/Domination authority `1ed9c23f`. Lead integration adds
the native/Horde shared-motion hook, Combined Arms infantry smoothing, the
third-person muzzle callback, Nacre Engine occlusion lookup, Combat's validated
0–8 bot menu argument, an actual in-game F11 diagnostics overlay on all routes,
and the explicit two-helper package closure. The clean-lineage source pin stays
`515daf07589150dd3241f4ae1425cc1b093912f5`; no Moth credential was added.

Verification was scheduled **one resource-heavy command at a time**. Local
native/identity Domination 24-bot smokes each reached 25 actors, sent movement
and fire, and exited cleanly. The rendered env-autostart and unarmed benchmark
gates both passed after Xvfb began waiting for a real X11 client instead of a
socket name. The final serial aggregate passed **185/185**, including the new
24-roster gate (six focused checks). Release-note commands
for the owner's GPU/Extreme map review are in
`port/release-notes/mode-parity-2026-09-24.md`. Hardware results and hands-on
Horde/movement/alignment verdicts remain pending.

### Nacre Engine Horde survival-map revision (next-build work)

The reauthored Nacre Engine has an explicit southern player start, enemies
approaching from both flanks and the northern yard, two supply wings, a connected
retreat loop, authored cover, and five source pickup caches that open on waves
1/3/5/7/9 through the **local-only** Horde adapter. Their locations and live
status appear on in-world signs and the Horde strip. Source-owned combat/wave
rules and the pinned source commit are unchanged. The researched design and
pickup diagram are in `port/native-identity-horde/SURVIVAL_MAP.md`.

Serial checks pass: identity authority 13/13 (including an accelerated ten-wave
cache sequence, not natural ten-wave combat), base Horde 56/56, package 39/39,
identity-map graybox 42,387 aggregate checks (Nacre routes included), and Godot composition 25/25. A software-rendered
natural three-wave run on the revised map won with 12 kills and three lives,
showed the wave-3 Plasma opening, and restarted cleanly; its startup and run
archives are under `port/native-identity-horde/evidence/2026-09-25T0*`.
The first three-wave attempt hit the 96 MiB raw evidence cap near the end of
wave 3; the recorder is now bounded at 192 MiB, and the subsequent attempt
completed/validated. A natural ten-wave, champion, defeat and weapon-balance
playthrough still precedes the next owner hardware playtest/build.

### LATTICE Strike flagship research

An Astra read-only audit of source roles, orders, economy, traversal, map graph
and the current Godot surface produced
`port/native-lattice/FLAGSHIP_VISION.md`. Its immediate recommendation is a
complete, readable native FPS/network match before adding more systems. The
largest proposed later source-rule change is coupling persistent squad orders
to **physical** capture: current short-lived HOLD/ATTACK can advance an empty,
uncontested point. This is a design proposal only; source pin and gameplay
rules remain unchanged.

### Nacre Horde build preparation (2026-09-25)

The revised map now includes selectable, source-validated operator/harness pairs
through the local Horde authority and the main menu; Claude remains locked to
Claude Code. The Nacre east armor station was shifted 1 m to avoid a false
Godot/source corner-sightline disagreement. A fresh source-ray oracle and the
Godot static ray gate pass. The full serial verifier passed **185/185** on this
tree. The rendered three-wave evidence predates the 1 m armor adjustment and
loadout menu wiring; the source match and package build use the revised bytes.
Release instructions are in `port/release-notes/horde-nacre-2026-09-25.md`.

The owner measured a separate Prism Foundry 12-bot run on an RTX 4070 Laptop
GPU at 1280×800: High, median-derived 88.8 FPS, p95 16.677 ms, partial
verdict (95% of the window under input control). Nacre hardware performance
and the natural wave-9/ten-wave playthrough are not covered by that result.

Six read-only Flash LATTICE research reports landed, and Astra wrote
`port/native-lattice/FLAGSHIP_SPEC.md` and `FLAGSHIP_PLAN.md` for later
sequential implementation. The source pin remains unchanged.
