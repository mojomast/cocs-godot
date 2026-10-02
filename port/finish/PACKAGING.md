# Finishing package closure — Astra worker

## Resumed Windows release preparation

The packaging lane has now merged canonical `e38b3662` at `88cbc406` and prepared
fighting/operator-finish/Moth raw-resource closure plus pinned Windows CI. See
[RELEASE_PREP.md](RELEASE_PREP.md) for the current source checkpoint, 234 passing
non-engine package checks, exact candidate/grant procedure and remaining native
acceptance. The following first-pass record is retained as historical evidence.

## Scope and acceptance boundary

Base: `6cefd9eb`, branch `finish/packaging-20261002`. Published runtime remains
`e731fd53`; its recorded 359 canonical gates and 75 extracted cases per platform
are historical acceptance, not results of this worker. No release/tag, source
lock, reviewed derivative, core bytes, production map registry or accepted mode
pair was changed. No Godot, Blender, import, export or native capture was run.

Evidence (including failed attempts):
`/home/mojo/.tmp-on-disk/cocs-finish-packaging-evidence-20261002`.

## Implemented files and closure

- `tools/godot-package/build.py`: committed build inputs include the separate
  replay runtime and feature catalogs. Adds explicit staged export filters for
  `input_bindings/contexts.json`, `replay/admission.json` and
  `audio/telegraphs/manifest.json`. Existing `experience/*.json` already covers
  both `source_catalog.json` and `public_event_types.json`. The project-level
  diagnostic export preset is not used by this builder.
- `feature_resources.mjs`: exact feature-anchor/data relationships, InputBindings
  autoload contract, 160 unique telegraph filenames and manifest/PCM hash checks.
  Threat service/policy are included. The audio generator gets a deterministic
  `--check` before packaging; its source is recorded as a build input.
- `replay_runtime.mjs`: exactly `game/demo.mjs`, `godot/replay/admission.json`,
  `tools/port/replay/adapter.mjs`, `tools/port/replay/service.mjs`, plus a generated
  local manifest under `replay-runtime/`. Copies only bytes matching the recorded
  commit, verifies the demo hash against admission, refuses an existing output,
  and validates all inputs before creating output. No authority or dependency
  tree is bundled in this separate runtime.
- `manifest_validation.mjs`: binds that four-file closure and feature-resource
  hashes to the artifact's recorded commit. Missing helpers, omitted fields and
  forged refreshed manifests fail. Re-derivation remains recorded-commit based;
  older artifacts are not required to acquire newly introduced feature fields.
- `world_closure.mjs`, `discover.mjs`, `world_resources.mjs`: preserve the seven
  original worlds and exact 43 original pairs. Only production `WORLDS` entries
  grant additional pairs, bounded to Helix, Gravemill, Parallax, Vesper, Abyssal
  and Stormglass IDs. Merely having a generated JSON or art file does not register
  anything. Empty/duplicate/unknown modes and unknown IDs fail.
- Complete standalone canonical wrappers are validated by the real `readWorld`
  path without passing their overheads through the old baker again. Accepted
  new assets must exist at `res://multiplayer_worlds/art/<id>/<id>.glb`; original
  urban/worlds art bindings remain intact. The existing tracked multiplayer
  authoring-input inventory remains part of build provenance.
- `verify_expansion.mjs` and `godot/tests/package_expansion.gd`: derive coverage
  from accepted pairs, retain every original pair and use explicit named art
  paths for new maps. The Sirocco fourteen-gate assertion is scoped to Sirocco,
  not every future racing map.
- `verify_features.mjs` and `godot/tests/package_features.gd`: additive extracted
  PCK JSON-hash/resource/autoload probe, plus an actual separate replay-helper
  process from a fresh CWD with spaces. Checks authenticated ping/list and rejected
  COCS recording; no authority is started by this helper test. Windows uses the
  package's `node.exe`; Linux uses the invoking Node executable. Existing platform
  verifiers call these checks when their recorded feature inventory is nonempty.
  Their cross-platform execution guards remain intact.
- `finishing_closure.test.mjs`: four non-engine tests for future accepted catalog
  pairs, unchanged baseline pairs, artifact commit binding, dirty checkout
  independence, missing/corrupt helpers, refreshed forged inventories, missing
  catalogs and InputBindings autoload validation. Git fixtures are integrity
  fixtures, explicitly not substitute runtime/native acceptance.

## Integration dependencies and required shared hooks

The integrator owns the prepared feature commits. This branch does **not**
cherry-pick `8d7bf0c3`; retain its challenge-authority launcher/factory and discovery
changes when applying this packaging commit. The discovery edit here only changes
world catalog derivation. Source challenge modules stay port-owned, with original
source and reviewed derivative provenance frozen.

Read inventories from the feature worktrees: pass-two Experience
`8d1efc60`, Controls `9aa752a8`, Replay `9794575a`, Audio `bf4d8865`, and the three
WORKSTREAM documents. Actual audio, controls and Experience resource inventories
were checked directly in those worktrees without modifying them.

**Required replay integration follow-up:** the prepared `godot/replay/bridge.gd`
currently falls back to `res://../` when its packaged service is absent. The
integrator's direct Home Replays entry must retain zero authority startup, choose
development paths only under `OS.has_feature("editor")`, and otherwise anchor to
the executable's `replay-runtime`. Before spawning, check its local manifest's
exact four paths and each SHA-256; missing/corrupt input must emit the existing
readable error, never retry a checkout helper or start authority. On Windows use
the bundled `node.exe` and fail clearly if it is absent; Linux uses `node` (or an
explicit bundled `node`). This worker's external verifier validates missing/corrupt
packages, but it does not by itself change the native bridge's startup behavior.

Map/robot/vehicle/scenery native acceptance remains the parent's responsibility.
No candidate map was registered here. Parent should add only granted pairs to all
production catalogs and reconcile the named art binding in the production map
renderer; packaging support is not an acceptance grant. Standalone generation
checks and full native movement/round/art inspection must pass before registration.

## Executed verification

1. `focused-tests.log`: 55/55 tests passed (initial new tests, manifest validator,
   extracted expansion contracts). The first attempt lacked the worktree's `ws`
   dependency; `initial-tests.log` retains that failure. Tests then used the existing
   dependency tree through an ignored local `node_modules` symlink.
2. `nonengine-package-tests.log`: **221/221 passed** with the reviewed derivative
   selected, excluding `career_native.test.mjs` and the known stale
   `native_arena_authority.test.mjs`. This includes 45 recorded-commit manifest
   tests and older-artifact/dirty-checkout behavior.
3. `final-new-tests.log`: **4/4 passed** after adding the fourth feature-provenance
   negative test. The larger run above contained the first three new tests.
4. `replay-branch-tests.log`: **15/15 actual replay adapter tests passed** on its
   prepared branch. `replay-package/replay-runtime` was copied from recorded
   `9794575a` using the new builder helper, and `replay-check/replay-result.json`
   records a passing actual extracted helper process/authentication/library test.
   Separate actual-helper corrupt/missing copies both failed before process
   startup; their package copies and failed reports are retained under
   `replay-{corrupt,missing}` and `replay-{corrupt,missing}-check`.
5. `audio-closure.json`, `controls-closure.json`, `experience-closure.json`:
   successful actual feature-branch resource inventory. `audio-generator-check.log`
   records deterministic 160-file PCM reproduction. `base-discovery.json` and
   `world-resources.json` retain the base runtime/accepted-world closure.
6. Python 3 AST parse of `build.py` and `git diff --check` passed.
7. Actual committed-object closure re-derivation at implementation commit
   `8522dcde` passed: 85 source modules, 38 port adapters and seven original world
   files. `committed-discovery.json` records the result; no checkout runtime was
   used for that re-derivation.

`package-tests.log` retains the broader initial attempt: 218/226 passed. Four
synthetic discovery failures were fixed by deferring world-catalog loading until
its entry exists. One source-lock failure needed explicit derivative selection.
One native test stopped at its missing `GODOT_BIN` prerequisite; no engine ran.
Two existing factory expectations still assume max seven bots while the current
launcher permits 24; these are outside the changed closure and remain reported.

**Integrator follow-up:** `76c6a9ec` supersedes those remaining factory failures.
The configured production bounds are explicitly 1..24 in both launchers and the
native authority's reviewed local-roster adapter. Dev/package factory fixtures now
retain 1/7/8 coverage, add an actual 24-bot source round, and reject both 0 and 25.
The source-only combined package suite passed those factory cases. Its separate
85-module Horde assertion was also reconciled to the integrated challenge route:
86 frozen source modules, with named challenge adapter/module inclusion and Horde
isolation assertions. The original packaging evidence above is retained.

The required exported Replay bridge startup repair is implemented in that same
integrator commit. See `HOME_REPLAY_HOOK.md` for exact paths and the prepared
48-check native negative journey; native execution remains deferred.

## Integrated commands (native commands await parent grant)

```sh
COCS_SOURCE_DERIVATIVE="$PWD/port/contracts/lattice-catalog-derivative.json" \
  node --test tools/godot-package/finishing_closure.test.mjs \
  tools/godot-package/manifest_validation.test.mjs \
  tools/godot-package/expansion_verification.test.mjs \
  tools/godot-package/native_arena_closure.test.mjs
node --no-warnings --experimental-vm-modules tools/godot-package/discover.mjs "$PWD"
node tools/godot-package/feature_resources.mjs "$PWD"
node tools/godot-package/world_resources.mjs "$PWD"

# After merged inputs are committed and the heavy-tool grant is available:
python3 tools/godot-package/build.py --state /tmp/opencode/NEW-linux-state --target linux --source-derivative
python3 tools/godot-package/build.py --state /tmp/opencode/NEW-windows-state --target windows --source-derivative
node tools/godot-package/manifest_validation.mjs --package /ABS/EXTRACTED --repo "$PWD" --json
node tools/godot-package/verify_linux.mjs /ABS/LINUX/EXTRACTED /ABS/NEW-LINUX-EVIDENCE
# Run Windows verification on Windows, with its own extracted artifact:
node tools/godot-package/verify_windows.mjs C:/ABS/EXTRACTED C:/ABS/NEW-EVIDENCE

# Optional independent Node-only helper diagnostic, after archive validation:
node tools/godot-package/verify_features.mjs /ABS/EXTRACTED /ABS/NEW-EVIDENCE --replay-only
```

The 75 existing extracted cases are preserved; new accepted map pairs increase
the derived expansion case list. Feature resource/helper results are additive
named report sections, not a replacement for those cases. Actual integrated PCK,
native replay/UI/input/audio behavior, exported Windows execution and newly
registered map journeys are **unrun** at this checkpoint.
