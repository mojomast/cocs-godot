# Content source validation — 2026-10-02

**READY FOR CORE/NATIVE COMBO VALIDATION**

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
