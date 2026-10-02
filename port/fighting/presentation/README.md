# Fighting presentation candidate — READY FOR ENGINE

Owner branch: `fighting/presentation-20261002`. This is source implementation and
prepared verification, **not native gameplay/art acceptance**. No Godot process,
import, Blender, render, encode or export was run: Foundry owns the heavy slot.

## Implemented shell and exact dependencies

`godot/fighting/main.tscn` / `main.gd` is an in-process route. It directly consumes
the DESIGN.md RefCounted simulation (`configure`, `start_match`, `step`,
`snapshot`, `save_state`, `load_state`), seeded AI (`configure`, `command`),
fighter visual (`configure`, `present`, `reset`) and FX director (`configure`,
`consume`, `advance`, `reset`). Production modules/assets must be present and
fighter `configure()` must succeed. Missing resources show a visible blocker;
there is no stand-in production fighter or duplicate combat simulator.

The actual content commits `827d24a8` / `79d98652` were cherry-picked as
`59c9076e` / `b1766e00`. Menus read `roster.json` names, archetypes, stats, move
commands, descriptions, counterplay and proposed learning routes. Nine operator
entries are the roster; harnesses do not become fighters. Routes retain their
`proposed` labels until core verification. DeepSeek's 36-back-tick and Grok's
18-down-tick charge requirements are stated in selection and the move guide.
Gemini's listed stance variants appear in the move guide; HUD reads the resource
dictionary from the snapshot.

Selection offers AI/local/training, both operators, available stage candidates,
difficulty, and exact device owners. Match HUD reads HP, meter, wins, timer,
phase, combos, resources, held/edge input and defensive cues. Pause offers move
list, mode-local Settings, training, rematch, selection and Home. Training offers
dummy modes, 25/50/100% speed, neutral single-step, reset, actual-command recording
and replay, last-12-tick input history, and authored active attack-envelope lines.
Replay restores a core save, replays both recorded command arrays and resets FX
and visual dedup/timelines. Recording has no combat-state edits.

Core optional fields consumed: `fighters[].throw_tech_frames_left`,
`fighters[].hurtboxes`, `fighters[].pushboxes`, `snapshot.frame_advantage`.
Absent boxes/advantage are explicitly described as unavailable in Training.
Active attack envelopes use the content's **lower-left** rectangle convention and
authoritative move frame; they are visual guides, not a collision implementation.
Throw-event aliases currently recognized: `throw_start`, `throw_capture`,
`throw_attempt` with `target` and `tick`. **Core owner must reconcile the actual
throw capture/tech event vocabulary before native cue acceptance.** An explicit
remaining-tech-frame snapshot is preferable to elapsed tick inference.

FX configuration sent is `{reduced_motion:bool, quality:"low"|"high",session_id}`.
The concrete director from `52c74a0c` is integrated. Every accepted snapshot calls
`present_projectiles(projectiles,fighters)`: owner transfer and removal come from
snapshot presence. `present_fighter(fighter,visual)` runs after animation
presentation for optional socket accents. Modal/Settings/pause/focus paths call
`set_paused(true)` immediately, including local audio voices; resume clears it.
New match allocates/configures once with a new session ID. Round change and seek
call `reset()` and reset fighter sockets; an event tick floor excludes retained
pre-boundary contact events. Settings explicitly reconfigure once per user change
and restore pause/projectile presence without replaying old sound/contact events.
No frame/tick/snapshot loop configures or recreates the pool. Animation
is presented at exact current snapshot time (`alpha=0`); no autonomous combat
clock or camera shake is introduced. Simulation steps exactly twice-player
commands at project physics 60 Hz. AI/dummy commands use normal core input paths.

## Private input API and controls

`presentation/input_router.gd` extends RefCounted, without class_name/cache needs.
Public API: `ingest(InputEvent)`, `command(player)->Dictionary`,
`assign(player,device)->bool`, `rebind(player,action,physical_key)->bool`,
`label(player,action)->String`, `set_modal(bool)`, `release_all()`, `unplug(device)`,
`load_settings()`, `save_settings()->Error`.

`command()` returns exactly `{axis_x,axis_y,held,pressed}` and consumes queued edges
once. The C1 core derives pressed edges from **held history**, not caller hints.
A button pressed and released entirely between simulation ticks is latched into
one command's held mask, then releases on the following command. This includes
short Guard taps and pad Super chords; it does not leave Guard held indefinitely.
Modal/focus/unplug clears unconsumed latches and requires fresh physical presses.
The tech dummy emits real separated held samples rather than repeating pressed
hints while Grab remains continuously held. Pad Super keeps Mobility/Grab bits;
the core's Super-first priority owns recognition. Both opposite axes neutralize.
Up is +1; down is -1. Keyboard echo is
ignored, physical codes are used, release does not generate negative edge.
D-pad and analog sources are unioned per direction before SOCD cleaning.
Deadzone defaults to .28, configurable .20/.28/.40 in the UI (disk values .1–.8).
AI replaces only its designated command in the exact-two-element array.

No global InputMap entries are registered or changed. Keyboard defaults:

| Action | P1 | P2 |
|---|---|---|
| Movement/jump/crouch | WASD | arrows |
| Light / medium / heavy | F / G / H | J / K / L |
| Special / mobility / grab | R / T / Y | U / I / O |
| Guard / dash / super | C / V / B | N / M / P |

Special+Grab is S3; Back+Grab is back throw. The router sends the literal combined
bitmask: **core resolves S3 before Grab**. Holding that chord does not repeat its
press edge. Guard has an independent immediate button. All thirteen keyboard
actions per player are editable. Duplicate physical codes across either layout,
Esc, F12 and the console backtick are rejected. Esc cancels an active rebind.

Pad: X/Square light, Y/Triangle medium, B/Circle heavy, A/Cross special; R1 mobility,
L1 grab, L3 guard, R3 dash; L1+R1 super. D-pad/left stick moves, up jumps, down
crouches; Start pauses. L3 guard is a deliberately separate control. Each pad's
exact device ID belongs to at most one player; unassigned devices cannot fight.
Bindings UI currently edits keyboard keys; pad mapping is the documented fixed
layout. Input labels update for selected devices and edited keyboard keys.

Modal/focus/device loss empties held/edge queues and blocks active physical tokens
until release, requiring a fresh press. Device loss pauses and prevents resume
with a disconnected assigned pad. Focus loss requires explicit resume. Menu
events keep release tokens current while combat input is blocked.

`user://fighting/bindings.json` and `settings.json` are mode-local documents. Unknown
root fields survive load/save. Device IDs are selected live instead of persisted
because enumeration can change. No launcher, Node authority, client or FPS award
service is created.

## Stage composition, geometry and bounds

Every stage root is collision-free Node3D scenery, with an authored 20m × 5m flat
visual platform at y=0. Core bounds remain x ±8000mm, all fighters z=0. No full
FPS map or actor scene is instantiated and no source map/material is mutated.

For source point P and sampled source origin O, stage point is **P − O** (unit
scale, no rotation). X/Z authored coordinates and original vertex heights are
preserved. O.y is highest original terrain-triangle support at O.x/O.z, sampled
barycentrically. Whole triangles are retained only when all vertices satisfy
|P.x−O.x| ≤45 and −65 ≤P.z−O.z ≤−4. That excludes foreground terrain/trees.

| Stage | Source origin O (metres) | Terrain / GLB crop |
|---|---|---|
| Basalt Reach | (0, 1.98048, 8) | 1,936 source terrain/water triangles; native source block architecture |
| Canopy Divide | (0, 2.20671, 8) | 1,936 source terrain/water triangles; source-tree placements and actual native branching/lobed meshes |
| Crown Array | (−13.76, 71.8218246, −3.44) | 630 source terrain triangles; actual campaign prop builders and receiver GLB at its authored position/scale |
| Helix Conservatory | (0,0,18) | 33,590 accepted GLB triangles, 21 retained material surfaces; central specimen/lightwell behind a muted botanical platform and gold front inlay |

Basalt/Canopy use `biomes/map.gd` material/mesh helpers with no `build()` call.
Crown uses `campaign/terrain.gd` native material/prop helpers, `_batch(...,false)`;
only receiver mesh resources/transforms are copied. Helix copies cropped mesh
surfaces from the accepted GLB while retaining mesh materials, UV/color and node
transforms; no imported scripts, colliders, lights or FPS simulation enter the
stage. Scene resources are freed after mesh extraction. Static crop counts omit
additional Basalt/Canopy block/tree and Crown prop triangles; they are not runtime
draw-call or performance claims.

Helix pins parent art commit `c8432fcb8aad1bf9834bb80d234de14ef07da1a2`, geometry
`f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2`, GLB SHA-256
`0c462ffa475f02aa388101c38339d6d81eb3df9549a7d664ca65ec390c802d88`.
The fourth option is hidden unless both exact recipe geometry and GLB hash exist
in the integrated project. Static proof reads the accepted parent's git object
when those files have not landed in this branch. It does not select an old GLB.
Parallax remains absent.

Stage-only ambient/key lighting, rough platform surfaces, and disabled scenery
shadows target Compatibility budgets. Stage GPU cost/readability is **unmeasured**.
Source vistas and the parent's accepted architectural images do not establish
side-on fighting acceptance, particularly Crown's mixed-HUD research capture.

Camera is side-on, +Z=24 facing −Z, orthographic KEEP_HEIGHT. Normal framing now
uses actual presented skin envelopes, current positions/velocities, committed
jump/mobility startup and bounded ballistic apex prediction, plus measured HUD
regions. Tick-driven easing, landing hold and hitstop freeze avoid continuous
zoom pumping; a hard envelope fit always contains current fighters/projectiles.
Only reduced motion retains the full-arena maximum-jump reserve. Center remains
bounded x ±4m across all four existing source crops. See `CAMERA_FOLLOWUP.md` for
the precise skin-bound/projection/smoothing contracts and prepared native A/B gate.
Native silhouette scale and HUD150 fit still need direct inspection; projection
math and the existing old-camera production captures are not new-camera art proof.

## Verification and next commands

Completed: gdtoolkit 4.5 grammar parse on eight owned scripts plus the two integrated
FX scripts; exact original recipe and
accepted Helix hashes; sampled floor support; real resource crop counts; 918
camera extrema cases; source isolation checks. External evidence:
`/home/mojo/.tmp-on-disk/cocs-fighting-presentation-evidence-20261002/source-proof.json`.

Repeat source proof (no heavy tools):

```sh
PYTHONPATH=/tmp/opencode/fighting-gdtoolkit python3 tools/fighting/presentation/verify.py --evidence /home/mojo/.tmp-on-disk/cocs-fighting-presentation-evidence-20261002
```

After the parent grants the engine slot and merges actual core/animation/FX and
accepted Helix resources, run the pinned 4.5.2 binary serially with
`LP_NUM_THREADS=1` (replace `$GODOT` with the approved binary):

```sh
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/fighting/presentation/input_gate.gd
LP_NUM_THREADS=1 "$GODOT" --path godot --script res://tests/fighting/presentation/journey.gd
LP_NUM_THREADS=1 "$GODOT" --path godot res://fighting/main.tscn
```

The mapper gate uses actual InputEventKey/JoypadButton/JoypadMotion events,
including edge/held/SOCD, modal fresh-press, distinct devices, unplug, chord,
deadzone, rebind/reserved/duplicate keys, unknown-field roundtrip, short-tap held
latches/next-tick release and clear-before-consumption. **Prepared,
unrun.** `journey.gd` uses the real scene and Input.parse_input_event to navigate
selection/start/play/guard/pause/move list/Settings/focus/results/rematch/select/Home.
It uses no direct combat writes. Focus notification is a harness exercise rather
than a claimed OS focus test. It deliberately reports throw-tech and physical
unplug native acceptance as separate owner-run pending items.

See `NATIVE_JOURNEY.md` for the OS-window/controller journey, training stepping,
four-stage/two-actor screenshots and performance evidence. No export is scheduled
while Foundry owns the slot.
