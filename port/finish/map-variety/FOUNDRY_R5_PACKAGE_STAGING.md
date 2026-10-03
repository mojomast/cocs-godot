# Foundry R5 — exact staged-resource shipping separation

Foundation **`7ae3f2f54cd1d0764274d5c014eeb937e161af29`**, including shared
prerequisite `bce5b834` and R5 artifact cherry-pick of
`4a2f120158040bdd0a894132d09eb8d6eea379aa`. Adopted as merge `395adcbc` in the
isolated `expansion-four/scenery` branch. Parent histories/docs were retained.

## Source audit and policy

The previous builder collected every tracked non-test/non-content Godot file.
It copied that list into a fresh project, then used `export_filter="all_resources"`
with broad JSON include patterns. Thus unreferenced R5 art was eligible for
import/export. The seven strict production inventories alone did not prevent it.

`tools/godot-package/staged_resources.mjs` now registers this exact candidate as
**`staged-not-runtime-promoted`**. Its immutable inventory is the non-test Godot
subset of the original R5 final manifest:

`tools/godot-multiplayer/new-maps/gravemill-foundry/revision5/evidence/final-manifest.json`

Manifest SHA-256:
`03c5a898d819363ebd56614bc7f7ba0c6337250563457d4ce5b52ac9b5e1d6c5`.
The complete manifest hash is required before any paths are selected, and all
selected file hashes/lengths and presence are checked. Tests independently
compare the manifest and every excluded file with original artifact `4a2f1201`.
The ancestry trigger is integrated parent `7ae3f2f5`, not an assumption that the
original cherry-picked artifact commit is an ancestor of the public branch.

### Exact exclusion scope: 63 files / 16,911,756 bytes

| Resource | Count |
|---|---:|
| `godot/multiplayer_worlds/art/revisions/gravemill-foundry-r5.glb` | 1 |
| Its `.glb.import` sidecar | 1 |
| Extracted R5 PNGs, each individually named/hashed in the manifest | 30 |
| Their individual `.png.import` sidecars | 30 |
| `godot/multiplayer_worlds/generated/revisions/gravemill-foundry-r5.json` | 1 |

The ten PNG families are aggregate, cast-seams, copper-heat-oxide, copper-patina,
forge-steel, iron-grate, lime-plaster, ribbed-steel, timber-weather and wet-soot;
each has albedo-srgb, normal and roughness channels. Selection is the manifest's
exact file keys, **not a wildcard exclusion**. Native fixture profiles under
`godot/tests/new_maps/gravemill_foundry/revision5` remain covered by the existing
test-resource exclusion and are not runtime inputs.

Unknown non-test Godot files in a `/revisions/` namespace fail preflight rather
than being ignored or shipped. Working preflight also rejects untracked revision
additions. Ordinary indexed native files still enter normal build-input identity
checks; unrelated untracked historical files are preserved.

## Actual shipping path

1. Before toolchain download/import/export, source preflight validates the exact
   staged manifest and files, and scans production native text plus discovered
   runtime source/adapter/data consumers. Literal revision paths, candidate
   filenames and candidate import UIDs reject. This includes public GDScript,
   scenes/resources, JSON data, project configuration and JS authority consumers.
2. `native_files` comes from the validated policy: **2,494 selected files**, with
   the 63 candidate files removed from the original 2,557 eligible files.
3. `stage_native_project` performs the real copy loop using that selection and
   asserts that no excluded candidate file exists in the fresh isolated project.
   No staged source means no candidate-derived import cache is generated there.
4. The real `all_resources` preset receives **63 exact project-relative
   `exclude_filter` entries**, retaining the existing test/probe/addon exclusions.
   This is defense in depth for both resource selection and wildcard JSON includes.
5. Staged paths reject if introduced through runtime data, explicit export JSON,
   raw-export plugin inputs or import-sensitive metadata. The final manifest is
   build provenance only; retaining its source identity does not copy its resources.
6. Windows source preflight and recorded-artifact validation use the same policy.
   Recorded artifacts use only their recorded commit. Pre-R5 artifacts do not
   load the new manifest and remain independent of ambient R5 files/HEAD.

The policy is source/static-reference validation, not a claim of general dynamic
GDScript execution analysis. Future dynamic consumers require explicit reviewed
dependency roots/promotion. No Linux/Windows package export or PCK inspection ran.

## Accepted Foundry runtime is retained

The selected runtime still includes the existing six Foundry art/report/sidecar,
data and dressing files. Key unchanged SHA-256 values:

| Accepted file suffix under `godot/multiplayer_worlds/` | SHA-256 |
|---|---|
| `art/worlds/gravemill-foundry.glb` | `46bf1648b32d23e337cd11b2c639a47f17d36c41361aab9434e1e621361e5935` |
| `generated/gravemill-foundry.json` | `172c94a271b49782f1a29ff89c4812a717ba6b4f9050ade8ea21546f0f875932` |
| `generated/worlds/gravemill-foundry.json` | `3c7f9242bb7c98000871b27d58d14c719a4867e1a9fc625b106c97f7c1c608eb` |
| `dressing/profiles/gravemill-foundry.json` | `8d7f94f29f15e336fb1c9141b707a43718ce4c5a463eb03a13412e593eaa51e5` |

All seven production receipt input hashes were rechecked: **zero changed pinned
dependencies**. No receipt, producer/native identity, pending field, acceptance
field or previous source advance changes. The new packaging helper and changed
build/artifact/preflight code are outside those asset receipt dependency graphs.

## Lightweight verification

**50 Node tests passed** (four staging tests, 45 recorded-artifact tests and one
source-state test), plus **three Python builder-fixture tests**. The fixtures
execute the actual native copy helper over tiny stand-ins for all selected paths,
prove every candidate resource absent from the resulting project, and apply the
actual builder's `all_resources` preset literal to test its exact exclusions.
They also reject raw/JSON/import/copy-list bypass attempts.

```sh
node --test tools/godot-package/staged_resources.test.mjs tools/godot-package/manifest_validation.test.mjs tools/godot-package/source_state_windows.test.mjs
python3 -B tools/godot-package/test_staged_build.py
node --test tools/godot-package/promoted_assets_git.test.mjs
```

The independent committed-Git test runs after commit and checks all seven strict
inventories, source identity and staged-path exclusion against committed bytes.
Source-only discovery plus staging preflight also passed for the actual integrated
runtime graph. Negative tests cover unknown artifacts, changed/missing staged
files, missing/forged manifest, production path/name/UID/JS references and raw/data
shipping attempts. Historical synthetic artifact identity tests remain passing.

## Promotion boundary

R5 remains qualified **staged integration only**. Hosted six-mode journeys,
manual visual acceptance and public promotion are not granted by this policy.
Later promotion needs parent-approved acceptance, explicit runtime bindings and
an exact policy/inventory transaction retiring the applicable staged exclusion;
altering/removing the manifest or connecting a consumer alone fails closed.
Later Abyssal/Stormglass artifacts need separately pinned entries when reviewed
and integrated. No map visuals, builders or source helpers owned by other lanes
were edited. T retains sole heavy ownership; no heavy work or child agents ran.
