# Package artifact verification (NATIVE-06 slice)

This documents the packaging/verifier slice of **NATIVE-06 — one release of
record**. It replaces the legacy extracted-package verifier's hardcoded adapter
allowlist with one reusable validator that binds every packaged byte and the
whole runtime closure to the commits the package manifest records. It does not
build or publish a release, does not run the engine, and does not touch the
locked source, the source derivative contract or the route intake.

## Where it lives

| Path | Purpose |
| --- | --- |
| `tools/godot-package/manifest_validation.mjs` | The one reusable validator (library + CLI). |
| `tools/godot-package/manifest_validation.test.mjs` | Real-git/temp-package fixture tests. |
| `tools/godot-package/verify_linux.mjs` | Native Linux runner; imports the validator. |
| `tools/godot-package/verify.py` | Extracted Linux play verifier; shells out to the validator. Adds `--package` static mode. |
| `tools/godot-package/build.py` | Records and asserts the launcher surface, including `settings_path.mjs`. |

`verify_windows.mjs` is **not modified** by this slice; actual Windows execution
remains owner-run. The Windows artifact *structure* is verified statically by
the same validator (see below).

## Manifest schema contract (schema_version 1)

The validator reads only `manifest.json` and git. Supported versions are listed
explicitly (`SUPPORTED_SCHEMA_VERSIONS = [1]`); any other value fails closed.
Unknown extra fields are ignored, so a future lane may add fields without a
version bump. Fields are:

Required:

- `schema_version` — integer `1`.
- `kind` — `private-local-linux-prototype` (Linux) or `windows-playable-demo` (Windows); must match `target`.
- `target` — `linux` or `windows`.
- `godot_version` — non-empty; must equal the repository `port/contracts/source-lock.json` value.
- `source_commit` — 40-hex; must equal the repository source-lock `source_commit`.
- `port_commit` — 40-hex; anchors every adapter and runtime data byte.
- `release_ready` — boolean (presence enforced; value is recorded, not asserted).
- `files` — exact artifact inventory: every packaged path except `manifest.json`, each a 64-hex SHA-256.
- A runtime closure: `server_closure` (`modules`, `adapterModules`, `dataFiles`, `identityDataFiles`, and the optional Cinderwake `hordeDataFiles`) written by the dynamic `discover.mjs` traversal.

Optional (validated when present, never required, so older v1 manifests stay
verifiable and a future field is not a failure):

- `source_derivative_commit` / `source_derivative_sha256` — both or neither.
- `source_runtime_sha256`, `port_adapter_sha256`, `native_arena_data_sha256`, `identity_arena_data_sha256`, `horde_map_data_sha256` — cross-checked against the closure when present.
- `career_catalog_sha256` — recorded when the later Career catalog exists.
- `operator_models` (must be `source-operators`), `staged_native_overrides` (must be empty), `launchers`, `bundled_node` (required for Windows structure).

Older v1 manifests that predate `server_closure` fall back to the explicit
per-path inventories; a manifest with neither fails closed.

## Source identity anchoring

Verification never reads `COCS_SOURCE_DERIVATIVE`, the current development
runtime configuration, or the caller's working directory. `verify.py` strips
`COCS_SOURCE_DERIVATIVE` from the validator environment explicitly.

1. `manifest.source_commit` must equal the repository source lock.
2. Every source module in the closure is hashed at `manifest.source_commit`, or
   at `manifest.source_derivative_commit` when it is listed in the derivative
   contract's `runtime_files`; the shipped `runtime/<path>` byte-for-byte equals
   that git object.
3. Every adapter and every runtime data JSON is hashed at `manifest.port_commit`.
4. The strict source-tree contract of `tools/godot-export/semantic.mjs` is
   replayed against the manifested commit: no changed tracked source, no added
   uninventoried source, and — when a derivative is recorded — the exact
   `runtime_files` inventory with recorded bytes.
5. Derivative binding: the repository contract at
   `port/contracts/lattice-catalog-derivative.json` must hash to
   `manifest.source_derivative_sha256`, and its `derivative_commit` /
   `source_commit` / `schema_version` must match the manifest. A mismatch is a
   hard failure ("derivative metadata mismatch"), never an ambient selection.

## Exact inventory and runtime closure

- On-disk ordinary files (excluding `manifest.json`) must equal the `files`
  keys exactly: added files, deleted files and changed bytes all fail. Symlinks
  fail.
- The runtime tree is the discovered closure plus the locked `ws` package. A new
  module — for example a Cinderwake horde-stages path — enters verification
  automatically from `server_closure`, with no hardcoded allowlist to update.
  Test/observer modules and any dependency other than `ws` fail even if a
  manifest lists them.
- The optional `hordeDataFiles` family (`godot/horde_maps/generated/*.json`) is
  verified the same way: hashed, anchored to `port_commit`, copied under
  `runtime/`, and recorded in `horde_map_data_sha256`. The field and the whole
  family are absent on the baseline, which stays valid.
- `runtime/port/**` must equal exactly the `port/` adapters in the closure.

## Target structures (static)

Common: `run.mjs`, `options.mjs`, `settings_path.mjs`, `endpoint.mjs`,
`catalog.json`, `README.md`, `cocs.pck`, Godot license/copyright.
`settings_path.mjs` must export the shared `settingsPath` helper.

- **Linux**: `cocs.x86_64`, executable `Domination.sh` / `Cheats.sh` with their
  reviewed routes.
- **Windows**: `cocs.exe`, `node.exe` (matching `bundled_node.executable_sha256`),
  the seven `.cmd` entry points, the Node license, and the Demo Menu references.
  This proves the shipped layout only; running it stays owner-run.

## Commands

```sh
# Build (heavy; serial slot) — records identity, launchers and closure.
python3 tools/godot-package/build.py --state /tmp/opencode/<state> [--source-derivative] [--target windows]

# Full extracted Linux play verification (heavy).
python3 tools/godot-package/verify.py --build-result <state>/builds/<id>/build-result.json --output /tmp/opencode/<new-dir>

# Native Linux CI runner (imports the shared validator).
node tools/godot-package/verify_linux.mjs <extracted-package> <new-output-dir>

# Static structure/identity for either target, no engine (safe anywhere):
node tools/godot-package/manifest_validation.mjs --package <extracted-package> --repo "$PWD" --json
python3 tools/godot-package/verify.py --package <extracted-package> --repo "$PWD" --output /tmp/opencode/<new-dir>

# Fixture tests (lightweight; register in tools/godot-dev/verify.py).
node --test tools/godot-package/manifest_validation.test.mjs
```

## Coordination edits needed for the Cinderwake build

- Source-owned modules (`game/**`, `server/**`) imported from a closure entry are
  picked up automatically by `discover.mjs`; nothing here is hardcoded.
- Port-owned adapter modules must be added to the reviewed `adapters` lists in
  `tools/godot-package/discover.mjs` (route/package lane owns that file); an
  unreviewed adapter import is rejected. Cinderwake's
  `port/native-horde/cinderwake-schema.mjs` is such an entry.
- `discover.mjs` exposes `closure.hordeDataFiles`
  (`godot/horde_maps/generated/cinderwake-drydock.json`); `build.py` consumes it
  when present and defaults to an empty list on the baseline. The map JSON is
  hashed, committed-byte-checked at `HEAD`, copied under `runtime/`, and recorded
  as `horde_map_data_sha256`. `horde_maps/generated/*.json` is in the export
  include filter.
- A reviewed derivative may **add** a source module (`game/horde-stages.mjs`) as
  well as modify locked files; both belong in the derivative contract's
  `runtime_files`, and the strict source-state replay (mirroring
  `tools/godot-export/semantic.mjs`) unions modified and added files.
- New Godot stage scenes/scripts under `godot/` ship automatically through the
  `git ls-files godot` staging copy; they must be tracked and committed.
- If the stage controller changes locked source bytes, Sol's combined derivative
  must list them in `runtime_files`; rebuild so the manifest records
  `source_derivative_commit` / `source_derivative_sha256`.
- The later Career catalog (`godot/career/catalog.json`, 23 gear / 22 mods) and
  its generator `tools/godot-export/career_catalog.mjs` are optional build
  inputs: `build.py` includes them only when they exist (baseline builds do not
  fail first), anchors the catalog to `HEAD`, records `career_catalog_sha256`,
  and exports `career/*.json`. Career parity checks remain that lane's.
- Keep `schema_version` at `1`; add a field rather than bumping. A bump requires
  adding the version to `SUPPORTED_SCHEMA_VERSIONS`.
- Register the new test file as an aggregate gate; `tools/godot-dev/verify.py` is
  parent-owned.

## Status and limits

This slice was implemented and checked with `node --check` / `py_compile` plus
isolated validator smokes (temporary git repositories and the two real derivative
contracts, read-only). No build, engine run, full suite or `npm install` ran. The
fixture tests and the extracted-package journeys are executed by the parent in
the serial slot. No release was built or published.
