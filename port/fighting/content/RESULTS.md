# Content source validation — 2026-10-02

**READY FOR CORE/NATIVE COMBO VALIDATION**

## Latest: actual native-03 follow-up

- Actual engine baseline: **54 cases, 16 passes, 38 failures; 54/54 replay matches**.
- Every original failure is mapped to contacts/starts/frame witnesses in
  `NATIVE_03_DIAGNOSIS.json`; original integration evidence is untouched.
- All 16 passing facing cases are preserved byte-for-byte. Revised candidates
  correct the 19 failing routes through input/route/setup changes only.
- Two-hit basic confirms, continuous Meta/Qwen crouch direction, Grok grounded
  corner grenade practice and three paired ordinary-jump air routes are authored.
  Four harder air-projectile finishers remain intact, with four-tick-later inputs
  and an explicit dependency on Astra's landing-timer repair.
  No single-hit replacement or signature removal; three routes/operator remain.
- All move balance/boxes/timings, rules and animation coverage are unchanged.
- Core landing timer latch is reported with exact committed code/frame witnesses
  for Astra; this lane makes no core changes.
- Source suite: **227/227 PASS**; fresh generation and frozen-source checks pass.
  Revised candidates remain proposed pending an actual-engine rerun.

Details: `NATIVE_03_FOLLOWUP.md`.
Source evidence: `/home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002/native03-followup/`.

The following sections retain earlier source-only checkpoints.

## Latest: legal grounded fixture correction

- Verifier `9549da1c` found the original 550 mm fixture inside 660 mm pushboxes.
- 18 ground candidates now use `rules.pushbox.w` (660 mm); nine air candidates
  retain their original fixture and input data.
- DeepSeek records a second ordinary-input charge-follow stream for the defender.
- Full source suite: **222/222 PASS**, with fresh generation passing.
- Moves, stats, resources, attacker samples, rules and animation timings unchanged.
  Runtime roster changes intentionally through combo metadata; parent effects/data
  contract hash synchronization is required after integration.
- All 27 actual core combo validations remain pending; no native engine run.

Details and roster hash: `GROUND_FIXTURE_CORRECTION.md`.
Evidence: `/home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002/ground-fixture-correction/`.

## C2/C3/F9 correction verification

Evidence:
`/home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002/correction-C2-C3-F9/`

- Strict full-field schema and semantic validation: **PASS**.
- Existing 14 tests plus 201 new focused negative/reproduction cases: **215/215 PASS**.
- Fresh-directory generation equals all current generated artifacts: **PASS**.
- Runtime roster/rules, animation requirements, estimates and move list compared
  with `79d98652`: **byte-identical**.
- Enforced freeze excludes every Markdown file; historical prose hash is
  informational. Exact initial intent and state keys are machine-readable JSON.
- Input expansion follows down=-1/up=+1, one edge per held transition and natural
  release on unspecified sparse ticks; actual core remains edge authority.
- Frozen source boundary diff and `git diff --check`: **PASS**.

No native engine/heavy tools were run. All 27 actual core combo validations remain
pending. Details and concrete integration contract: `AUDIT_CORRECTIONS.md` and
`CONTRACT_DETAILS.md`.

## Original authoring checkpoint

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002`

| Source gate | Result |
|---|---|
| Imported CHARACTERS identity and exact DESIGN targets | PASS, 9 operators |
| Required common moves and explicit stance variants | PASS, 138 records |
| Three proposed traces/operator and mathematical cancel/stun estimates | PASS, 27 traces |
| Complete authored clip requirement manifest | PASS, 336 state/combat clips + 225 victim instances |
| Shared paired timeline requirements | PASS, 25 attacker timelines |
| Focused source/mutation tests | PASS, 14/14 |
| SHA-256 authored-data freeze | PASS |
| `git diff 37dd3da4 -- game server port/contracts/source-lock.json` | PASS, no changes |

Eight operators have 15 records each; Gemini has 18 including `palm_l`, `palm_m`,
`palm_h`. All nine have three independently listed traces. The manifest has 22
state clips per operator, 138 combat clips, and every victim GLB must cover all
25 paired throw/counter variants; these numbers describe requirements, not built
or accepted animation assets.

Actual simulation execution, native contacts/combos, runtime resource clamps,
Blender/GLB authoring, native art and human fighting balance remain pending.
No Godot, Blender, heavy Helix-slot job or nested agent was run.

To reproduce evidence:

```sh
node tools/fighting/content/evidence.mjs /home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002
```

The evidence runner validates without regenerating authored data, records both
source-check logs and a machine-readable summary, and checks the frozen boundary.
Data-mechanics reconciliation is tracked in `CONTRACT_DETAILS.md`; the concrete
input and native verification procedure is in `README.md`.
