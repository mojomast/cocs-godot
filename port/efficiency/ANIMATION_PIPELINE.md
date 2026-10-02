# Fighting animation & asset efficiency audit — shared-skeleton pipeline

- **Branch:** `efficiency/animation-20261002`
- **Worktree:** `/home/mojo/.tmp-on-disk/cocs-efficiency-animation-20261002`
- **Base:** `10a90fd0` (“Integrate full fighting roster and reconcile reviewed stage-plan provenance”)
- **Date:** 2026-10-02
- **Scope:** independent efficiency audit of the *animation / rig / asset* layer for
  the nine-operator fighting mode. **Research and measurement only.**
- **Constraints honoured:** no nested agents; no Godot, Blender, ffmpeg, audio or
  capture execution; no production-file edits; the active `fighting/animation-*`
  lane is **not polled**; the exclusive Blender/Godot/import/render heavy slot is
  owned by **Gravemill Foundry revision 3** and is not requested here. Every number
  below is either parsed from committed files in this worktree or cited to a
  primary source fetched on 2026-10-02.

Convention: **[verified]** = observed in this repository or a primary source on
2026-10-02; **[proposed]** = recommendation, not implemented; **[measure]** =
metric to collect, not a claimed result. No saved-time figure is invented; only
measured values and metrics are reported.

---

## 0. Bottom line

The dominant efficiency opportunity is structural and is currently *underused*:
**all nine operator rigs already share one identical rest skeleton.** Parsing the
shipped GLBs shows the 27 rig/joint matrix nodes (basis **and** translation) are
equal across all nine operators to parsed precision; the only per-operator
difference is the rigid mesh geometry. That means:

1. Body-proportion retargeting is a **no-op** — it should be dropped from the plan.
2. One shared motion library (rotation-only tracks) drives all nine with zero
   retarget error.
3. All 225 victim-clip instances can be **25 authored timelines aliased by name**,
   not 225 stored heavy clips.
4. Per-operator uniqueness still comes from authored full-body pose arcs, per-move
   timing (already per-operator in the content manifest) and mesh silhouette/VFX —
   nothing about the owner requirement is cut to two characters or a recolour.

Three concrete savings and their owners are in §10; the full all-nine gate plan is
in §12; verified CC0 inventory vs marketing counts is in §13.

---

## 1. Verified current state

Parsed in this worktree on 2026-10-02.

### 1.1 Content manifest (`port/fighting/content/ANIMATION_COVERAGE.json`) **[verified]**

| Thing | Count | Note |
|---|---:|---|
| Operators | 9 | chatgpt, claude, grok, meta, gemini, deepseek, mistral, kimi, qwen |
| State clips / operator | 22 | `idle, walk_f, walk_b, crouch, jump_*, land, dash_*, guard_*, hit_*, block_*, knockdown, wakeup, throw_tech, win, lose` |
| Combat clips / operator | 15 | Gemini 18 (adds `palm_l/m/h`) |
| State clips total | 198 | 9 × 22 |
| Combat clips total | 138 | 8 × 15 + 18 |
| **State + combat total** | **336** | the “~37 clips each” target (Gemini 40) |
| Unique victim clip names | 25 | `victim_<attacker>_<move>` where move ∈ {`throw_f`, `throw_b`, `special3`} |
| Victim instances stored | 225 | 25 names × 9 victim GLBs |
| Paired attacker timelines | 25 | one per named victim clip |
| Combat clips with contact windows | 124 | plus 6 projectile-spawn, 11 movement, 1 counter |
| Combat clip lengths | 15–64 frames, median 38, sum 4,960 | timings already differ per operator |

### 1.2 Shipped operator assets (`godot/source_operators/generated/*.glb`) **[verified]**

Parsed GLB JSON chunk:

| Operator | bytes | nodes | meshes/batches | skins | animations | joint-like nodes | materials |
|---|---:|---:|---:|---:|---:|---:|---:|
| chatgpt | 1,458,548 | 145 | 111 | 0 | 0 | 31 | 13 |
| claude | 1,326,796 | 151 | 117 | 0 | 0 | 31 | 13 |
| grok | 1,387,524 | 144 | 110 | 0 | 0 | 31 | 13 |
| meta | 1,495,524 | 151 | 117 | 0 | 0 | 31 | 13 |
| gemini | 1,366,660 | 144 | 110 | 0 | 0 | 31 | 13 |
| deepseek | 1,415,016 | 150 | 116 | 0 | 0 | 31 | 13 |
| mistral | 1,321,560 | 143 | 109 | 0 | 0 | 31 | 13 |
| kimi | 1,418,796 | 145 | 111 | 0 | 0 | 31 | 13 |
| qwen | 1,416,516 | 147 | 113 | 0 | 0 | 31 | 13 |
| **Total** | **12,606,940** | | | **0** | **0** | | |

Facts used below: 0 skins, 0 animations, ~83–85 source draw objects and
~27,972–31,872 LOD0 triangles per operator, 13 unlit materials each, and all mesh
nodes carry **no** local transform (geometry is baked into the owner joint’s space).
Manifest `method` states “No anatomy scaling. No triangle decimation.”

---

## 2. Decisive structural finding: the rest skeleton is shared **[verified]**

`tools/godot-operators/export.mjs` writes one GLB per operator. Comparing the
**27 matrix nodes** (the named joints plus `rigPivot0..7` and the team/weapon
helpers) across all nine GLBs:

- **Rotation basis (matrix[0..11]): identical in 27/27 nodes across all nine.**
- **Translation (matrix[12..14]): spread 0.0 mm in every axis for all 27 nodes.**
- `manifest.json` per-operator `joints` agree: every joint local position and
  quaternion matches across operators (`hips` = `[0, 0.7835, 0]`, `torso` =
  `[0, 0.22, 0]`, `chest` = `[0, 0.30, 0]`, `head` = `[0, 0.28, 0]`, …).

What differs per operator is only the **rigid mesh geometry** (bounds height
1.793 m Gemini → 2.034 m Grok; width 0.926 m Qwen → 0.988 m Meta) and palette.
Because each mesh is rigidly bound to one owner joint, the visible body differs
but the articulation frame does not.

**Consequences [proposed]:**

- Drop the per-body “retarget once / `motion_scale` / `Rest Fixer`” work from the
  plan. Godot’s `Normalize Position Tracks` and `Overwrite Axis` are unnecessary
  and `Overwrite Axis` is actively risky (see §4.3); leave them **off**.
- One shared `AnimationLibrary` of rotation tracks (plus the one allowed `Root`
  position track) applies exactly to all nine.
- Numeric animation and pair checks become **body-independent**: a socket contact
  that is correct on one operator is numerically correct on all nine. Expensive
  native visual checks still need body extremes (§12).

This corrects `research/ANIMATION_ASSETS.md` §2.8/§11, which assumed per-operator
rest proportions in the skeleton.

---

## 3. Answers to the four owner questions

### 3.1 Can 37 unique clips/operator be reached via “common base + per-char poses”? **[proposed]**

Yes, and the shared skeleton makes it cheap — but the owner’s rule stands: the
final clip must be **authored, not parameterised**. The safe hybrid is:

- **Shared base** for genuinely universal motion (`idle`, `walk_*`, `jump_*`,
  `land`, `guard_*`, `hit_*`, `block_*`, `knockdown`, `wakeup`, `throw_tech`,
  `win`, `lose`). Reuse the base *skeleton curves* and then apply **per-operator
  full-body pose deltas and timing**; the content `motion_brief` fields already
  specify distinct posture vocabulary per operator, so the deltas are authored,
  not tinted.
- **Fully authored per operator** for the identity set: all normals, all three
  specials, the super, and both throws. These are where “unique full-body
  trajectories” must live.
- **Timing is already unique**: the manifest gives each operator different frame
  counts per move (e.g. `stand_l` 15/17/18/19/21/23/24 across operators). Preserve
  those lengths as authored data; do not normalise them away.

Physical acceleration: author the common base once, then have each operator pass
add full-body key poses at anticipation/contact/recovery plus its own clip length,
and bake deterministically. Time-warp alone does not satisfy the owner requirement;
body-proportion retarget is a no-op and cannot create identity.

### 3.2 Signature strikes/grapples vs victim reactions **[proposed]**

- Attacker-side throws/specials/supers: **unique per operator**, full-body
  trajectories (25 attacker timelines).
- Victim reactions: **generic per attacker throw**, authored once, aliased into
  every victim library (25 authored, 225 names). Because victim skeletons are
  identical, the chain of joints is exact; no per-body retarget is needed.
- Do not store 225 independent heavy clips. Keep the 225 *names* (contract) but
  bind them to 25 shared `Animation` resources.

### 3.3 Native pose inspection vs body-dimension numeric checks **[verified + proposed]**

- **Cheap, do now:** numeric preflight (bone count/non-zero length, rest identity,
  finite transforms, socket existence, foot/hand socket rest positions, LOD draw
  counts). These can run headless without the heavy slot.
- **Critical, do before bulk:** **native side-on pose inspection of a vertical
  slice** (Meta vs Mistral) because import, skinning, bone axis, material and
  camera readability can only be judged on screen. Gate the remaining 300+ clips
  on that slice. Numeric checks cannot certify visual quality; a batch authoring
  run that later fails native inspection is the largest avoidable cost.

### 3.4 Stage composition **[proposed]**

- Reuse the chosen map’s geometry as a **cropped, non-colliding decor mesh**
  (`stage_only`), with the fight-plane octagon as the *only* physics that the
  fighting mode loads. Do not inherit the FPS scene, actors, pickups or collision
  tree (matches `research/ROSTER_STAGES.md` §7.5).
- GLB reuse is a **positive** for resource closure: the map GLB already exists and
  its hashes are frozen; importing it as a scene keeps closure without a new
  authoring dependency.
- Reuse the **already-owned UI/HUD** from `presentation`; do not build a second
  shell.
- Import-cache hygiene (§8) keeps stage re-imports from regenerating unrelated
  maps.

---

## 4. Godot 4.5 pipeline best practices **[verified — primary docs]**

Project runtime is Godot **4.5.2-stable**, Compatibility renderer
(`godot/project.godot`, `tools/godot-operators/check.py`).

### 4.1 Import cache and content hashing

`Import process` (4.5): Godot keeps imported resources in `res://.godot/imported/`
alongside `<asset>.import`; “When the **MD5 checksum** of the source asset changes,
Godot will perform an automatic reimport”. `*.import` files and `<asset>.import`
must be committed; `.godot/` must not.

**Efficiency rules [proposed]:**
- Treat each `.glb`/`.blend` content hash as the reimport key (the repo already
  uses this pattern in `content/FREEZE.json`). Only regenerate what changed.
- Do **not** let a shared base change ripple through every operator: keep one
  `.blend` per operator (or per authoring group) so a rig change invalidates only
  that operator’s import.
- Record `source .blend hash → exported GLB hash → AnimationLibrary hash` per
  operator; a mismatch is a build failure, not a silent reimport.

### 4.2 Shared animation libraries (the core dedup lever)

`Import configuration` (4.5): “As of Godot 4.0, you can choose to import **only**
animations from a glTF file … For example, this allows you to use **one set of
animations for several characters, without having to duplicate animation data in
every character**” (Import mode = **Animation Library**). `AnimationLibrary`
(4.5) is a `Resource` container of `Animation` resources keyed by `StringName`;
the same `Animation` resource can be referenced by more than one library.

**Design [proposed]:** build motion as a shared library and compose at runtime:

```
operator scene (Skeleton3D + skin + rigid batches)   ← 1 GLB/operator, mesh+skin only
        └─ AnimationPlayer
             ├─ default library     : operator-specific clips (specials/super/throws)
             └─ shared motion lib   : base states + shared victim reactions
```

Keys remain exactly `ANIMATION_COVERAGE.json`’s names. If the contract must keep
one self-contained GLB per operator, generate per-operator libraries whose
`Animation` resources are the shared ones (by reference) via an import script —
data is still stored once.

### 4.3 Retargeting and rest handling

`Retargeting 3D Skeletons` (4.5): sharing animations needs matching bone rests as
well as names. `BoneMap` + `SkeletonProfileHumanoid`; options include **Remove
Tracks** (Except Bone Transform / Unimportant Positions / Unmapped Bones),
**Bone Renamer**, and **Rest Fixer** (Apply Node Transform / Normalize Position
Tracks / Overwrite Axis / Fix Silhouette). `Overwrite Axis` “can produce horrible
results if the original Bone Rest set externally is important”. `Normalize Position
Tracks` scales position by `scale_base_bone` (Hips) stored as `motion_scale`.

**Applied to this repo:** the nine rests already **match exactly** (§2), so the
correct settings are the conservative ones:

- `Remove Tracks → Except Bone Transform`: **on** (animation library); remove
  unmapped bones; **Unimportant Positions** may stay **off** because there is no
  cross-body position mismatch — or on, since only `Root`/`Hips` positions are
  meaningful. Either is safe here; document the choice.
- `Rest Fixer`: **all off** (T-pose/axis already consistent; no per-body fix
  needed). `Overwrite Axis` in particular should not be used on this mechanical
  rig.
- Author/keep a humanoid T-pose-ish reference rest and a `RESET` animation so
  blended tracks have defined initial values (§4.4).

### 4.4 AnimationTree blending determinism

`Using AnimationTree` (4.5): `AnimationTree` has no animations of its own; it
drives an `AnimationPlayer`. Nodes: `AnimationNodeAnimation`, `BlendTree`
(`Blend2`/`Blend3` with per-track **filters**, `OneShot`, `TimeSeek`, `TimeScale`,
`Transition`, `StateMachine`), `BlendSpace1D/2D`. Transitions are
Immediate / **Sync** / At End with Xfade and `travel()`. **Determinism:** blended
tracks need a defined initial value; for `Skeleton3D` bones the initial value is
**Bone Rest**, so a T-pose rest near the midpoint of motion is preferred. Rotation
tracks prevent >180° rotation from the initial value.

**Applied:** use `AnimationNodeStateMachine` for fight states and `OneShot` for
reactions/specials, with `Blend2` + filters for guard/hit layers. **Authority stays
in the fixed tick**: the mixer never gates a hit. Cosmetic hitstop may pause the
mixer, but sim ticks continue.

### 4.5 Playback and seek cost

`AnimationPlayer` (4.5): `seek(seconds, update=false, update_only=false)` — if
`update` is false it updates at process time; “Events between the current frame and
`seconds` are skipped”; `update_only` skips method/audio/playback tracks. `play()`
updates on the next process; to force immediate evaluation call `advance(0)`.

**Efficiency rule [proposed]:** drive discrete fight states by **key + crossfade**,
not by per-frame `seek()`. Use `seek(..., update_only=true)` only for deterministic
scrub/verification tools; a seek per frame walks intervening keys and skips events,
which both costs CPU and can desync cosmetic events. **[measure]** the actual seek
CPU at the target clip/key density before adopting any scrub-based UI.

---

## 5. Blender 4.5 authoring and export **[verified — primary docs]**

Approved toolchain: Blender **4.5.14 LTS**
(`/home/mojo/.tmp-on-disk/cocs-blender-toolchain/…`).

### 5.1 glTF export recipe

`glTF 2.0` manual (4.5), Animations:
- **Animation Mode = Actions (default).** “An action will be exported if it is the
  active action on an object, or it is **stashed to an NLA track** … make sure they
  are stashed!” The glTF animation name is the action name unless the **NLA track
  is renamed**. “This mode is useful if you are exporting for a game engine, with
  an animation library of a character. **Each action must be on its own NLA track.**”
- **Slotted-action change (4.4+):** tracks are now merged **by the action they use,
  not by name**. This is the one 4.5-specific trap: do not rely on two
  same-named tracks merging; use one action per exported clip.
- Options: `Merge Animation` = **None** (or by Action), `Export all Armature
  Actions` (single armature only), **`Reset pose bones between actions` = on**
  (“needed when some bones are not keyed on some animations”), `Limit to Playback
  Range`, `Set all glTF Animation starting at 0`, `Bake All Objects Animations`.
- `Actions`/`Active Actions merged` are the only modes that handle non-sampled
  animation; sampling is the safe default for retarget fidelity.

**Recipe [proposed]:** one `.blend` per operator (or per authoring group); every
clip = one stashed action on its own NLA track named exactly the clip key; export
`Mode = Actions`, `Merge = None`, `Reset pose bones between actions = on`,
`Set all glTF Animation starting at 0 = on`; keep 30 fps authoring and let Godot
resample (the fighting sim still runs at 60 Hz).

### 5.2 Slotted actions

`Animation / Actions` (4.5): every action organises its data into **slots**; a
data-block selects an action **and a slot**. Slots have a name + associated
data-block type (unique name+type within an action) and are not bound to a
specific object. Multi-object animation can live in one action with one slot per
object.

**Efficiency rule [proposed]:** keep one slot per exported armature action. Do not
pack many operator clips into one slotted action hoping to split them at export —
4.5 merges by action, which would fuse them into one glTF animation. If a
single-`.blend` “library” is preferred, use **separate actions + separate NLA
tracks**, one clip each.

### 5.3 Non-zero bones, bind matrices, constraints, reproducibility

- **Non-zero rest bones** are required (owner correction to the earlier
  proposal). Humanoid profile bones with no existing joint (`UpperChest`, `Neck`,
  `Shoulders`, `Toes`, optional 1–2 finger joints/side) must be added with real
  length and a real parent chain, not zero-length fillers.
- **Rigid bind contract:** assign every existing batch 100% to its current owner
  bone (weight 1.0), one skin shared by all batches (Blender exports shared binds).
  Keep batch names/LOD masks so the existing distance policy still selects
  geometry. Preserve materials/vertex colours/`KHR_materials_unlit`.
- **Constraints → bake:** if control rigs/IK/constraints are used, bake to bone
  keyframes before export and strip constraints; export the baked action. Godot
  never sees the constraint graph. Verify baked output equals the viewport pose at
  declared key frames.
- **Reproducibility [proposed]:** a committed Blender script drives creation/export
  (headless when the heavy grant is used) from the machine-readable joint data in
  `manifest.json` plus the authored actions, so a GLB can be rebuilt from source
  and hashed. No hand-edited binary GLBs.

---

## 6. Asset-efficiency design decisions **[proposed]**

| Decision | Choice | Why |
|---|---|---|
| Skins | 1 skin/operator, **named skins on** | Blender shares binds; named skins let the shared library retarget by name |
| Animations | one **shared** library + per-operator library | avoids duplicating base states/victim clips 9× |
| Retarget | **none** (rest-identical) | §2 |
| LOD | expose LOD0/LOD1 in fighting; keep LOD2 for source parity | fighters sit <~10 m; the 50 m LOD is dead weight in a 2.5D stage |
| Materials | keep 13 unlit materials initially; consider consolidating only with measured draw-call gain | 117 materials total; do not risk the unlit look for an unmeasured win |
| Colliders | **none** on fighters or cropped stage decor; sim owns collision | DESIGN fixed X/Y authority |
| Root motion | `Root` position is the only moving position track; everything else rotation-only | determinism/rollback |
| Import | `FPS` = 30, Optimizer on, Trimming on, Remove Immutable Tracks on | smaller, faithful animations |

---

## 7. Throw/victim math and pair validation **[proposed]**

### 7.1 Single authoritative contact

A throw is one paired timeline with one authoritative `contact` frame and a hold
window, owned by the fixed simulation. Presentation only matches it.

### 7.2 Contact-alignment math

Because both skeletons are identical, alignment is a closed-form transform, not a
search:

- Let `A_c` = attacker contact socket world transform (e.g. `Socket_KnuckleL/R`
  or `Socket_GripL/R`) at the contact frame, and `V_g` = victim grab socket
  (`Socket_Chest`/`Socket_Hand*`) local transform relative to the victim root.
- The sim pins `victim_root = A_c ∘ V_g⁻¹` (with the authored relative yaw and the
  side-swap flag applied for `throw_b`). Physics/position remains sim-owned; the
  bones only report sockets.
- **Validation:** at every frame of the hold window compute
  `d = dist(A_socket, V_socket)` and assert `d ≤ ε_contact`; assert both actors
  report the **same** frame index for `contact`; assert the victim leaves the
  shared timeline at the declared `throw_tech`/release frame.

Suggested tolerances (tune on the slice, then freeze): contact `ε ≤ ~2 cm`,
foot-plant drift `≤ ~1 cm/frame`, floor penetration/float `≤ ~0.5 cm`, strike
contact vs sidecar `≤ ~3 cm`; every value recorded with its measured max.

### 7.3 Why this collapses validation

With identical rests, `d` is **independent of which operator is the victim** for a
given attacker timeline. So:

- **All-pair numeric checks** reduce to the 25 attacker timelines × their victim
  socket math, then a mapping assertion that every `victim_<attacker>_<move>` name
  on every operator resolves to the correct shared clip.
- **Expensive native visual pair checks** are reserved for **body extremes**:
  tallest Grok (2.034 m) and shortest Gemini (1.793 m), widest Meta (0.988 m) and
  narrowest Qwen (0.926 m), plus one asymmetric body (Grok) and one grappler
  (Meta). This covers the mesh-proportion spread that the numeric check cannot see.

---

## 8. Stage composition and import-cache / rig-delta hygiene **[proposed]**

- **Crop, don’t port:** instantiate the chosen map GLB, keep only the crop’s decor
  batches, disable inherited collision, and add only the fight-plane octagon +
  ring walls. Reuse frozen map hashes for resource closure.
- **Stage-only import:** mark cropped/duplicated stage meshes `stage_only`; expose
  only the source coordinates transform and hashes (already required by DESIGN).
- **Content-hash delta:** since `Import process` reimports on source MD5 change
  (4.5), a stage change must not touch operator GLBs and vice-versa. Keep separate
  `.blend`/`.glb` sources per domain (operators, motions, stages) so the delta set
  is small.
- **Rig-tracking delta:** if the shared base rig changes, re-export the shared
  motion library once and reimport only that one asset; the nine operator
  mesh/skin GLBs are unchanged because the rest is unchanged. This is the payoff of
  the shared skeleton and the reason to keep motions in their own source.
- **UI:** reuse the existing presentation shell; no second HUD resource tree.

---

## 9. Nine FX structural vocabularies **[proposed]**

Reuse the repo’s existing pooled/instanced idiom
(`godot/combat_particles/manager.gd`, `game/effects-fx.mjs`): fixed slot pools,
shared geometry/masks generated once, oldest-first slot reuse, **public events
only** with dedup, and quality tiers Low 8,192 / High 32,768 / Extreme 1,000,000
(the existing measured precedent: Extreme ≈ 448 ms median, High ≈ 44 ms on
llvmpipe — *software* renderer, selection-only).

- **Nine structural vocabularies**, not tints: cage/ring (chatgpt), shard fan
  (claude), asymmetric chevron (grok), twin contrail (meta), bifurcating lance
  (gemini), vented cone (deepseek), aerofoil streak (mistral), gimbal orbit
  (kimi), layered wall (qwen). Shape carries identity; palette is secondary.
- **One pooled system, nine shape recipes:** instance the same `GPUParticles3D`
  slots and shared masks, parameterised by a per-move recipe (`vfx_events[]` in
  the sidecar: name + frame + socket + budget class). No per-operator duplicate
  systems.
- **Budget before benchmark:** assign every event a class mapped to a tier and
  default to High; **[measure]** actual active-particle counts and frame cost at
  the chosen counts per tier **after** the vocab is locked — do **not** benchmark
  large frame counts prematurely.
- **Under the heavy-slot rule:** no FX benchmarking on hardware without the grant
  and teardown; the existing llvmpipe numbers are the only local evidence.

---

## 10. Top three cost savings (with owner and provenance impact)

No saved-time numbers are claimed; each saving is a concrete change with an
observable count/byte metric (§11) and does **not** reduce uniqueness to two
operators or a recolour.

### Saving 1 — Eliminate per-body retarget and 9× animation duplication

- **Change:** ship one shared motion library on the rest-identical skeleton;
  rotation-only tracks + the single allowed `Root` position track; import the nine
  operators as mesh+skin scenes. No `Rest Fixer`, no `Normalize Position Tracks`,
  no `motion_scale`.
- **Owner:** Astra animation (assets), parent/core (interface).
- **Provenance:** one hash set for the shared motion source; each operator keeps
  its own mesh/skin hash. Victim/motion provenance is recorded once, not nine times.
- **Guard:** per-operator authored pose arcs and timings are retained.
- **Evidence it is safe:** 27/27 rest matrices identical across nine (§2).

### Saving 2 — Author 25 victim timelines once; alias 225 names

- **Change:** keep the contract’s `victim_<attacker>_<move>` names, but bind them
  to 25 shared `Animation` resources instead of storing 225 clips; freeze the
  25 hashes plus the name→clip mapping table.
- **Owner:** Astra animation (timelines), Sol content (naming/contract), core
  (paired timeline).
- **Provenance:** the 25 attacker throw sources are the provenance unit; the
  9× mapping is generated, not hand-duplicated.
- **Guard:** attacker-side throws remain fully per-operator; only the generic
  victim reaction is shared, exactly as the owner requested.
- **Observable:** stored victim-clip count drops 225 → 25 (bindings stay 225).

### Saving 3 — Hybrid uniqueness with a native-slice gate

- **Change:** shared authored base for universal states + per-operator full-body
  key-pose deltas and per-operator clip lengths for normals/specials/supers/throws;
  bake deterministically; **gate the remaining ~300 clips on native side-on
  inspection of Meta vs Mistral**.
- **Owner:** Astra animation, with the heavy grant sequenced after Foundry rev 3
  releases the slot.
- **Provenance:** each clip records its base reference + authored delta + bake
  hash.
- **Guard:** no “same clip, different colour/speed”; timing values already differ
  per operator in `ANIMATION_COVERAGE.json`.
- **Process saving (supporting):** content-hash import deltas (§8) so re-exports
  touch only changed assets.

---

## 11. Meaningful metrics to collect (not invented times)

| # | Metric | How to measure | Gate |
|---|---|---|---|
| M1 | Rest-skeleton identity | compare 27 matrices + manifest joints across 9 | 27/27 basis equal, translation spread 0.0 mm |
| M2 | Skin/rig validity | parse GLB: skins=1, joints mapped, non-zero rest lengths, finite transforms | 9/9 pass |
| M3 | Animation payload | GLB `animations` count, tracks/clip, key totals, animation bufferView bytes | reported per operator |
| M4 | Stored vs referenced clips | count distinct `Animation` resources vs 225 names | stored = 25 victim + per-op sets |
| M5 | Import cost | wall time to import one operator + `.godot/imported` bytes | reported; delta-only reimport verified |
| M6 | Blend determinism | repeat identical state machine input, hash bone poses | identical hashes per run |
| M7 | Socket contact error | max `dist(A_socket, V_socket)` at contact + hold window | ≤ frozen ε (§7.2) |
| M8 | Foot plant / floor | max planted-socket drift per frame; min signed floor distance | ≤ ε; no float/penetration |
| M9 | Strike trajectory | contact socket vs sidecar position at contact frame; monotonic arc | ≤ ε; no reversal unless feint |
| M10 | At-risk / all-pair numeric | run pair math over all ordered pairs | 100% pass; body-independent |
| M11 | Native body-extreme visual | side-on contact sheets for Grok/Gemini/Meta/Qwen + grappler | human pass on all listed |
| M12 | Draw/geometry budget | draws, triangles, materials per operator LOD0 and per stage crop | within stated bounds |
| M13 | FX cost | active particles + frame time per tier at locked counts | measured post-lock only |
| M14 | Provenance closure | source `.blend` hash → GLB hash → library hash, licence file present | mismatch = fail |

---

## 12. Full all-nine gate plan

**Numeric, automated, all pairs (cheap; can run at source level):**

- All 9 operators: skin present, 1 skin, mapped bones, non-zero rest, finite
  transforms, no accidental weapons, rigid weights valid.
- All 25 victim names on all 9 operators resolve to the correct shared clip
  (mapping assertion, not 225 hand checks).
- All ordered operator pairs (9×9, incl. mirrors) and distinct pairings (36):
  run the closed-form socket/foot-plant math of §7.3; because rests are identical,
  correctness is body-independent and can be asserted once per attacker timeline,
  then mapped to every body.
- Left/right symmetry: face-swap the attacker timeline and re-assert.

**Native visual, representative body extremes only:**

- Tallest Grok (2.034 m) vs shortest Gemini (1.793 m); widest Meta vs narrowest
  Qwen; plus one asymmetric (Grok) and one grappler (Meta) pairing.
- Side-on at 1280×800 and 1920×1080, startup/active/recovery contact sheets,
  greyscale silhouette readability at 3 m / 10 m / far band.
- Both fighters present with FX for every clipped stage.

**Per-operator unique-motion gate:**

- Side-by-side pose sheets for the identity set (normals/specials/super/throws)
  across all nine, asserting distinct silhouette and timing — not just distinct
  clip names.

**Process gates:**

- Heavy slot explicitly granted after Foundry rev 3 releases it; single owner at a
  time; teardown confirmed.
- Import cache delta verified; provenance hashes recorded.

---

## 13. Verified CC0 library inventory vs marketing

Fetched 2026-10-02; **no file was downloaded or committed.** Exact free per-clip
file lists require the free ZIP’s `unzip -l` (and the Quaternius free download is
JS/purchase-gated), so the counts below are the **stated tier** facts, with that
limitation explicit.

| Source | Marketing count | Free/CC0 reality | Formats | Verdict |
|---|---|---|---|---|
| Quaternius **Universal Animation Library** (March 2025) | “120+ animations” | CC0; free tier “**60–70% of my pack is completely free**”; `.blend` only in paid **Source** tier | FBX, GLB, (Blend paid) | usable base; exact free clip list must be enumerated from the free ZIP |
| Quaternius **Universal Animation Library 2** (January 2026) | “130+ animations” | CC0; same 60–70% free tier; includes 3/4-hit combos split into hits + recoveries | FBX, GLB, (Blend paid) | usable combat base; same enumeration caveat |
| KayKit **Character Animations** (devlog update 2025-12-10) | “**161** humanoid animations” | free tier states “**150+** … completely free”; spread across **Rig_Medium 100+** and **Rig_Large 25+**; `.blend` is a paid **$14.99** Source tier; “No generative AI was used” | FBX, GLTF | strong secondary; do **not** assume all 161 are one rig |
| Mixamo | — | free, royalty-free use, but **raw files may not be redistributed** | FBX | reference/prototype only; **never commit** |
| CMU MoCap | — | “may be copied, modified, or redistributed” (secondary confirmation; primary FAQ intermittent) | ASF/AMC (+conversions) | allowed supplement; heavy cleanup |

Hard rule: committed motion must be CC0 or explicitly redistributable; record the
licence beside the asset. No paid download is implied or required.

---

## 14. Primary references (version + date)

All fetched 2026-10-02 unless noted.

1. **Godot 4.5 — Import process.** `https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/import_process.html` — `.import`, MD5 automatic reimport, `.godot/imported/`.
2. **Godot 4.5 — Import configuration (Importing 3D scenes).** `.../importing_3d_scenes/import_configuration.html` — Animation Library import mode, import scripts (`EditorScenePostImport._post_import`), filter scripts, Optimizer/FPS/Trimming/Remove Immutable Tracks, named/shared skins, LOD/shadow meshes, `Export Bones Deforming Mesh Only`, `Group Tracks`, `Always Sample`, `Limit Playback`.
3. **Godot 4.5 — Retargeting 3D Skeletons.** `.../retargeting_3d_skeletons.html` — BoneMap/SkeletonProfileHumanoid, Remove Tracks, Rest Fixer, Normalize Position Tracks/`motion_scale`, `Overwrite Axis` warning.
4. **Godot 4.5 — Using AnimationTree.** `.../animation_tree.html` — Blend2/3 + filters, OneShot, TimeSeek, TimeScale, StateMachine (Immediate/Sync/At End, `travel()`), blend determinism + T-pose Bone Rest, root motion.
5. **Godot 4.5 — AnimationPlayer class reference.** `.../classes/class_animationplayer.html` — `seek(seconds, update, update_only)`, sections, `advance(0)`, process-frame update.
6. **Godot 4.5 — AnimationLibrary class reference.** `.../classes/class_animationlibrary.html` — `Resource` container of `Animation`s keyed by `StringName`.
7. **Blender 4.5 LTS Manual — glTF 2.0.** `https://docs.blender.org/manual/en/4.5/addons/import_export/scene_gltf2.html` — Animation Mode Actions/Active-merged/NLA Tracks, NLA track naming, 4.4 slotted-action merge-by-action, `Merge Animation`, `Export all Armature Actions`, `Reset pose bones between actions`.
8. **Blender 4.5 LTS Manual — Animation / Actions (Action Slots).** `https://docs.blender.org/manual/en/4.5/animation/actions.html` — slots, name+type uniqueness, multi-data-block actions.

Asset/licence sources (counts and terms verified on the page; no download):

9. Quaternius UAL — `https://quaternius.com/packs/universalanimationlibrary.html` (March 2025, CC0).
10. Quaternius UAL2 — `https://quaternius.com/packs/universalanimationlibrary2.html` (January 2026, CC0).
11. KayKit Character Animations — `https://kaylousberg.itch.io/kaykit-character-animations` (CC0; devlog update 2025-12-10).

Repository evidence parsed this audit: `port/fighting/content/ANIMATION_COVERAGE.json`,
`port/fighting/content/{README,CONTRACT_DETAILS,FREEZE,RESULTS,MOVE_LIST}.md`,
`port/fighting/{DESIGN,WORKSTREAM}.md`,
`port/fighting/research/{ANIMATION_ASSETS,ROSTER_STAGES}.md`,
`godot/source_operators/generated/*.glb`, `.../manifest.json`,
`godot/fighting/data/{roster,rules}.json`.

### Offline / unavailable (explicit)

- **Mixamo FAQ** primary (`helpx.adobe.com/.../mixamo-faq.html`) returns **403 to
  automated fetch**; the licensing finding rests on the earlier research memo’s
  visible community mirror and must be re-verified by a human before any reliance.
- **CMU MoCap FAQ** intermittently refuses automated fetch; licence text is
  secondary-sourced. CMU is **not** the selected acquisition path.
- **Quaternius free ZIP listing** could not be enumerated: the free download link
  is JS/purchase-gated, so exact free per-clip names remain unverified. Enumerate
  with `unzip -l` on the free archive before promising specific base clips.
- **No hardware performance** was measured: the only particle numbers are the
  existing llvmpipe (software) results and cannot certify real-GPU cost.

---

## 15. Safe priority (recommended order)

1. **Now, source-only (no grant):** adopt the rest-identity preflight (M1) and the
   mapping assertion (M4) as committed tests; reconcile the shared-library
   interface and the 25-victim aliasing with parent/core before any clip batch.
2. **First heavy grant (after Foundry rev 3 releases):** Meta vs Mistral vertical
   slice — rig conversion with non-zero bones, one shared library, native side-on
   inspection, socket/foot numeric checks. Do not author the other ~300 clips first.
3. **Batch:** expand to all nine with the hybrid base+delta authoring; run
   all-pair numeric checks continuously; native visual gates on body extremes.
4. **Stage + FX:** crop stage decor and lock the nine FX vocabularies with pooled
   slots; measure budgets only after vocab lock, under the granted slot.

---

## 16. What this audit did and did not do

- **Did:** parse the committed content manifest and all nine shipped GLBs; run a
  numeric rest-transform comparison; fetch and cite primary Godot 4.5 / Blender
  4.5 / CC0 sources; propose the shared-library, victim-dedup, pair-math, stage,
  FX and gate plans; write only this document.
- **Did not:** poll the active `fighting/animation-*` lane; write any production
  or `godot/` file; run Godot, Blender, ffmpeg, audio, capture, import or render;
  spawn nested agents; request or use the heavy slot owned by Foundry rev 3;
  download or commit any third-party asset.
