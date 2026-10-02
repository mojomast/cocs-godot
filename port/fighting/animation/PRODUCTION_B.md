# Native production B — 2026-10-02

## Delivered assets

Nine actual Blender 4.5.14 masters at `tools/fighting/animation/masters/<id>.blend`;
nine self-contained animated GLBs, content-bound JSON manifests and Godot import
settings at `godot/fighting/assets/operators/<id>.*`.
Meta owns 25 shared victim Actions; the other eight masters link those Actions.
Every master was reopened in a separate Blender process before GLB export.
336 state/combat Actions + 25 shared victim Actions resolve to 561 clip usages.
The package's existing six-file pipeline hash and exact master paths pass without
a package-code change. Strict `finalResources(requireFighters:true)` reports no
pending fighters, 355 runtime resources and 25 provenance resources.

The canonical anchor was merged first, followed by operator shell revision
`cd12c1dc` and parent `bf20ad05` at subprocess boundaries. FPS source GLBs and
simulation movement/stats were not edited. Finish PNG changes bind at runtime.

## Native discoveries and fixes

- Blender deleted-object access avoided by collecting non-mesh objects first.
- Tangents exported with retained UVs for fitted operator materials.
- Grasp contact moved from internal chest pivot to front armor (+.16 m).
- Hand longitudinal axes follow forearms; original rigid limb lengths retained.
- Walk support uses linear backwards contact velocity and operator stride timing.
- Knockdown/lose rotate the articulated full body while keeping actor roots fixed.
- Godot defaults removed an important back-throw hip key. Import at 60 fps with
  `_subresources.nodes["PATH:AnimationPlayer"]["optimizer/enabled"]=false` and
  compression disabled. Per-animation optimizer settings do **not** disable this
  node-level optimizer. Commit the supplied `.glb.import` files.
- One initial expanded-project editor shutdown crashed after import; retained its
  log and reran with `--quit-after 5`, which completed cleanly.

## Verification actually run

Evidence root: `/home/mojo/.tmp-on-disk/cocs-fighting-animation-evidence-20261002/production-b/`.

| Check | Result / evidence |
|---|---|
| Source poses, original limb lengths, content binding, binary exports | `all-nine-source-binary.json`; zero requested IK clamping |
| All-nine native bones/clips/manual seeking/root/contact gate | **137,046 checks, no failures**, `all-nine-native-gate-node-lossless.json` |
| Core | **194 checks**, `core-run.log` |
| Core invariants | **113,550 checks**, `core-invariants.log` |
| Actual content routes | **54 cases, zero failures**, `core-actual_content.log` |
| Snapshot pair seeking | `PAIR_SEEK_NATIVE_PASS`, `animation-pair_seek.log` |
| Strict package resource/hash inventory | `final-resources.json`, pending `[]` |
| Package resource tests | 4 passed |

Earlier failing 30/60-fps optimized contact gates are preserved; do not substitute
those files for the final node-lossless result.

## Images and motion

- `all-nine-pose-review/`: 336 native five-phase strips, one per state/combat clip.
  `index.json` records simulated frames and installed finish state.
- `slice-pose-review/meta-stand_h.png`, `mistral-stand_h.png`, and
  `meta-knockdown.png`: initial revised two-body contrast review.
- `pair-meta-qwen-throw_f/`, `pair-qwen-meta-throw_b/`,
  `pair-grok-gemini-throw_f/`, `pair-gemini-grok-throw_b/`: extreme body pair phases.
  `pair-extremes-v2.jpg` is the correctly assembled overview.
  These fixed-root phase captures are contact studies; core performs actual swaps.
- `gameplay-refined-{meta-mistral,chatgpt-claude,grok-gemini,deepseek-kimi,qwen-meta}/`:
  actual Basalt Reach shell, UI, simulation and FX; PNG sequences, `trace.json`,
  and nine-second `motion.mp4` each. Cases: throw, tech, super, special1, heavy,
  walk. Traces confirm throw start/hit/end, tech, hits and projectile spawn for
  ChatGPT/Grok/Qwen. DeepSeek charge special is not asserted by this simple input.
- `operator-finish-{off,rejected,refined}/`: matched all-nine idle strips, same
  exported rigs/camera/light. Rejected profiles/PNGs are from `9c684569` in the
  isolated proof project, identity in `operator-rejected-identity.json`.
  Production source was not swapped. Proof project restored to refined inputs.
  `operator-compare-<id>.png` crops the central fighter for three-column review.

Representative review shows distinct planted double-arm Meta strikes, Mistral
kicks, ChatGPT rising arm, Kimi raised knee, Qwen forward hands and different
torso accents. Refined shell differences are subtle in these side-lit idle views;
do not claim a dramatic all-angle material acceptance from those crops alone.

## Presentation blocker and acceptance boundary

The actual production camera always reserves an 8 m jump envelope, yielding an
approximately 18 m vertical frame even for grounded close combat. Fighters are
only about 80 px tall at 1280x800. This was reported to the parent/presentation
owner; `godot/fighting/presentation/camera.gd` was not edited by this lane.
Close-up studies establish articulated motion/contact, not final gameplay-camera
readability. No complete art acceptance or GPU-performance claim is made.
Final gameplay framing and user-facing art acceptance remain parent integration
work. The actual nine production rigs and their native verification are delivered.

## Bounded natural-surface pass

Separate evidence: `/home/mojo/.tmp-on-disk/cocs-fighting-animation-evidence-20261002/surface-refinement-b/`.
New `surface.gdshader` compiled/rendered under Godot 4.5.2 GL Compatibility.
All eleven inherited Foundry/Helix district cameras captured flat/rejected/refined;
Foundry cooling and Helix archive inspected full resolution first. Two additional
12-frame matched camera translations use grazing sun (-12,-65,0). The harness
receipts retain exact eye/target/FOV/light/clock/viewport/profile hashes, with
`input-identity.json` retaining copied source identities. All refinement receipts
have empty failures. Existing lifecycle proof also ran for both maps.

`district-comparison-0.jpg` and `district-comparison-6.jpg` summarize the eleven
districts. Full-res critical files:
`foundry-cooling/gravemill-foundry-{flat,rejected,refined}-000.png` and
`helix-archive/helix-conservatory-{flat,rejected,refined}-000.png`.
Repeated purple plates/checker surfaces are reduced, retaining botanical greens
and architectural accent colors. Art follow-up: Foundry ceiling light panels are
much duller with finish enabled than the flat baseline. Palette/emission changes
remain with the art owner. These use inherited proof lighting, not a verified
production multiplayer lighting match. Software capture cadence is not GPU timing.

Old production/rejected captures and prior Meta/Mistral masters are preserved.
No Parallax native promotion or Windows publication was performed.

## Delivery and exclusive-grant release

- `ded21092`: native pipeline fixes and capture fixtures.
- `1b690f01`: nine masters, nine GLBs, manifests and required import settings.
- Grant B **released 2026-10-02T21:45:31.798193Z** after checking all 83 owned
  command process groups: zero remaining live owned processes.
- Receipt: `production-b/HEAVY_GRANT_RELEASE.json` under the evidence root above.
  No further heavy work may run in this lane without a new explicit grant.
