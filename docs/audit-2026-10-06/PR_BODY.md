# Implement the 2026-10-06 audit: foundation, feel and disclosure increments

Candidate branch `audit/2026-10-06-implementation`, based on the audited
baseline `9b497d53c95b36198d5a0239ce578469b1acf358` (no source changes existed
between the audit and this implementation). Engine stays pinned at Godot
`4.5.2.stable.official.6ce3de25a`; no engine upgrade and no broad
source-extension is included.

This PR implements the audit's Phase 0 foundation and the safe Phase 1/2
increments. Each commit is a narrow, revertable release unit with its own
evidence; unrun/manual gates are never reported as passing.

## Foundation

- **F01 — one reviewed active-source descriptor.** `port/contracts/active-source.json`
  (+ `ACTIVE_SOURCE.md`, `tools/godot-dev/active_source.mjs`) names the current
  derivative and pins its bytes; the dev launcher, semantic exporter, verifier
  and package builder resolve it when `COCS_SOURCE_DERIVATIVE` is unset, and
  README/CI no longer select the stale lattice inventory. Historical
  lattice/movement contracts stay immutable. `core-provenance.test.mjs` keeps
  the movement candidate's claim at its frozen commits and adds an active-source
  test that verifies every current runtime byte through the reviewed chain.
  A modified source byte still fails closed.
- **F15 — gate/baseline record.** `docs/audit-2026-10-06/GATE_STATUS.md` separates
  the audited baseline failures from this implementation's results and lists
  every unrun/manual gate explicitly.

## Feel / gameplay

- **F11 — checkpoint reward continuity.** `campaignCheckpoint()` now carries a
  versioned player inventory snapshot (weapon, bounded ammo, clamped armor);
  death/Retry validates it fail-closed and restores it, so claimed workshop
  rewards survive retry without replay or duplication (`+35` armor and full
  ammo-cache probes covered).
- **F08 — truthful weapon attribution (presentation shipped; source measured).**
  Damage-confirmation audio resolves the causing shot's weapon from the same
  accepted batch instead of a stale last-held weapon; the audit's weapon-0-vs-8
  counterexample is a regression test. A source-side experiment
  (branch `audit/exp-f08-contact-20261006`: additive `blocked`/`contact`
  classification + weapon identity on damage events, regenerated campaign core)
  passes 38/38 targeted probes and differential invariance, and is **not
  promoted** — promotion requires a new `game/core.mjs` derivative layer,
  regenerated core and migration of four receipt-pinned presentation consumers.
- **F07 — cadence characterization.** A new `cadence-source` gate measures every
  primary weapon at 60 Hz: effective cadence is tick-quantized with bounded
  overshoot (Pulse Rifle `.1 s → 116.667 ms`, SMG `.058 s → 66.667 ms`), with
  tap/pause tests proving no catch-up burst. No balance change.
- **F05 — weapon presentation profile + sampled-animation pilot.** A shared
  immutable `WeaponPresentationProfile` now backs the first-person helpers
  (rig/handling/inertia/sprint-FOV/session-binding) with independently verified
  byte-identical parity (166-check executed parity, 84-row constant comparison
  zero mismatch, gate result lines unchanged) plus new gates
  `presentation_profile` 970 and `mechanism_pilot` 574. The reload pilot slaves
  a profile-named clip to source progress with cancellations and no rotation
  leak; the source Pulse Rifle currently cannot reload, so the pilot is
  test-exercised only. No visual acceptance claimed.
- **F10 — encounter completion policy (measured experiment, not promoted).** An
  opt-in `restore-and-withdraw` policy for `siltwake-crossing:1` lets the
  transfer objective complete while surviving guards withdraw (bounded despawn,
  no kill credit, no reward farming on retry); the control reproduces the audit
  finding (`holdProgress` 1.00, never completes while guards live) and its
  deterministic trace is bit-identical to the baseline. Independently verified
  (84/84 harness with real AI, 30-seed stress, negative farming/leak attempts).
  Not promoted: withdrawal presentation and an owner playtest are open items.

## Product / visuals

- **F12 — menu disclosure.** `lab`/`cheats` are declared `developer: true` in the
  generated registry; the menu hides those categories, routes and search results
  unless `COCS_DEV_MENU=1`/`--dev-menu`, `MENU_READY` reports
  `visible`/`developer`, and the stale `routes:22` comment is corrected. All 26
  declared capabilities and the launcher/supervisor contract are unchanged.
- **F17 — ground material role (attempted, reverted).** The dielectric ground
  change was measured and reverted: `godot/campaign/materials/ground.gdshader` is
  a production-receipt package input, so the byte change invalidated the receipt
  fingerprints. No production change is included; the correct path is the additive
  receipt-advance discipline plus the Blender weapon-material export.

## Verification (exact results in `docs/audit-2026-10-06/GATE_STATUS.md`)

- core-provenance 4/0 · semantic export exit 0 · modified-byte control rejects
- menu contracts 1153/0 · route parity 13/0 · `gen_routes --check`
- campaign + interludes 20/0 · full native-campaign 33/0
- audio feedback 412/0 · cadence 2/0 · world-weather unit + spatial contracts
- client input flow 1970/0 · real dev-launcher menu journeys (16 visible default,
  26 with developer navigation)
- receipt advance: independently verified (7/7 byte-identical reversals, all tamper
  probes rejected, strict closure clean) + dedicated consolidation contract test 3/3;
  regenerated for the W2 profile (16 changed / 2 added inputs, pending empty),
  package suite **318/0**
- first-person after the W2 merge: presentation_profile 970/0, mechanism_pilot 574/0,
  handling/recoil/ads/lifecycle/muzzle/detail/finishes byte-identical to base
- decode-once gate hardened to 16 checks (12 in-gate self-tests; whitespace and
  relocation evasions closed)
- F08 source experiment (unpromoted branch): 38/38 probes, differential
  invariance, only the expected hash-pin boundary failures

Not run and not claimed: the full 386-gate aggregate, GPU/visual captures,
audio-hardware listening, human playtests, target-hardware performance, package
CI and the 4.7.2 engine trial.

## Remaining blockers (documented, not hidden)

- F08 source-side `blocked`/contact classification is implemented and measured
  on `audit/exp-f08-contact-20261006`; promotion (derivative layer + regenerated
  core + receipt advance + four consumer migrations) is the next gated source unit.
- F17 weapon GLB rubber/ceramic role export needs the Blender master pipeline
  plus matched visual review.
- F02 round composition, F05 sampled-animation promotion beyond the pilot,
  F13/F14 visual capability work, F15 archive/deletion and the 4.7.2 trial
  remain gated follow-ups.
- F10's `restore-and-withdraw` policy is measured on
  `audit/exp-f10-completion-20261006`; promotion needs a withdrawal presentation
  pass, the objective-string update and an owner playtest.
