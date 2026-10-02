# C2 / C3 / F9 bounded content correction

Basis: efficiency architecture audit `aa3f9bff`, parent integration `b0669433`
and reviewed prose-hash repair `10a90fd0`. Work remains in the existing content
lane; no parent branch merge or runtime implementation is part of this correction.

## C2: complete strict authored schema

`godot/fighting/data/schema.json` and its `schema.mjs` generator enumerate every
existing field, including all optional projectile, movement, throw, counter,
armor, resource-effect, stance and input members. Node validates structural types,
required members, finite safe integer bounds, enums and unknown keys before
cross-field validation. Malformed containers return errors instead of exceptions.

Cross-field checks cover invulnerability sentinel pairs/windows, incompatible
air/ground restrictions, charge axis/frame pairs, operation-specific pull/anchor/
air-use fields, resource references/costs, stance mappings and paired chronology.
The schema preserves existing data and mechanics; Astra owns core handler support.
No new physics or combat authority is implemented here.

## C3: machine oracles and narrow freeze

- `balance_targets.json` contains the exact original nine HP/walk/weight targets;
  validator consumes JSON instead of regexing DESIGN Markdown.
- `state_keys.json` pins all 22 actually specified universal state keys. The audit's
  approximate 25-state count is not used as a new requirement.
- Runtime `roster.json` stays authoritative; generator consumes machine targets
  instead of maintaining a second stat table.
- Enforced freeze covers runtime/generator/schema/machine-data inputs. No `.md`
  file is an enforced hash. Historical DESIGN hash is informational provenance.
- The source boundary base is explicit freeze metadata rather than an evidence
  runner literal. Its existing baseline remains `37dd3da4`.
- A fresh-directory generation test compares all generated artifacts byte-for-byte
  without writing into the working tree or refreshing hashes to conceal drift.

## F9: coverage and canonical input expansion

Manifest validation requires exact operator/state/combat/victim sets and checks
contact windows, projectile spawn, movement/counter windows, paired contact/damage/
release, victim placement, side swap and socket mapping against roster data.
Fingerprints now cover every gameplay field, with stable nested-key ordering;
only presentation names/prose/animation/effect IDs are excluded.

`trace.mjs` is an input-expansion helper. Canonical down=-1/up=+1 and mirrored
world left/right are explicit. Sparse single-tick samples release on unspecified
ticks; duration samples preserve held buttons and emit one expected rising-edge
hint. Overlaps, invalid durations and hints inconsistent with held history fail
source validation. Actual core derives edges independently; caller hints do not
authorize attacks. All 27 authored sparse traces remain unchanged.

## Verification and scope

The existing 14 tests are retained with strict-schema diagnostic assertions;
new negative cases cover each actual mechanic member's type, missing required
members, numeric finiteness/ranges, enums, booleans and unknown keys, plus manifest
drift, expanded fingerprints and input-duration semantics. Fresh generation and
enforced prose exclusion are tested.

Final source gate: **215/215 tests pass** (14 retained + 201 new), strict validator
passes, fresh generation passes, frozen-source boundary diff is empty, and
`git diff --check` passes.

Runtime roster/rules and existing animation/estimate/move-list outputs remain
byte-identical to `79d98652`. Newly generated data consists of schema metadata and
the revised freeze. Nine distinct operator motions are still required in full.
The actual 27 native combo traces and human balance remain pending. No native or
heavy tool process was run; Foundry retains its heavy slot.

Evidence: `/home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002/correction-C2-C3-F9/`
