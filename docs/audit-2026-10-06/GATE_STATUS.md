# Gate status — audit implementation 2026-10-06

Exact candidate: branch `audit/2026-10-06-implementation` from the audited
baseline `9b497d53c95b36198d5a0239ce578469b1acf358` (no source changes existed
between the audit and this implementation start). Engine: pinned Godot
`4.5.2.stable.official.6ce3de25a`.

## Known baseline failures (present at the audited SHA, now resolved or scoped)

| Baseline failure | Status |
|---|---|
| `port/native-campaign/core-provenance.test.mjs` compared the movement-only historical inventory against a later racing source (audit §21: 21 pass / 1 fail) | **Repaired by T1/F01**: the movement claim is scoped to its frozen commits; a new active-source test verifies current bytes through the reviewed chain. 4/4 pass. |
| `port/reports/verification.json` is a historical failed report from older dirty source `e530c1c9` (318 gates, 7 fail) | **Not a current regression.** Left untouched as historical evidence; the current aggregate was not rerun in the audit and is not claimed here. |
| README/CI selected the stale lattice derivative; a fresh documented launch failed source verification | **Repaired by T1/F01**: one active-source descriptor consumed by dev/package/CI/verify; semantic export and both suites resolve it. |

## Checks executed for this implementation

| Task | Command (summary) | Result |
|---|---|---|
| T1 F01 | `node --test port/native-campaign/core-provenance.test.mjs` | 4 pass / 0 fail |
| T1 F01 | modified-byte negative control through `verifySource(activeSource())` | rejected: `Derivative source byte mismatch: game/race.mjs` |
| T1 F01 | `node tools/godot-export/semantic.mjs <tmp>` (no env, descriptor default) | exit 0, 9 maps exported |
| T4 F12 | `godot --headless --script res://tests/main_menu/contracts.gd` | **1153 checks / 0 failures** |
| T4 F12 | `node --test tools/godot-package/route_parity.test.mjs` + `gen_routes --check` | 13/0 + parity green |
| T5 F11 | `node --test campaign.test.mjs interludes.test.mjs` then full native-campaign suite | 20/0 then 33/0 |
| T6 F08 | `godot --headless --audio-driver Dummy --script res://tests/protocol/audio_feedback.gd` | **412 checks / 0 failures** |
| T7 F07 | `node --test game/cadence.test.mjs` (new `cadence-source` gate) | 2/0; audit counterexamples reproduced |
| T8 F17 | `world_weather/unit.gd` (headless) and `world_weather/spatial.gd` (xvfb) | `WORLD_WEATHER_NATIVE_OK`, `WORLD_WEATHER_SPATIAL_OK` |
| T2/T3 | Flash decode-once (merged) + Space Bunny weapon profile worker branch | T2 merged (see ledger); T3 pending integration |

## Real process journeys executed

| Journey | Command | Result |
|---|---|---|
| Dev supervisor → menu → self-quit | `node tools/godot-dev/launch.mjs --experience=menu --smoke` | exit 0; `MENU_READY {"routes":26,"categories":5,"visible":16,"developer":false}` |
| Dev supervisor → menu with developer navigation | `COCS_DEV_MENU=1 node tools/godot-dev/launch.mjs --experience=menu --smoke` | exit 0; `MENU_READY {"visible":26,"developer":true}` |
| Client protocol input flow (campaign/arena/horde) | `godot --headless --script res://tests/campaign/input_flow.gd` | **1970 checks / 0 failures** (rerun after the W1 merge: still 0) |
| W1 decode-once guard (new gate) | `godot --headless --script res://tests/protocol/decode_once.gd` | `DECODE_ONCE_OK` — exactly one `JSON.parse_string` across the chain, in `net/client.gd` |
| Native client contract after W1 | `godot --headless --script res://tests/native_arenas/protocol/client_contract.gd` | `NATIVE_ARENA_PROTOCOL {"failures":0,"ok":true}` |
| Package suite with the receipt advance | `node --test tools/godot-package/*.test.mjs` (minus career_native) | **315 pass / 0 fail** (advance layer verified for all seven receipts) |

## Receipt advance (required because protocol/UI/audio files are receipt-pinned)

`godot/net/client.gd`, `godot/native_arenas/client.gd`, `godot/campaign/client.gd`,
`godot/ui/main_menu.gd` and `godot/world/audio_feedback.gd` are production
package inputs of all seven units, so their byte changes ship through the
sanctioned additive advance layer:

- `tools/godot-package/consolidation_dependencies.mjs` (newest layer; verifies
  and reverses to the exact committed predecessor).
- `tools/godot-package/reconcile_consolidation_advance.mjs` derives the layer
  from the unpromoted expectation closure, fail-closed on unreviewed drift.
- The apron/dressing/racing/movement/polish lanes resolve live bytes through the
  newer layer; every earlier lane still reconstructs its own history.
- The layer is reversed and re-derived after each worker merge, never stacked.

## Independent adversarial verification of the advance layer (Flash, read-only)

| Probe | Result |
|---|---|
| Reverse each of the 7 layers → committed predecessor bytes | **7/7 byte-identical** |
| `previousReceipt.sha256` identity + cross-receipt delta consistency | 7/7 PASS (same 11 changed + 1 added) |
| Forged `after` / `before` / deleted `added` / removed layer (direct verifier) | all **rejected** |
| Real byte mutation in a disposable tree | rejected by layer and by closure |
| `productionResources` strict (`worldIds` = 13) | **no pending**, 7 units |
| Package suite in a fresh worktree | **315 pass / 0 fail** |

Two review notes: the layer verifier alone accepts a *self-consistent* deletion of an
`added` entry (the production closure's exact packageInputs equality catches it),
and `previousReceipt` is format-checked inside the verifier (the reversal byte
identity and `verifyMovementPredecessor`'s hard-coded history hashes anchor it).
`consolidation_dependencies.test.mjs` now covers both cases (3/3).

## F08 source-side experiment (measured, not promoted)

Space Bunny's experiment on branch `audit/exp-f08-contact-20261006` (commits
`9206881c`, `7ae8411a`) adds explicit shot `blocked`/`contact` classification and
carries the causing weapon on damage events where the source knows it:

- Probes (real source `Match`, checked against both the source core and the
  regenerated campaign core): **38/38 checks**, including the audit cover
  counterexample (accepted shot, zero damage, `blocked:true`, `contact:"blocked"`),
  clear-line `contact:"actor"`, the muzzle stub, and same-batch/delayed-projectile
  weapon identity.
- Differential invariance vs baseline `59279c0e`: event streams identical modulo
  the new fields; shooter/enemy/match state identical across all scenarios.
- `port/native-campaign/core.generated.mjs` regenerated by the project generator
  (`--check` clean); source sha pinned to `b11165db…`.
- Boundary (expected, promotion-gated): 22/24 source tests — exactly the two
  hash-pin provenance failures; the receipt subset drops to 16/50 on the branch
  (no receipts touched, hash cascade only).

**Not promoted in this pass.** Promotion is a gated source-extension unit: new
`game/core.mjs` derivative layer + repointed active descriptor + regenerated core
+ receipt advance + migration of the four presentation consumers
(`player_fx/impacts.gd`, `game/feedback.mjs`, `game/view.mjs`,
`world/audio_feedback.gd`). Flash's independent verification confirmed the claims
and refined the recipe below; the branch is preserved for the gated phase.

### Independent verification (Flash, read-only) — claims verified, no counterexample

- Full diff inspection plus a mechanical additive-only proof: stripping exactly
  the advertised inserted tokens reproduces both `game/core.mjs` and the
  generated core equal to `59279c0e` (whitespace-insensitive), so nothing else
  changed.
- Own probes (31 checks × both cores): world-cover counterexample (0 damage,
  `blocked:true`, source `hit` still the camera candidate), two-enemy ray case,
  clear `contact:'actor'`, muzzle stub (no `hit` field), delayed-rocket launch
  weapon identity, melee/ability/sentry omissions, damage-before-shot order.
- Differential fuzz: 40 randomized seeds + a scripted matrix — event streams
  (after stripping the new fields) and actor/match state byte-identical;
  coverage 6744 shots / 2975 clear / 5 blocked / 802 damage samples.
- Regeneration: `generate-core.mjs --check` exit 0; all three SHA pins agree.
- Tests: only tests 17/18 flip to `not ok` vs the clean baseline; both are the
  `655f…→b111…` pin boundary. No other assertion regressed.

**Promotion recipe additions from the review:** include the
`port/finish/matrix.json` `lattice-source` oracle pin
(`tools/port/lattice/source-oracle.mjs` fails on the same boundary); cover the
`_flakBurst` shrapnel `shot` events that carry neither `blocked` nor `contact`
(consumers must tolerate undefined); add
`port/expansion-three/horde/analyze-trace.mjs` to the consumer migration list;
decide the vehicle-mounted chaingun attribution (`fireVehicle` omits `weapon:0`
although its `vehicle-shot` event carries it); and note that `contact:'world'`
includes open-air max-range shots (consumers must probe geometry before spawning
surface effects).

## F10 completion-policy experiment (measured, not promoted)

Space Bunny's experiment on `audit/exp-f10-completion-20261006` (commits
`50439b4a`, `f6c910a2`) adds an explicit, opt-in completion policy
(`restore-and-withdraw`) for exactly one encounter (`siltwake-crossing:1`),
leaving the shipped rule bit-for-bit as the control:

- **Control reproduces the audit finding** in a scripted match: `holdProgress`
  reaches 1.00 and the objective still refuses to complete while guards live
  (40 s sim, 208 damage, never completes).
- **Experiment**: completes with 4/4 guards alive; survivors withdraw via a
  bounded 73-tick despawn (no kill credit, no orphans, no damage after
  completion); partial kills bank exactly their kills and retry carries them
  without re-earning; leave/return, death/retry and whole-map completion all
  reach terminal states. All four other timed encounters still resolve to the
  control (progress 1.00 with guards alive → no completion).
- **Defect caught and fixed during measurement**: withdrawing guards previously
  counted against the next encounter for 71 ticks; now excluded
  (`encounterAlive`), re-measured at 0.
- Tests: campaign+interludes 20/0, new completion-policy 11/0, all
  native-campaign 64/0, feel + solo-cheats 13/0, eslint clean.

**Not promoted.** Open items before promotion: withdrawal is a despawn (no
walk-off presentation), the objective string is stale under the experiment, and
"smart play vs giving up" needs an owner playtest. The emitted
`campaign-guard-withdrawal` event is additive; `playerCarry` is untouched.

### Independent verification (Flash, read-only) — claims verified, no counterexample

- Control path is **bit-for-bit identical on the wire**: a deterministic
  1603-tick control trace hashes identically at `59279c0e` and `f6c910a2`;
  every behavioral change is gated and `playerCarry`/`campaignCheckpoint` are
  untouched.
- Independent harness (input for actor 0 only, so real NPC AI runs): **84/84**
  checks; author's probe table reproduced; 30-seed stress `bad=0`; drain is a
  fixed 73-tick deadline; 0 post-completion damage with live AI; kill-credit
  paths untouched (direct `health=0` bypasses `damage()`), banking exact.
- Falsification all negative: 4× death/retry after banking 2 cannot grow kills
  or carry; the policy census over all 20 encounters resolves only
  `siltwake-crossing:1`; 8 invalid policy names throw; other four timed
  encounters stay blocked under every policy request.
- Blast radius: 31/0, 64/0, 13/0, eslint clean.

Promotion-phase notes: (1) the committed "no damage after completion" test
disables NPC AI (`idleTick` supplies input for every actor) — the behavior is
verified but the test must be strengthened before promotion; (2) a latent
suppression bug exists in the currently unreachable two-opted-in-encounter
merge path (stagger timers pinned to the pre-extension deadline); (3) the
HUD/story `enemiesRemaining` still counts withdrawing guards during the grace
window (presentation-only; `live.mjs:36` surfaces it); (4) `dead:1e9` is a
behavioral value future consumers must not read as a respawn timer.

## F15 gate-tier inventory (merged)

`docs/audit-2026-10-06/GATE_TIERS.md` (`f1c34ce5`) classifies all **386**
registered gates into tiers (A deterministic 98 · B Godot headless 238 ·
C display-requiring 28 · D frozen pins 22 as a computed sub-count) and audits
candidate binding: `port_commit` and the derivative sha are real, but there is no
dirty-tree hash, no post-run tree state, no per-log candidate header, and four
registrations can fall back to a machine-path engine. It also records that only
`godot-native.yml` executes the registry (`ci.yml` runs zero registered gates),
that no audio-hardware gate exists, that 11 "smoke" gates are actually headless,
and that a second registry (`port/finish/matrix.json`) pins a different candidate.
Orchestrator spot-check confirmed the 384+2=386 count and the direct call sites;
independent verification (T18) recomputed the census and tier math from scratch —
the registry count, tier sums and every assignment were confirmed, and S2/S5/S6
were confirmed exact — and corrected seven presentation-level discrepancies in
the document (D-subset wording, the ±2 renderer-census split, a fifth
unpinned-engine fallback plus its reachability nuance, S9's arithmetic and two
citations); the merged `GATE_TIERS.md` carries the corrections.

## W1 decode-once independent review (Space Bunny, read-only)

Verdict: **VERIFIED, no behavioral counterexample.**

- The three moved validation bodies are byte-identical modulo indentation
  (`net/client.gd` unchanged since the merge); the only ordering change
  (native/base size guards before campaign checks) is unobservable because all
  three share one inherited `MAX_FRAME_BYTES`.
- Reconstructed pre-migration chain vs the shipped chain, same process: a
  46-frame battery with 40-field state fingerprints and ordered signal
  sequences — `BUNNY_DIFFERENTIAL checks=46 failures=0`; reconnect/identity
  scenarios 18/0.
- Runtime parse count on a malformed packet: pre-migration **3** (2 subclass +
  1 base) → post-migration **1**, always originating in `net/client.gd`; a 1 MB
  frame produces zero parses and zero `deliver_frame` entries, so rejection
  precedes parse.
- Required gates green: `DECODE_ONCE_OK` (10 checks, `singleParseInBase`),
  campaign client, native arena protocol, input flow 1970/0. The eight
  broader-suite failures were proven pre-existing/environmental
  (`Missing/empty manifest. Run semantic exporter.`): identical with the two
  migrated files reverted.

Gate weaknesses found by the review and fixed before merge (T19, commits
`85b1931e` + `e1a68289`): the original gate was purely lexical — a double
`super.deliver_frame` was accepted, a comment mention false-failed, and alternate
JSON APIs (including whitespace spellings) evaded it; a parse could also be
relocated out of `decode_text`. The hardened gate strips comments/strings,
detects parse APIs whitespace-insensitively, requires exactly one
`super.deliver_frame`, binds the base parse to the `decode_text` body, and carries
12 in-gate self-tests (checks 10→16). Flash found the initial whitespace and
relocation gaps; both are closed with pre/post falsification. Residual limits are
documented in the gate header: callable/reflection indirection, textual (not
call-graph) placement, semantic swallow, unverified check order, ungated
horde/lattice routes, and no runtime measurement.

Pre-existing latent hazards recorded (unchanged by the migration, out of its
contract): a non-string `type` raises a script error instead of the intended
`fail("Malformed JSON envelope")` (the base envelope check is unreachable
through both chains), and `input_epoch` mutates before validation, so a
rejected frame can wedge the connection. Scope gap: `horde/client.gd` and
`lattice/transport.gd` still parse twice per packet (pre-existing; follow-up).

## Explicitly unrun / not claimed

- The full `tools/godot-dev/verify.py` aggregate (**386** registered gates:
  384 table commands + the direct `toolchain-version` and `release-refused`
  probes; see `GATE_TIERS.md`) was dispatched at the W1-merged candidate
  (`59279c0e`) and was still running when this record was refreshed; its result
  lands in `port/reports/verification.json` and a final aggregate runs at the
  frozen candidate. The historical failed report is preserved at
  `docs/audit-2026-10-06/historical-verification-e530c1c9.json`.
- GPU/rendered captures, color-vision review, audio-hardware listening, human
  playtests, target-hardware latency/performance and the 4.7.2 engine trial are
  **unrun**. No hardware/visual/audio/human acceptance is claimed.
- Package builds/CI were not rerun for this candidate.
- The source-side F08 classification is implemented and measured on an
  unpromoted branch (see above); the weapon GLB material-role export (F17)
  remains a gated asset phase.

## New regressions observed

- **Menu disclosure (F12) selection-loop regression — found by the first aggregate
  run and fixed (`ef423531`).** `select_category` iterated every registry route and
  indexed `route_buttons[id]`, raising `SCRIPT ERROR: Invalid access to property or
  key 'viewer'` on the first hidden developer route; `main-menu-smoke` fails on
  ERROR lines even when the process exits 0. The button lookup is now guarded and
  hidden categories return early. Disk-free reruns: smoke output clean, contracts
  1153/0, both launcher journeys green.
- **The first aggregate run at the W1 candidate is not usable as evidence.** It was
  executed while the tmpfs holding `TMPDIR` was exhausted (61 G / 100 %); 43 gates
  failed with an environment-wide blast pattern. Gates re-run in isolation on a
  disk-free host (menu smoke, menu contracts, campaign client, input flow, package
  suite) pass, and the 384+2 registry completed (386 executed). The final aggregate
  at the frozen candidate is the authoritative record.
- **`product-shell-journey` is environment/harness-blocked on this host (not
  claimed, not a regression).** Its committed log proves it passed historically
  (`passed:true`, 18 visits). On this llvmpipe host the run proceeds through the
  first visit and return-to-menu, then the driver's own deadline —
  `max(240 s, 18 × 30 s) = 540 s` — kills the child (`exit_code:null`, 1/18
  visits) while the registered gate budget is 300 s. A `COCS_DEV_MENU=1` control
  run is in flight to test whether hidden-route navigation is implicated; the
  completing menu gates (smoke, contracts 1153/0, launcher journeys) are green.
  No pass is claimed.
- The F08 experiment branch fails only the expected hash-pin provenance boundary
  (no receipts or production files changed there). Worker-branch validation is
  recorded on merge.
