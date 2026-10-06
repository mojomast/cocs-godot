# F08 promotion: truthful shot/contact attribution, verifier hardening, and gated follow-ups

Follow-up to the merged audit implementation (#1). This phase promotes the
measured F08 source experiment into the active reviewed source, migrates every
presentation consumer, and lands the two small owner-approved verifier items —
with independent adversarial verification of the whole promotion.

## What changed

### Source: explicit shot contact + weapon attribution (F08)

`game/core.mjs` now emits, additively:

- shot events: `blocked: true` + `contact: "blocked"` when the muzzle ray is
  blocked before the camera candidate; otherwise
  `contact: "actor" | "vehicle" | "sentry" | "world"`. `hit` is unchanged — a
  blocked shot still names the camera candidate, which was the audit's
  counterexample.
- damage events: `weapon: <index>` wherever the source knows the causing weapon
  (hitscan, alt hitscan, detonate, explode direct/splash, pierce, chain, flak).
  Omitted for melee, abilities, sentries, rams and `fireVehicle` — no wrong
  data, just no claim where the source has none.

### Consumers migrated off reconstructing causality from `hit`

- `godot/player_fx/impacts.gd` — actor-hit accounting via `actor_contact()`;
  blocked shots become surface contacts.
- `game/feedback.mjs` — surface impact/ricochet cue decided by classification.
- `game/view.mjs` — effect placement from `contact`, never the blocked camera
  candidate.
- `godot/world/audio_feedback.gd` — prefers the damage event's own `weapon`,
  keeping the same-batch/cache fallback.
- `port/expansion-three/horde/analyze-trace.mjs` — counts hit shots by contact.

Legacy producers (older cores, flak shrapnel, melee) keep the previous `hit`
semantics through a tri-state classifier (`null` = no claim).

### Reviewed source chain: contact derivative layer

- New `tools/godot-package/contact_derivative.mjs` resolves on top of the
  receipt-pinned racing chain; the movement and racing resolvers stay
  byte-identical and every historical contract delegates unchanged
  (inventories 13 / 14 / 15 files).
- `port/contracts/contact-candidate-derivative.json` pins the reviewed bytes:
  `game/core.mjs`, `game/feedback.mjs`, `game/view.mjs`.
- `port/contracts/active-source.json` points at the contact contract; the
  provenance tests compare current bytes through the new chain.
- `godot/source_operators/moth_finish/manifest.json` updates its art-reference
  digest for `game/view.mjs` — reviewed promotion data, not a silent rewrite.

### Receipts

One fresh consolidation layer re-derived from the pre-advance restore commit
across all seven production receipts (`pending: []`), now carrying the F08
sources, the impacts consumer, the regenerated campaign core, the manifest
update and the new resolver. Robot source closures and polish additions resolve
through the newest reviewed lane; the transaction is idempotent at an
already-advanced HEAD and the restore path reproduces the committed receipts
byte-for-byte.

### Verifier hardening (owner-approved)

- Seven gates that print their success markers with zero failures now allowlist
  the two exact generic scene-tree engine prints from untouched code; all seven
  re-verified passing under the runner's exact logic.
- Exact-candidate binding: `verification.json` records `port_tree` and a hash of
  the tracked binary diff; every gate log carries a candidate header; the
  resolved `GODOT_BIN` is exported to child processes.

### Scheduled / recorded

- `docs/audit-2026-10-06/ENGINE_TRIAL_PLAN.md` schedules the Godot 4.7.2 trial
  as its own gated phase and PR (trial-only, delta report, decision gate).
- `port/map-finish/gravemill-foundry/author.py` documents its superseded
  historical status.

## Verification record

Headless/deterministic only; no visual, audio-quality or human claim is made.

- Package suite: **318/318 pass, 0 fail** (includes committed-tree validation
  and all seven unit closures).
- Semantic export through the active contact chain: exit 0; active descriptor
  resolves the contract with matching sha.
- Provenance `4/4`; campaign + interludes `20/0`; JS suites `313/0`.
- Godot: audio feedback 416 checks; first-person lifecycle 63; first-person
  presentation 970; presentation replay 6 states; main-menu smoke; menu
  contracts 1153; player-fx impacts 54.
- Independent adversarial cross-review (separate agent, own worktree):
  contract before/after byte-truth and inventories 13/14/15, historical
  contracts untouched, active-source sha, three tamper probes (contract flip →
  export fails; core rollback → provenance fails; descriptor sha), the named
  node suites (24/0), the package suite (318/318), and the F08 Godot gates
  (416 / 970 / 1153 / 54) with no engine-error lines. The first pass found and
  this phase fixed three defects: an analyze-trace import of the deleted
  classifier module; three stale absolute impact counts caused by the new
  blocked-surface draw (now asserted against captured counters — a falsifying
  occlusion mutation makes the check fail, then the file was restored
  byte-identically); and the advance transaction's non-idempotence at HEAD
  (now a true no-op; the restore path at `c04dfefe` re-derives all seven
  receipts plus the requirements byte-for-byte).
- Two pre-existing F01 source-drift tests (`source-inventory`,
  `source-selection`) remain red in the tree and are unaffected by this phase;
  they are already triaged in `GATE_STATUS.md`. Residual, disclosed: active
  `game/core.mjs` and the generated derivative disagree on `hit` for blocked
  shots — benign for every migrated consumer, but a future `.hit`-only reader
  would need the classifier.

## Not claimed / gated follow-ups

- Owner-run visual/audio/full-round acceptance remains unrun.
- F10 restore-and-withdraw stays unpromoted pending owner playtest.
- `fireVehicle` weapon attribution remains an open decision (no wrong data).
- Source-lock drift in the strict-source straggler tools and the unattributed
  fixture failures remain triaged follow-ups, not part of this phase.
