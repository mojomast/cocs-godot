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

Implementation models resolved from the model catalog:
`openai/gpt-6.1-sol` and `openai/gpt-6-astra`. Roles will follow the finalized
interfaces: Sol for bounded implementation/content work, Astra for combat/animation
architecture, integration and complex correctness. Implementation has not launched.

## Received research and parent review

- Engine report `87b7fc4f` (parent `98064fb4`) received. Parent independently
  verified Castagne's v0.58 Godot-3 release and Sakuga's Godot-4.7/.NET README.
  An isolated local fixed-tick Godot fighter is the leading recommendation;
  architecture is finalized after the roster/stage research also arrives.
- Animation report `512e7716` (parent `afa1c714`) received. Existing nine
  operator GLBs have zero skins and zero animation clips; current motion is
  runtime procedural. A new authored animation pipeline is substantive work.
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

The finishing agents remain active under `port/finish/WORKSTREAM.md`. Helix
revision 2 owns the exclusive Blender/Godot/import/render/encode slot. Fighting
research has no heavy grant. Future code authoring may proceed independently once
planned; actual Blender and native production require serialized explicit grants.

Keep frozen source and derivative identities intact. New fighting authority must
be isolated with explicit provenance rather than silently changing existing FPS
rules. Existing operator assets/maps, releases, screenshots and failed attempts
are preserved. All-operator gameplay, unique motion and effects require actual
native evidence before the new mode is considered complete or advertised.
