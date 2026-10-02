# Fighting mode — independent architecture/data/test efficiency audit

Status: **independent audit, read-only scope; no gameplay, import, render or engine work.**
Branch `efficiency/architecture-20261002`, base `10a90fd0`. Owner-requested efficiency
lens, not a second design. This document is the only file written on this branch.

Reviewed committed material only (no mutable/uncommitted lane files):

- `port/fighting/{DESIGN,WORKSTREAM}.md`, `port/fighting/research/ENGINE_MECHANICS.md`,
  `port/fighting/content/CONTRACT_DETAILS.md`, `FREEZE.json`.
- `godot/fighting/data/{roster.json,rules.json}` (138 moves, 27 proposed traces),
  `godot/tests/fighting/content/content.test.mjs`,
  `tools/fighting/content/{author,validate,evidence}.mjs`.
- `node tools/fighting/content/validate.mjs` → `source_valid` (exit 0) at base.

Scope guardrails honoured: keep all nine characters, their distinct animations and FX,
and every identity-bearing balance field; no data prune of essentials; no wholesale
stack rewrite (stock Godot 4.5.2 GDScript is already the right call); no
Godot/import/render/gameplay implementation; no heavy-tool grant (Foundry still owns it).

---

## Findings head

| # | Finding | Owner | Severity | Time saved (qualitative) |
|---|---|---|---|---|
| **C1** | Input edge authority, `axis_y` sign, integer arithmetic and hitstop/stun ordering are unspecified/contradictory across DESIGN, CONTRACT_DETAILS and research | core | **High** | Avoids a core rewrite plus regeneration of 27 traces and all replay/symmetry fixtures after they first disagree |
| **C2** | `validate.mjs` accepts optional fields the core contract does not bound, and omits fields the core must reject — validator schema ≠ core schema | content + core | **High** | Avoids per-lane debugging of silently dropped operator mechanics and false "content valid" signs |
| **C3** | DESIGN.md prose table is a load-bearing data oracle; `roster.json` is generated, and FREEZE hashes both plus the generators | content + verify | **Medium‑High** | Removes parent merge churn and manual regeneration for unrelated doc edits; shrinks freeze surface |
| F4 | GDScript int division / JSON round-trip type drift threatens deterministic save/load and left/right mirror | core + verify | High | Prevents a replay-equality bug that is expensive to localise once combos exist |
| F5 | Tick ownership and catch-up are unspecified; interpolation/teleport resets are not called out | core + UI | Medium | Avoids jitter/slow-motion debugging in native gates |
| F6 | `movement` is described as a 10-value enum; risk of 9 bespoke operator machines / 10 type branches instead of one parameterised composition | core | Medium | Keeps one timeline code path; avoids 9× maintenance |
| F7 | Acceptance enumerates ~81–90 pairings; 27 traces freeze absolute ticks. Cartesian/authoring cost is avoidable | verify + content | Medium‑High | Replaces hand-authored pairing matrix with a few metamorphic properties |
| F8 | Rollback readiness is over-scoped relative to "local-only now" | core | Low‑Medium | Avoids building prediction/reconciliation nobody ships yet |
| F9 | Validation gaps: `states` unvalidated, manifest contact windows not cross-checked, fingerprint omits cancels/level/resource, `pressed` subset unchecked | content + verify | Low‑Medium | Cheap coverage close-up, no new fixtures |
| F10 | `evidence.mjs` hardcodes the launch base `37dd3da4`; other lane docs can perturb the DESIGN freeze | verify | Low | Small brittleness fix |

Detail below; **C1–C3 are the actionable top three.**

---

## Top 3 corrections

### C1 — Pin input authority, integer arithmetic and hitstop ordering before core lands
**Owner: core. Severity: High.**

Three independent ambiguities currently exist between the documents:

1. **Who derives `pressed`?** DESIGN line 120 defines an input as
   `{axis_x, axis_y, held, pressed}` and the frame-data owner computes it; AI and the
   UI adapter are separate callers. Two sources of truth for the rising edge means a
   human, an AI, a training replay and a saved input trace can disagree on the same
   `held` sequence → nondeterministic replay and "double activation" the contract warns
   about. **Fix:** core derives `pressed = held & ~prev_held` internally (axis rises
   likewise) and treats caller-supplied `pressed` as advisory/ignored; or validate it
   equals the derived value. Record the pre-step `held` in the saved replay state.
2. **`axis_y` sign is undefined.** DESIGN says axes are `-1/0/1` but never which is up;
   the generator uses `axis_y = -1` for crouch. CONTRACT_DETAILS says only "Down
   chooses crouch normals". If the UI sends `+1` for down, jump/crouch invert. **Fix:**
   state `axis_y: +1 = up, -1 = down` (and `axis_x: +1 = toward facing +X`) next to the
   schema. `rules.json` `input_help.notation` already implies this (8 up, 2 down) — just
   make the machine contract say it.
3. **Hitstop ordering is contradictory.** Research `ENGINE_MECHANICS.md:356` fixes
   `hitstop → stun timers → input resolve → …`. DESIGN says hitstop "freezes combat
   frame advancement". If stun timers run after the hitstop gate and decrement
   unconditionally, hitstun/blockstun tick *through* hitstop, silently changing combo
   timing and damage-scaling cadence. **Fix:** amend the order to
   `input sample/buffer → if hitstop>0: decrement hitstop, advance input history only,
   skip ALL of {move timeline, stun timers, resources, movement/push, collision, hit
   resolution} → else: stun → transition → movement → collision → hits → events`.
   This matches the reference demo (below), where `state_process()`/`movement_process()`
   are gated on `hitstop <= 0` while `input_process()` still appends history.

4. **Integer arithmetic convention.** Positions/velocities are integer, but damage
   scaling (`damage × percent / 100`), pushbox averaging, gravity and resource regen all
   divide. GDScript integer `/` truncates toward zero; mixing in `roundi`/`floori` or any
   float (`sqrt` for throw/projectile range) breaks bit-identity and can break the
   required left/right mirror. **Fix:** one documented helper, e.g.
   `static func mul_div(a:int,b:int,c:int)->int: return (a*b)/c` with a stated
   truncate-toward-zero rule (symmetric under `x→-x`), forbid float operands in the sim,
   and use squared-distance comparisons for reach/trigger ranges instead of `sqrt`.
   Coordinates are within ~±16000 mm, so int64 squares (~2.6e8) cannot overflow; the
   only overflow/privacy risk is storing sim ints in float or 32-bit float arrays.

Leaving these to six parallel lanes guarantees each will pick a different convention;
the cost lands when traces, AI replays and mirror tests first disagree. Cost now is
documentation; cost later is a core rewrite plus regenerating the traces.

### C2 — Make the validator's accepted schema equal the core's accepted schema
**Owner: content (validator) + core (defaults). Severity: High.**

DESIGN requires the core to "validate required fields and reject unknown move mechanics
instead of silently dropping operator distinctions". `validate.mjs` currently bounds only
a subset of the optional dictionaries declared in `CONTRACT_DETAILS.md`. Observed gaps
(union of keys actually present in `roster.json` vs keys checked in `validate.mjs`):

- `projectile`: present `x,y,vy,gravity,pierce` — **unchecked**.
- `movement`: present `vx,vy,air_only,ground_only,invulnerable_from,invulnerable_to,on,pull_speed,reset_on_land` — **unchecked** (only `from,to,distance,duration,cooldown,anchor_*,air_uses` are checked).
- `throw`: present `victim_x,victim_y,side_swap,command,ground_only` — **unchecked**.
- `counter`: present `strike,range` — **unchecked**.
- `resource_effect.reset_on_land`, `input.motion`, `input.charge_axis` — **unchecked**.
- top-level `air_ok`, `ground_ok`, `knockdown_frames` — **unchecked** (`knockdown_frames` is only checked inside `throw`).

Consequence: content can pass "source_valid" while the core either rejects a move at
load (fail-closed → an operator loses a signature special) or silently ignores a field
that distinguishes that operator — the exact silent-collapse the design forbids. Pick one
contract and enforce it in both places: either bound every field here, or have the core
tolerant-default it and return a diagnostic that the source validator also treats as
failure. `pierce`/`on`/`air_uses` are semantically load-bearing (Gemini's band, Qwen's
anchor, ChatGPT reel) and should not be the ones left lax.

### C3 — Decouple the balance oracle from prose; stop double-freezing generated data
**Owner: content + verify. Severity: Medium-High.**

`validate.mjs:31,35-36` reads `port/fighting/DESIGN.md` and regexes the markdown table
to force `roster.json` stats to equal the design targets. `FREEZE.json` then hashes
`DESIGN.md`, `roster.json`, `rules.json`, all generated JSON, `MOVE_LIST.md`,
`author.mjs` and `validate.mjs`. The generator (`author.mjs`) is therefore both the
recipe and a frozen artifact, and any prose edit to DESIGN.md (including unrelated parent
integration notes) fails the freeze — `WORKSTREAM.md:84-89` records exactly this class of
false failure and a manual FREEZE re-hash. This is the "stat targets markdown hash
fragility" plus self-referential recipe cost.

Correction:

- Put the authoritative initial stat/target matrix in machine-readable data (either
  `rules.json` or a small `port/fighting/content/BALANCE_TARGETS.json`) and have
  DESIGN.md reference it. Validate stats against that file, not a regex over prose.
- Treat `godot/fighting/data/roster.json` as the authored source of truth and
  `author.mjs` as a one-time/bootstrap expansion, or keep generation but freeze only the
  *inputs* (source tables) and validate outputs against them. Freezing both generator and
  generated artifact means every one-stat tweak must re-run generation and re-hash the
  generator.
- Narrow FREEZE to the runtime inputs (`roster.json`, `rules.json`, `game/data.mjs`) and
  the schema; prose docs should not gate numerics.

This also removes cross-lane coupling: DESIGN.md is parent-owned and is expected to
change; the content gate should not break when it does for non-numeric reasons.

---

## Other findings

### F4 — Deterministic save/load: JSON type drift is the real hazard (core + verify, High)
`save_state()`/`load_state()` must produce "identical future stepping" and JSON-safe deep
copies. Godot's own JSON doc states *"converting a Variant to JSON text will convert all
numerical values to float types"* and parse yields floats; so an int field written as
`5` returns as `5.0`, and all downstream arithmetic silently becomes float (breaking int
truncation and hash equality). Also `snapshot()` "deep detached" copies can still alias if
`duplicate()` is shallow. **Fix:** a single typed codec that `int()`-casts every integer
field (and casts enums/bools) on load, plus a cheap test: `save → JSON.stringify →
JSON.parse → load → step N → hash` equals the in-memory run, and `save → load → save`
byte-equals. This is the highest-value, lowest-cost determinism test and it needs real
Godot, not a Node mirror (F7). Also pin RNG state explicitly (the reference demo stores
`RandomNumberGenerator.state`; DESIGN says an injected seeded RNG is serialized — good).

### F5 — Tick ownership and catch-up (core + UI, Medium)
`step()` consumes exactly one 1/60 tick, but nothing says who calls it. Use Godot's fixed
physics loop, not `_process`: default `physics_ticks_per_second = 60` is already the
contract; run exactly one `step()` per `_physics_process`; do not accumulate or multi-step
in `_process` (determinism + input sampling). If you ever allow catch-up, clamp at
`Engine.max_physics_steps_per_frame` (default 8) and define per-skipped-tick input (duplicate
or release), or the sim slows rather than desyncs. Presentation is read-only: interpolate
from the two latest snapshots with `Engine.get_physics_interpolation_fraction()`, and call
`reset_physics_interpolation()` on match/round reset, wakeup teleports, blink and camera
snaps (Godot's interpolation doc: teleports without it streak; "move (almost) all game
logic from `_process` to `_physics_process`"). `Input.is_action_just_pressed` is reliable
per physics tick, so the adapter may use it, but core must not — it takes explicit inputs.

### F6 — Composition, not 9 bespoke machines (core, Medium)
The data model is already data-driven; keep it that way. `movement.type` has 10 values
and per-type fields. Implement it as one parameterised modifier on the common move
timeline — `{apply vx,vy over [from,to]} ∪ {teleport once at from} ∪ {pull target on hit}`
— not a `match type` ladder or per-operator class. `resource_effect`, `armor`, `stance`,
`counter`, `throw` are orthogonal components; the only legitimate special-casing is the
generic operation kind (velocity vs. teleport vs. pull-on-contact), not the operator id
or the marketing name. Likewise the six operator resources (DeepSeek charge, Gemini
band, Mistral air counter, Qwen regen, Meta brace) are the same "bounded resource" code
with different data. This yields one tested timeline and makes all nine distinct through
data, satisfying the distinctiveness requirement without nine maintenance surfaces.

### F7 — Test cardinality: metamorphic over Cartesian (verify + content, Medium-High)
Acceptance asks for nine mirrors plus all 36 pairings and left/right symmetry
(~81–90 matchups) and every operator's three combos against the core. Hand-authoring
90 input fixtures scales linearly and rots as data changes. Prefer a few strong
properties over enumeration:

1. **Mirror symmetry:** transform a random input log and stage by `x→-x, facing→-facing`,
   `axis_x→-axis_x`; assert the resulting state is the mirror (occupancy/scalar fields
   equal, `x/vx` negated). One property covers all 45 orderings' left/right bug class.
2. **Determinism:** same seed + same input log ⇒ same state hash across two runs and
   across `save/load` in the middle.
3. **Bounded invariants (fuzz):** random inputs over bounded ticks assert
   `0 ≤ hp ≤ max`, positions within stage bounds, hit/cancel counters monotone, no
   unbounded combo beyond `max_hits`, no negative resource, no non-integer/NaN fields.
4. **Representative matrix:** pick the archetype extremes (heavy grappler, light
   rushdown, zoner, charge, stance) rather than all 81; native/manual acceptance covers
   the visual pairings.

Keep the pure Node `validate`/freeze tests (cheap, fast). Move all numeric authority —
integer truncation, hitstop gate, trade ordering, RNG replay — into a Godot **headless
RefCounted** gate with no scene and no rendering (the sim is `RefCounted`, so it needs
neither Node3D nor GPU). This is the "native unit without scene" split: numeric tests
headless, visuals/rig/FX/camera in the separately-owned native visual gates. Do **not**
build a second simulator in Node to "cross-check numbers" (research §6.5): a duplicate
implementation cannot prove GDScript integer semantics and will drift.

### F8 — Rollback draft is realistic only as *discipline*, not as machinery (core, Low-Medium)
Local-only phase 1 does not need prediction/reconciliation. The integer-fixed-point
choice already removes the research's "cross-platform float identity" phase-2 risk.
Keep: seeded serialized RNG, engine-physics-free collision, stable array ordering,
`save_state`/`load_state` and the replay-equality test. Defer: the Snopek/Delta addon,
per-tick network serialization in the hot path, `_interpolate_state`. Do not serialize the
full state to JSON every tick for checksums — hash a compact int tuple instead. This keeps
phase 2 as wiring rather than redesign while not paying for it now.

### F9 — Small validation gaps worth closing cheaply (content + verify, Low-Medium)
- `states` is written into the manifest but never validated (contract fixes 25 universal
  state keys); assert the exact set.
- Manifest `contact_windows`/`projectile_spawn`/`movement_window` are emitted but not
  cross-checked against the move data; assert they equal hitbox/projectile/movement
  windows (catches animation/move drift before native).
- `fingerprint()` in `validate.mjs` omits `cancels`, `level`, `meter_gain/cost`,
  `pushback`, `launch_velocity`, `juggle_cost`, `chip`, `resource_effect`, `input`; two
  "duplicate" moves can differ in exactly the fields that matter. Widen it.
- Combo samples don't assert `pressed` is a rising subset of `held`, nor that
  `duration` fields are sane.
These are small edits to existing tests, no new fixtures.

### F10 — Evidence base pin and freeze surface (verify, Low)
`evidence.mjs:15` hardcodes `37dd3da4`. It fails loudly if the ref is missing, but record
the expected base in `FREEZE.json` (or a constant) so a re-base is intentional. Combined
with C3, this prevents "passed because the diff compared the wrong range".

---

## Keep (correct existing design — do not weaken)

- **Integer fixed-point sim in stock Godot 4.5.2 GDScript, engine-physics-free, isolated
  under `godot/fighting/**`.** Correct for determinism, avoids the float cross-platform
  problem entirely, and avoids adding a GDExtension. No Godot 3 migration.
- **`simulation.gd` RefCounted with `step(inputs)` + `snapshot`/`save_state`/`load_state`
  and exactly two inputs per tick.** The right seam; keep explicit inputs (never poll
  `Input` inside the core).
- **Data-driven moves with optional typed dictionaries and one common timeline.** This
  already delivers 9 distinct characters without 9 code paths — preserve it (F6 just
  keeps it honest).
- **Fixed simulation owns hits/timing; animation is presentation; hitstop is a counter,
  not `time_scale`.** Matches the reference implementation and the glossary.
- **Honest status:** 138 moves / 27 `proposed` traces, `runtime_combo_proof:false`,
  `native_art_proof:false`. Keep that honesty; do not promote estimates to proof.
- **No frozen-core edits; additive paths and gates only.** Keep.
- **All nine operators, their distinct clips, paired victim timelines and FX.** No cuts;
  any recommendation above is schema/ordering, never identity removal.
- **6-frame buffer, SOCD neutral both axes, negative edge off, independent guard.**
  Consistent across DESIGN and `rules.json`; only the axis sign (C1) needs stating.

---

## Sources (primary, inspected; access date 2026-10-02)

1. Godot 4.5 — *Using physics interpolation*:
   <https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/using_physics_interpolation.html>
   — "Move (almost) all game logic from `_process` to `_physics_process`"; use
   `Engine.get_physics_interpolation_fraction()`; call `reset_physics_interpolation()`
   when teleporting; docs explicitly warn netplay should use a custom interpolation.
2. Godot 4.5 — *Engine* class:
   <https://docs.godotengine.org/en/4.5/classes/class_engine.html>
   — `physics_ticks_per_second = 60`, `max_physics_steps_per_frame = 8`, `max_fps = 0`,
   `get_physics_frames()`, `is_in_physics_frame()`. Basis for F5.
3. Godot 4.5 — *Input* class:
   <https://docs.godotengine.org/en/4.5/classes/class_input.html>
   — `is_action_just_pressed` is true only on the frame/physics tick of the press;
   `use_accumulated_input` defaults true; prefer `is_physical_key_pressed`; device-loss via
   `joy_connection_changed`. Basis for C1/F5 adapter rules.
4. Godot 4.5 — *JSON* class:
   <https://docs.godotengine.org/en/4.5/classes/class_json.html>
   — "The JSON specification does not define integer or float types, but only a number
   type. Therefore, converting a Variant to JSON text will convert all numerical values
   to float types." Basis for F4.
5. `blast-harbour/Godot-Rollback-Fighter-Demo` @
   `c9effb322e4a62e50ef6c5117f4596f09666757b` (MIT, Godot 4.2.2, stale 2024-07-10) —
   reference only:
   `demo-fighting/scripts/FightManager.gd` orders all fighters' passes (state→movement→
   hitstop decay→pushbox→hurtbox→projectile→hitbox→check_hits→get_hit) with an explicit
   comment about avoiding port priority; `Fighter.gd` gates `state_process()`/
   `movement_process()` on `hitstop <= 0` while `input_process()` still appends the input
   history; `HitBehavior.gd` carries per-hit `hitstop`. Its fixed point comes from the
   `SGFixed`/SG Physics GDExtension — the one thing this project correctly does not copy.
6. `Fxll3n/FightEngine` @ `a12a81c1bc5f31242f512d7e26d4e4aa43444dde` (MIT, Godot 4.5,
   v0.0.2-alpha, last push 2026-02-04) — reference only for `HitBox2D`/`HurtBox2D` node
   shape and animation-driven windows; its demo pulls in LimboAI (a GDExtension), so do
   not depend on it.
7. `gitlab.com/snopek-games/godot-rollback-netcode` (MIT) — `_save_state`/`_load_state`/
   `_interpolate_state` and `NetworkRandomNumberGenerator` (state-based RNG). Phase-2
   reference only; matches the delta fork's `NetworkRandomNumberGenerator.gd` above.

No benchmarks are asserted; all cost/time statements are qualitative reasoning from the
inspected code and the documented engine behaviour.
