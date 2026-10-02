# Required production assets and fighter import settings

Source-only packaging follow-up after merging committed parent `652b8f3c`, then
the actual nine-rig production parent `bb02e34b` (merge `af652afa`). No active
worker's dirty files were copied. Parallax revision inspection used **Git objects
at `3e9bf9e5`**, not the active production checkout. No engine, import, Blender,
encoding, archive/export, Windows workflow or publication was run.

## Actual fighting inputs now verified

`final_resources.mjs` now passes against the real committed nine GLBs, masters
and manifests: **355 runtime paths, 25 provenance paths, pending `[]`**. The six
animation-pipeline paths match the actual manifest's algorithm and committed
bytes. These are source hash/format results, not a repeat of the animation
worker's native acceptance or a grant of full release acceptance.

`fighter_imports.mjs` additionally verifies all **nine actual `.glb.import` files**:
the correct source identity, animation import at 60 Hz, no trimming, and
`PATH:AnimationPlayer` with both `optimizer/enabled=false` and
`compression/enabled=false`. Hashes and the exact committed
`tools/fighting/animation/prepare_native.py` hash receive separate manifest fields.
The existing tracked-native copy includes these sidecars. Builder now compares
the staged bytes with their original hashes **after import and after export**;
an editor rewrite aborts rather than silently changing the reviewed key policy.
Archive validation re-derives these identities from recorded Git objects.

The existing 116 PNG / **63 finish** identities remain unchanged in count. No
rig, animation, import setting, production runtime or shared matrix was edited.

## Explicit final production requirements

`tools/godot-package/production_requirements.json` lists seven required units:

| Unit | Required masters | Runtime exports | Additional identity |
|---|---:|---:|---|
| robots | 9 | 9 GLBs: three skins and six props | three skeletal reference GLBs, builder receipt, exact serialized recipe, source contract |
| vehicles | 9 | 9 GLBs: Puma/Titan/Scout × three LODs | nine generated recipes and nine builder reports |
| scenery | 12 | 24 GLBs | real catalog/mesh hash, all four chapter recipe bindings |
| Parallax interiors | 1 revised master, plus original master input | 1 promoted GLB | revision inputs and private Moth dressing |
| Vesper | 1 | 1 GLB | canonical wrapper and authored recipe/build inputs |
| Abyssal | 1 | 1 GLB | canonical wrapper and authored recipe/build inputs |
| Stormglass | 1 | 1 GLB | canonical wrapper and authored recipe/build inputs |

All promotions are currently **null**. Strict package preflight therefore still
fails, even though the fighter closure is complete. Deleting a unit, setting
`required=false`, dropping an essential builder/recipe, changing a unit's map
identity or treating a local unit as external fails validation. Queue status
strings, optional runtime fallbacks, existing candidate files and configured
triangle budgets never promote an asset.

Maps additionally require production registry membership as derived by committed
discovery. No registry was changed here. Vesper/Abyssal/Stormglass package art paths
now match the actual consolidated builders' `art/worlds/<id>.glb`; that mapping
does not register a candidate. Parallax retains its named `art/<id>/<id>.glb` path.

## Receipt handoff to the asset consolidator / parent

The package verifier consumes the existing receipt's `unit`, `sourceHashes`,
`sourceFingerprint`, `masters` and `exports` fields. Its GLB reader independently
checks declared GLB hashes, embedded image byte ranges/hashes and each local mesh
node's current `asset_source_fingerprint`. A refreshed outer receipt cannot bless
stale embedded fingerprints. Natural coatings are **not** forced to gain normal
maps: material quality/native UV review remains with the producer.

Producer reconciliation integrated after this lane's base: `935e24a0` (parent
`7c74b553`) updates preflight/reopen/receipts to the intended selective-normal
contract, including retained robot COLOR_0 and bound UV channels. The old blanket
normal-texture requirement is resolved in source; actual exported material/native
UV acceptance remains required. Do not restore a blanket normal requirement for
natural roles authored with zero normal strength.

After real generation and native acceptance, commit a receipt at the fixed path
`tools/godot-package/production_receipts/<unit>.json`. Extend the existing report
with these explicit fields:

```json
{
  "unit": "vehicles",
  "sourceHashes": {"<every plan recipePath plus common finishScript>": "<sha256>"},
  "sourceFingerprint": "<existing compact sorted sourceHashes fingerprint>",
  "packageInputs": {"<every expected.packageInputs path>": "<sha256>"},
  "masters": [{"path": "<exact expected master>", "sha256": "<sha256>"}],
  "exports": [{"path": "<exact expected export>", "sha256": "<sha256>", "textures": [{"name": "<GLB image name>", "bytes": 123, "sha256": "<embedded image bytes hash>"}]}],
  "runtimeHooks": {"<actual production activation/placement .gd/.gdshader/.json>": "<sha256>"},
  "rawFiles": []
}
```

This is a schema example, **not an asset or acceptance receipt**. Hash the actual
committed report, then change that unit's promotion from null to:

```json
{"receipt":"tools/godot-package/production_receipts/vehicles.json","sha256":"<actual report hash>"}
```

`production_resources.mjs --audit` emits each unit's **exact** `expected` paths and
`expected.packageInputs`; these are executable inventories rather than a broad
directory glob. Inputs include essential builders/recipes, supporting reports,
finish helper, local literal JS dependencies and GDScript preload/load resources.
`packageInputs` must have exactly that key set and current hashes. A missing or
changed helper/recipe/report is rejected before a promoted unit can package.
Runtime hooks are hash-bound but their actual selection/placement/lifecycle must
still pass the independent native matrix; merely naming a script proves no use.

**One new producer output is required:** archive
`tools/godot-robots/generated/recipe.json` as the exact UTF-8 bytes of Python
`json.dumps(manifest(), sort_keys=True)` **without a trailing newline**, matching
the existing robot builder's `recipeSHA256` calculation. This makes the declared
recipe hash independently checkable without installing Python/Blender on the
Windows verification host. The builder/harness owner should emit this alongside
real production; this packaging worker did not edit or execute those builders.

Parallax is intentionally different: the committed revision uses material-batch
geometry plus native Moth dressing, not the common `finish_scene` embedded-image
pipeline. Its promoted GLB need not invent embedded textures/fingerprints. It must
still pass binary/hash checks, record exact masters/revision inputs, register only
accepted pairs, and bind the private dressing scripts/profile/shader. Preserve the
original accepted master and source-check history while promoting the revised
runtime asset. If the final isolated revision changes its committed path/schema,
reconcile the explicit specification after that commit arrives; never glob its
working directory or substitute the old accepted GLB for the new interior unit.

## PCK and historical contracts

- New `production_resource_sha256`, `production_provenance_sha256` and
  `production_raw_resource_sha256` fields are re-derived from the artifact's
  recorded commit. Production validation is activated by its **recorded builder**,
  so earlier releases do not retroactively require the new queue or fighter
  sidecars.
- Each required declared JSON enters the staged export's explicit include list.
  Masters/reference exports/helpers stay build provenance. Imported GLBs, images,
  scripts and the new private
  `res://multiplayer_worlds/dressing/surface.gdshader` remain ordinary resource
  dependencies with recorded hashes. Its absence fails closure when the presenter
  exists.
- Existing raw fighting PCM/Helix handling remains intact. Production `rawFiles`
  may name only already-declared runtime paths, without duplicates; those bytes
  join the existing raw export plugin inventory and extracted hash probe. Current
  robot/vehicle/scenery adapters use imported resources, so they need no invented
  raw GLB copies.
- The existing extracted final probe receives the additional declared resources
  and raw-byte inventory. No replacement scenes or weakened Windows checks were
  introduced. Real Windows execution, native factory/placement/lifecycle, stage
  registration, human/camera/audio/GPU acceptance and explicit export/publication
  grants remain separate final prerequisites.

## Executed source checks and evidence

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-finish-packaging-evidence-20261002`.

- `queued-production-package-tests.log`: **239/239** package Node tests passed;
  only engine-dependent `career_native.test.mjs` excluded. Reviewed derivative
  selected. Relevant existing package regressions were run once.
- `queued-production-final-tests.log`: **50/50** targeted production/import and
  historical-manifest tests passed after the final protocol refinements.
- `queued-actual-fighters.json`: real strict nine-rig closure, 355/25 paths, no
  pending fighters. `queued-fighter-imports.json`: nine actual sidecar hashes.
- `queued-production-audit.json`: seven pending units, exact expected paths and
  missing inputs. Current expected runtime exports: 9 robots, 9 vehicles,
  24 scenery, and one per queued map. No pending unit is reported as produced.
- Negative tests cover dropped requirements/builders, changed helpers/recipes,
  refreshed bad export/embedded-texture hashes, stale GLB fingerprints, invented
  raw paths, missing/changed import settings and forged recorded import hashes.
  GLB metadata fixtures are explicitly synthetic integrity tests using a real
  committed PNG; they are not claims of generated vehicle art/native acceptance.
- The initial import-parser failure is retained in `queued-production-tests.log`;
  its nested-dictionary parsing was corrected before the passing suites.
- Python AST and `git diff --check` passed. No engine proof is claimed here.

Source-only commands:

```sh
node tools/godot-package/final_resources.mjs "$PWD"
node tools/godot-package/fighter_imports.mjs "$PWD"
node tools/godot-package/production_resources.mjs "$PWD" --audit
# Strict gate: expected to fail until all required production/promotions land.
node tools/godot-package/production_resources.mjs "$PWD"
```
