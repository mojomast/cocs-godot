# Fighting mode — animation, rig and asset research

- **Branch:** `fighting/research-animation-20261002`
- **Worktree:** `/home/mojo/.tmp-on-disk/cocs-fighting-research-animation-20261002`
- **Date:** 2026-10-02
- **Author:** DeepSeek V4.1 Flash (animation research subagent)
- **Scope:** research only. No engine code, no Godot project changes, no Blender execution, no asset imports, no downloads.
- **Heavy slot:** the repo's exclusive Blender/native "heavy slot" is held by **Helix** (Conservatory map revision 2) per `port/finish/WORKSTREAM.md`. This memo deliberately performs **no** Blender or engine work so it does not contend for that slot.
- **Sibling lanes (not duplicated here):** `fighting/research-roster-20261002` (roster/archetype audit) and `fighting/research-engine-20261002` (mode/netcode/authority). This memo owns the *animation/rig/asset* layer and only references the other two where an interface is required.

Convention used throughout: **[checked]** = directly observed in this repository or a primary source fetched on 2026-10-02; **[proposed]** = design recommendation, not yet implemented or verified.

---

## 1. Executive summary

The nine existing operators are **stylized rigid mechanical bodies driven by a procedural pose solver**, not skinned characters with authored animation. The shipped Godot assets (`godot/source_operators/generated/*.glb`) contain **zero skins and zero animations**; every mesh is a rigid child of one articulation node. The "reference clips" that exist in the repo are **sampled single poses and a 90-step fixture sequence**, not playable clips. Any fighting mode therefore cannot "reuse the existing animations" — it must first build an animation rig and a clip pipeline.

**Recommended single production pipeline [proposed]:**

1. Derive a deformation **Armature** from the existing articulation hierarchy and bind every existing batch **rigidly (weight 1.0 to its current owner bone)**. The silhouette, materials and rigid mechanical read are preserved exactly; only the transport changes from `Node3D` transforms to a `Skeleton3D` + skin.
2. Make the armature conform to Godot's **`SkeletonProfileHumanoid`** so a CC0 humanoid motion base can be **retargeted**, then re-authored per operator.
3. Author **per-operator clips in Blender 4.5** as **NLA-stashed actions**, exported with glTF **Animation Mode = Actions**, naming each track per animation. This yields one `.glb` per operator with a full clip library and per-clip names.
4. Ship a **data sidecar per operator** (frame windows, hit/cancel/foot-plant/throw-contact events, root-travel metadata). Combat **authority stays in the fixed-tick simulation**; `AnimationTree` is presentation only and a hit landing is never decided by the mixer or by a call-method track.
5. Motion base from **CC0 libraries** (Quaternius *Universal Animation Library* 1 & 2; KayKit Character Animations). **Mixamo is usable in a game but its raw files may not be redistributed**, so Mixamo is prototyping/reference only and must never be committed. CMU mocap is redistributable and may supplement the base after retarget and cleanup.
6. VFX/effects are **silhouette- and event-driven**, deduplicated, reduced-motion aware and bounded by the existing particle budget tiers. Palette is secondary, never the primary identity.
7. Uniqueness is authored, not parameterised: each operator gets genuinely distinct **timing, pose arcs and silhouette** per move, not one clip recoloured or speed-scaled.

**Scale, stated honestly:** a minimum per-operator fighting inventory is roughly **38 clips** (locomotion, guard, normals, air, reactions, knockdown/getup, 3 specials + 1 super, throw pair). Nine operators is therefore **on the order of 340 clips plus shared paired timelines**. Section 8 defines the minimum; Section 9 defines what makes each operator unique; Section 10 defines what "accepted" means.

---

## 2. Existing operator pipeline audit **[checked]**

### 2.1 Source construction

The operators are built procedurally in the source web game:

- `game/operator-anatomy.mjs` authors per-operator chest/limb cross-sections, plate outlines and proportions (`OPERATOR_ANATOMY`, nine entries).
- `game/view.mjs` `robotModel()` builds the actual hierarchy; `refineOperatorCharacter()` refines it.
- `game/character-anim.mjs` solves poses; it is deliberately Three.js-free and unit-testable.
- There is **no per-operator Blender source**: the only `.blend` files in the repo are environment/landmark/robot/structure art under `tools/godot-campaign/**/blend/`. Operators are never authored in Blender — they are generated in JS and exported.

### 2.2 Articulation

`tools/godot-operators/export.mjs` reads `model.userData.joints` and keeps these named nodes plus intermediate pivots:

```
root > hips > torso > chest > head
                      ├─ armUpperL > forearmL > handL > gripL
                      ├─ armUpperR > forearmR > handR > gripR
                      ├─ gunAnchor > weapon > Muzzle
                      └─ backpack
hips > legUpperL > legLowerL > footL
hips > legUpperR > legLowerR > footR
```

`rigPivot0`–`rigPivot7` are unnamed intermediate rotation pivots between a parent and a named joint (shoulder→upper arm, elbow→forearm, hip→upper leg, knee→lower leg). Anchor contract exported per operator: `FeetOrigin`, `Helmet` (=`head`), `GunMount` (=`gunAnchor`), `GripLeft` (=`gripL`), `GripRight` (=`gripR`), `Muzzle` (`weapon` child at `[0, 0.01, -0.85]`).

### 2.3 Procedural pose solver

`game/character-anim.mjs` `characterPose(state)` returns joint Euler triples from a bounded state dictionary (`phase`, `speedNorm`, `grounded`, `crouch`, `ads`, `strafe`, `forward`, `focusYaw`, `focusPitch`, `hit`, `accel`, `lateral`, `land`, `landRoll`, `slide`, `reload`, `secondary`). Key mechanics:

- stride **phase is accumulated** from a speed-dependent stride frequency (`advancePhase`), not wall time;
- **contact-gait IK** solves a planted ankle from measured limb lengths (0.34/0.35 m) when `contactGait` is on (opt-in);
- a bounded **secondary channel** (`SECONDARY_BOUNDS`: head/chest yaw-pitch-roll, flex, fin, crest, pack) carries presentation spring lag;
- `deathLimbPose()` is a separate deterministic corpse solver;
- a physics **ragdoll adapter** (`applyRagdoll`) blends particle orientation back onto joints.

### 2.4 Godot port

- `godot/source_operators/character_rig.gd` (188 lines) ports the solver as **rigid `Node3D` joints**: `configure(nodes)`, `reset()`, `update(state)`, `solve(inputs)`, `apply_pose()`, plus death/ragdoll entry points. Joint channels and damping match the source.
- `godot/source_operators/operator_visual.gd` (323 lines) is the drop-in host: identity/team application, LOD selection, death playback, world-weapon attachment.
- `godot/source_operators/locomotion.gd` adds a distance-driven gait, a critically damped landing spring, a **hip/knee/ankle chain rotated into the travel plane** (side and backward steps) and chest counter-rotation.
- `godot/source_operators/hand_grips.gd` and `motion_math.gd`/`ground_contact.gd`/`surface_detail.gd`/`armor_detail.gd` complete the presentation layer.
- No `AnimationPlayer`, `AnimationTree`, `AnimationMixer`, `Skeleton3D`, `BoneMap` or `root_motion` usage exists anywhere in `godot/` (grep over `*.gd`/`*.tscn` returned only unrelated "retarget" matches in audio/director code). **The port is entirely procedural.**

### 2.5 Export and shipped assets **[checked]**

`tools/godot-operators/export.mjs` clones the source hierarchy, bakes each visible mesh into its nearest rigid owner, groups by owner/material/LOD mask, and writes one `.glb` per operator via Three.js `GLTFExporter.parseAsync(scene, {binary:true, onlyVisible:true})` — **no `animations` argument**. It also writes `manifest.json` (SHA-256 per file) and `catalog.gd`.

Direct inspection of the shipped GLBs (JSON chunk parsed in this worktree):

| Operator | bytes | nodes | meshes | skins | animations |
|---|---:|---:|---:|---:|---:|
| chatgpt | 1,458,548 | 145 | 111 | 0 | 0 |
| claude | 1,326,796 | 151 | 117 | 0 | 0 |
| deepseek | 1,415,016 | 150 | 116 | 0 | 0 |
| gemini | 1,366,660 | 144 | 110 | 0 | 0 |
| grok | 1,387,524 | 144 | 110 | 0 | 0 |
| kimi | 1,418,796 | 145 | 111 | 0 | 0 |
| meta | 1,495,524 | 151 | 117 | 0 | 0 |
| mistral | 1,321,560 | 143 | 109 | 0 | 0 |
| qwen | 1,416,516 | 147 | 113 | 0 | 0 |

Generator: `THREE.GLTFExporter r185`; `extensionsUsed: ["KHR_materials_unlit"]`; total 12,606,940 bytes across nine files. All nine are rigid hierarchies of `Mesh` children under joint nodes (verified by walking the node tree; e.g. `claude` has `LOD*_Batch*` meshes under `head`, `handL`, `forearmL`, `legUpper*`, etc.).

### 2.6 "Reference clips": sampled, not played **[checked — important]**

The export fixture `godot/tests/source_operators/source_transforms.json` contains:

- `states`: `idle, walk, run, crouch, aim, crouch_aim, reload, hit, airborne, slide, secondary, reduced` — each is a **single sampled pose snapshot** (positions/quaternions/world matrices) produced by calling `characterPose(state)` **once**;
- `sequence`: a 90-step `updateSequence`, but snapshots are written only every 15 steps (`index%15===14`) purely as a numeric fixture;
- `death`: one sampled corpse pose;
- `geometrySamples`: per-batch triangle samples for import validation.

**There is no authored clip that is actually played back or sampled across a timeline and shipped for playback.** The only thing that "plays back" at runtime is the procedural solver recomputed each frame from live state. This is the single most important gap for a fighting mode.

### 2.7 Existing VFX / budget substrate **[checked]**

- `godot/combat_particles/manager.gd`: bounded world-space `GPUParticles3D` pool, **public events only** ("presentation never predicts explosions, damage, projectile disappearance, or gameplay collision outcomes"), event-ID dedup with a 4,096 window, quality tiers `Low 8,192 / High 32,768 / Extreme 1,000,000`, `HARD_LIMIT` 1,000,000, and explicit drop/recycle counters.
- `godot/player_fx/` (burst/impacts/mark pool/surface), `godot/weapon_effects/` (controller, trail shader, discharge/conduit/flash), `godot/blood_fx/` (settings, surface query, streak/pool/wire shapes).
- Reduced-motion handling already exists as an explicit channel (`state.reduced`) that resolves to the frozen `SECONDARY_REST` and is consumed by weather/handling/session code.
- Measured precedent: `port/native-combat-particles/RESULTS.md` (Godot 4.5.2, Compatibility, llvmpipe) — Extreme 1,000,000 slots ≈ 448 ms median at 1280×800, High 32,768 ≈ 44 ms. **Budget must be justified, not asserted.**

### 2.8 Operator anatomy to choose the solution **[checked]**

`game/operator-anatomy.mjs` (units are source metres, half-extent style; `power` is the contour power exponent):

| Operator | design | chest | limb | width | waist | depth | power | shoulder | bind height (from `native-source-operators/README.md`) |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| chatgpt | split-cage survey instrument | cage | suspension | .258 | .112 | .161 | .78 | .164 | 1.956 m |
| claude | ceramic warding chassis | shield | ceramic | .267 | .170 | .164 | .56 | .181 | 1.802 m |
| grok | asymmetric industrial outrider | offset | suspension | .232 | .088 | .157 | .62 | .153 | 2.034 m |
| meta | twin-turbine heavy chassis | twin | industrial | .278 | .190 | .168 | .48 | .183 | 1.802 m |
| gemini | bifurcated ceramic anatomy | petals | ceramic | .237 | .090 | .154 | .90 | .162 | 1.793 m |
| deepseek | pressure-vessel salvage frame | diver | industrial | .250 | .172 | .175 | .89 | .173 | 1.891 m |
| mistral | swept aerofoil interceptor | keel | swept | .253 | .082 | .150 | .68 | .163 | 1.828 m |
| kimi | orbital gimbal reactor | orbital | ceramic | .260 | .106 | .165 | 1.00 | .173 | 1.956 m |
| qwen | lamellar mechanical sentinel | lamellar | lamellar | .265 | .164 | .160 | .58 | .178 | 1.956 m |

Implications for the solution:

- The bodies are **visually asymmetric and differently proportioned** (grok offset, meta twin, gemini petals, mistral swept, kimi orbital). A single shared 1:1 armature cannot be assumed; the solution must **share the animation skeleton but allow per-operator rest proportions** (non-uniform bone scales baked per operator, or per-operator rest pose).
- The rig is **deeply rigid** (113 batches for claude). A skinning conversion must preserve rigid read; blending between independently animated rigid batches is only acceptable if the owner bones match.
- Existing **hand joints are single pivots** (`handL/R`) and grips are separate nodes (`gripL/R`). There are **no fingers, no wrist roll, no knuckles**. Fighting-specific detail (guard, grip, punch impact, streak) needs **new attachment sockets**, not new deform bones.

---

## 3. Gap analysis

| Requirement | Exists today | Gap |
|---|---|---|
| Playable clip library | none (procedural only) | build armature + clips |
| Skinning / `Skeleton3D` | none (0 skins) | rigid-skin conversion |
| Retarget to humanoid | none | `SkeletonProfileHumanoid` mapping |
| Per-operator unique moves | none | per-operator authoring |
| Frame-accurate hit windows | solver has `hit` envelope only | data sidecar + sim timeline |
| Paired throws | none | shared paired timeline + contact sockets |
| Root motion | none | explicit lock policy |
| Hand/foot/streak sockets | `handL/R`, `gripL/R`, `Muzzle` only | add sockets |
| VFX identity | shield/ring/palette only | per-operator silhouettes |
| Authority separation | solver is presentation already; particles are public-event only | keep and extend |

---

## 4. Godot 4.5 animation system research **[checked]**

Project facts: `godot/project.godot` uses `config/features = ["4.5","GL Compatibility"]`; the verified runtime is **Godot 4.5.2-stable** (`port/native-combat-particles/RESULTS.md`, `tools/godot-operators/check.py` expects `Godot_v4.5.2-stable_linux.x86_64`).

- **AnimationPlayer / AnimationTree split** — an `AnimationTree` has no animations of its own; it references an `AnimationPlayer`. Root node types: `AnimationNodeAnimation`, `AnimationNodeBlendTree`, `AnimationNodeBlendSpace1D`, `AnimationNodeBlendSpace2D`, `AnimationNodeStateMachine`. [`Using AnimationTree`, 4.5](https://docs.godotengine.org/en/4.5/tutorials/animation/animation_tree.html)
- **Blend nodes** — `Blend2`/`Blend3` with per-track **filters** for layering; `OneShot` with customizable fade in/out and filters; `TimeSeek` (seconds); `TimeScale` (negative = reverse); `Transition`; `StateMachine` with *Immediate / Sync / At End* transitions, `Xfade Time`, `Xfade Curve`, `Reset`, `Priority`, and `travel()` via `AnimationNodeStateMachinePlayback`. Same source.
- **2D blend spaces** — `BlendSpace2D` with Delaunay triangles and *Discrete* / *Carry* blend modes; `BlendSpace1D`. Same source.
- **Determinism caveat for blending** — in Godot 4, blended tracks must have a defined initial value; for `Skeleton3D` bones the initial value is **Bone Rest**, and the docs explicitly prefer a **T-pose** import so the rest sits near the midpoint of the range. This directly justifies a humanoid T-pose rest and a `RESET` pose. Same source.
- **Root motion** — choose the root bone as the *root motion track*; the visual transform is cancelled and motion is read via `AnimationTree.get_root_motion_position/rotation/scale` and the `*_accumulator` variants, then fed to `CharacterBody3D.move_and_slide()`. [`Root motion`, 4.5](https://docs.godotengine.org/en/4.5/tutorials/animation/animation_tree.html)
- **Retargeting** — `Skeleton3D` import exposes a **BoneMap** built on a **SkeletonProfile**; Godot ships **`SkeletonProfileHumanoid`**. Options include *Remove Tracks* (Except Bone Transform / Unimportant Positions / Unmapped Bones), *Bone Renamer*, and *Rest Fixer* (Apply Node Transform / Normalize Position Tracks / Overwrite Axis / Fix Silhouette). The profile's reference rules: **T-pose, facing +Z, right-handed Y-up, no node transform, +Y from parent to child joint, +X bends the joint**. `root_bone = Root`, `scale_base_bone = Hips`. [`Retargeting 3D Skeletons`](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/retargeting_3d_skeletons.html); [`SkeletonProfileHumanoid`](https://docs.godotengine.org/en/4.5/classes/class_skeletonprofilehumanoid.html)
- **Humanoid bone set** — `SkeletonProfileHumanoid` prints the hierarchy `Root > Hips > {Left/RightUpperLeg>LowerLeg>Foot>Toes, Spine>Chest>UpperChest>{Neck>Head>{Jaw,Eyes}, Left/RightShoulder>UpperArm>LowerArm>Hand>{finger chains}}}`. The class prose says "54 bones", while the `bone_size` property is `56`; the printed hierarchy and the 30 finger bones are the actionable contract. Same class source.
- **Realtime retarget module** — TokageItLab `realtime_retarget` (MIT) is a **C++ custom module requiring a custom Godot build**, and documents the exact failure mode of `Overwrite Axis` on models whose bone rest matters (fingers, robots). It is **not** usable with the stock 4.5.2 toolchain without rebuilding the engine, so it is **out of scope for the recommended pipeline** (and outside this branch's "no engine" rule). [GitHub](https://github.com/TokageItLab/realtime_retarget)

---

## 5. Blender 4.5 glTF export research **[checked]**

The repo's approved Blender is **4.5 LTS** (`/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64.tar.xz`, with SHA-256 alongside). Blender 4.5 manual, *glTF 2.0*:

- Animation mode is controlled by **Animation → Mode**:
  - **Actions (default)** — an action is exported if it is the active action or **stashed to an NLA track**; actions not associated with an object are **not** exported. The glTF animation name is the action name by default and can be overridden by **renaming the NLA track**. Renaming two tracks on different objects to the same name makes them **one** glTF animation. "Useful if you are exporting for a game engine, with an animation library of a character. **Each action must be on its own NLA track.**"
  - **Active Actions merged** — ignores NLA; one animation from active actions.
  - **NLA Tracks** — each NLA track becomes an independent glTF animation (useful for strip modifiers or multiple actions on one track).
- Blender **4.4** changed merge semantics with slotted actions: tracks are merged **by the action they use**, not by name.
- Relevant options: **Merge Animation** (by Action/slot, by NLA Track Name, or none), **Export all Armature Actions** (does not support multiple armatures), **Reset pose bones between actions**, **Reset Shape Keys between actions**, and an action-name filter.
- Only *Actions (default)* and *Active Actions merged* can handle non-sampled animation.

Source: [Blender 4.5 LTS Manual — glTF 2.0](https://docs.blender.org/manual/en/4.5/addons/import_export/scene_gltf2.html) (Animations section).

**Consequence [proposed]:** author every operator clip as a **stashed action on its own named NLA track** in one `.blend` per operator, export with **Mode = Actions, Merge = None**, `Reset pose bones between actions = on`. That produces one `.glb` per operator carrying a named animation per clip, which Godot imports into one `AnimationPlayer` with one `AnimationLibrary`.

---

## 6. Licensing matrix **[checked, fetched 2026-10-02]**

> "Free to use" is **not** the same as "redistributable". The decisive question for this repository is whether the **raw animation/rig files may be committed and shipped**, or only used to produce derived work. No file was downloaded or committed for this research.

| Source | URL | Licence / terms | Commercial game use | Redistribute raw files | Modify / retarget | Format | Rig / notes | Verdict for this repo |
|---|---|---|---|---|---|---|---|---|
| **Adobe Mixamo** | [helpx FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) (403 to fetch; community mirror: [Mixamo FAQ](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400), 2022-09-29) | Free, no royalty; Adobe retains rights | **Yes** (games, DLC, film) | **No** — "the only thing you can't do is distribute the raw character and animation files"; no asset-store/engine-redistribution packages | Retarget/derivative in a project: yes; **ML training: no** | FBX | Mixamo/Adobe rig | **Reference/prototype only. Never commit.** Terms are third-party-controlled and can change. |
| **CMU Graphics Lab Motion Capture DB** | [mocap.cs.cmu.edu/faqs.php](http://mocap.cs.cmu.edu/faqs.php) (site intermittently refuses automated fetch; licence text confirmed via [Hugging Face mirror](https://huggingface.co/datasets/gbionics/cmu-fbx) and multiple secondary citations) | "The motion capture data may be copied, modified, or redistributed without permission." | **Yes** | **Yes** (do not sell the animations themselves) | Yes | ASF/AMC (BVH/FBX conversions exist) | Skeleton-native, needs retarget + cleanup | **Allowed base/supplement**, but heavy cleanup; keep provenance. |
| **Quaternius — Universal Animation Library** | [pack page](https://quaternius.com/packs/universalanimationlibrary.html), March 2025 | **CC0 1.0** | Yes | **Yes** | Yes | FBX, GLB, (Blend in Source tier) | "universal humanoid rig", tested in Godot/Unity/Unreal, "ready for retargeting"; locomotion 8-way, jog, sprint, push, crawl, swim, sit, deaths, **combat and gun** | **Primary base library.** |
| **Quaternius — Universal Animation Library 2** | [pack page](https://quaternius.com/packs/universalanimationlibrary2.html), January 2026 | **CC0 1.0** | Yes | **Yes** | Yes | FBX, GLB, (Blend in Source tier) | 130+ animations, 3- and 4-hit combos **split into separate hits with recoveries**, parkour, zombie locomotion | **Primary base library (combat combos).** |
| **KayKit — Character Animations** (Kay Lousberg) | [itch page](https://kaylousberg.itch.io/kaykit-character-animations), updated 2025-12-10 | **CC0 1.0** | Yes | **Yes** (CC0); page *requests* not reselling unmodified copies | Yes | FBX, GLTF; `.blend` in paid Source tier | 161 humanoid animations: general (hit/death/spawn/interact), movement, **melee combat (1H/2H/unarmed/dual/blocking)**, ranged, simulation | **Strong secondary base**; note "no generative AI was used" tag. |
| **Kenney** | [support FAQ](https://kenney.nl/support) | **CC0** | Yes | **Yes** | Yes | many | Mostly props/UI/2D; limited humanoid fight motion | **Props/VFX only**, not fight motion. |
| **Motifect Combat Motion Pack** | [itch page](https://motifect.itch.io/motifect-combat-motion-pack) | "Free for personal and commercial use"; **AI-assisted** disclosure | Yes | Not explicitly stated; assume project-use only | Yes | FBX + BVH | 40 clips: punches, kicks, blocks, dodges, combos, **hit reactions, knockdowns** | **Optional**, flagged AI-generated; verify provenance policy before adopting. |
| **Godot Engine** | [godotengine.org](https://godotengine.org/) | MIT | Yes | Yes | Yes | — | Runtime | Already the project engine. |
| **TokageItLab `realtime_retarget`** | [GitHub](https://github.com/TokageItLab/realtime_retarget) | MIT | Yes | Yes | Yes | C++ module | **Requires a custom engine build** | Out of scope (no engine work; not stock 4.5.2). |
| **Pyxus `fray`** (combat framework) | [GitHub](https://github.com/Pyxus/fray) | **MIT** | Yes | Yes | Yes | GDScript addon | Hierarchical state machine, **composite/motion/charge/sequence inputs**, hitbox management keyed from an AnimationPlayer property; **alpha**, Godot 4.2+ | Optional reference; do not let an alpha addon own authority. |
| **Charles Partous `GoHitHurt`** | [Godot Asset Store](https://store.godotengine.org/asset/charles-partous/gohithurt/) | **MIT** | Yes | Yes | Yes | GDScript addon | Hitbox/hurtbox nodes, per-frame enable/disable, `hit_data`; store lists min Godot **4.7** for the current version | Optional reference only; version target is ahead of 4.5. |

**Hard rule adopted [proposed]:** anything whose terms forbid shipping raw files (Mixamo) must never enter `godot/`, `tools/` or git history as an asset. Committed motion must be **CC0 or explicitly redistributable** (Quaternius, KayKit, CMU), with licence and provenance recorded next to the asset.

---

## 7. Recommended production pipeline **[proposed]**

### 7.1 Rig conversion — rigid-skin the existing batches

1. In Blender, reconstruct the operator's existing hierarchy as an **Edit-Bone armature** using the source joint rest transforms (already machine-readable in `manifest.json` `joints` + the GLB node transforms). Collapse intermediate `rigPivotN` into bone rest orientation (which is what the pivot encodes).
2. **Do not re-topologise.** Parent each existing LOD batch to its current owner bone with weight **1.0** (rigid skin). Visible result is identical to the rigid `Node3D` hierarchy; only the transport is now `Skeleton3D` + `Skin`.
3. Keep the **rigid batch naming and LOD masks** so the existing LOD policy (`2/10/50 m`, `sourceLodMask`) still selects geometry; the skin is one armature, the batches stay the same.
4. Preserve **original materials, vertex colours and `KHR_materials_unlit`**; the export pipeline already forbids acquired textures, so no material work is added.
5. Humanoid rest: author the armature to satisfy `SkeletonProfileHumanoid` reference rules (T-pose, +Z facing, +Y parent→child, +X bend) so retargeting and blend determinism work.

### 7.2 Proposed bone mapping **[proposed]**

| Existing joint | Proposed `SkeletonProfileHumanoid` bone | Notes |
|---|---|---|
| `root` | `Root` | root-motion / actor origin, locked (7.7) |
| `hips` | `Hips` | `scale_base_bone`; per-operator height normalisation |
| `torso` | `Spine` | |
| `chest` | `Chest` | |
| — (new) | `UpperChest` | add for shoulder/chest twist separation |
| — (new) | `Neck` | needed for head/guard readability |
| `head` | `Head` | carries `Helmet` anchor |
| `armUpperL/R` | `LeftUpperArm` / `RightUpperArm` | |
| `forearmL/R` | `LeftLowerArm` / `RightLowerArm` | |
| `handL/R` | `LeftHand` / `RightHand` | |
| `legUpperL/R` | `LeftUpperLeg` / `RightUpperLeg` | |
| `legLowerL/R` | `LeftLowerLeg` / `RightLowerLeg` | |
| `footL/R` | `LeftFoot` / `RightFoot` | |
| — (new) | `LeftToes` / `RightToes` | toe-off / plant |
| — (new, optional) | fingers | a **minimal 1–2 joint per finger** set is enough for guard/grip; full 30-bone hand only if finger VFX require it |
| `rigPivot0..7` | *(merged into parent bone rest)* | pivots are axis decomposition, not anatomy |

Profile bones with **no existing joint** (`UpperChest`, `Neck`, `Shoulders`, `Toes`, fingers) are added as zero-length/child bones so the operator still satisfies the humanoid map. The **map is per-operator identical**; only rest proportions differ (aligns with §2.8).

### 7.3 Attachment sockets **[proposed]**

Added as non-deform bones / `BoneAttachment3D`, one set per operator, all with source-authored coordinates:

| Socket | Parent | Purpose |
|---|---|---|
| `Socket_Weapon` | `gunAnchor` | held weapon |
| `Socket_Muzzle` | `weapon` | muzzle flash/projectile origin (existing `Muzzle`) |
| `Socket_GripL/R` | `handL/R` | existing `gripL/R` |
| `Socket_HandL/R` | `handL/R` | hand trail / hit spark |
| `Socket_KnuckleL/R` | `handL/R` + offset | impact contact point, streak origin |
| `Socket_StreakL/R` | `forearmL/R` | weapon/limb streak trail |
| `Socket_ElbowL/R`, `Socket_KneeL/R` | limb bones | contact/impact fallback |
| `Socket_FootL/R` | `footL/R` | foot-plant validation, dust, stomp |
| `Socket_GuardL/R` | `forearmL/R` | guard spark / block VFX |
| `Socket_Chest`, `Socket_Hips` | `chest`/`hips` | centre-body VFX, throw grab target |

`Socket_FootL/R` and `Socket_HandL/R` are also the measurement anchors for acceptance (§10).

### 7.4 Authoring and NLA **[proposed]**

- One `.blend` per operator: `tools/godot-fighting/operators/op_<id>.blend` (source of truth, committed). *(Directory does not exist yet; this is a proposal, no file was created.)*
- Reuse the **CC0 base library** by retargeting each source clip onto the humanoid rest, then **re-author timing/pose arcs** per operator (see §9). Never ship a retargeted base clip unchanged as an operator identity move.
- Every clip is its **own stashed action on its own NLA track**, track named exactly the clip name. Export **Mode = Actions**, **Merge = None**, **Reset pose bones between actions = on**.
- Frame rate: author at **30 fps** (matches the base libraries) and let Godot resample; recorded acceptance samples at 60 Hz.

### 7.5 glTF interface contract **[proposed]**

One `.glb` per operator plus one JSON sidecar:

```
godot/fighting/operators/op_<id>/op_<id>.glb        # Skeleton3D + skin + named animations
godot/fighting/operators/op_<id>/op_<id>.json       # frame data, sockets, provenance/licence
godot/fighting/operators/op_<id>/LICENSE
```

GLB requirements:

- exactly **one skin** whose joints are the mapped humanoid bones plus sockets;
- one `AnimationPlayer` animation per clip on import, named `<state>` (e.g. `light_1`, `special_2`, `throw_execute`);
- node names exactly the socket/bone names above (so `BoneAttachment3D` and tests can find them);
- no gameplay call-method tracks: cosmetic events only, and only if the sidecar cannot express them.

Sidecar requirements (per clip): `name`, `fps`, `frames`, `loop`, `startup`, `active`, `recovery`, `cancel_into[]`, `invuln[]`, `foot_plant_l/r[]`, `contact[]`, `vfx_events[]` (name + frame + socket + budget class), `root_travel` (locked metres), `reduced_motion` substitute. **This file, not the animation graph, is the authority input.**

### 7.6 Godot runtime interface **[proposed]**

- Load `op_<id>.glb` into an `AnimationPlayer` + `AnimationTree`. Locomotion = `AnimationNodeBlendSpace2D` (or 1D) driven by sim velocity; states = `AnimationNodeStateMachine`; reactions/specials = `AnimationNodeOneShot`; guard/hit-layers = filtered `Blend2`/`Blend3`.
- **Authority boundary:** the fixed-tick simulation owns hit detection, damage, knockback, hitstop, cancels and win state. `AnimationTree` is fed state and reports triggers; it **never** decides whether a strike connects. A discrete hit is a **sim event**; presentation subscribes to the deduplicated public event stream exactly as `combat_particles/manager.gd` already does ("presentation never predicts").
- `AnimationMixer` time may drive *cosmetic* hitstop (freeze/slow the mixer + camera), but sim time and frames continue deterministically for rollback/replay.
- Reduced motion: when `reduced` is set, swap to the sidecar's reduced substitute and drop camera-shake/streak classes (§7.9).

### 7.7 Root motion policy **[proposed]**

Fixed simulation is authoritative, so:

- **Default: locked root.** Clips are authored **in place**; horizontal travel is stored in the sidecar (`root_travel`) and applied by the sim. The rig `Root` stays at the actor origin. This is the safest for determinism and rollback.
- **Optional: consumed root motion.** If an authored step must drive weight shift, expose `AnimationTree.get_root_motion_position_accumulator()` as a *request* the sim may clamp or reject. Never call `move_and_slide()` directly from the animation.
- `Root` position tracks are the **only** position tracks allowed to move; all other bones are rotation-only, and importer settings should remove unimportant position tracks (the retargeting docs' *Unimportant Positions*), matching the Godot 4 concern that absolute bone poses distort different body shapes.

### 7.8 Throws and paired alignment **[proposed]**

- A throw is one **shared paired timeline** referenced by both actors (attacker clip + victim clip), with a single authoritative `contact` frame and a `hold` window.
- Align by socket, not by eye: at `contact`, attacker `Socket_KnuckleL/R` (or `Socket_GripL/R`) and victim `Socket_Chest`/`Socket_Hand*` must be within tolerance, and **both actors must report the same contact frame index**.
- The sim pins both actors' relative yaw/position for the hold window and any divergence beyond tolerance is a data bug, not a gameplay outcome. Throw escape/tech splits at a declared frame; the victim's `throw_victim` clip must support both outcomes from that frame.

### 7.9 VFX, readability, budget and reduced motion **[proposed, built on checked substrate]**

- **Source-event dedup:** effects subscribe to the same deduped public-event stream as `combat_particles` (event IDs, 4,096 window). One strike = one impact event = at most one burst + one streak + one audio cue.
- **Silhouette first:** each move reads as a distinct shape at 3–10 m before palette. Palette (existing `TEAM_PALETTE` and per-operator materials) is **secondary**.
- **Palette-neutral stages:** because team colour already differentiates sides, operator identity must survive on a colour-blind/desaturated stage: use motion arcs, pose asymmetry and VFX *shape* (ring/arc/lance/cage/lamella) rather than hue.
- **Budget:** inherit `Low 8192 / High 32768 / Extreme 1000000`. Assign each `vfx_event` a class; the fighting mode's default should be **High** unless a measured case justifies more (per the measured precedent, Extreme is ~448 ms on the software renderer and is *explicit selection only*).
- **Reduced motion:** reuse `state.reduced`; substitute a shorter/closed-pose clip, suppress camera shake, screen streaks and rapid flashes; keep hit framing readable.
- **Floor/camera:** side-on fixed camera; every clip must keep the declared `Socket_Foot*` on the floor plane (no float/penetration) and keep the character inside the stage's camera-silhouette band.

---

## 8. Minimum move animation inventory **[proposed]**

Assumes a 2D-plane side-on fighter with one horizontal lane. `L/M/H` = light/medium/heavy. "Unique" = authored timing + pose arcs per operator (§9); paired clips are shared timelines instantiated per throw.

| # | Category | Clips | Per operator | Notes |
|---|---|---|---:|---:|
| 1 | Locomotion | `idle`, `walk_f`, `walk_b`, `dash_f`, `dash_b`, `backdash` | 6 | contact-gait foot plant required |
| 2 | Air | `jump_start`, `jump_air`, `jump_land` | 3 | landing compression already modelled procedurally |
| 3 | Stance | `crouch_idle`, `crouch_walk`, `guard_idle`, `guard_walk` | 4 | guarded stances; see lane note below |
| 4 | Guard reactions | `guard_block`, `guard_hit`, `guard_break` | 3 | |
| 5 | Ground normals | `light_1`, `light_2`, `medium`, `heavy` | 4 | standing, chainable |
| 6 | Crouch normals | `crouch_light`, `crouch_medium`, `crouch_heavy` | 3 | |
| 7 | Air normals | `air_light`, `air_medium`, `air_heavy` | 3 | |
| 8 | Specials | `special_1`, `special_2`, `special_3` | 3 | **unique per operator** |
| 9 | Super | `super` | 1 | **unique per operator**, cinematic |
| 10 | Throws | `throw_start`, `throw_execute` (attacker), `throw_victim` (victim), `throw_tech` (victim) | 2 owned + shared | paired timeline |
| 11 | Hit reactions | `hit_light`, `hit_medium`, `hit_heavy`, `hit_air`, `launch` | 5 | |
| 12 | Down/getup | `knockdown`, `getup`, `getup_attack` | 3 | |
| 13 | Match framing | `intro`, `victory`, `defeat` | 3 | |
| | **Total per operator** | | **~43** | |

Practical reading: **~38–43 clips per operator**, three of which (specials + super) are fully bespoke and several of which are per-operator re-authored variants of a shared base. Nine operators is **~340–390 clips**, not counting paired throw timelines. A **vertical slice** of one operator (categories 1–7 + one special + throw + reactions ≈ **26 clips**) should be completed and accepted before committing to all nine — see §10.

**Guarded stance lanes [proposed]:** during guard and crouch, the thighs, shins and forearms must each stay in declared "lanes" (angular corridors) so arms never intersect the torso and legs never cross; validate as constraint checks in the acceptance pass, not by eye.

**Inertia and foot plant [proposed]:** keep the existing critically damped `landing`/`lean`/`secondary` channels for inertia; feed the new clips a blend of clip pose and procedural secondary so stops and turns read as weight, while the **planted foot's `Socket_Foot*` world position** is the hard contact truth.

**Wrist/knuckle/streak [proposed]:** wrist orientation is owned per clip (not by the grip pass); knuckle sockets are the impact point; streak sockets drive trails whose length is a budgeted VFX class, never a gameplay reach.

---

## 9. Per-operator uniqueness **[proposed]**

Uniqueness must be authored, not parameterised (no "same clip, different colour/speed"). The roster lane (`fighting/research-roster-20261002`) owns the archetype audit; this section only states the **animation identity contract** each operator must satisfy. Derived from §2.8's anatomy and `operator-anatomy.mjs` design strings:

| Operator | Archetype signal (from design/anatomy) | Required unique motion traits | Signature silhouette shape | Signature VFX shape |
|---|---|---|---|---|
| chatgpt | split-cage survey instrument | balanced, caged limbs, symmetrical arcs | open cage / frame | containment ring/segment |
| claude | ceramic warding chassis | deliberate guards, broad shoulders, shield-like forearms | warding shield | ceramic shard fan |
| grok | asymmetric industrial outrider | uneven timing, one-sided offsets, limping feints | offset diagonal | asymmetric chevron |
| meta | twin-turbine heavy chassis | heavy, slow startup, high inertia, ground-shaking | twin turbine | twin contrail |
| gemini | bifurcated ceramic anatomy | split/petal strikes, mirrored pair timing | petal/bifurcation | bifurcating lance |
| deepseek | pressure-vessel salvage frame | compact power, diver-like tucks, pressure release | vessel/diver | vented pressure cone |
| mistral | swept aerofoil interceptor | fast, sweeping, low-profile dashes | swept wing | aerofoil streak |
| kimi | orbital gimbal reactor (power 1.0) | orbiting arcs, gimbal rotations, full-body spins | orbital ring | gimbal orbit |
| qwen | lamellar mechanical sentinel | layered/sequential plates, measured, tactical | lamellar stack | layered wall/relay |

The **special + super** set is where identity is concentrated: three specials and one super per operator, each with a distinct startup/active/recovery rhythm, distinct hand trajectory and distinct VFX shape. Normals can share a base library, but the per-operator pass must change **timing, pose arcs and follow-through**, not just scale.

---

## 10. Production acceptance **[proposed]**

Adapted from the repo's existing operator proof (`tools/godot-operators/check.py`, `contact_sheets.py`, `port/native-source-operators/README.md`), which already compares source vs native at 1280×800 and 1920×1080, front/side/back, 3/10/25 m, and a 12-phase walk GIF.

**Joint anatomy**
- All mapped humanoid bones exist, in the correct parent chain, with a T-pose rest satisfying the profile rules (T-pose, +Z facing, +Y parent→child, +X bend).
- No `rigPivot` bones remain as deforming nodes; sockets present and parented as specified.
- Per-operator rest proportions match the source GLB joints within a stated tolerance.

**Hand trajectory**
- For every strike, `Socket_KnuckleL/R` (or declared contact socket) reaches the sidecar's declared contact position within tolerance at the contact frame, sampled at 60 Hz.
- Trajectory arc is monotonic through startup→active (no foot-gun reversal) unless the move is intentionally a feint.

**Foot plant**
- During declared `foot_plant` windows, planted `Socket_Foot*` world position drift ≤ stated tolerance per frame and no floor penetration/float beyond tolerance.
- No clip moves the character in a way the locked root cannot explain.

**Paired throws**
- At the shared `contact` frame, attacker contact socket to victim grab socket distance ≤ tolerance; both actors report the **same frame index**.
- Hold-window alignment holds; `throw_tech` leaves the shared timeline at the declared frame on both actors.
- Contact sheets render both actors together.

**Native side-on render / source frame correlation**
- Side-on deterministic capture at 1280×800 and 1920×1080, pose-by-pose contact sheets (startup/active/recovery), exactly like the existing operator comparison sheets.
- Where a source reference clip exists (CC0 base before re-authoring), sample the same frame indices and assert joint-angle correlation above a stated threshold; record the reference SHA-256.

**Readability / stage**
- Silhouette distinguishable at 3 m, 10 m and the camera's far band; stage contrast floor met in greyscale.
- Palette is not required to identify the operator.

**Budget / reduced motion**
- Each VFX class maps to a particle budget tier; default High. Reduced-motion run substitutes clips and suppresses shake/streak classes.
- No VFX is emitted twice for one deduped event.

Every acceptance item must report a **measured value and a named tolerance**, not "looks correct".

---

## 11. Risks and open questions

- **Skating risk:** rigid-skin conversion changes transport but not proportions; different operator heights mean a shared clip can skate unless `Hips` `motion_scale` / per-operator position normalisation is handled.
- **Retarget cleanliness:** the existing rig is mechanical and asymmetric; `Overwrite Axis` can corrupt source bone rest (documented by the realtime-retarget module). Prefer a humanoid rest authored at conversion, and avoid `Overwrite Axis` on fingers/sockets.
- **Blender 4.4+ slotted actions** changed NLA merge semantics; the export recipe must be pinned to 4.5 LTS and validated once.
- **Scale/cost:** ~340–390 clips is a multi-lane effort. The vertical slice must be accepted first.
- **Authority drift:** the temptation to let `AnimationTree` signals gate hitboxes would break the repo's fixed-sim/replay model; this must be enforced by contract, not convention.
- **Licence drift:** Mixamo terms are third-party and can change; keeping any Mixamo-derived raw file in history is a legal risk.
- **Not verified here:** GoHitHurt/Fray behaviour in this repo; actual retarget quality; actual Blender export output; actual particle cost of proposed fighting VFX on hardware (only the existing software-renderer measurements exist).

---

## 12. Sibling interfaces **[proposed]**

- **Roster lane** (`fighting/research-roster-20261002`): provides archetypes, movelists, damage/knockback numbers and which operators share a base. This memo consumes that as identity inputs (§9) and does **not** re-derive movelists.
- **Engine lane** (`fighting/research-engine-20261002`): owns mode rules, fixed-tick schedule, netcode/rollback and the `contact` frame definition. This memo's sidecar/frame-window schema and root-motion lock (§7.5–7.7) are the interface it must accept.
- **Integration:** the vertical-slice acceptance artifacts (§10) should reuse `tools/godot-operators/contact_sheets.py` conventions and the `port/native-source-operators/evidence/` layout.

---

## 13. Sources

Fetched 2026-10-02 unless noted.

**Godot 4.5**
- https://docs.godotengine.org/en/4.5/tutorials/animation/animation_tree.html
- https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- https://docs.godotengine.org/en/4.5/classes/class_skeletonprofilehumanoid.html
- https://docs.godotengine.org/en/4.5/classes/class_skeletonprofile.html
- https://docs.godotengine.org/en/4.5/classes/class_bonemap.html
- https://docs.godotengine.org/en/4.5/classes/class_animationtree.html

**Blender 4.5 LTS**
- https://docs.blender.org/manual/en/4.5/addons/import_export/scene_gltf2.html

**Licences / assets**
- Adobe Mixamo FAQ (primary, automated fetch 403): https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- Mixamo licensing/ownership FAQ (visible community mirror, 2022-09-29): https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400
- CMU MoCap FAQ (licence text confirmed via mirrors): http://mocap.cs.cmu.edu/faqs.php · https://huggingface.co/datasets/gbionics/cmu-fbx
- Quaternius Universal Animation Library: https://quaternius.com/packs/universalanimationlibrary.html
- Quaternius Universal Animation Library 2: https://quaternius.com/packs/universalanimationlibrary2.html
- Kenney support (CC0): https://kenney.nl/support
- KayKit Character Animations: https://kaylousberg.itch.io/kaykit-character-animations
- Motifect Combat Motion Pack: https://motifect.itch.io/motifect-combat-motion-pack

**Tools / addons**
- TokageItLab realtime_retarget (MIT, custom module): https://github.com/TokageItLab/realtime_retarget
- Pyxus fray (MIT, alpha): https://github.com/Pyxus/fray
- GoHitHurt (MIT, Asset Store, min 4.7 listing): https://store.godotengine.org/asset/charles-partous/gohithurt/

**Repository evidence (this worktree)**
- `game/character-anim.mjs`, `game/operator-anatomy.mjs`, `game/operator-profiles.mjs`
- `tools/godot-operators/export.mjs`, `check.py`, `contact_sheets.py`, `reference.mjs`
- `godot/source_operators/character_rig.gd`, `operator_visual.gd`, `locomotion.gd`, `hand_grips.gd`
- `godot/source_operators/generated/catalog.gd`, `manifest.json`, `*.glb` (parsed here)
- `godot/tests/source_operators/source_transforms.json`
- `godot/combat_particles/manager.gd`, `godot/player_fx/`, `godot/weapon_effects/`, `godot/blood_fx/`
- `port/native-combat-particles/RESULTS.md`, `port/native-source-operators/README.md`
- `port/finish/WORKSTREAM.md`, `port/new-maps/WORKSTREAM.md` (Helix heavy-slot ownership)
