# COCS Fighting Mode — Engine Mechanics Research

Status: **research only.** No code, no engine grant, no asset import, no Blender.
This document prepares a local, complete fighting mode; it does not implement one.

- Worktree: `/home/mojo/.tmp-on-disk/cocs-fighting-research-engine-20261002`
- Branch: `fighting/research-engine-20261002`
- Base commit: `ffcd7216edb70e2cbc7bb87e8c9e2c2013f92012`
- Frozen source identity: `source_commit = 515daf07589150dd3241f4ae1425cc1b093912f5`
  (`port/contracts/source-lock.json`), audited lineage merge base `e79fcc04`.
- Access date for every URL below: **2026-10-02**.

Observation labels used throughout:

- **Observed** — read directly from a repository file or a fetched primary source.
- **Assumption** — an inference or design choice, not verified in a source.
- **Proposed** — a recommendation for the future implementation, not yet built.

Scope of the eventual work (per the task): **local 1v1 vs AI + local versus/training,
all operators, complete playability.** Online/rollback is *phase 2* and is explicitly
not promised now. This document refuses "fake netplay" (see §7).

---

## 1. Local audit — what already exists and is frozen

### 1.1 The Godot project

**Observed** (`godot/project.godot`):

- `config_version=5`
- `config/features=PackedStringArray("4.5", "GL Compatibility")`
- `renderer/rendering_method="gl_compatibility"`
- Main scene `res://main.tscn` → `world/viewer.gd`.
- 684 `.gd` files; **no** `.gdextension` file anywhere in the repository.

`port/contracts/source-lock.json` pins `godot_version = 4.5.2.stable.official.6ce3de25a`.
`port/contracts/CONTRACT.md` states: Godot 4.5.2 stable official, Compatibility renderer,
**typed GDScript**, one source unit = one metre, `+Y` up, `-Z` forward, and authoritative
support is terrain triangles rather than sampled height.

### 1.2 The frozen Node authority

**Observed** (`docs/ARCHITECTURE.md`, `docs/SYSTEMS.md`, `game/core.mjs`, `server/room.mjs`):

- `game/core.mjs` `class Match` is the single authoritative simulation entry point:
  `Match.step(dt, inputs)`.
- `RULES.dt` in `game/data.mjs` is `1/60`; the whole stack runs a **fixed 60 Hz** step.
- `server/room.mjs` accumulates real time and runs at most 5 `RULES.dt` sub-steps per
  call (`while (this.tickAcc >= RULES.dt && steps < 5)`).
- Randomness is **injected**: `new Match(character, harness, random, mapId, options)`.
  A seeded generator produces byte-identical traces. `game/net.mjs` `NetHarness` uses a
  deterministic LCG so prediction/reconciliation can be asserted frame-for-frame.
- The renderer is never authoritative: `game/view.mjs` reads snapshots only.

**Observed** (`port/contracts/protocol.json`): protocol version 3, simulation 60 Hz,
snapshots 30 Hz, **`prediction: false`**, advertised delta 0.

**Observed** (`port/contracts/CONTRACT.md`): wire is protocol-3 JSON text WebSocket frames;
60 Hz simulation, 30 Hz snapshots; actor identity comes from `lobby.players[].actorId`;
validation fails closed; and, verbatim, *"Shared game/server files remain unchanged"* and
*"existing source gameplay, dependencies and nine-map source lock remain unchanged."*

### 1.3 The Godot port is a client, not a simulator

**Observed** (`godot/net/client.gd`, `godot/player_gameplay/session_binding.gd`,
`godot/player_gameplay/status.gd`):

- `PortNetwork` connects a `WebSocketPeer`, speaks protocol 3, tracks `snapshot` / `events`
  / `results`, and exposes lobby/start/state verbs. It does **not** simulate.
- `session_binding.gd` consumes `session.client.snapshot` and `...events` and projects a
  read-only status model. Its own comment: *"Read-only public snapshot projection. Timers
  are never predicted locally."*
- There is **no JS bridge and no GDExtension**. `grep` for `JavaScriptBridge`/`JavaScript`
  in `godot/**/*.gd` finds only unrelated hits (`social_model.gd`, `practice.gd`,
  `projectiles.gd`, `zone_modes/variants.gd`, `weather_service.gd`), none of which embed
  or run the Node engine.

**Assumption (strong):** the native port deliberately re-presents authoritative Node
state; it is not a second simulation. Any new fighting simulation is therefore a *new
kind* of authority and must be isolated from the frozen Node core.

### 1.4 Roster and operator assets (for the roster lane, noted not owned here)

**Observed** (`game/data.mjs`): nine characters —
`chatgpt, claude, grok, meta, gemini, deepseek, mistral, kimi, qwen` — and seven
harnesses — `openclaw, hermes, opencode, claudecode, codex, cline, roo`.
**Observed**: `godot/source_operators/generated/` contains per-operator `.glb` plus
`catalog.gd`. The engine lane depends on that catalog; the roster lane owns its content.

### 1.5 Verification pattern to reuse

**Observed** (`tools/godot-dev/verify.py`, `docs/TESTING.md`):

- Primary test runner is Node's built-in `node:test` (`game/*.test.mjs`, `server/*.test.mjs`).
- Godot headless gates are registered and run through `tools/godot-dev/gate_runner.py`
  and aggregated into `port/reports/verification.json`.
- The aggregate explicitly lists manual acceptance as *"owner-run / unrun"*; headless
  gates do **not** establish graphical acceptance.

**Proposed:** a fighting mode reuses exactly this shape — a pure-data Node test lane plus a
Godot headless deterministic-trace gate, with manual play declared separately.

**Frozen-core rule derived for this work (Proposed):** do not edit `game/core.mjs`,
`game/data.mjs`, `server/**`, `game/protocol.mjs`, or the source-lock/map allowlists.
New fighting code lives under new paths only, and `source_commit` stays `515daf07…`.

---

## 2. External engines and frameworks (primary sources)

Findings are the **state on 2026-10-02**, not marketing claims.

### 2.1 Castagne

Sources: <https://github.com/panthavma/castagne> ·
<https://api.github.com/repos/panthavma/castagne> ·
<https://raw.githubusercontent.com/panthavma/castagne/main/LICENSE.md> ·
<https://api.github.com/repos/panthavma/castagne/releases> ·
<https://castagneengine.com/docs/> ·
<https://castagneengine.com/docs/index/online> ·
<https://castagneengine.com/docs/index/full-feature-list> ·
<https://castagneengine.com/articles/roadmap2025>.

**Observed facts:**

- Repository: `panthavma/castagne`, language **GDScript**, 153 stars, 22 forks,
  `archived: false`, created 2021-12-10, last push **2026-07-28**.
- License: root `LICENSE.md` is **Mozilla Public License 2.0**. GitHub metadata reports
  license as `Other`/`NOASSERTION` because assets and `external/` differ. README says, as a
  simplified explanation: *"You must say that Castagne was used in the game"* and *"If you
  modified Castagne, you must redistribute the modified source files"*; contributors release
  contributions under MIT for merge.
- Tags: `v0.58`, `v0.54.21`, `v0.54.20`, `v0.53.2`, `v0.5`, `v0.4-preview`.
- The latest release, **v0.58, is named "v0.58 (Godot 3 Final Update)"** (published
  2026-07-28). The docs site labels its online page *"In construction!"* and says the online
  feature *"is set to be completed for Castagne v0.8"*, while the docs index advertises
  *"Rollback netcode working out of the box."*
- The 2025 roadmap article (published **2025-08-10**) is candid: *"the v0.5x cycle, which is
  finishing up soon and will be the last Godot 3 version"*; *"v0.58: Bugfixing update before
  starting the v0.6x cycle. This is the last update I will really work on for Godot 3."*
  It lists weaknesses including *"rollback not really being there"* and *"godot 3"*, and
  plans the Godot 4 passage as **v0.60**, with rollback only in the third phase
  (roughly Q2–Q3 2026, explicitly non-contractual).
- The full-feature page observed on 2026-10-02 lists the supported game type as
  **"2.5D Fighters"** only.

**Conclusion (Observed + Assumption):** Castagne is a mature 2.5D fighting *design*, but on
2026-10-02 the published engine is **Godot 3 only**, with the Godot 4 build unreleased and
rollback unscheduled on stable output. It is **not Godot 4.5-compatible today**.

### 2.2 Sakuga Engine

Sources: <https://github.com/NoisyChain/Sakuga-Engine> ·
<https://api.github.com/repos/NoisyChain/Sakuga-Engine> ·
<https://raw.githubusercontent.com/NoisyChain/Sakuga-Engine/main/README.md>.

**Observed facts:**

- Godot-4 fighting engine written **in C#**, MIT, 244 stars, 34 forks, created 2024-06-01,
  last push 2026-08-01, topics include `rollback-netcode`.
- README: *"Currently using Godot 4.7 .NET"*; *"Made completely in C#"*; *"Sakuga Engine
  is only for 2D traditional fighting games"*; *"only for 1v1 games at the moment"*.
- Included features (per README): 2D 1v1 anime-style, rollback netcode out of the box,
  3D sprites/models support, robust state system, stances, projectiles, pseudorandom number
  generator, game modes, **experimental AI**, an example character. Puppets/cinematics are
  listed as future.

**Conclusion:** the closest *living* Godot-4 fighting engine, but it requires the **.NET
build and C#**, targets a newer Godot than 4.5, and is a whole-project engine rather than a
layer over the existing COCS operator/asset pipeline.

### 2.3 Fxll3n's Fight Engine

Sources: <https://api.github.com/repos/Fxll3n/FightEngine> ·
<https://raw.githubusercontent.com/Fxll3n/FightEngine/main/README.md> ·
<https://godotengine.org/asset-library/asset/4674>.

**Observed facts:**

- `Fxll3n/FightEngine`, **GDScript**, MIT, 24 stars, 1 fork, created 2026-01-06, last push
  **2026-02-04**, repo updated 2026-09-11. Asset Library entry: *"Fxll3n's Fight Engine
  v0.0.2-Alpha"*, *"A comprehensive Godot 4.5 plugin for creating 2D fighting games with
  precision and ease"*, MIT, submitted 2026-01-20.
- README: provides `HitBox2D` and `HurtBox2D` collision nodes that *"automatically filter
  irrelevant collisions"*; an **animation-driven** attack model where `AnimationPlayer`
  keyframes move/activate hitboxes and hurtboxes; recommends Max FPS 60; **demo state
  machine uses LimboAI** (a separate GDExtension).

**Conclusion:** directly targets Godot 4.5 and GDScript, but is a very early alpha, thin,
and stale for ~8 months. Useful as a **code reference** for hitbox/hurtbox node shape, not
as a dependency (it would also drag in LimboAI, a GDExtension this repo deliberately lacks).

### 2.4 Rollback tooling (phase 2 only)

Sources: <https://gitlab.com/snopek-games/godot-rollback-netcode> ·
<https://github.com/blast-harbour/Godot-Rollback-Fighter-Demo> ·
<https://api.github.com/repos/blast-harbour/Godot-Rollback-Fighter-Demo>.

**Observed facts:**

- *Godot Rollback Netcode* (David Snopek), **MIT**. Core `SyncManager` singleton; per-node
  virtual methods `_save_state()`, `_load_state(state)`, `_interpolate_state(old,new,w)`,
  `_get_local_input()`, `_predict_remote_input(prev, ticks_since)`, `_network_process(input)`;
  rollback-aware nodes `NetworkTimer`, `NetworkAnimationPlayer`,
  `NetworkRandomNumberGenerator`; project settings include Max Buffer Size, Input Delay,
  Interpolation; replaceable `NetworkAdaptor`, `MessageSerializer`, `HashSerializer`; a
  built-in **Log Inspector** for state/input mismatch debugging.
- *Godot Rollback Fighter Demo* (blast-harbour), MIT, GDScript, 56 stars, created
  2024-06-21, last push **2024-07-10** (stale). It builds on **Bimdav's "Delta Rollback"**
  (a C++ GDExtension fork of Snopek's addon) plus **SG Physics 2D**, on **Godot 4.2.2**.
  Features observed: a `FightManager` node ordering all gameplay callbacks; a node-based
  state machine; an input system with a command buffer for motion inputs; fighter push
  interactions; hitbox/hurtbox behaviors for on-block/on-hit/on-air-hit; high/low blocking;
  projectiles; health bars and round restart — all under rollback.

**Conclusion:** the rollback *addon* is the credible phase-2 netplay path, and its
save/load-state discipline should be designed in from day 1 even if never enabled locally.
The demo is an excellent **reference** for feature decomposition but is stale relative to
Godot 4.5.

### 2.5 Godot 4.5 fixed-tick and presentation contract

Source: <https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/index.html> ·
<https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/physics_interpolation_introduction.html> ·
<https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/using_physics_interpolation.html>.

**Observed quotes/facts:**

- Physics runs at a fixed tick rate (*"defaults to 60 ticks per second"*) decoupled from
  rendered frames.
- The recommended smoothing is fixed-timestep interpolation: keep current **and previous**
  transforms and interpolate with the fraction from
  `Engine.get_physics_interpolation_fraction()`. This introduces a small, deliberate
  display delay (renders *between* one and two ticks in the past).
- *"Move (almost) all game logic from `_process` to `_physics_process`"*; setting an
  interpolated object's transform outside the physics tick causes jitter. Teleports should
  call `reset_physics_interpolation()`.
- The docs explicitly warn: *"An example category is internet multiplayer games. Multiplayer
  games often receive tick or timing based information from other players or a server and
  these may not coincide with local physics ticks, so a custom interpolation technique can
  often be a better fit."*

### 2.6 Rollback vs delay-based (context)

Sources: <https://en.wikipedia.org/wiki/Netcode> · <https://en.wikipedia.org/wiki/Fighting_game>.

**Observed:** rollback runs local input immediately and predicts remote input; on a wrong
prediction the state is reverted and re-simulated. Delay-based netcode delays local input to
match the remote. Rollback *"requires the game engine to be able to turn back its state"*
and is associated with **GGPO**, an MIT-licensed library. Fighting matches are typically a
set number of **rounds** (commonly best-of-three) with health bars; throws/grappling bypass
blocking and projectiles are a 2D staple.

---

## 3. Mechanics reference — exact definitions (Infil glossary)

Canonical community glossary, fetched as JSON:
<https://glossary.infil.net/> → <https://glossary.infil.net/json/glossary.json>
(accessed 2026-10-02; the site reports *"over 800 fighting game terms"*).

These are the observed definitions the eventual design must honour. Quoted/paraphrased:

| Term | Observed definition (abridged) |
| --- | --- |
| **Frame data** | The startup, active and recovery frames of each move, the frame advantage on hit/block, damage, and special properties. The two most important numbers are startup and safety-on-block. |
| **Startup** | Time after pressing the button before the attack can contact; measured in frames; the "windup". |
| **Active frames** | The period a hitbox is present; *"the active period of a move is defined to be when a hitbox is present (there are no hitboxes during a move's startup or recovery)."* |
| **Recovery** | Time after the attack finishes hitting (or whiffs) before control returns. |
| **Frame advantage** | Who recovers first when a move hits/is blocked; being "+" means you recover first. |
| **Hit stop** | *"An extremely brief moment where the game pauses… whenever an attack successfully hits."* Exists *outside* startup/active/recovery; the blocked analogue is **blockstop**. |
| **Hit stun** | Time the character cannot act after being hit; combos exist because a new hit lands while still in hit stun. |
| **Block stun** | Time the character cannot act after blocking; consecutive attacks with no gap are a block string. |
| **Buffer window** | A time window in which an input is accepted and then applied on the first legal frame (e.g. a reversal buffered before wakeup). |
| **SOCD** | *"Simultaneous Opposite Cardinal Directions."* Left+right or up+down on leverless controllers; the game must define a policy (neutral, last-wins, first-wins) because each choice changes shortcuts and charge behaviour. |
| **Cancel** | Removing recovery to transition into another move (normal → special, "2-in-1"), notated `xx`. |
| **Chain** | Canceling a light normal into another light normal. |
| **Link** | Two moves combo by letting the first fully finish (including recovery) before the second starts; requires the first to be plus on hit by at least the second's startup. |
| **Combo** | A sequence that is unavoidable once the first hit lands (the next hit occurs while still in hit stun). |
| **Hitbox** | Invisible area that defines how an attack contacts a character; its size defines range. |
| **Hurtbox** | Area that defines how a character is allowed to be hit; a separate hurtbox commonly indicates where throws can connect. |
| **Pushbox** | Non-overlapping collision volume; walking into the opponent pushes them. |
| **Cross-up** | Attacking immediately after changing which side you face, usually after jumping over; forces the defender to switch block direction. |
| **Juggle** | Comboming an airborne opponent while grounded. |
| **Air combo** | Comboming an airborne opponent while also airborne. |
| **Damage scaling** | Damage reduced per hit as a combo lengthens, to a minimum; related to per-move **proration**. |
| **Gravity scaling** | The juggled character falls faster as the combo lengthens, ending it; used to prevent infinites. |
| **Hit stun deterioration** | Hit stun decreases as a combo lengthens until the victim can recover. |
| **Infinite** | An unbounded combo; anti-infinite systems (scaling, deterioration, gravity scaling, burst) exist to stop it. |
| **Meter / super meter** | A resource built by playing and spent on EX/super moves; measured in bars. |
| **Super** | A strong, often cinematic attack costing meter; supers have levels. |
| **Projectile** | An attack that travels independently and has no hurtbox; opposing projectiles usually destroy each other; some moves turn projectile-invincible. |
| **Clash** | Two hitboxes overlap on the same frame without colliding with a hurtbox (distinct from a **trade**, where both hit hurtboxes). |
| **Reflect** | A defensive mechanic that pushes the opponent away when a parry succeeds (DBFZ), cancellable into attacks. |
| **Cooldown** | A move cannot be used for a set time after use; uncommon historically, tried in Rising Thunder / GBVS / MK11. |
| **Throw** | A fast close-range move that cannot be blocked; defended by a throw tech, beating by jumping or invincibility. |
| **Throw tech** | Pressing the throw input as the opponent throws; both are pushed apart; also "throw break"/"throw escape", sometimes with a delayed-tech window. |
| **Round** | Play until one health bar is depleted; most games reset positions and health each round and require multiple round wins. |
| **Counter hit** | Hitting someone during their attack startup; usually more damage/frame advantage. |
| **Mixup / 50-50** | Multiple attacks requiring different defenses; the defender must guess. |
| **Reversal** | An attack on the first legal frame after a state that forbade attacking; often invincible. |
| **Okizeme / wakeup / meaty** | Offense against a knocked-down opponent / the defender's rise / an attack hitting exactly on the first rise frame. |
| **Armor** | Absorb a hit without entering hit stun; can often be thrown or broken. |
| **Reset / proration / hit confirm / whiff** | Standard combo and risk vocabulary. |

**Assumption:** a COCS fighting mode should implement the *subset* that makes a complete
local game (frame data, buffers, cancels, stun/hitstop, blocking, throws/tech, projectiles,
meter, rounds, training), and use the anti-infinite terms (scaling / deterioration /
gravity) as the design controls against unbounded combos.

---

## 4. Mechanics model (Proposed)

### 4.1 Time and units

- **1 frame = 1/60 s.** The simulation advances one integer tick per step; all durations are
  stored as integer frame counts and converted to seconds only at the simulation boundary
  (`dt = 1/60`), mirroring the existing `RULES.dt` convention.
- The Godot project's physics tick stays 60; `Engine.get_physics_interpolation_fraction()`
  drives presentation-only interpolation (§6.4). Gameplay never reads wall-clock time.
- **Hitstop** is a counter on both fighters (or globally) that pauses *advancement of the
  move timeline and physics* while the tick counter still advances. It is not a `time_scale`
  change, so frame counts stay exact and determinism is preserved.

### 4.2 Input

- **Canonical command** (serializable, fixed size):
  `{ tick:u32, seq:u32, buttons:u16, x:i8, y:i8 }` where `x,y ∈ {-1,0,1}` are already
  SOCD-cleaned. Buttons: light, medium, heavy, special, throw, meter, guard, start.
- **SOCD policy (Proposed):** left+right = neutral, up+down = up (classic leverless
  convention). Record the policy in the match config so a replay is self-describing. Cite
  glossary SOCD for why this must be explicit.
- **Buffer:** a short ring buffer (default 6–8 frames) stores the raw command history.
  Motion recognition (quarter-circle, dragon-punch, charge) reads the buffer and emits a
  resolved special; a separate "buffer window" applies a pending input on the first legal
  frame (e.g. reversal, wakeup). Negative edge (release to trigger) is a configurable input
  leniency flag.
- **Devices:** keyboard and gamepad both map to the same canonical command; gamepad axes
  are quantized to `{-1,0,1}` before the buffer so keyboard and pad produce identical
  commands.

### 4.3 Fighter state machine

Per fighter, an explicit state machine with integer frame counters:

- **Common states:** idle, walk-fwd/back, crouch, jump (prejump/air/landing),
  dash (fwd/back), block (stand/crouch/air), hitstun, blockstun, hitstop, knockdown,
  wakeup, throw-start/throw-execute/throw-tech, stunned, KO, round-intro/round-out.
- **Move states** carry `startup`, `active`, `recovery`, each with hitbox/hurtbox frame
  windows. Active is exactly the union of frames where a hitbox is enabled (glossary).
- **Cancels** are an explicit directed graph authored per move: `cancel_into` lists
  `{target, from_window, requires: hit|block|whiff|any, cost}`. Links are *not* graph edges;
  they fall out of frame advantage + hitstun (glossary).
- **Priority order per tick:** hitstop → stun timers → input resolve → state transition →
  movement/push → collision → hit resolution → events. This order is fixed and unit-tested.

### 4.4 Collision and the 2.5D axis

- Gameplay happens on a **2D plane**: `x` lateral, `y` vertical, `z` is a **fixed stage
  depth** for all gameplay boxes. 3D operator meshes and camera are presentation only.
  Boxes are stage-local AABBs (`x,y,w,h`) plus an authored `z_offset` used only for draw
  order / camera framing. This is the "2.5D" interpretation Castagne's own feature page
  lists, and it matches COCS's 3D operators rendered from a side camera.
- **Hit detection is computed by the fighting simulation**, not by Godot's physics server:
  simple AABB overlap against enabled hitbox/hurtbox windows, with optional circle
  approximations for throw/projectile checks. Godot physics is used only for cosmetic
  ragdolls/particles. This keeps collision deterministic and rollback-safe.
- **Pushboxes** keep fighters from overlapping; they also define corner behaviour (§4.7).
  Throws read a dedicated **throwbox** (the glossary notes throws may use a second
  hurtbox).
- If a true 3D-axis (side-step) variant is ever wanted, it is a separate product decision
  and out of scope for this local mode.

### 4.5 Offense / defense lattice

- **Blocking:** hold back; high/low/overhead distinguish stand vs crouch block; air block is
  configurable (default off, as in many games) and must be explicit. Chip damage is a
  per-move field.
- **Throws/grapples:** uncatchable by block, with a **throw tech window** (e.g. 2–3 frames
  after the throw connects) and **throw invulnerability** frames after wakeup/tech to stop
  true throw loops. Command throws differ from normal throws only by data (untechable flag,
  damage, range).
- **Projectiles:** owned entities with position/velocity/frames/lifetime, a hitbox, no
  hurtbox; projectile-vs-projectile **clash** destroys both (or a per-move clash level);
  optional **reflect** window redirects ownership. Projectiles have spawn cost/cooldown.
- **Clash/trade:** equal-priority hitboxes overlapping without a hurtbox produce a clash
  (both moves cancel or bounce); simultaneous hurtbox contacts are a trade (both take
  damage). Represent both as events so presentation can react.
- **Meter:** gain on dealing/taking/blocking (per-move rates), spend on EX/super; all
  rates and costs are data.

### 4.6 Anti-infinite systems

- **Damage scaling:** per-combo multiplier curve from a config table; per-move
  **proration** multiplier.
- **Hit stun deterioration** and **gravity scaling:** per-combo counters that shorten hit
  stun and increase fall speed; both are configurable and can be disabled in training.
- **Juggle limit:** each launch/hit assigns a juggle cost; a per-combo budget bounds air
  combos. All counters reset on neutral/wakeup as configured.
- These are the primary levers; a **burst/escape** move is optional and, if added, must be
  authored as data with its own gauge.

### 4.7 Movement, wall and corner

- Walk/dash/jump with quantized input; dash has startup and is block-disabled (glossary).
- **Pushboxes** resolve overlap; the stage's left/right bounds (existing arena geometry) act
  as walls. Corner pressure emerges from pushbox + wall, so no special corner code is
  needed beyond bounds. **Cross-up** is emergent from facing + jump arcs, but the facing
  update must be explicit and frame-stable.
- Wall bounce / ground bounce are per-move data (launch type) and must respect juggle
  budget and scaling.

### 4.8 Match flow, AI, training

- **Rounds:** best-of-three default; KO, time-over (higher health wins), double-KO draw;
  positions and health reset per round. A match is a small explicit state machine:
  intro → fight → round-end → next-round/match-end → rematch.
- **AI:** a deterministic policy that reads only the same observation a human sees
  (positions, states, frame counters, health/meter) and emits canonical `InputCommand`s
  through the same input buffer. It must use an injected seeded RNG. No hidden state, so AI
  matches are reproducible and testable. Suggested tiers: dummy (stand/crouch/block/tech),
  easy/medium/hard (reaction windows, wakeup choices, anti-air/anti-projectile), all as
  data-configured policy parameters.
- **Training:** record/replay input, hitbox/hurtbox/pushbox display from the same box data,
  frame step, dummy behaviours (stand/crouch/block/guard-switch/CPU/reversal), damage and
  hitstun readout, infinite-prevention toggles, and input-display/buffer visualization.

---

## 5. Architecture options and recommendation

### 5.1 The decision

Two structural options were on the table; the recommendation is explicit.

**Option A — Godot-native standalone deterministic fighting core (RECOMMENDED for phase 1).**
The fighting simulation lives entirely in Godot, under new paths (e.g. `godot/fighting/**`
and `port/fighting/**`), and is local-only. It reuses the existing operator GLBs,
`source_operators/generated/catalog.gd`, and the rig/animation presentation lane. It never
edits `game/core.mjs`, `game/data.mjs`, `server/**`, or `game/protocol.mjs`.

**Option B — Node extension / isolated port authority (DEFER to phase 2).**
Implement the fighting simulation as an *additive* module on the Node authority
(new files, new protocol verbs) so two clients could fight through the existing
`Room`/`Match` machinery. This crosses the frozen boundary: `CONTRACT.md` says shared
game/server files remain unchanged and protocol is v3. Adding this now would require either
editing frozen files or introducing a parallel protocol version, and it would tempt the team
into shipping an unfinished online promise.

### 5.2 Why A for phase 1

- The existing Godot client is presentation-only with `prediction: false`; the frozen
  protocol has no fighting vocabulary. Option A ships a *complete local game* without
  touching any frozen file.
- Determinism is far easier to guarantee inside one codebase than across a Node↔Godot
  boundary that today has no shared simulation.
- Option A still buys Option B later: if the core is fixed-60, seeded, serializable and
  engine-physics-free (§6.3), the same rules can be driven by the rollback addon P2P, or
  ported to the Node authority as an isolated module, without redesign.

### 5.3 Acceleration options — adopt/reject

| Option | Verdict | Precise reason |
| --- | --- | --- |
| **Castagne** (panthavma/castagne) | **REJECT as engine; reference only** | Main is Godot 3: v0.58 is literally named "Godot 3 Final Update" (2026-07-28); Godot 4 passage is the unreleased v0.60; rollback is phase 3. MPL 2.0 imposes attribution + redistribution of *modified* source files. Adopting it would replace the repo architecture and still not meet Godot 4.5 today. Its move/module/state-model documentation is worth reading. |
| **Sakuga Engine** (NoisyChain/Sakuga-Engine) | **REJECT as engine** | Requires C#/.NET, README says "Currently using Godot 4.7 .NET"; repo is Godot 4.5.2 Compatibility typed GDScript with no GDExtension. It is a whole 2D-1v1 engine that bypasses the existing operator/asset pipeline. MIT makes it forkable later if that trade ever changes. |
| **Fxll3n's Fight Engine** | **PARTIAL: reference/possible vendored helper** | Godot 4.5 + GDScript + MIT, directly on target. But v0.0.2-alpha, 24 stars, last push 2026-02-04 (stale), and its demo pulls in LimboAI (GDExtension the repo deliberately lacks). Read its `HitBox2D`/`HurtBox2D` shape; do not depend on it for core logic. |
| **Godot Rollback Netcode (Snopek) / Delta Rollback** | **ADOPT for phase 2 only** | MIT; purpose-built save/load-state rollback with `NetworkTimer`/`NetworkAnimationPlayer`/`NetworkRandomNumberGenerator` and a log inspector. Correct phase-2 netplay path for P2P. Not phase 1; the frozen protocol is WebSocket/JSON to a Node authority, so a P2P rollback transport is a separate decision. |
| **Node authority extension (Option B)** | **DEFER to phase 2** | Would need new protocol verbs / server routes; violates the "shared game/server files unchanged" contract unless done as a fully additive protocol version. Only pursue if online is a real, funded milestone. |
| **Custom Godot-native core (Option A)** | **ADOPT** | Fully under our control, no license entanglement, reuses the existing operator/rig/animation work, and satisfies the frozen-core rule by construction. |

**"Don't modify core" is a hard rule for this plan.** The only acceptable phase-1 footprint
outside `godot/fighting/**` and `port/fighting/**` is new menu routing/registration and new
test/gate registration, and even those should be additive.

---

## 6. Interfaces and data formats (Proposed)

Authoring follows the repo's JSON-catalog pattern (`player_gameplay/catalog.json`,
`player_models/recipes.json`, `ui/routes.json`) and keeps schemas versioned.

### 6.1 Frame-data schema (JSON, `schema_version: 1`)

```
fighter:   { id, display_name, source_operator, skeleton, stats{ health, walk_fwd, walk_back,
             dash, jump, weight }, palette, moves[], supers[], throws[] }
move:      { id, name, kind: normal|special|super|projectile|throw,
             input: { motion, button, charge_frames },
             startup, active, recovery, hitstop, hitstun, blockstun,
             guard: high|low|overhead|unblockable|throw,
             damage, chip, hitstun_deterioration, proration, juggle_cost, juggle_start,
             knockback{ x, y }, launch: none|ground|wall, meter_gain, meter_cost,
             cancel_into: [ { target, from: startup|active|recovery, requires: hit|block|whiff|any } ],
             boxes: { hit: [ { from, to, x, y, w, h } ],
                      hurt: [ { from, to, x, y, w, h } ] } }
system:    { scaling_curve[], gravity_scaling[], hitstun_deterioration[], throw_tech_window,
             throw_invuln_frames, pushbox{ w, h }, round{ count, time_frames }, meter{ rates... } }
stage:     { id, arena_id, bounds{ min_x, max_x }, wall{ left, right }, camera }
```

Invariants validated by a Node test (like `semantic.test.mjs`): `startup ≥ 1`, `active ≥ 1`,
`recovery ≥ 0`; every `cancel_into.target` resolves; the cancel graph has no cycle that
skips a hit; every move is reachable from at least one input; box windows lie within
`startup+active+recovery`; damage/scaling/juggle fields are finite and non-negative.

### 6.2 Runtime types

- **`InputCommand`** — §4.2. Append-only per tick; what replays store.
- **`FighterState`** — every field serializable to primitives for rollback:
  `{ tick, x, y, z, vx, vy, facing, state, state_frame, move_id, move_frame,
     health, meter, hitstop, hitstun, blockstun, guard, combo_hits, juggle_budget,
     scaling, throw_state, rng_state, stun }`.
- **`ProjectileState`** — `{ id, owner, move_id, x, y, vx, vy, frame, lifetime, clash_level }`.
- **`StateEvent`** — `{ tick, serial, type, actor, ...data }`, append-only, capped (mirroring
  `Match.emit`'s capped event buffer), never read as authority by presentation.
- **`MatchSnapshot`** — a detached read-only projection: round/phase, timer, both
  `FighterState`s, projectiles, combo/scaling readouts, and an input/command log id.

### 6.3 Determinism / rollback readiness contract (applies in phase 1)

- No Godot physics for gameplay; no `randf()` in the sim; one injected seeded RNG whose
  state is serialized each tick.
- No wall-clock reads, no `_process` mutation of gameplay state; all stepping in the fixed
  tick. Ordering of iteration is stable (arrays, not dictionary order, where order affects
  results).
- `save_state()` / `load_state()` exist from day 1 and are exercised by a test even though
  no netcode uses them yet. **Assumption to verify:** GDScript 64-bit float arithmetic is
  identical on one machine/build; cross-platform float identity is a phase-2 risk (§8).

### 6.4 Render/animation frame contract

- **Simulation:** integer tick, 60 Hz.
- **Presentation:** once per rendered frame, read the two most recent authoritative
  snapshots and interpolate with `Engine.get_physics_interpolation_fraction()` (Godot 4.5
  docs) or a custom render delay for a networked variant (docs explicitly recommend custom
  interpolation for netplay). Presentation never writes simulation state.
- **Animation:** `AnimationPlayer` is advanced by **frame count / a tick-driven clock**, not
  by wall time, so hitstop and rollback re-execution stay coherent. This mirrors
  `NetworkAnimationPlayer`'s design (Snopek addon) and the Fxll3n animation-driven hitbox
  approach.
- **Events:** hitstop shake, hit spark, SFX, camera, and announcer consume `StateEvent`s
  once; they are presentation-only and never gate simulation.
- **Debug:** a development overlay can draw hitbox/hurtbox/pushbox from the same authored
  data used by collision, guaranteeing the debug view tells the truth.

### 6.5 Meaningful verification

- **Node lane:** JSON frame-data schema/invariant tests (§6.1). Pure, fast, runs in the
  existing `node:test` harness.
- **Godot headless lane:** a deterministic trace gate — feed a committed `InputCommand`
  log, run K ticks, hash the `FighterState`/`StateEvent` stream, and compare to a committed
  golden hash. Register it beside the existing `gate_runner.py` gates.
- **Rollback-readiness lane:** at tick T, `save_state`; run ahead M ticks; `load_state`;
  re-run the same M inputs; assert identical hash. This proves the phase-2 prerequisite
  locally, without any netcode.
- **Cross-check:** for shared concepts (frame counts, damage scaling math), a Node reference
  function can assert the same numbers as the Godot test to catch transcription mistakes —
  without requiring two implementations of the simulation.
- **Manual acceptance:** declared separately as owner-run, exactly as the current aggregate
  does; headless gates do not claim graphical acceptance.

---

## 7. Explicit non-goals and anti-patterns

- **No fake netplay.** Do not present input-delay or snapshot interpolation of a
  non-deterministic Godot sim as rollback/online. If online happens, it is phase 2 and uses
  real rollback (Snopek/Delta addon) or the isolated Node authority path.
- **No core edits.** `game/core.mjs`, `game/data.mjs`, `server/**`, `game/protocol.mjs`, the
  source lock and map allowlists stay as pinned by `515daf07…`.
- **No engine grants / no Blender import in this lane.** Roster and animation assets are
  other lanes; this lane consumes them.
- **No scope creep into online, matchmaking, or ranked** before local 1v1 + versus +
  training are complete across the roster.
- **No engine-physics-driven gameplay**, because it breaks determinism and rollback.

---

## 8. Technical risks

1. **Frozen boundary pressure (high).** The first online request will push toward editing
   frozen files. Mitigation: Option A by construction; phase-2 decisions documented here.
2. **GDScript performance (medium).** Many box checks per tick across two fighters plus
   projectiles. Mitigation: AABB/circle math only, pooled arrays, per-move active windows,
   no engine physics; profile against 60 Hz early.
3. **Float determinism across platforms (medium, phase 2).** Rollback needs identical
   arithmetic on both peers. Mitigation: keep the phase-1 sim simple and inspectable; if
   phase 2 netplay is funded, evaluate fixed-point/integer positions for authoritative
   values, and validate with the save/load re-run test.
4. **Authoring volume (medium).** Nine operators × full move sets is a large data task.
   Mitigation: schema + generator workflow; roster lane owns content; engine lane owns the
   validator and the runtime.
5. **Godot 4.5.2 API drift (low).** Docs are 4.5 and the pin is 4.5.2; keep to documented
   APIs (`Engine.get_physics_interpolation_fraction`, `_physics_process`, `AnimationPlayer`)
   and re-run headless gates on upgrade.
6. **Training/AI feeling bolted-on (low).** Mitigation: AI and training both consume/produce
   the same canonical `InputCommand` stream as a human; no privileged paths.
7. **Rollback addon integration cost later (medium).** Mitigation: adopt its state
   discipline now (§6.3) so phase 2 is wiring, not redesign.

---

## 9. Sources (all accessed 2026-10-02)

Local (read at base `ffcd7216edb70e2cbc7bb87e8c9e2c2013f92012`):

- `port/contracts/CONTRACT.md`, `port/contracts/source-lock.json`,
  `port/contracts/protocol.json`.
- `docs/ARCHITECTURE.md`, `docs/SYSTEMS.md`, `docs/TESTING.md`.
- `game/core.mjs`, `game/data.mjs`, `game/net.mjs`, `server/room.mjs`.
- `godot/project.godot`, `godot/net/client.gd`, `godot/player_gameplay/session_binding.gd`,
  `godot/player_gameplay/status.gd`, `godot/source_operators/generated/`.
- `tools/godot-dev/verify.py`, `tools/godot-dev/launch.mjs`.

External:

- Castagne: <https://github.com/panthavma/castagne> ·
  <https://api.github.com/repos/panthavma/castagne> ·
  <https://api.github.com/repos/panthavma/castagne/releases> ·
  <https://api.github.com/repos/panthavma/castagne/tags> ·
  <https://api.github.com/repos/panthavma/castagne/branches> ·
  <https://raw.githubusercontent.com/panthavma/castagne/main/LICENSE.md> ·
  <https://castagneengine.com/docs/> ·
  <https://castagneengine.com/docs/index/online> ·
  <https://castagneengine.com/docs/index/full-feature-list> ·
  <https://castagneengine.com/articles/roadmap2025> ·
  <https://castagneengine.com/download>.
- Sakuga Engine: <https://github.com/NoisyChain/Sakuga-Engine> ·
  <https://api.github.com/repos/NoisyChain/Sakuga-Engine> ·
  <https://raw.githubusercontent.com/NoisyChain/Sakuga-Engine/main/README.md>.
- Fxll3n's Fight Engine: <https://api.github.com/repos/Fxll3n/FightEngine> ·
  <https://raw.githubusercontent.com/Fxll3n/FightEngine/main/README.md> ·
  <https://godotengine.org/asset-library/asset/4674>.
- Rollback: <https://gitlab.com/snopek-games/godot-rollback-netcode> ·
  <https://github.com/blast-harbour/Godot-Rollback-Fighter-Demo> ·
  <https://api.github.com/repos/blast-harbour/Godot-Rollback-Fighter-Demo>.
- Godot 4.5 docs: <https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/index.html> ·
  <https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/physics_interpolation_introduction.html> ·
  <https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/using_physics_interpolation.html>.
- Glossary / netcode: <https://glossary.infil.net/> ·
  <https://glossary.infil.net/json/glossary.json> ·
  <https://en.wikipedia.org/wiki/Netcode> ·
  <https://en.wikipedia.org/wiki/Fighting_game> ·
  <https://www.hitboxarcade.com/blogs/support/what-is-socd>.

---

## 10. Bottom line

Build a **Godot-native, fixed-60 Hz, deterministic, local-only 1v1 fighting core** under new
paths, reuse the existing operator/rig/animation work, and validate it with JSON frame-data
tests plus a Godot headless deterministic-trace and save/load-re-run gate. Reuse ideas (not
code) from Castagne and Fxll3n's FightEngine, keep Snopek/Delta rollback as the phase-2
netplay option, and do not touch the frozen Node core or protocol. Ship local 1v1 vs AI,
local versus, and training across the full roster before promising anything online.
