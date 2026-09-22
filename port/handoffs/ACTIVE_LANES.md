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
