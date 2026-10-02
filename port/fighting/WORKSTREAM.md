# Full-roster fighting mode — research, then implementation

## Owner's request

Research Godot fighting games and tools that accelerate development using Flash
subagents. Plan a fighting mode using **all existing operators**, each with distinct
stats, combos, proper unique animations and unique effects. Research projectile
attacks, grapples, throws and other fighting mechanics. Use the best-looking
existing maps as stages. After research and planning, use **Sol and Astra** agents
to implement the mode, assets and animations.

## Research ownership

Three `deepseek/deepseek-flash` workers are running in the background. They have
research/documentation scope only, no runtime implementation or heavy-tool grant.

| Workstream | Session | Branch | Deliverable |
|---|---|---|---|
| Godot engines and combat mechanics | `ses_f027b718dffekVY2gb7cDjpJIr` | `fighting/research-engine-20261002` | `research/ENGINE_MECHANICS.md`: verified frameworks/tools, compatibility/licenses, simulation and frame-data contracts, combat mechanics and acceptance |
| Distinctive animation and assets | `ses_f027b6fd2ffe9A9whn2K1QlFk1` | `fighting/research-animation-20261002` | `research/ANIMATION_ASSETS.md`: current rig audit, animation production/retargeting, verified asset terms, per-character animation and VFX acceptance |
| Exact operator roster and stages | `ses_f027b6ea7ffedSk10e1AdmHcza` | `fighting/research-roster-20261002` | `research/ROSTER_STAGES.md`: source-verified complete roster, proposed stats/moves/identities, visually inspected stage shortlist |

Worktrees: `/home/mojo/.tmp-on-disk/cocs-fighting-research-<engine|animation|roster>-20261002`.
Each researcher owns only its named document and commits on its isolated branch.
No nested agents. References must contain actual inspected URLs/code/image paths,
version/license findings and distinguish observed facts from proposed design.

## Research-to-build handoff

After **all three research results** arrive, parent consolidates a concrete design
and implementation contract before delegating runtime/asset production. Decisions
to settle from evidence:

1. Exact full roster and identity-preserving per-operator stat/moveset matrix.
2. Fighting plane/camera, round flow, local versus/AI/training controls and first
   playable scope. Networking support must have its own explicit proof.
3. Fixed-tick authority and input buffers; startup/active/recovery, blocking,
   hitstop/stun, cancel/link windows, scaling, juggle/anti-infinite rules, meter,
   projectile interaction, throws, techs and paired animation alignment.
4. Existing-rig integration, skeleton/action naming and source-frame-to-pose
   contract. Every operator must have genuinely authored motion signatures;
   recoloring or changing playback speed alone does not meet the request.
5. Distinct VFX silhouettes and event timing, presentation budgets and readability.
6. Evidence-ranked map stages, bounded scene reuse, camera framing and clear
   fighter silhouettes. Unrendered candidate art cannot be called best-looking.
7. Framework/tool adoption versus reference, compatible versions, licensing,
   package closure and reproducible asset builds.
8. Parallel implementation ownership plus cross-lane/native acceptance and release
   dependencies, including current prepared-feature integration.

All three reports are complete. Parent consolidated their findings and corrections
into [DESIGN.md](DESIGN.md), then launched implementation from **`37dd3da4`**.

## Active implementation ownership

| Lane | Model | Session | Branch | Owned deliverable |
|---|---|---|---|---|
| Combat core / AI | Astra | `ses_f026f7ab3ffeH2Gn5BX0BDDz5i` | `fighting/core-20261002` | Fixed-tick combat, move/input recognition, throws/projectiles, resources, deterministic state and AI |
| Nine-character movesets | Sol | `ses_f026eedd8ffeCVNtizjJEn6vHg` | `fighting/content-20261002` | Roster/rules/frame data, distinctive specials and supers, combo inputs and schema validation |
| Rigs and unique animation | Astra | `ses_f026e25e4ffezp2kvz5VGox7dz` | `fighting/animation-20261002` | All nine fighting rigs, Blender-authored clip recipes, paired throws, runtime playback and asset provenance |
| Interface, input and stages | Sol | `ses_f026d6c45ffefUJ0hXFvdcTgG3` | `fighting/presentation-20261002` | Character/stage selection, versus/AI/training, two-player controls, HUD/camera and three initial map stages |
| Unique effects and sound | Sol | `ses_f026ccc26ffexFjFqmEZ171Q6x` | `fighting/effects-20261002` | Nine distinct effect vocabularies, bounded source-event presentation and audio |
| Independent acceptance | Astra | `ses_f026c14a5ffeK3WZVDmpQEEylH` | `fighting/verification-20261002` | Mechanics/matchup/animation/stage/lifecycle gates and bounded merged native runner |

Models: `openai/gpt-6.1-sol`, `openai/gpt-6-astra`. Worktrees:
`/home/mojo/.tmp-on-disk/cocs-fighting-<lane>-20261002`; evidence uses
`cocs-fighting-<lane>-evidence-20261002`. All six run in the background, without
nested agents. Shared APIs, fixed-point units, clip/move IDs and file ownership are
defined in DESIGN.md. The parent resolves cross-lane schema extensions and final
integration. No lane received a Blender/Godot grant at launch.

## Received research and parent review

### Animation and independent acceptance checkpoints

Core `ce3f603b` + `6be3b1ce` is merged as `4d4b952d` + `09160dc0`, completing
source integration of all six implementation lanes. The actual roster corrections
are consumed with no new stat/move/timing edits. Core lane passed 227 Node checks
(222 content plus five core/trace checks) and grammar parsing; native compilation,
mechanics, determinism and combo acceptance are still pending. Snapshot contract
now exposes shared dynamic pair knots, projectile `owner` and original provenance,
true contact coordinates and top-level anchor/stance timers. Animation owner is
binding the dynamic pair knots in a bounded source follow-up.

Foundry explicitly released the heavy slot. Parent issued
`FINISH-COMBINED-NATIVE-20261002-A` to the existing finish integration Astra
`ses_f0294303bffed6Fb8UJLKe4ZDz`, using parent `09160dc0` in the existing sandbox.
It covers combined feature native verification plus asset-independent fighting
core fixtures, invariants and 27 actual traces in both facings after native typing.
No fighting art production is authorized yet. Meta/Mistral Blender/native slice
follows the integration owner's explicit process teardown/release.

Animation pipeline `bebcf101` + `e3c51498` is merged as `20145483` + `fe5e94c2`.
It provides a common 20-bone rigid-skin conversion, 336 distinct state/combat
recipes, 25 shared victim choreographies, content-bound manual seeking and
Blender build/reopen/export scripts. Source checks sampled 34,221 poses and 7,425
task-space contacts. Those closed-form checks do not establish visible contacts,
foot planting or native rig correctness. No fighting master or GLB exists yet.
The first granted animation production is Meta, then Mistral, then an inspected
integrated slice before the remaining seven. Initial self-contained GLBs may
duplicate victim transport data while source Actions are shared; a shared Godot
library optimization is deferred until actual track-path compatibility is proven.

Independent acceptance `1267f122` + `9549da1c` is merged as `583ed124` +
`2f9fa981`. Sixteen Python tests passed on its lane, including evidence refusal,
binary validation and sparse-input semantics. Missing generated assets correctly
leave source acceptance deferred. Native gates cover the first slice, input-only
combos/pairs/AI, JSON continuation, mirrors and alias-aware clips; all are unrun.

The verifier exposed proposed ground-combo separation 550 inside a 660-unit
pushbox width. Content owner is correcting authored spacing and adding a negative
check. Core owner is resolving shared paired-animation phases for late-active
throw catches and delayed counters. Neither issue may be hidden by teleporting
fixtures after setup or inventing visual damage/release timing.

### Effects and presentation source checkpoints

FX `52c74a0c` is merged as `9fd6f74e`: nine form/motion vocabularies, 138 attack
IDs, 99 named cues, bounded director and 54 reproducible original PCM files. Five
source tests and grammar parsing passed on the lane; runtime/audio/visual quality
is unverified. Pool limits are configuration, not measured GPU budgets.

Presentation `c995ba66` + Home hook `53505568` are merged as `b0c23d43` +
`dcc6aa4e`: JSON-driven nine-character selection, AI/local/training shell, private
input, HUD/camera and four stage adapters. Lane source checks include 918 camera
extrema and stage/resource checks; no native UI or rendering has run. Production
start blocks visibly when the core/visual dependencies are absent. The mode is
not complete or package-accepted merely because a Home route exists.

Bounded follow-ups assigned: UI persistent-projectile/socket/pause-audio wiring,
very-short-input latch, precise core contact event coordinates. The completed Flash
efficiency audit also drives shared-rig/clip reuse and a Meta/Mistral native slice
before bulk exports. See `port/efficiency/DECISIONS.md`; all-nine unique animations
and effects remain required. Content schema/prose-free provenance changes and
core input/math/hitstop/JSON corrections are in progress with existing owners.

Presentation follow-up `a814d422` is merged as `bc78be27`. The actual FX director
now receives projectile snapshots, post-pose socket accents and pause/focus/Settings
audio state; new rounds/seeks clear FX history. Short button taps latch for one
simulation tick, then release, matching core-derived input edges. The training
tech dummy emits separated held samples. Production FX dependency checks and
prepared InputEvent negatives are included. Lane grammar, interface, resource and
918 camera checks passed; native input/audio/reflection/seek execution remains
pending. Parent reviewed the integration diff without repeating unchanged suites.

### Fighting content checkpoint

Content `827d24a8` + `79d98652` is merged as `0193f14a` + `b0669433`.
Nine operators have 138 authored moves (135 required plus three Gemini stance
variants), 27 proposed combo traces, 336 state/combat clip requirements and 25
paired timelines across nine victim bodies (225 victim instances). Fourteen
source tests passed on the lane; actual-core combos, native motion and balance
remain pending. `content/CONTRACT_DETAILS.md` now supplies exact optional fields
to the core, animation, presentation, effects and independent verification owners.

Parent merge check initially passed 13/14: the design hash correctly detected the
newly appended Helix stage/resource decision. Parent inspected the diff: only the
fourth-stage eligibility/resource note changed, with combat interfaces/stat targets
unchanged. `content/FREEZE.json` now records the reviewed updated DESIGN hash;
runtime roster/rules, source identities and all other content hashes are unchanged.
Initial failure is retained at `/tmp/opencode/fighting-parent-content-tests.tap`.

Content audit corrections `bcb1effe` + `242d5741` are now merged as `1c19f1ca` +
`70c1ce4b`. The enforced freeze now covers machine-readable balance/state/schema
inputs rather than editable prose. Full optional-field validation and sparse
trace expansion are implemented. All 18 grounded combo candidates use the legal
660 mm pushbox width; nine airborne candidates remain unchanged. DeepSeek charge
setup includes ordinary-input defender following. The lane passed 222 source
tests, including clean-directory regeneration; actual-core combo proof remains
pending. Original 550 mm fixture failure is documented, not erased.

Roster hash is now `a736dcfe91d44a08b165e1f7191420617984a561972505b0dd53df1b22cd4748`.
Parent resynchronized the effects-only contract/catalog and ran its five source
tests successfully. Only roster hash/provenance fields changed in effect outputs;
all 54 PCM files, moves/stats/resources/rules and animation timings are unchanged.
Core owner received the exact corrections and final data contract.

- Engine report `87b7fc4f` (parent `98064fb4`) received. Parent independently
  verified Castagne's v0.58 Godot-3 release and Sakuga's Godot-4.7/.NET README.
  An isolated local fixed-tick Godot fighter is the leading recommendation;
  architecture is finalized after the roster/stage research also arrives.
- Animation report `512e7716` (parent `afa1c714`) received. Existing nine
  operator GLBs have zero skins and zero animation clips; current motion is
  runtime procedural. A new authored animation pipeline is substantive work.
- Roster/stage report `464180b0` (parent `6c895d43`) received: nine operators,
  seven harnesses and 57 valid FPS loadouts. Fighting scope is nine characters,
  with new authored fighting stats rather than 63 separate harness fighters.
  Parent independently viewed Basalt/Canopy/Blood Gulch/Crown images. Basalt,
  Canopy and Crown are initial stage-framing targets; Parallax requires the final
  art dependency. The distant Blood Gulch phase-1 view is insufficient to prioritize
  it over those targets. All fighting-stage compositions need fresh native review.
- Parent fetched the Quaternius Universal Animation Library 2 and KayKit Character
  Animations primary pages: both advertise CC0. KayKit provides free FBX/glTF;
  its editable Blender sources are a paid tier. Quaternius's advertised complete
  library and source tier must not be confused with its free downloadable subset.
  Inspect the actual downloaded free inventory before promising specific clips.
- CMU's primary FAQ could not be fetched by the parent. Its reported permission
  text remains secondary-source evidence; it is not the selected acquisition path.
- Implementation correction to animation research proposal: Blender edit bones
  must have nonzero length. Add meaningful rest bones/attachments as required;
  do not implement the report's proposed zero-length filler bones. Humanoid
  profile mapping should use the supported required/optional bone set rather
  than inventing degenerate bones solely to populate every profile entry.
- Base animation reuse accelerates locomotion and reactions; unique per-operator
  combat poses, trajectories, timing and throw choreography still require actual
  authoring and native side-on review. Merely having hundreds of named clips is
  not evidence of distinct motion quality.

## Existing work and resource ownership

The finishing work remains active under `port/finish/WORKSTREAM.md`. Gravemill
revision 3 now owns the exclusive Blender/Godot/import/render/encode slot after
Helix's explicit release. Fighting implementation remains source/code-only;
actual Blender and native production require serialized explicit grants.

Helix revision-2 art passed parent architectural review and is merged at `c8432fcb`.
The fighting presentation agent was assigned its lightwell/specimen composition as
a fourth stage target using the actual final GLB. This promotes its eligibility
for stage authoring, not native fighting-stage acceptance. Its side-on framing,
fighter visibility and stage budget still require verification.

Keep frozen source and derivative identities intact. New fighting authority must
be isolated with explicit provenance rather than silently changing existing FPS
rules. Existing operator assets/maps, releases, screenshots and failed attempts
are preserved. All-operator gameplay, unique motion and effects require actual
native evidence before the new mode is considered complete or advertised.
