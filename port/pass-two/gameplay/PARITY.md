# Second-pass player gameplay — source/code ready, engine acceptance pending

Branch: `improvement/pass-two-gameplay`, base `51c29dc9`.
Implementation/source-oracle commit: `77e7684f` (follow-up adds native shared-rope
expiration/reconnect scenarios and this acceptance handoff).

Authority verified with `verifySource`: frozen
`515daf07589150dd3241f4ae1425cc1b093912f5`, reviewed derivative
`0326b435a2fdd88e6e7a01b8a7325feccc4d15cb`, core SHA-256
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
No authority, `game/`, `server/`, lock, combat-actions, or shared-session changes.
The existing PlayerGameplay composition hook suffices; there is no shared-hook
commit to integrate separately.

## Audited source and delivered changes

The audit used `app/page.tsx` (`controlsFromState`, key handlers), `game/kits.mjs`,
`game/movement.mjs`, `game/core.mjs`, `game/ability-vfx.mjs`, current
`godot/player_gameplay/`, and `port/next-port/gameplay/README.md`.

| Journey / presentation | Source contract | Second-pass change |
|---|---|---|
| Grok Super Jump | `movement.advanceCharge`: hold crouch for `.45s`, then **release crouch**; early release cancels | Correct misleading Ctrl→Space hint; show authoritative charge progress and release-ready instruction using catalog budget |
| ChatGPT upward grapple | `stepActive` cancels on mobility release; `stepGrapple` resolves/sweeps a standable ledge | Explicit **HOLD X**, release-to-detach hint; source-input roof oracle and native held-X journey |
| Qwen shared rope | `core._ropePlace` starts at feet; `moveActor` auto-boards any grounded actor within source radius, not only owner | Nearby shared-boarding instruction through existing `model.statuses`; source guest route and native guest runner |
| Grok Heat | `ability-vfx._verb`: `heat/maxFireRateBonus`, source orange palette | Bounded snapshot-scaled orange channel; maximum comes from generated source catalog |
| DeepSeek Deep Compute | Source charge radius `.5 + .85*charge`, cyan palette | Snapshot-scaled low ring |
| Qwen Tool Use | Source `windowIn > 0`, radius `1.05`, purple palette | Handling-window ring that disappears with source state |
| Meta Braced | Source grounded, out-of-combat, below spawn armor conditions | Static blue recovery ring under those conditions |
| Death / absence / invalid replacement | Public health, anchor life, actor presence, finite bounded coordinates | Drain cable and passive channels; invalid replacement cannot leave an older cable visible |
| Disconnect / reconnect | Transport-drop signal precedes authoritative resume snapshot | Immediately publish empty `status_changed`, hide panel, drain cues; empty snapshot cannot resurrect old local actor model |
| Quality / reduced motion | Existing F9 combat quality and local reduced-motion setting | Passive channel budgets **8/24/32**, power bursts **4/12/16**; essential cable cap **32**. New channels are static; existing burst growth respects reduced motion |

These are native readability/access changes. They do not re-port Q powers,
movement physics, ADS, alternate fire, grenades, targeting, acknowledgements,
weapon animation, or Alignment Review shields. Braced/Heat use simple static
native silhouettes rather than claiming complete Three.js particle equivalence.
Long Context ground breadcrumbs, Revision/Adaptive flashes, and full visual
equivalence for every passive remain outside this delivered slice.

## Composition contract

`PlayerGameplay.status_changed(model)` and existing model keys are retained.
Charge/boarding guidance flows through the existing Experience ability/status
surface; `show_compact_status=false` remains respected. Signal emissions now
occur when the projected model changes, plus explicit lifecycle clears.
World cues are separate from HUD layout and read the existing combat quality
controller. No new overlay or settings menu is installed.

Source rope `anchor.from` is eye-height based; cable/boarding rendering retains
the existing feet conversion. The source snapshot does not expose the placement
stance separately. This pass does not claim to solve a later owner-stance change
altering that presentation conversion.

## Source-derived journeys

`tools/port/pass-two-gameplay/source.mjs` steps the actual `Match` at `1/60`, from
normal deterministic spawns, through ordinary control dictionaries. It never
assigns actor poses/health/resources or substitutes physics callbacks. Its
generated oracle is test-only and dynamically loaded by native acceptance.

Canonical map: **meridian-exchange**, RNG `.5`. Six operators plus ChatGPT:

| Operator | Actual source witness | Max rise (m) | Negative control |
|---|---|---:|---|
| Mistral | `move-start:dash` | 1.4073 | No jump → no activation/rise |
| Gemini | `move-start:double-jump` | 2.2567 | No jump → no activation/rise |
| Grok | `charge-release`, Super Jump | 2.9664 | Early Ctrl release → no launch/rise |
| DeepSeek | `move-start:hover`, fuel/phase snapshots | 0.2755 | No hold → no activation/rise |
| Meta | `slam-launch`, `slam-impact` | 1.6726 | No chord → no activation/rise |
| Claude | `move-start:glide`, fuel/phase snapshots | 1.4073 | No hold → no activation/rise |
| ChatGPT | Resolved grapple ledge; ends grounded on **5m roof** | 5.0757 | One-tick X hooks then releases, **0m** rise |

The canonical roof trace ends with source `grapple-release:blocked`, not
`arrive`. The actual final grounded roof pose and earlier resolved ledge are the
mantle witnesses. An initial stricter `arrive` assertion failed and is retained;
the oracle was corrected after reading `stepGrapple`, not by changing authority.
No source bug or pin advance is asserted.

The two-player source route walks guest 1 from `(44,34)` via `(44,-34)` to owner
0 near `(-44,-34)`. Qwen deploys after the approach begins; another operator
auto-boards and rides. No-X negative control never boards. Source expiration
clears both live rope list and public anchor.

`wire.mjs` independently exercises the actual WebSocket protocol with two Node
clients: guest boarding at source time **17.033s**, owner resume preserving the
still-live source anchor, then ordinary guest primary fire kills owner at
**19.7s** and clears the anchor. It uses accelerated wall ticks with unchanged
simulation dt; it is neither native acceptance nor latency/performance evidence.

## Native preparation / truthful boundary

- `second_pass_live.gd` + `native.mjs`: seven source-derived plans through native
  keyboard/mouse, Q/cooldown refusal, snapshots, wide/compact screenshots,
  grapple cable and final roof checks.
- `second_pass_shared.gd` + `native-shared.mjs`: native **guest** walks/boards/
  rides; scripted Node source-wire **owner** deploys. Separate death, expiration,
  and interrupted-transport/resume scenarios. Reconnect invokes the real lobby
  Retry handler, not a pose or transport-state fixture.
- `second_pass_test.gd`: actionable source hints, source-sample projections,
  invalid cable replacement, lifecycle clears, static reduced-motion channels,
  bounded Low quality, empty-model publication, shared boarding guidance.

All native scripts are **prepared, unexecuted**. Native owner X deployment was
already exercised in first pass; this pass's shared runner does not claim two
native windows or native-owner input evidence. Engine parsing, native journey
results, real screenshot/clip inspection, hardware GPU and human play remain
pending as listed in `ACCEPTANCE.md`.
