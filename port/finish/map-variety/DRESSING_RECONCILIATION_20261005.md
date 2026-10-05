# Runtime Moth dressing reconciliation (2026-10-05)

Parent record for integrating the three missing runtime dressing profiles and
advancing the seven production receipts. This is a supporting-input
reconciliation, not a native or visual acceptance.

## Delivered content

- `godot/multiplayer_worlds/dressing/profiles/vesper-viaduct.json`,
  `abyssal-pressureworks.json`, `stormglass-causeway.json` — authored profiles
  (materials/panels/signs/pockets/motes) whose selectors are the maps' actual
  glTF material names.
- `godot/multiplayer_worlds/dressing/profile.gd` — three new `IDENTITIES`
  entries; existing entries byte-identical.
- `tools/godot-multiplayer/new-maps/runtime-dressing/{author.mjs,check.mjs,validate_profiles.gd,README.md}`
  — reproducible authoring (emits the JSON byte-for-byte), an independent
  schema/selector checker (24 injected corruptions rejected; the three existing
  maps pass as controls), and a headless Godot validator that calls the real
  `Profile.validate()`.
- Integration: subagent branch `spacebunny/dressing-20261005` (`777328a6`,
  `3a493abc`) merged as **`09e10058`**; advance as **`28d862c1`**.

## Receipt advance (`dressingAdvance`)

All seven production receipts gained a `dressingAdvance` layer:

- `changed`: `godot/multiplayer_worlds/dressing/profile.gd`,
  `tools/godot-package/racing_dependencies.mjs`,
  `tools/godot-package/production_resources.mjs`.
- `added`: `tools/godot-package/dressing_dependencies.mjs`.
- `runtimeChanged`: `profile.gd` for `parallax-interiors` (its production-c
  native hook).
- Package fingerprints, previous-receipt commit/sha and the review boundary
  (`port/finish/map-variety/RUNTIME_DRESSING_THREE_MAPS_20261005.md`,
  `nativeChecks: pending`). `production_requirements.json` promotion pins
  updated.

The map profile JSONs load dynamically from `binder.gd` and are deliberately
**not** part of the static production closure; `profile.gd`'s advance carries
the runtime change.

Chain updates: `racing_dependencies.mjs` reverses dressing before
reconstructing pre-racing inputs; `production_resources.mjs` chains Parallax's
production-c runtime hook through dressing; four history assertions
(`feature`, `polish`, `promoted_assets_git`, `scenery`) walk the dressing layer
first.

## Verification

- `author.mjs --check` OK x3; `check.mjs` PASS x3 with 57 Moth resources
  resolved and the three existing maps passing as controls.
- Headless Godot on the integrated tree — **all six maps PASS** real
  `Profile.validate()`:
  `helix 9/12, gravemill 7/8, parallax 6/6, vesper 8/8, abyssal 6/6,
  stormglass 7/7` materials; zero failures.
- Full `tools/godot-package` suite: **310 pass / 1 fail**, the single failure
  being the pre-existing horde harness that requires `COCS_SOURCE_DERIVATIVE`.
- `verifySource`/derivative contracts unchanged: dressing files are Godot-side,
  outside the source lock and the racing derivative.

## Scope and operational notes

- `status: "ready"` is predicted, not proven: `binder.gd::_collect` instance
  overrides and `_sign` readability need a native load per map.
- The profiles are pinned to the current runtime geometry hashes
  (`27c71cc8…`, `32366a6c…`, `6afb8a36…`). If a map's art is promoted and the
  geometry hash changes, the profile becomes ineligible (silent no-dressing)
  and must be re-pinned with the new identity.
- Stormglass headroom is thin: 75/80 motes and 12/12 pockets; future additions
  need a profile edit.
- Nothing here is visual/native acceptance, and no promotion follows.
