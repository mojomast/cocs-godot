# Movement research implementation — Astra, 2026-10-03

Source implementation on `astra/movement-refinement`, sparse worktree
`/home/mojo/.tmp-on-disk/cocs-movement-astra`, based on `90be2af7`.
The worktree was created with `--no-checkout`; working directory, Git top-level
and branch were verified before edits. No child agents or engines were run.

## Chosen changes

1. **Close the ground/takeoff acceleration loophole.** Ground and air input now
   use the same speed-gain limiter. Each acceleration sample captures speed
   **after friction and before acceleration**, then bounds its result to the
   greater of that speed and the current stance/modifier terminal budget.
   Ground input can no longer create overspeed that the next air tick mistakes
   for incoming momentum. This is an inductive per-tick bound, not a claim that
   every pre-input velocity is externally generated. It needs no provenance
   state. Existing above-budget impulses can steer without gaining speed;
   ordinary ground friction still dissipates them. Sprint, crouch, ADS, buffs,
   carriers and Effortless keep their existing budget composition. Slide bursts
   happen before the sample; launchers happen after movement; cable rides retain
   their early-return owner. The terminal multiplier remains **2.2**.
   This is a stance-dependent budget, **not a global 17.6 m/s ceiling**:
   base-8 walking permits 17.6 m/s; grounded sprint permits **24.2 m/s**.
2. **More useful midair corrections:** `airAccel` 3.5 → **4.5**, `airCap` 1.6 →
   **2.2**, selected after the bounded comparison below. Base speed, ground
   acceleration/friction, slide boost/friction and jump forgiveness stay at
   their prior values. Effortless retains its 1.4× acceleration / 1.2× air-cap
   identity, plus its existing slide and hop advantages.
3. **Forgive an airborne crouch tap just before landing.** A rising crouch edge
   with sprint intent records **150 ms** of intent. Release before landing no
   longer loses it. First post-landing movement consumes it only above 6 m/s,
   with the existing slide cooldown satisfied and no requested/buffered jump.
   A released tap commits crouch/slide for the existing minimum duration
   (including Effortless/passive bonuses), then releases and starts slide
   cooldown. Jump cancels it; held-crouch behavior stays on its existing path.
   Holding crouch does not refresh the timer. Grok super-jump / Meta brace-slam
   reserve crouch; other non-ready verbs, harness dash, vehicles, cable rides,
   launchers and dead actors cannot buffer. Actor creation, spawn, death, fall,
   vehicle entry/exit and teleports clear pending/committed tap state. The three
   added actor fields (`slideIntent`, `slideCrouchHeld`, `slideTap`) travel in the
   existing actor snapshot spread; no wire input or epoch semantics changed.
   The configured 150 ms is frame-quantized: landing is consumed by the next
   movement tick, whose timer decrement runs first. A flat-floor initial-height
   sweep (0.001–0.800 m, initial vertical speed zero) found the latest successful
   landing **133 ms after the press-processing tick at 60 Hz**, and **100 ms at
   30 Hz**. Those are observed landing offsets, not a guarantee of a continuous
   150 ms landing window. Authority remains fixed 60 Hz; this follow-up does not
   retune the window.
4. **Readable slide posture:** a damped weapon-only cant of **0.08 rad**
   with **18 mm right / 25 mm down** default offset in native and web presentation
   (web also respects the existing bounded weapon-bob preference).
   Native uses `1 - aim_weight`; web carries a separate slide pose so the ADS
   composer also removes it completely at settled aim. Reduced motion clears
   it immediately. Hidden/dead/spectating/mounted presentation clears it.
   It writes no camera, FOV, reticle or authoritative ray. Existing inertia,
   landing and kick composition remain the pose owners. No extra HUD overlay.
5. **Native flow-control parity:** move campaign's four-outstanding-input
   window into its native-arena base (also covering identity), and apply the
   same guard to Horde. Only applied/cancelled sequence ACKs retire credit;
   received ACKs do not. Cancels bypass backpressure. Epoch/round/disconnect
   clear old credit. `ERR_BUSY` allocates no sequence, keeps one-shots pending,
   and resamples current held input on the ordinary next send. Horde now treats
   busy as backpressure rather than a connection failure. Repeated inactive
   Horde frames send one ordered cancellation per transition/epoch, with retry
   after actual transport failure and a fresh cancel after new active input.

## Measured comparison

`node tools/movement-comparison.mjs` compares baseline source loaded directly
from Git with the working implementation, using the same unchanged dependency
modules and a flat empty arena. `mechanics.json` contains the source hash,
10-second trace samples and the cap+buffer-only intermediate comparison.
These are pure-source mechanics measurements, not native or human fun ratings.

| 60 Hz probe | Baseline | Implemented |
|---|---:|---:|
| 0 → 8 m/s ground acceleration | 9 ticks | 9 ticks |
| 8 → 0 ground release | 24 ticks | 24 ticks |
| 8 → negative air-cap reversal | 21 ticks to −1.6 | 17 ticks to −2.2 |
| Lateral correction during one full hop | 1.167 m | 1.600 m |
| Full-hop duration | 46 ticks | 46 ticks |
| Orthogonal real-ground walking autohop, 160 s | 25.236 m/s | 17.600 m/s |
| Actual landings during that trace | 204 | 204 |
| Incoming 24 m/s after orthogonal takeoff | 24.037 m/s | 24.000 m/s |
| Released late landing tap | no slide, 7.2 m/s | slide on tick 4, 9.2 m/s |

The baseline regression was run **before the fix**: the 30 Hz real-ground test
failed at tick 230 (17.80087 m/s > 17.6), and the incoming-24 takeoff assertion
also failed. At 60 Hz the retained trace first exceeds the budget at tick 981.
Cap+buffer alone retains the baseline's 1.167 m lateral correction; moderate
air tuning supplies an additional 0.433 m without raising terminal speed.
The different-dt tests assert invariants, not identical trajectories.

## Research decisions / provenance

Flash's three research lanes were relayed by the parent; implementation
independently reproduced the locomotion defect and inspected ordering/owners.
No third-party engine code was imported or copied.

- [Quake III `bg_pmove.c`](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/bg_pmove.c):
  projection acceleration and friction are useful precedents for preserving
  directional skill. Adopt the bounded local policy above, not unlimited gain.
- [Community ioquakelive implementation](https://github.com/tjone270/ioquakelive/blob/1487e89c/code/game/bg_pmove.c):
  useful diminishing-acceleration comparison; **not** an official Quake Live
  behavior guarantee. [UT2004 Pawn reference](http://ericdives.com/UT2004-UnCodex/engine/pawn.html)
  supports treating acceleration/air control as separate tunable budgets.
- [Titanfall controls interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right):
  relayed precedent for slide/chaining and weapon cant. The selected cue is a
  small weapon-only pose, not an asserted reproduction of Titanfall angles.
- [Celeste and forgiveness](https://www.maddymakesgames.com/articles/celeste_and_forgiveness/):
  transfer the intent-across-boundaries principle, not platformer movement.
  The 150 ms slide window is a local starting value requiring human evaluation.
- [Mirror's Edge movement talk](https://www.gdcvault.com/play/1012171/Creating-First-Person-Movement-for):
  relayed perceived-motion/comfort rationale. Community Apex/wiki/video claims
  are not treated as verified primary-source slide-buffer specifications.
- [Tribes physics overview](https://floodyberry.wordpress.com/2008/02/20/tribes-1-physics-part-one-overview/)
  and [history](https://store.epicgames.com/en-US/news/the-history-of-tribes-the-fastest-shooter-in-the-west):
  terrain skiing is a larger terrain/ability design, deferred here. Blanket
  base-speed increases, generic grapple/wallrun, terminal 2.35 and simultaneous
  friction/slide retuning were rejected for this pass as scope/balance choices,
  not user prohibitions.
- [Gaffer fixed timestep](https://gafferongames.com/post/fix_your_timestep/),
  [snapshot interpolation](https://gafferongames.com/post/snapshot_interpolation/),
  [Godot physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)
  and Flash's `/tmp/opencode/cocs-lane3-input-audit-handoff.md`: preserve authority
  cadence and bounded transport, fix the actual missing client window.

**Deferred:** automatic pointer/held-state recovery after stale-input reset.
The retained P diagnostic's gaps and epoch rejection are consistent with a
client stall; they do not alone prove render-scheduling causality. Safe recovery
requires fresh actual-input sampling plus focus/menu/death/reset ordering tests.
Keeping a saved held-key ledger would be insufficient. TTL 250 ms, epochs,
sequence acceptance, cooldowns and source jump windows remain authoritative.
No synthetic catch-up input, retries for gameplay actions, or local prediction.

## Verification and integration handoff

Pure Node suites cover real-ground 60-second bounds at 30/60/120 Hz; incoming
impulses; stance/ADS/carrier/buff changes; Effortless; tap timing at
30/60/120/144 Hz; expiry/held/cooldown/verb/traversal rejection; lifecycle reset;
fixed-60 Hz `Match.step` replay; native-shaped FIFO into source Match; weapon
cue comfort/visibility and ADS composition. Existing movement, operator,
traversal, feedback and ADS suites are included in the final run.

Final pure-source run: **217 passed, 0 failed**, 1.69 seconds. Command:

```sh
node --test --test-reporter=spec game/movement-refinement.test.mjs game/movement-feedback.test.mjs game/arena-movement.test.mjs game/feedback.test.mjs game/phase1-weapons-ads.test.mjs game/phase2-movement-integration.test.mjs game/movement.test.mjs game/operator-verbs.test.mjs game/traversal.test.mjs port/native-arenas/tests/input-events.test.mjs port/native-horde/input-buffer.test.mjs
```

Log: `/tmp/opencode/movement-astra-tests.log`. Initial sparse-fixture failures
were missing `three` (resolved by the existing dependency symlink) and missing
`port/native-debug` source (added to sparse checkout). No endpoint was started.

Native tests authored/expanded, **not executed (no engine grant)**:

- `godot/tests/campaign/input_flow.gd`: all three clients, under-consuming FIFO,
  pulse retention, cancel bypass, epoch credit, failures and inactive Horde.
- `godot/tests/first_person/slide.gd`: bounded pose, camera neutrality, settled
  ADS, reduced motion and hidden/death/spectator/mounted lifecycle.

Native parsing, rendered comfort/readability and human fun remain pending.
The pure web tests use a symlink to the parent's existing `node_modules` (no
package install/copy). The sparse worktree contains no imported asset/cache
checkout. Disk was initially checked at 85 MiB free and at 42 MiB near handoff;
no retained evidence was deleted. Parent must schedule storage before native work.

**Dependency drift is intentional and must be reconciled before native claims:**
`game/core.mjs` and `game/operator-verbs.mjs` changed; the campaign generated core
and frozen source pins still describe the previous implementation. Native arena
`match.mjs` and Horde `authority.mjs` import `game/core.mjs` directly.
`port/native-campaign/core.generated.mjs` currently declares source SHA256
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
The new core hash is `655f112934b7b4a4f1d9f043a8c545511e7284f557e4c9586dfd72d3e5a8e7a3`
(also recorded in `mechanics.json`). `port/native-campaign/generate-core.mjs`
pins the old hash and will reject regeneration until explicitly reconciled.
`tools/port/lattice/source-oracle.mjs` also references that old hash. Existing
`tools/godot-package/production_receipts/{abyssal-pressureworks,robots,scenery,vesper-viaduct}.json`
and `port/finish/ASSET_PRODUCTION.json` contain the prior dependency hash.
Campaign generation, source dependency pins, client GDScript hashes and the
first-person rig candidate need reconciliation and fresh native tests under the
parent's storage/engine schedule. No receipt was re-stamped.
