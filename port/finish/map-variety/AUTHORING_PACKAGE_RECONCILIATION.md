# Reviewed Moth authoring resources — exact source inventory correction

Foundation: **`4cd806fa0783b1731505f8003e840bdc2f7d4786`**, merged into the
isolated `expansion-four/scenery` branch as `7dcfa67e`. No parent files were
overwritten or edited in the shared worktree.

## Failure and bounded correction

Parent's integrated movement reconciliation run was **111 passed / 2 failed out
of 113**, not a complete pass. `movement_dependencies.test.mjs` source preflight
and `promoted_assets_git.test.mjs` rejected the new `assets/moth/map-variety-20261003`
files as extra runtime derivative entries. Those resources were merged after the
worker's earlier `f61f6156` foundation. The locked namespaces correctly include
`assets/`; excluding that namespace or a directory glob would hide future drift.

The correction registers a separate exact authoring-resource contract. Neither
`source-lock.json`, `lattice-catalog-derivative.json` nor
`movement-candidate-derivative.json` is changed. The movement derivative retains
its **13 runtime files** and exact `91f58a1c` implementation ancestry.

## Immutable authoring inventory

| Identity | Value |
|---|---|
| Reviewed resource commit | `9dc08e53c97422b80c969615bbc31d7a05498196` |
| Reviewed resource tree | `d61690d7907ba562e4fc7b87de7f4d3dec1c79d0` |
| Contract | `port/contracts/moth-authoring-resources.json` |
| Contract SHA-256 | `abc05c5adf529e3b74ec42752c9fe9a650ab678c101ad5a89fe3158560f855aa` |
| Exact files | **886** |
| Total bytes | **133,726,498** |
| Status | `authoring-resources-not-runtime-map-adoption` |
| Shipping policy | `excluded-from-runtime-copy` |

The contract lists every path with SHA-256 and byte length, including base
`5c18608f`, catalog `2ca445a0`, final multi-engine `9dc08e53`, original failed
baselines, evaluation archives, hidden `.mothbake-archive.json` files, sanitized
API schemas/jobs, authoring code, previews and material channels. It does not
reinterpret those records as successful output or map acceptance.

`inventory_authoring_resources.mjs` derives that contract only from the fixed
Git commit and tree. Verification pins the entire contract hash and requires
the reviewed commit in the explicit comparison commit's ancestry. Each approved
file must be an actual addition to the upstream lock and must match its exact
bytes. Only those validated individual paths are removed from the runtime
derivative comparison. Unknown assets still reject, including filenames ending
in `.test.mjs`; the test-source exemption applies only to `game/` and `server/`.

Historical artifacts before the reviewed resource commit do not load this new
contract. Their own recorded commits and contracts continue to determine their
source validity independently of ambient HEAD or current resource files.

## Runtime/package policy and seven-unit impact

The pack is approved for authoring/Blender application under the parent report,
**not copied as package runtime and not adopted by any map here**. The package
builder explicitly rejects approved authoring paths in its discovered runtime
closure; recorded-artifact validation rejects them in packaged file inventories.
Windows source preflight applies the same separation. The contract is recorded
as a source build input; this does not copy its 886 referenced resources into the
runtime directory or PCK.

Re-derived committed closure at the actual integrated `4cd806fa` base:
**86 source modules, 40 adapters, 13 worlds, zero authoring resource paths**.
No assets, map registry, Godot scenes, imports, GLBs or map production receipts
are changed by this correction. Runtime data/copy behavior remains scoped to
the existing discovery graph.

All seven production receipt `packageInputs` were audited against current bytes:
**zero changed pinned dependencies in every unit**. The changed source verifiers
(`semantic.mjs`, `manifest_validation.mjs`, `windows_source_preflight.mjs` and
`build.py`) are package verification/build inputs, not members of these seven
asset receipt closures. The new helper does not modify `source_derivative.mjs`
or any previously pinned movement helper. Consequently no asset receipt advance
or new asset receipt hash is necessary; the complete `76054ece` movement history,
producer identities, original acceptance/pending fields and exact inventories
remain unchanged (649/657/798/909/673/657/667 inputs).

## Verification

**115 source tests passed, zero failed**, using the prior 112-test source suite
plus three new authoring tests. Independent committed-Git seven-unit strict
closure is run after committing, bringing the expected distinct test total to
116. Exact source command:

```sh
node --test tools/godot-package/authoring_resources.test.mjs tools/godot-package/movement_dependencies.test.mjs tools/godot-package/source_state_windows.test.mjs tools/godot-package/manifest_validation.test.mjs tools/godot-package/polish_dependencies.test.mjs tools/godot-package/stormglass_imports.test.mjs tools/godot-package/feature_dependencies.test.mjs tools/godot-package/abyssal_imports.test.mjs tools/godot-package/vesper_imports.test.mjs tools/godot-package/scenery_imports.test.mjs tools/godot-package/production_resources.test.mjs tools/godot-package/build_channel.test.mjs tools/asset-production/candidate-contract.test.mjs tests/new_maps/abyssal_pressureworks/admission.test.mjs port/native-campaign/core-provenance.test.mjs port/native-campaign/movement-parity.test.mjs port/native-campaign/hit-volume.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
```

New tests prove exact complete inventory against `9dc08e53`, changed approved
bytes/missing inventory/missing additions reject, runtime shipping rejects,
and unknown assets reject in Git-object-only synthetic descendants of actual
`4cd806fa`. The synthetic descendants add the new contract to that integrated
base without copying/checking out assets. Old synthetic artifact tests still
pass, including isolation from later/dirty HEAD and ambient derivative contracts.
The working source preflight uses this integrated checkout, and the post-commit
test verifies its actual committed source state and seven strict inventories.

## Native and production status

Q completed and released as reported in `movement-research/NATIVE_Q.md` and
parent `190fa2a2`: **1,970 input-flow + 10 slide checks**, zero failures/errors,
no runtime correction. Those are native client-method/presentation contracts at
`f61f6156`, not live-server movement journeys or rendered feel. This correction
does not rewrite the earlier movement receipt's historical pending status.

R remains the sole heavy owner for Foundry production. Other map lanes remain
review/source work and their unbuilt revisions are not promoted. P's 89/22/31,
manual/audio/GPU blockers and final release obligations retain their scopes.
No engines, Blender, imports, servers, exports, captures or child agents ran here.
