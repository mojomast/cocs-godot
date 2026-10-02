# Animation/rig implementation — native production

Status: **All nine masters and GLBs built, separately reopened and native tested**
under exclusive grant `FIGHTING-ANIMATION-PRODUCTION-20261002-B`.
See [PRODUCTION_B.md](PRODUCTION_B.md) for actual results, evidence and remaining
presentation/art review limitations. Earlier source-only findings below are
historical; native gates do not by themselves establish visual acceptance.

## Owned implementation

- `tools/fighting/animation/recipes.py`: nine independently composed guards,
  torso/hip counterrotation, hand/wrist arcs, normals, signatures, reactions,
  locomotion and match poses. 336 state/combat clips including Gemini
  `palm_l`, `palm_m`, `palm_h`; 25 shared victim choreographies.
- `glb.py`: standard-library binary GLB reader, actual rest/layout and geometry
  bounds oracle; source owner → humanoid bone mapping.
- `kinematics.py`: analytical two-link limbs, original lengths, full-body
  task-space curves and immutable actor root. No sinusoidal automatic jab solver.
- `pairing.py`: closed-form shared-rig **victim pelvis/limb pose** correction to
  the attacker's grip at the fixed content-relative actor positions. It never
  moves an actor root or changes the simulation's contact/damage.
- `content.py`: read-only binding to Sol's actual roster, rules and coverage,
  exact common-rest assertions and source hashes.
- `blender_pipeline.py`: rigid weight-1 conversion, material/LOD skin batching,
  Blender 4.5 slotted Actions/NLA, save, separate-process reopen, export and hash
  validation. Exporter enum names were checked in the installed 4.5.14 add-on
  source; actual API/slot behavior is still an execution gate.
- `godot/fighting/visuals/fighter_visual.gd`: exact public API from DESIGN.md;
  manual AnimationPlayer seeking and named socket lookup. `configure()` reports
  missing art honestly. There is no development model masquerading as animation.
- `godot/tests/fighting/animation/{native_gate,capture}.gd`: prepared native
  finite-pose, clock-freeze, rewind, facing and pair-contact gates plus side-on
  phase captures, optionally displaying the paired victim.
- `prepare_native.py`: minimal selected-operator proof project, avoiding imports
  of the full FPS/map project.

## Common rest correction and mechanical anatomy

The efficiency audit `284e6938` supersedes the research assumption of different
rest proportions. The source checker independently verifies identical converted
rig dictionaries across all nine. Mesh bounds and mechanical silhouettes differ;
**mesh penetration/contact acceptance remains per body**.

Keep all source materials, vertex colors, original plate topology and normals.
Rigid pieces receive exactly one weight of 1.0 to their source articulation.
This preserves metal robot anatomy rather than smoothing joint plates into skin.
Delete only the imported fighting copy's `gunAnchor/weapon/Muzzle` subtree;
hands remain unobscured. Source FPS files are never written.

Twenty real, nondegenerate bones are sufficient. Source mapping:

| Source | Bone | Rest length m |
|---|---|---:|
| root | Root | .7835 |
| hips | Hips | .22 |
| torso | Spine | .30 |
| chest | Chest | .14 |
| chest→head midpoint | Neck | .14 |
| head | Head | .14 |
| chest shoulder plane→arm pivot | Left/RightShoulder | .30 |
| armUpperL/R, rigPivot0/1 | Left/RightUpperArm | .29 |
| forearmL/R, rigPivot2/3 | Left/RightLowerArm | .275 |
| handL/R, gripL/R | Left/RightHand | .09 |
| legUpperL/R, rigPivot4/5 | Left/RightUpperLeg | .34 |
| legLowerL/R, rigPivot6/7 | Left/RightLowerLeg | .35 |
| footL/R | Left/RightFoot | .13 |

`backpack` follows Chest; team marks follow Spine. Intermediate pivot meshes bind
to the corresponding actual limb. No padding fingers/toes/UpperChest or
zero-length bones. This is a humanoid **name map with preserved robot rest**, not
a claim of a newly accepted humanoid T-pose. No BoneMap Rest Fixer,
NormalizePositionTracks, motion-scale rewrite or OverwriteAxis is required.
Keep all authored position channels: pelvis compression and solved limb transforms
are intentional. Root remains fixed. No AnimationTree retarget layer is involved.

Socket keys (also accept `Socket_` prefix): `Chest,Hips`, and bilateral
`Hand,Knuckle,Grip,Foot,Streak,Elbow,Knee,Guard` + `L/R`. Sockets are offsets in
existing bones, not unnecessary deform bones. Grip is +.045 m along hand bone;
knuckle +.085 m; Chest is the actual chest pivot. Native silhouette review must
verify those offsets against **each robot's visible hand/armor geometry**.

### Gun-removed source dimensions (LOD0, metres)

Axes below are source width X, height Y, depth Z. These are binary vertex-bound
measurements, not animation envelopes or accepted collision extents.

| Operator | Width | Height | Depth |
|---|---:|---:|---:|
| chatgpt | .932202 | 1.955500 | .696000 |
| claude | .961242 | 1.801842 | .696000 |
| grok | .931761 | 2.033500 | .737344 |
| meta | .987798 | 1.801842 | .696000 |
| gemini | .931495 | 1.792940 | .737344 |
| deepseek | .934000 | 1.891500 | .696000 |
| mistral | .953314 | 1.828500 | .737344 |
| kimi | .981120 | 1.955500 | .696000 |
| qwen | .925726 | 1.955500 | .696000 |

## Timing contract for core/content/presentation

`configure(operator_id:String)->bool`, `present(fighter:Dictionary,alpha:float)`,
`socket_world(name:String)->Vector3`, `reset()` are implemented. Optional
`set_lod(0..2)` selects original masks, without decimating or disconnecting joints.
Meshes batch across rigid owners only when material, LOD mask and shadow flag
agree; weight groups preserve articulation.

- Position is exactly snapshot `(x,y,0)/1000`; source -Z faces right after yaw
  `-PI/2`. Left-facing uses a proper +PI rotation, not negative skeletal scale.
- **`animation_frame` is zero-based move-local time**, including for victims.
  It must freeze during hitstop and remain reproducible under seek/rollback.
  `alpha` does not advance attacks or extrapolate position. No delta-time clock,
  animation method tracks or animation damage callbacks are permitted.
- Combat clip names are the content `animation` key. Victim keys are
  `victim_<attacker>_<move>`. Grok/Mistral special3 are strikes, so there are 25,
  not 27, paired timelines. Claude special3 includes its counter-grab timeline.
- Each action is authored over 0..60 at 60 fps. Explicit manifest knots map
  simulation frames to those authored seconds; direct `animation_frame/60` is
  used only by the 60-frame state loops, not guessed for combat.
- For ordinary strikes, the pose's `.50` second impact maps to startup S;
  `.40` preactive maps before S; `.60` follow-through maps to S+A; final recovery
  maps to S+A+R. Projectile impact maps to `spawn_frame`; mobility maps to
  `movement.from`. Knots preserve content frame envelopes if durations change.
- Paired `.28/.68/.82/1.0` phases map to **actual contact/damage/release/end**.
  Contact is throw startup or counter.from. Damage/release come directly from
  `throw`/`counter`; end is S+A+R. No damage time is invented.
- Victims face opposite the attacker while held, root at the authoritative
  `victim_x/victim_y`; visual pelvis and bent limbs meet the grip. Relative actor
  placement, tech, release, side swap, knockdown and KO interruption remain core
  decisions. `socket_world()` is presentation-only and cannot move a hitbox.
- Manifest hashes bind `roster.json`, `rules.json`, coverage, master, original
  GLB and the generating pipeline. Runtime refuses stale roster/rules hashes.

**Dynamic core integration:** the adapter now consumes core `6be3b1ce`'s shared
`pair_phase` and maps actual catch/damage/release/end to .28/.68/.82/1.0. It
validates strictly increasing integral knots and matching `frame`/animation_frame.
The snapshot alone selects the pose; repeated hitstop, rewind and fresh adapter
construction do not require a remembered catch. Tech, KO, new attacks and reactions
discard obsolete pair metadata. Root and facing always remain snapshot-authoritative;
core performs side swap at **damage**, not release.

**One core projection remains required:** `pair_phase` is currently cleared on
release. Preserve optional attacker `animation_pair_phase` through recovery so
dynamic release/end knots cannot fall back to the fixed manifest. The adapter
already accepts it; precise lifecycle/save-load requirements are in
`PAIR_SEEK_HANDOFF.md`. Native pair capture below is a fixed-placement authoring
proof, not a simulator trace for side swaps or tech/KO interruption.

## Sharing and resource closure

Authored content is **336 unique state/combat + 25 shared victim = 361 curves**;
the API resolves **561 usages** across nine operators. One Meta source master
owns the 25 victim Actions. Mistral and the other seven masters link those same
Actions/slots by relative Blender library reference. No 81-pair master family,
body-normalization pass, or repeated victim keyframe authoring is needed.

Initial export closure is self-contained `<id>.glb` + `<id>.json` per operator
under `godot/fighting/assets/operators/`. The first native proof deliberately
uses those exports. They temporarily duplicate victim transport data; a shared
Godot AnimationLibrary/custom composition loader is **not implemented or claimed**.
After the two-character proof, measure whether animation-library import is worth
changing transport. Do not replace the current adapter before proving track/root
path compatibility. Source closure includes `masters/meta.blend` for every linked
master. Master/pipeline/content hashes detect stale linked actions.

No third-party motion has been downloaded, used or committed. All curves here
are authored source recipes; therefore no guessed free-tier coverage, Mixamo
payload or license snapshot is represented as acquired provenance.

## Source verification — completed

```sh
python3 tools/fighting/animation/check.py --output /home/mojo/.tmp-on-disk/cocs-fighting-animation-evidence-20261002/source-audit.json
python3 -m compileall -q tools/fighting/animation
git diff --check
```

Oracle checks all nine binary source GLBs, common rest, positive bone lengths,
finite poses, exact original limb lengths, root lock, no aliased state/combat
curve arrays, cross-operator normalized trajectory RMS, exact content clip
coverage and monotone actual frame binding. It solves all 225 victim usages,
checking 7,425 task-space grip/chest samples at the fixed simulation placement.

Current numeric result: 0 m requested-target IK clamping; smallest rest bone .09 m;
task-space pair error below 1e-12 m against .06 m tolerance. This measures the
closed-form socket solve, **not visible mesh contact, floor clearance, native
bone-axis correctness or animation quality**. Native gate enforces .06 m again
after Blender export/Godot import, including mirrors and every body pairing.

## Next commands — only after the parent grants the heavy slot

Run serially with `LP_NUM_THREADS=1`. Parent supplies the approved Godot 4.5.2
binary in `$GODOT`; Blender path is the installed approved 4.5.14 toolchain.
Do not run bulk builds before Meta/Mistral have passed actual native inspection.

```sh
export LP_NUM_THREADS=1
export BLENDER=/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender
export EVIDENCE=/home/mojo/.tmp-on-disk/cocs-fighting-animation-evidence-20261002

"$BLENDER" -b --factory-startup --python tools/fighting/animation/blender_pipeline.py -- build --operator meta --evidence "$EVIDENCE"
"$BLENDER" -b --factory-startup --python tools/fighting/animation/blender_pipeline.py -- reopen-export --operator meta --evidence "$EVIDENCE"
"$BLENDER" -b --factory-startup --python tools/fighting/animation/blender_pipeline.py -- build --operator mistral --evidence "$EVIDENCE"
"$BLENDER" -b --factory-startup --python tools/fighting/animation/blender_pipeline.py -- reopen-export --operator mistral --evidence "$EVIDENCE"

python3 tools/fighting/animation/prepare_native.py --operators meta,mistral --output "$EVIDENCE/native-slice"
"$GODOT" --headless --path "$EVIDENCE/native-slice" --editor --import --quit
"$GODOT" --headless --path "$EVIDENCE/native-slice" --script res://tests/fighting/animation/native_gate.gd -- --operators meta,mistral --output "$EVIDENCE/native-slice-gate.json"
"$GODOT" --path "$EVIDENCE/native-slice" --script res://tests/fighting/animation/capture.gd -- --operator meta --clip throw_f --victim mistral --output "$EVIDENCE/meta-mistral-pair"
"$GODOT" --path "$EVIDENCE/native-slice" --script res://tests/fighting/animation/capture.gd -- --operator mistral --clip stand_h --output "$EVIDENCE/mistral-heavy"
```

Inspect neutral/guard, locomotion, full planted attack phases, aerial motion,
throw/counter grasp→damage→release, hands/feet, and original material/color
readability at gameplay scale. Fix Meta/Mistral in this same context before
serially building `chatgpt,claude,grok,gemini,deepseek,kimi,qwen`. Then run the
binary oracle with `--exported`, prepare all nine, and run native gates/captures
for all nine and every pair. Store `.import` settings after this proof; do not
commit `.godot/` caches. Source recipes still need visual tuning for gait skating,
floor clearance, armor intersections and throw landings; no visual acceptance
claim follows from source coverage.
