# Fighting FX / sound — engine-ready candidate

Authoritative interface: `port/fighting/DESIGN.md` §Presentation FX. This lane
authors original fighting presentation only. Native acceptance is **UNRUN**:
Foundry revision 3 now owns the exclusive Godot/Blender/import/render/audio/ffmpeg slot.

## Inventory

- `godot/fighting/effects/director.gd`: bounded event director, pooled meshes and
  voices, authoritative contact intake, dedup, optional socket/projectile bridge.
- `godot/fighting/effects/geometry.gd`: Compatibility-safe unlit triangle ribbons;
  no particles, custom shaders, physics, animation callbacks or autonomous clock.
- `godot/fighting/assets/effects/catalog.json`: 138 exact attack IDs (15 × 9 plus
  Gemini `palm_l/palm_m/palm_h`),
  plus 99 movement/guard/tech/counter/reflect/clash/release IDs. Every ID is exactly
  `<operator_id>:<move_id>`. Move keys are the DESIGN keys, including `super`.
- 54 generated original mono PCM WAVs: each operator has attack, guard, impact,
  throw, super and tech motifs. `manifest.json` records actual byte hashes, lengths,
  duration, sample peak/RMS and generation provenance. No external assets required.
- `tools/fighting/effects/build.mjs`: deterministic geometry/audio source authoring;
  `--check` compares committed bytes rather than trusting recorded hashes.
- `tools/fighting/effects/content_contract.json`: minimal effects-only projection
  of the concrete content roster at `827d24a8` + `79d98652`, with its actual SHA-256,
  exact effect IDs/levels and declared movement/throw/counter/stance windows.
  `sync_content.mjs` refreshes it from a roster path without writing content files.
- `tools/fighting/effects/verify.test.mjs`: source coverage, structural uniqueness,
  asset reproduction, PCM/header/mix/clipping verification and authority isolation.
- Prepared native runtime gate and fighter/battle inspection scene under
  `godot/tests/fighting/effects/`. Contact-sheet composition tool under `tools/`.

| Operator | Authored form | Authored motion | Motif identity |
|---|---|---|---|
| ChatGPT | four open brackets, articulated cable | tracking contraction and reel | clear three-note survey sine |
| Claude | nested chevrons, rear plate ward | staggered forward plate settling | ceramic triangle triad |
| Grok | unequal piston rails, offset embers | sharp extension, ballistic drops | low odd-harmonic stepped piston |
| Meta | paired separated turbine sectors, brace | counterrotating inward implosion | low turbine sine triad |
| Gemini | four split asymmetric petals; broadside palm fan | interleaved opposite rotations, reversed broadside palm band | bright two-band triangle steps |
| DeepSeek | converging channels, diamond bubbles | inward compression, buoyant escape | octave pressure sine steps |
| Mistral | closed swept aerofoil, narrow ribbons | diagonal sweep and ribbon shear | high aerofoil triangle sequence |
| Kimi | four broken orbital arcs, echo line | orbital rotation and trailing echo | close-interval gimbal sine sequence |
| Qwen | gapped tether, nested lamellar locks | quantized latch, closing plate jaws | measured odd-harmonic locking sequence |

Hue-independent form/motion fingerprints are source-checked. Distinct fingerprints
and waveforms are not claims of visual quality or audible recognizability.

## Shell integration

```gdscript
var fx = preload("res://fighting/effects/director.gd").new()
arena_root.add_child(fx) # same X/Y world coordinates as fighters; identity transform
fx.configure({"quality":"high", "reduced_motion":false, "muted":false,
              "volume":1.0, "session_id":"match-1"})
# After fighter_visual.present(), once per detached snapshot / render update:
fx.consume(snapshot.events, snapshot.fighters)
fx.present_projectiles(snapshot.projectiles, snapshot.fighters) # optional
fx.present_fighter(snapshot.fighters[0], fighter_visuals[0]) # optional socket accents
fx.present_fighter(snapshot.fighters[1], fighter_visuals[1])
fx.advance(render_delta)
fx.set_paused(true) # freezes effect age, pauses existing local voices
fx.reset() # round/reset/seek: clear FX, audio, dedup and socket history; keep pool
fx.restart_session("match-2") # reconfigure explicitly for a new match/seek
# Scene teardown naturally frees director children; it never owns other AV nodes.
```

Required four API signatures match DESIGN exactly. `configure` copies options;
`consume` reads/copies detached fighter snapshots and never mutates input. Reset
retains configured bounded pool, stops voices and clears counters. Configure
replaces its pool with detached old nodes queued for free. Sockets are cosmetic,
and are sampled after animation presentation, never used to reposition impacts.
The optional socket helper emits short operator-form accents rather than a line
joining samples. It rejects >0.6 m socket jumps, backwards frame seeks, move changes,
facing flips, invalid/missing providers and sockets >3 m from actor origin.
Pass `seeking=true` on explicit seeks, and reset on round/new match.

### Event compatibility

Every source event needs DESIGN fields `id,tick,type,actor,target,move_id,x,y`.
`effect` may be supplied by core; the director resolves exact catalog IDs from the
current operator and move so reflected projectiles use the **current owner**, not
the stale original-attacker effect string. Finite integral IDs/ticks/coordinates
are validated; presentation coordinates are capped at ±100 m. Contact XY is
converted by 1000 units/metre, with mesh depth -0.06 m behind fighter hands/head
for a positive-Z shell camera. The stage foreground must not be placed ahead of
this contact plane. This depth ordering awaits native inspection on real stages.

Intake is **arrival-based**, independent of wall clock. 4096 retained IDs plus an
ID high-water floor support bounded out-of-order intake and prevent very old events
from replaying after eviction. Core IDs must remain unique/increasing over a match;
reset clears the match ledger. Unknown event types/moves are counted and ignored.
The same event cannot spawn another mesh or voice on snapshot replay.

Recognized events:

| Event types | Visual beat / sound |
|---|---|
| `move_start`, `attack_start`, `startup` | compact anticipation / attack motif |
| `hit`, `projectile_hit` | contact burst / impact |
| `counter_hit`, `counter` | rotated pressure beat / impact |
| `block`, `guard`, `guard_start` | narrow ward / defending operator guard motif |
| `projectile_spawn` | projectile-origin silhouette / attack |
| `projectile_clash`, `clash` | contact disruption / impact |
| `projectile_reflect`, `reflect` | new-owner form / impact |
| `throw_start`, `throw_grab` | paired-contact grapple beat / throw |
| `throw_hit` | damage moment / throw |
| `throw_release`, `throw_end`, `anchor_end` | dropping release beat / throw |
| `throw_tech`, `throw_break` | separating fragments / separate tech motif |
| `super` or startup with `move_id=super` | enlarged 0.72-second local form / super |
| `mobility`, `dash`, `land`, `jump` | short local movement form / attack |
| `whiff` | thin abbreviated form / silent |

Optional contact annotations: `blocked:bool`, `counter_hit:bool`,
`level:String` (`mid|low|overhead|unblockable`), `new_owner:int` on reflection.
Low uses a small white underline; overhead uses two downward white slashes;
positions remain core's contact coordinates. Without an event-level annotation,
the exact authored roster level is used. Startup cue durations use declared
startup ticks/60 (bounded 0.06..0.6 s), not a guessed move/animation delta.
The catalog preserves exact `movement`, `throw`, `counter` and `stance` windows,
including Gemini's 180-tick palm duration, Claude's counter/reflect window and
Qwen anchor lifespan. These are not additional timers or gameplay rules:
authoritative reflect/tech/release/anchor events and detached snapshot presence
determine the displayed outcome. `consume` also displays small persistent cues
from explicit `anchor_left/anchor_x` and `stance_left` fields, and a narrow ward
while authoritative `move_frame` lies inside the exact declared counter window.
Missing fields suppress persistent cues; removal closes them immediately.
This director does not extrapolate a stance/anchor timeout or counter success.
Core state events with an empty move key (`throw_tech`, `throw_break`, `land`,
`jump`, `dash`, `guard_start`) resolve their explicitly catalogued presentation
cue ID; an unknown nonempty attack key is never replaced. `throw_end` is the
core owner's release spelling. Block events use target identity; `guard_start`
uses actor identity.

Optional `present_projectiles` consumes `{id,owner,move_id,x,y}` with no movement
prediction. It refreshes finite snapshot-bound visuals, moves their origin to
authoritative XY, replaces their operator form upon ownership transfer and removes
absent entities after clash/despawn. Do not omit this bridge when a travelling
projectile should remain visible; spawn contact alone is not its flight path.
ChatGPT/Qwen `special2` events also draw a <=6.5 m articulated/gapped cable from
the current actor chest to the authoritative event point. Persistent anchors must
provide updated explicit snapshot fields; these finite effects never invent trap
life. `anchor_trigger`, `anchor_set`, `stance_change` also accept explicit events;
the supplied attack key must resolve exactly.

## Budgets and accessibility

These are **configured ceilings / mathematical bounds**, not measured GPU costs.

| Tier | Mesh slots | Segments/slot | Max vertices | Mesh triangles | Voices | Pool child nodes |
|---|---:|---:|---:|---:|---:|---:|
| low | 12 | 12 | 864 | 288 | 4 | 16 |
| high (default) | 32 | 24 | 4608 | 1536 | 6 | 38 |
| detail | 48 | 32 | 9216 | 3072 | 8 | 56 |

One mesh node/draw surface per active effect, one material shared by the director,
zero GPU/CPU particles, lights, decals, full-screen effects or camera shakes.
Finite transient lifetimes <=0.72 seconds; full pools drop new accents rather than
allocate unbounded children. Level/cable segments share the same segment cap.
Projectile refreshes are limited by the same pool. Metrics expose accepted,
duplicate/invalid/unsupported events, drops, peak occupancy and segment counts.
Stream cache is bounded by the 54 operator/role combinations (at most 410,796 PCM
bytes; WAV headers excluded). Audio cap is 4/6/8 local voices with -24 dB maximum
gain per voice; volume option can attenuate, never amplify above that bound.
No AudioServer/global bus edits, FPS threat cues, announcer, camera or haptics hooks.

Reduced-motion mode keeps the nine silhouettes and level/hit/guard/tech cues with
only 6% slow shape change. It suppresses socket accents, orbital swings and cable
bend motion; there is no shake or rapid fullscreen flash in either mode.
Readable local contact opacity/fade is retained. Runtime and real-device
performance/readability remain pending.

## Verification and serial-grant commands

Completed lightweight source checks:

```sh
node tools/fighting/effects/build.mjs --check
EFFECTS_EVIDENCE=/home/mojo/.tmp-on-disk/cocs-fighting-effects-evidence-20261002 node --test tools/fighting/effects/verify.test.mjs
```

The source coverage gate checks all **138 actual roster effect IDs** and exact
declared windows against the committed projection. With `EFFECTS_ROSTER=/path/to/roster.json`
or an integrated local roster it also checks that file's SHA and full effect coverage,
and fails on changed content until explicitly refreshed. Gemini's three palm
variants use a broadside, reversed-interleaving fan rather than silently sharing
the claw shape. Native geometry difference remains unrun.

No heavy tool was started. A lightweight gdtoolkit 4.5 grammar parser checked the
five GDScript source files; this is not Godot static-type/runtime validation.

After explicit grant, from the integrated candidate, use the stock approved Godot
4.5.2 binary as `$GODOT`, `LP_NUM_THREADS=1`, and the owner's serial launch/teardown
procedure. Never start these concurrently with Foundry or another native gate:

```sh
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/fighting/effects/runtime_gate.gd
LP_NUM_THREADS=1 "$GODOT" --path godot res://tests/fighting/effects/inspection.tscn -- --output=/home/mojo/.tmp-on-disk/cocs-fighting-effects-evidence-20261002/native
python3 tools/fighting/effects/contact_sheets.py /home/mojo/.tmp-on-disk/cocs-fighting-effects-evidence-20261002/native
LP_NUM_THREADS=1 "$GODOT" --path godot res://tests/fighting/effects/inspection.tscn -- --battle --output=/home/mojo/.tmp-on-disk/cocs-fighting-effects-evidence-20261002/battle
```

The contact fixture requires real fighter_visual assets; it refuses missing visuals
instead of presenting proxy fighters as evidence. It prepares 480 labelled synthetic
contact images: 9 operators × 13 event cases × wide/compact × full/reduced motion,
plus all three Gemini palm keys in the same four settings,
including all five required normal/projectile/grapple/release/super sheets.
`--battle` runs 720 fixed input ticks per operator against Meta and consumes actual
core events/projectiles; it records new events and at most 12 images per operator.
These inputs are a prepared smoke sequence, not proof that every special, grapple,
meter-funded super or matchup executes. The core/combo verification lane must drive
its validated routes for complete actual-move native acceptance.
Add `--sound` only under an audio grant with a real output driver and human listener.
The fixture is muted by default. No playback, recording, encoding or ffmpeg occurred.

**Still UNRUN:** Godot parsing/types/imports, native runtime gate, actual fighters
and stage depth/occlusion checks, sockets/seek/facing continuity in native playback,
wide/compact/reduced sheets, actual playing-battle event captures, human sound
listening, real output-driver mix, real-GPU frame timings and export closure.
No art, balance, listening quality or performance acceptance is claimed.
