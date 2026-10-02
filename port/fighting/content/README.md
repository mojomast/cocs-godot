# Operator Clash content handoff

**READY FOR CORE/NATIVE COMBO VALIDATION.** This is authored source content, with
human balance, actual core combo proof and native animation acceptance pending.

## Deliverables

- `godot/fighting/data/roster.json`: nine source-identity operators, 138 explicit
  records: 9 normals + 2 normal throws + 3 specials + super each, plus Gemini's
  three listed palm-stance variants. HP/walk/weight match DESIGN.md exactly.
- `godot/fighting/data/rules.json`: 60 Hz integer-mm rules, 99 seconds, two round
  wins, six-tick buffer, ten-tick normal throw tech, bounded combo/meter policy,
  separate high/low Guard and player-facing notation help.
- `CONTRACT_DETAILS.md`: concrete optional mechanics proposal for Astra/parent.
- `MOVE_LIST.md`: original names, input notation, damage/frame/reach tables,
  descriptions, counterplay and three proposed routes per operator.
- `COMBO_ESTIMATES.json`: 27 finite mathematical estimates with cancel timing,
  available stun and slack, explicitly excluding runtime contact/landing proof.
- `ANIMATION_COVERAGE.json`: complete unique-GLB clip requirements, move-local
  contact/mobility/counter windows and paired attacker/victim timelines. This is
  an authoring manifest, not an assertion that GLBs or clips already exist.
- `godot/fighting/data/schema.json`: complete strict authored-field shape, including
  optional mechanic dictionaries; unknown keys/enums and unsafe integers fail.
- `tools/fighting/content/balance_targets.json`: machine-readable initial intent;
  roster remains authoritative runtime data. `state_keys.json` pins universal clips.
- `FREEZE.json`: SHA-256 machine-input/data freeze and informational provenance.
  Human prose is excluded from enforced hashes. Source identities
  are imported from `game/data.mjs` CHARACTERS, never edited. Seven harnesses are
  source-audited metadata, not 63 fighters or a second loadout move system.

## Source commands

```sh
node tools/fighting/content/validate.mjs
node --test godot/tests/fighting/content/*.test.mjs
```

`tools/fighting/content/author.mjs` is the explicit-table authoring recipe. Running
it regenerates roster/rules, move reference, manifest, estimates and freeze.
An optional output-directory argument writes a fresh isolated output tree for
byte-for-byte reproduction checks. Regenerate only for an intentional content
revision: validation checks the current
freeze without rewriting it. Node validation is a data/schema invariant check;
it contains no authoritative combat simulation.

## Integration and actual combo verification

1. Reconcile the optional typed fields with `core/simulation.gd` before treating
   operator distinctions as implemented. Parent/core should reject unsupported
   mechanics, rather than silently substitute generic hits. Important cases:
   Claude reflect/capture, Meta armor/grab, Gemini timed palm stance + one double
   jump, DeepSeek back charge + fuel hover, Mistral one air dash, Kimi telegraphed
   noninvulnerable blink, Qwen expiring one-trigger anchor, ChatGPT contact pull,
   Grok down-charge jump and armored tackle.
2. Start native training using the authoritative configured roster/rules. Place
   fighters using each trace's fixture preconditions; air-corner traces begin
   with both actors already airborne. DeepSeek includes a real 36-tick back-charge
   setup; maintain its back hold through normals and forward release for S1.
   Grounded fixtures start at the rules' legal pushbox width (660 mm). During
   DeepSeek's charge, replay its explicit `defender_setup_inputs` using the same
   initial attacker-facing conversion, so the same-operator dummy walks alongside
   the attacker through ordinary inputs. Release the dummy at first attack.
   Place the actors once before playback; never teleport them per step.
3. Expand sparse trace samples to two canonical input dictionaries each tick.
   Use `trace.mjs`: a duration holds axes/buttons, while a rising-edge `pressed`
   hint is emitted only on the first tick; unspecified ticks are neutral. Core
   derives actual edges from held history. Down=-1, up=+1; mirror facing-relative
   horizontal axes into canonical world-left/right values.
4. Execute `step` and record contact events, attacker move/frame, victim stun,
   combo count, damage, resources and landing. Assert each intended contact
   lands before stun release, with no unrecorded neutral gap and all intended
   moves recognized. Include projectile travel, hitstop freeze, pushback and
   hitstun deterioration. Verify both facing directions and defender ordering.
5. Correct schedules/data if native core exposes gaps; record trace/core/data
   hashes and tick-by-tick results, then mark only those traces `core_verified`.
   Save/load replay of the same input must reproduce results. Runtime clamp,
   charge expiration, throw immunity, trap expiry and combo-cap enforcement are
   core tests; bounded numeric data alone does not prove them.

First-contact estimates do not model swept projectile collision, high/low guard,
corner pushback, invulnerability, vertical trajectories or animation quality.
The authored routes are candidates rather than promises of unavoidable damage.

## Acceptance record

Source validation checks exact imported roster identity and machine balance targets;
all move fields, common animation/effect keys, explicit variants, bounded windows,
acyclic cancels, finite projectiles/traps/resources and mathematical trace gaps.
Mutation tests demonstrate rejection of missing specials, copied fingerprints,
bad boxes, resource overflow, increasing scaling, unsupported movement, infinite
cancel cycles, missing animation requirements and insufficient stun.

No human fighting-feel/balance decision has been made. Frame/damage values are
new original fighting targets, not FPS ranges or cooldowns. Reach uses mm/1000
metres against an 1800 mm reference body, with melee <=3.5 m and projectile <=7 m.
All clip common keys remain per-operator GLB-local; authored movement identity
and source/native inspection are separate author gates.
