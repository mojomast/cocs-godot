# Actual native-03 content follow-up

**Revised candidates ready for actual-engine rerun; not newly native-verified.**

The native run tested committed core `a84f6961` with source/JSON identity repair
`065d78a5`. Tested roster hash matches content checkpoint `242d5741` exactly:
`a736dcfe91d44a08b165e1f7191420617984a561972505b0dd53df1b22cd4748`.
Its 54 cases produced 16 passes, 38 failures and **54/54 equal replay comparisons**.
Original evidence remains untouched under:
`/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/fighting-native-03/`.

`NATIVE_03_DIAGNOSIS.json` maps **every case in both facings**, retaining actual
contacts, combo counters, move starts, third-input state and first-active boxes
where present. Its evidence SHA-256 pins the original report. No Node combat
simulation or native engine execution was used to construct this diagnosis.

## All 38 failures mapped

| Cases | Operators/routes | Observed cause | Candidate correction |
|---:|---|---|---|
| 12 | ChatGPT, Claude, Grok, Gemini, DeepSeek, Kimi basic; both facings | L/M connect continuously; third normal starts but its active box misses the displaced victim. ChatGPT victim x=1291 already at H start, and moves farther during H startup. | Two-hit basic L/M confirm using the observed contacts; preserve three-hit special and air practice. |
| 8 | Meta/Qwen basic and signature; both facings | Crouch M never starts. Separate down taps with neutral between satisfy the recognizer's `22` mobility motion inside its 18-tick history. Later H/S1 connects as a fresh hit after stun. | Hold down continuously through crouch L/M. Basic is two normals; signature retains its third S1. |
| 2 | Mistral basic; both facings | Crouch H never starts after the second down tap: the same `22` priority consumes it. At the third-input witness the victim is also already beyond that short H's box. | Use the two recorded continuous normals as basic; preserve both native-passing three-hit signature and air candidates. |
| 2 | Grok signature; both facings | S1 actually connects at tick54 after L@4/M@18, but the combo counter resets. Projectile travel and arc delay exceed remaining stun. | Keep the arcing grenade as third attack in an explicit grounded corner-pressure candidate. Corner reduces early travel so contact can occur before the arc passes above the standing hurtbox; no trajectory/stun edit. |
| 6 | Claude, Meta, DeepSeek air; both facings | Attacker lands at tick21 before third H input (tick31–34). It is grounded with `landing_left=4`; no third move starts. H also now recognizes a standing move instead of air H. | Start grounded at legal 660 mm corner spacing and jump both actors through ordinary Up edges at tick0. Begin L/M/H air normals at tick8 during ascent, avoiding the original descending fixture. |
| 8 | ChatGPT, Gemini, Kimi, Qwen air; both facings | Attacker lands at tick21; third projectile input (tick28–30) is blocked by `landing_left=4` latched during air M. Existing L/M contacts are continuous. | Retain the harder projectile finisher and original physical fixture. Delay its input four ticks to cover ordinary landing recovery. Explicitly blocked on Astra's landing-timer repair; no substitute normal or specially tailored fixture hides the core issue. |

The basic reduction is deliberately **two hits**, never one hit. Full roster,
all 138 move records, three distinct practice routes per operator, the harder
three-hit specials and air routes remain. Command grabs and their escape/throw
immunity mechanics remain intact; no invalid guaranteed hitstun grab is introduced.
All four harder airborne-to-projectile finishers remain in their original routes.

### Preserve the native successes

All eight previously passing candidates (16 facing cases) remain byte-identical:
ChatGPT/Claude/Gemini/DeepSeek/Mistral/Kimi signature routes, plus Grok/Mistral air
routes. The source test asserts that identity. Their replay evidence is retained,
not substituted with mathematical estimates.

## Precise core issue for Astra/parent: landing timer latch

In committed `simulation.gd`, `_physics` lines 466–471 sets `landing_left` on
landing during a committed attack. `_try_move` lines 337–339 rejects every buffered
move while the counter is positive. The counter decrements only in `_locomotion`
lines 408–415, but `_advance` lines 318–335 invokes locomotion only when no move is
committed. Consequently the counter remains four throughout the old air M recovery
and the six-tick buffered third input expires. Concrete witness: ChatGPT air route,
positive facing, trace tick28: y=0, move=air_m, frame=10, landing_left=4,
victim stun=24; no special1 start occurs. Other 13 air failures show the same latch.

Astra should decide and repair landing recovery advancement on non-hitstop ticks
while an attack is committed, with a regression for landing during an attack and
a legal grounded follow-up. Avoid double decrement when locomotion resumes.
Simply repairing the timer does not make a ground-recognized H into an air H.
The ordinary-jump content correction remains necessary for the three air-normal
routes. The four retained projectile routes require that timer repair plus actual
contact/continuous-stun verification with their four-tick-later input; no new
trajectory success is claimed. **No core file is changed by this lane.**

## Content changes and verification

- No HP, walk, weight, jump, resource, damage, stun, hitstop, cancel graph, move
  startup/active/recovery, hit/hurt/push box, projectile or movement values change.
- Legal initial ground spacing remains 660 mm. DeepSeek charge follow remains
  ordinary inputs; new air setups contain only Up edges, no y/vy injection.
- Grok's corner fixture is a normal matchup situation, not a shrunken collision
  box or per-step repositioning. Its actual new contact tick must be verified.
- Generator, roster traces, strict schema, estimates, move help and freeze are
  updated reproducibly. The diagnosis tool only condenses existing evidence.
- Revised roster SHA-256:
  `1cb28db7f34fefe3c37ccb8f4b5a54822465d2b28fa8a6401ab0fa8fd77e5e02`.
- Source suite: **227/227 PASS**, including preservation of valid native cases,
  balance-field identity, no one-hit routes, ordinary jump setup and continuous
  crouch direction. Fresh-directory reproduction and frozen source boundary pass.
- Rules and animation coverage remain byte-identical. Parent should refresh only
  canonical content hashes after integrating the final candidate revision.

Source evidence:
`/home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002/native03-followup/`.
All changed candidates remain `proposed`; no revised trace is promoted to verified
without the actual native rerun. No native/heavy grant or nested agent was used.

To reproduce the read-only diagnosis against the same preserved report:

```sh
node tools/fighting/content/diagnose_native03.mjs /home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/fighting-native-03/actual_content-detail.json
```
