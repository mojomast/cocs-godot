# Effects source gate results — 2026-10-02

Status: **READY FOR ENGINE**, source candidate only. Foundry revision 3 owns the
heavy slot; no Godot, Blender, import, renderer, playback, capture or encoder ran.

## Completed

- Node built-in test runner: **5/5 PASS**, including an explicit comparison to the
  content owner's actual `roster.json` at `827d24a8` / `79d98652`.
- Exact coverage: **138/138 attack effect IDs**, 99 named presentation cue IDs.
- All nine hue-independent authored geometry/motion fingerprints are different;
  every family contains multiple motion rules. Positions/widths/recipe lifetimes
  are source-bounded; actual generated native vertices remain pending.
- Gemini `palm_l/palm_m/palm_h` are explicitly authored broadside fan variants.
- Exact level/startup/movement/throw/counter/stance data preserved for all moves;
  renderer remains read-only and does not create independent combat timers.
- **54/54 WAV files** reproduce byte-for-byte. Header/sample-rate/mono/16-bit
  checks pass; samples start/end at zero; 54 distinct waveform hashes.
- Five GDScript files passed gdtoolkit 4.5 grammar parsing, logged separately in
  external evidence. Grammar is not engine typing.
- `git diff --check`: PASS. All changed paths are effects-owned additions.

## Measured source facts versus configured ceilings

Measured/generated: 54 WAVs total **413,172 bytes** including headers, 410,796 raw
PCM bytes; 22,050 Hz mono 16-bit PCM. Peak/RMS/duration/hash for every file and
actual aligned eight-operator super mix are recorded in `pcm-verification.json`.
Measured maximum motif peak **0.316223** (normalized amplitude); the -24 dB voice
attenuation gives a worst-case eight-voice bound **0.159619**. The actual aligned
eight-operator super PCM mix peaked at **0.084977**. These are local motif arithmetic,
not measurement of a live game's entire master bus.

Configured ceilings: low **16**, high **38**, detail **56** child nodes; respective
mesh slots **12/32/48**, ribbon segments per slot **12/24/32**, audio voices **4/6/8**.
Maximum detail triangles **3,072**, vertices **9,216**; no particles. Effects expire
within 0.72 s unless refreshed by authoritative projectile presence. ID dedup
ledger capped at 4,096. Runtime drops/peaks/node counts await the prepared gate.

## Prepared, UNRUN

- Native gate: finite sampled mesh vertices, nine native geometry fingerprints,
  palm/claw differentiation, all pool tiers/drop accounting, paused lifetime,
  arrival dedup and 4,096-ledger eviction, reset/reused IDs, reflection form and
  projectile snapshot XY/ownership/despawn, explicit anchor presence/removal,
  socket seek/facing/teleport safety,
  reduced motion and teardown ownership.
- Real fighter contact capture: **480** labelled synthetic cases, wide/compact,
  full/reduced; all nine × normal/projectile/grapple/release/super sheets prepared.
- Real simulation battle smoke: 720 input ticks for each operator against Meta,
  actual event ledger and snapshot projectiles, up to 12 captures/operator.
- Human listening/real output driver, stage depth/readability, GPU performance,
  complete executable special/throw/super route capture and export closure.

## Integration dependencies

1. Use `present_projectiles(snapshot.projectiles, snapshot.fighters)` for persistent
   flight and reflected-owner form; the director never extrapolates projectiles.
2. Reset director when starting a new match/loading a replay seek; core IDs may
   restart and old sockets must not survive. Pause through `set_paused`.
3. Current core event spellings inspected: `move_start`, `hit`, `block`, `reflect`,
   `counter`, `throw_start`, `throw_hit`, `throw_end`, empty-move `throw_tech`,
   `projectile_spawn`, `projectile_clash`, `mobility`, `anchor_end`, `jump`, `land`.
   These all resolve or intentionally consume only an explicit named cue.
4. Core owns true contact coordinates: the emerging `_emit` default is target
   chest / actor feet. Projectile clashes/reflections must emit their actual
   contact XY, projectile spawn should emit actual projectile XY, and startup
   should emit the intended telegraph location. FX faithfully displays event XY;
   it does not repair or predict those authoritative contacts with a muzzle.
5. Core must reconcile actual content optional dictionary fields from
   `CONTRACT_DETAILS.md`. Declared windows here are metadata, not authority
   substitutes. Persistent anchors/stance cues require explicit core events or
   explicit `anchor_left/anchor_x`, `stance_left`, or state-window events, not
   presentation delta guesses. `consume` uses those fields when present.

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-fighting-effects-evidence-20261002`.
See `README.md` for API details and serial-grant commands. No visual/audio quality,
performance, native runtime or gameplay-balance acceptance is claimed.
