# Operator Clash — implementation decision and shared contract v1

Status: **planned after three completed Flash research reports; implementation
authorized by the owner, native/asset acceptance still pending**. Working title:
Operator Clash. Research is in `research/{ENGINE_MECHANICS,ANIMATION_ASSETS,ROSTER_STAGES}.md`.

## Product and architectural decisions

- A 2.5D one-on-one fighting game: existing 3D operators, side-on camera, a fixed
  X/Y fighting plane, no sidestep/ring-out or inherited FPS collision.
- Complete first scope: all **nine** operators; local versus (two controllers or
  separate keyboard bindings), versus readable AI, and training with dummy modes,
  input history, move list, frame advantage/combo readout and hitbox display.
- Best-of-three rounds, 99-second timer, KO/timeout/draw handling, rematch,
  character/stage selection, pause/Settings/Home, configurable fighting bindings.
- Native GDScript local fixed-60 Hz authority, isolated under `godot/fighting/`.
  Integer fixed-point positions/velocities and integer frame counters. A complete
  serializable state plus input trace supports deterministic save/load replay.
  This is newly authored mode authority, not a port of nonexistent FPS rules.
- Frozen `game/`, `server/`, source locks and FPS movement/collision stay intact.
  No Node server starts for fighting. Existing FPS progress is not awarded by
  fighting results. Mode-local settings only; no global input rewrites.
- Use stock Godot 4.5.2 and Blender 4.5.14. External fighting frameworks are design
  references rather than runtime dependencies: Castagne stable targets Godot 3;
  Sakuga targets 4.7/.NET; FightEngine/Fray alpha would introduce integration cost.
- Native AnimationPlayer/AnimationLibrary and Blender-authored skeletal clips are
  the presentation pipeline. Fixed simulation owns hits, not animation callbacks.
  AnimationTree may blend locomotion if helpful, but must not advance combat time
  autonomously. No custom engine, .NET migration or additional GDExtension.
- Online/rollback requires separate later acceptance; save/load discipline now
  does not establish cross-machine determinism or shipped network play.

## Corrections to research proposals

Research move identities are inspirations, not literal FPS frame data. Do not use
52–90 m beams, 20-second ropes or raw FPS cooldowns on a ~16 m fighting stage.
Use readable startups/recoveries, bounded range and fighting-specific balancing.
The proposed RMB-tap medium / RMB-hold guard is rejected: attacks and guard must
have independent immediate controls. Shared locomotion bases must receive
operator-specific posture and timing; the research suggestion that shared clips
need no per-operator work does not meet the owner's distinctive-motion requirement.
Do not create zero-length Blender bones. Do not assume every advertised clip is
available in the free tier or import restricted/raw Mixamo files.

## Full roster and initial balance targets

These are authored initial fighting targets, not measured balance. Harnesses are
not extra fighters: nine operators, not 63 loadout variants. Preserve operator IDs.
All operators have light/medium/heavy standing, crouching and airborne normals,
forward/back normal throws, three signature specials and one super.

| ID | HP | Walk mm/tick | Weight % | Identity, signature mechanics and visual language |
|---|---:|---:|---:|---|
| chatgpt | 1000 | 52 | 100 | All-rounder; Survey Orb, bounded cable reel/pull, Adaptive Throw; teal survey brackets and articulated cable |
| claude | 1060 | 44 | 110 | Defensive footsies; ward lance, Safety Glide, timed counter-grab; salmon ceramic chevrons and layered shields |
| grok | 980 | 57 | 95 | Brawler; arcing pressure grenade, charged super-jump, Rocket Tackle; asymmetric hooks/elbows, orange piston bursts |
| meta | 1100 | 40 | 120 | Grappler; short shock cone, airborne Brace Slam, Twin Grab; deep braced poses and blue turbine sectors |
| gemini | 960 | 56 | 95 | Two-stance duelist; Rail Lance, Double Jump/band transition, Revision Grab; mirrored claw/palm vocabulary and bifurcated cream petals |
| deepseek | 1080 | 42 | 115 | Charge zoner; bounded Compute Shot, fuel-limited Hover Jets, Vessel Crush; pressure-weighted strikes and cyan compression rings |
| mistral | 920 | 62 | 85 | Rushdown; short Flak Fan, one airborne dash, Slide Takedown; swept kicks, lean guard and amber aerofoil ribbons |
| kimi | 900 | 58 | 85 | Mobile zoner; finite rail pulse, telegraphed Blink Step, Context Grab; orbital limb arcs and pink broken gimbal rings |
| qwen | 1020 | 48 | 105 | Setplay/grapple; tool pulse, bounded tether anchor, Tool Throw; grounded lamellar poses, violet segmented cable and locking glyphs |

Initial normal damage ~45–130, throws ~120–180, specials ~70–160, supers
~220–300 before scaling. Content owner defines exact authored frame data and
tradeoffs. Every fighter needs three executable example combos (basic confirm,
signature special route, corner/air route), verified against the actual simulator.
Do not call research strings valid combos until executed without hitstun gaps.

## Mechanics acceptance contract

- Startup/active/recovery in integer frames; high/mid/low/overhead/air interaction,
  high/low guard, safe guard release, whiff punishment and counter-hit feedback.
- Distinct hit/hurt/push boxes, swept projectile contacts where needed, simultaneous
  trade resolution independent of player processing order, corner pushback.
- Six-frame button buffer, directional history and configurable simple-special
  controls alongside motion inputs. SOCD: opposite horizontal/vertical neutral.
  Press edges cannot repeat while held; mirrored-facing commands and facing locks
  during committed moves are explicit. Negative edge is off initially.
- Hitstop freezes combat frame advancement coherently, preserving bounded input
  buffering. Hitstun/blockstun, cancel eligibility on hit/block/whiff, legal links,
  damage scaling floor, hitstun deterioration, juggle cap, bounce/OTG limits and
  hard knockdown/wakeup invulnerability prevent infinite or guaranteed loops.
- Projectiles have finite life/range/count, startup and recovery; clash strength,
  reflection ownership and no phantom repeated hits. Include at least one real
  reflect/counter mechanic and a meaningful projectile-grappler matchup.
- Normal throws have range, whiff recovery and a visible ten-frame tech window;
  command throws have clearly telegraphed startup/escape counterplay. Throw
  invulnerability on wakeup/hitstun prevents guaranteed throw loops. Paired actor
  placement, damage moment, break and side swap come from a shared simulation
  timeline, matched by attacker/victim animation. KO interrupts pairs cleanly.
- Meter 0–1000, super costs 1000; gaining/spending is deterministic. Character
  resources are bounded and reset on round start. Explicit durations for charge,
  stance, hover, air-dash/double-jump count, anchor and blink; no permanent traps.
- AI uses the same input commands, seeded decisions and reaction delay; no health,
  position or hidden player-input reads to win. Training resets and frame advance
  are labelled training controls, isolated from normal versus acceptance.

## Shared interfaces — owned paths and stable APIs

These names are the parallel-work contract. Additional fields must be optional
and documented. Required breaking changes need parent coordination before use.

### Simulation (Astra core owner)

`res://fighting/core/simulation.gd` extends RefCounted, class_name omitted to avoid
global-cache dependence. Public API:

```gdscript
configure(roster: Dictionary, rules: Dictionary) -> void
start_match(config: Dictionary) -> void
step(inputs: Array) -> Dictionary
snapshot() -> Dictionary
save_state() -> Dictionary
load_state(saved: Dictionary) -> void
```

`config`: `{operators:[id0,id1], stage_id:String, seed:int, training:bool}`.
`step` consumes exactly one 1/60-second tick; exactly two input dictionaries.
An input is `{axis_x:int, axis_y:int, held:int, pressed:int}`; axes -1/0/1;
buttons bit masks: L=1, M=2, H=4, SPECIAL=8, MOBILITY=16, GRAB=32,
GUARD=64, DASH=128, SUPER=256. Up axis triggers jump on rising edge; down
crouches. GRAB is normal throw; directional special+grab/command motions select
special3; simple special3 may be mapped as SPECIAL|GRAB with one input edge.
Input owner documents this in UI; core recognizer prevents double activation.

Snapshot required shape:

```text
version, tick, phase (intro|fight|round_over|match_over), round_index,
round_ticks_left, wins:[int,int], winner (-1|0|1), stage_id,
fighters:[{id:0|1, operator_id, x:int, y:int, vx:int, vy:int,
  facing:-1|1, hp:int, meter:int, state:String, move_id:String,
  move_frame:int, animation:String, animation_frame:int,
  hitstop:int, stun:int, combo_hits:int, combo_damage:int, resources:Dictionary}],
projectiles:Array, events:Array
```

Units: 1000 integer units = one metre; y=0 at feet/floor; render at
Vector3(x/1000.0,y/1000.0,0). Fighter art +X is facing right; adapter owns GLB
orientation conversion. Snapshot and saved state are deep detached copies,
JSON-safe; saved state additionally contains all input history, RNG, hit ledgers,
paired throws, cooldowns and counters needed for identical future stepping.
Events contain `{id:int,tick:int,type:String,actor:int,target:int,move_id:String,
x:int,y:int,effect:String}` plus optional damage/blocked/throw-phase fields.
Event IDs never collide inside a match; consumers reset dedup on new match.

AI: `res://fighting/core/ai.gd`, `configure(seed:int,difficulty:int)` and
`command(state:Dictionary,actor:int)->Dictionary`. Returned commands use above
schema, no mutation of snapshot. State persistence must capture AI RNG/decisions
when recording an AI-controlled session.

### Data (Sol content owner)

`res://fighting/data/roster.json`: `{version:1, operators:[...]}`. Each entry:
`{id,name,archetype,stats:{hp,walk_speed,weight,jump_velocity},resource,
moves:{move_id:move},combos:[{name,inputs:[...],notes}]}`.

Move keys are stable across fighters: `stand_l/stand_m/stand_h`,
`crouch_l/crouch_m/crouch_h`, `air_l/air_m/air_h`, `throw_f/throw_b`,
`special1/special2/special3/super`. Optional operator-specific followups and stance
variants must be explicitly listed, never silently substituted by one generic move.
Required move fields: `name,kind,startup,active,recovery,damage,hitstun,blockstun,
hitstop,level,animation,effect,hitboxes,cancels,meter_cost`.
`kind`: strike/projectile/mobility/throw/counter/super.
`level`: mid/low/overhead/unblockable.
`hitboxes`: `[{from:int,to:int,x:int,y:int,w:int,h:int}]` in fighter-facing
fixed-point coordinates, local-frame inclusive intervals; width/height positive.
`cancels`: `[{to:String,from:int,until:int,on:Array[String]}]` on hit/block/whiff.
Optional typed dictionaries: `projectile`, `movement`, `throw`, `resource_effect`,
`armor`, `stance`; core and content must document any newly needed subfields.
`rules.json` defines version/tick_rate/units_per_meter/round_seconds/rounds_to_win/
stage_half_width/seed defaults/buffer_frames/throw_tech_frames/combo limits.
Core uses tolerant optional defaults but validates required fields and rejects
unknown move mechanics instead of silently dropping operator distinctions.

### Animation/assets (Astra animation owner)

`res://fighting/visuals/fighter_visual.gd` extends Node3D:
`configure(operator_id:String)->bool`, `present(fighter:Dictionary,alpha:float)->void`,
`socket_world(name:String)->Vector3`, `reset()->void`.
No ticking authority, no autonomous combat clock. Asset availability reported
honestly; provisional fallback models are development-only, not finished animation.
Per-operator clip IDs exactly match data `animation`; universal state keys:
`idle,walk_f,walk_b,crouch,jump_rise,jump_apex,jump_fall,land,dash_f,dash_b,
guard_hi,guard_lo,hit_hi,hit_lo,hit_air,block_hi,block_lo,knockdown,wakeup,
throw_tech,win,lose`. Combat clip keys use above move IDs. Victim tracks use
`victim_<attacker_operator>_<throw_move>` with documented placement/socket rules.
One `.blend` master per operator outside `godot/`, generated GLBs under
`godot/fighting/assets/operators/<id>.glb`, manifest and frame/clip hashes beside
them. Preserve all FPS operator files and collision identities.

### Presentation FX (Sol effects owner)

`res://fighting/effects/director.gd` extends Node3D:
`configure(options:Dictionary)->void`, `consume(events:Array,fighters:Array)->void`,
`advance(delta:float)->void`, `reset()->void`.
Effects reference `<operator_id>:<move_id>` IDs. Numeric contact points in events
are authoritative; sockets may shape trails but cannot move hits. Distinct form,
motion and sound per operator, not tint-only variants. Bounded nodes/particles,
event dedup, reset/seek/pause and reduced-motion controls. No global AV hooks.

### Shell/stages/input (Sol presentation owner)

`res://fighting/main.tscn` is an in-process Home route with no authority launcher.
`res://fighting/presentation/` owns selection/HUD/training/input/camera/scene
composition. It loads the four core interfaces above; no duplicate combat rules.
Controls are keyboard/controller friendly, independent actions and device routing,
with focus/modal/device-loss release handling and per-player binding labels.
AI simulation runs only while a match is active. Scenes unload all owned resources
and resume existing Home/Settings correctly. Home hook is a separate commit.

Stage owner also owns `res://fighting/stages/`: initial targets Basalt Reach canyon,
Canopy Divide ravine and Crown Array court. Stage backgrounds reuse real native
map geometry/builders and an authored unobstructed foreground fighting platform.
No full FPS authority, actors, pickups, collision tree or expensive offscreen world
simulation. Preserve source coordinates via documented transform and asset hashes.
Choose camera-facing scenery views with distinctive landmarks; reframe/adjust
stage-only set dressing if necessary for readable side-on combat. Parallax is a
fourth candidate after final art dependency integration. Helix/Foundry can follow
their active revisions. Blood Gulch's distant phase-1 view is insufficient evidence
to prioritize it. No stage is advertised until inspected with both fighters and FX.

## Animation production and quality gates

Author all nine, with ~37 base/state/combat clips per operator plus paired victim
variants as needed. This is a coverage target, not a quality metric. First prove
Meta versus Mistral as a contrasting heavy/light vertical slice, then extend through
all nine. Every operator must have a distinct neutral stance, locomotion posture,
attack vocabulary, signature movement, throw choreography and super silhouette.
Reuse CC0 base motion only with concrete provenance; prefer free KayKit/Quaternius
downloads where their actual contents help. No paid purchase implied. Author
missing combat actions in Blender rather than silently leaving a placeholder.

Clip gates: finite valid transforms; nonzero rest bones; correct weighted rigid
body pieces; no accidental weapons; feet planted during intended contact; natural
hip/shoulder counterrotation; knees/elbows bend anatomically; attacks align with
hit-frame envelopes; victim grasps/contact and landing match throw timeline;
root locked except authored relative victim tracks; readable anticipation and
recovery; reference poses/screenshots inspected side-on at gameplay scale.
Trajectory/hash-difference tests catch identical libraries but do not certify
visual quality. Native playback and real Blender master reopen are required.

## Verification and resource schedule

No new heavy-tool grant: **Helix revision 2 still owns it**, then queued map/native
work. Research is complete; Sol/Astra code, data, recipes, source validation and
prepared native gates can proceed now. Blender/import/render/Godot/capture require
explicit serial grants with `LP_NUM_THREADS=1` and owned-process teardown.

Acceptance: required schema/roster coverage; tick-by-tick buffered input and
hit/guard/throw/projectile tests; simultaneous trades and both player orderings;
save/load input replay equality; every operator's three combos; nine mirrors plus
all 36 distinct pairings and left/right symmetry; input-only full AI rounds;
no-infinite property tests; mode UI/start/rematch/Home/focus/device tests; native
rig/clip/FX inspection for every operator; screenshots at wide and compact/UI150;
all stage cameras at max separation and jump height; low/reduced modes; exported
Windows/Linux closure. Headless/source proof does not substitute for native art,
human fighting feel/balance or real-GPU performance. Canonical/package hooks are
parent-owned and applied after the candidate has passed its focused native gates.
