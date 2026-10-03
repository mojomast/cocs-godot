# Foundry R6 — unpromoted artifact exclusion

## Parent integration

W passed independent qualified staged review and is merged as **`5641fec9`**,
preserving `fceaac00` ancestry. Package-only `af648e8a` is integrated as
**`9c5eca6d`**. Parent passed all 58 package checks (55 Node including committed-Git
closure, three Python builder tests), plus nine R6 source tests. All 226 original
W manifest files remain byte-identical. Seven invalid tangent bases remain a
documented staged limitation; see `FOUNDRY_R6_REVIEW.md`. The original registry
review-pending status records this exclusion transaction's history, not promotion.

Package-fixture branch: `package/foundry-r6-staging`, in the isolated scenery
worktree. Started at parent **`5f5a58c7`** and merged W artifact history as
**`6d2596f8c993d00977da0cfa17ddb0fee25885f6`** solely for source packaging checks.
That merge includes source **`b5dfe08e36abf0c125c6a05abaf8cd28dce39184`** and
artifact **`fceaac00b3b74a0272294a9470ab30ae7e5c4846`**, based on `e66fce84`.
This local fixture integration does not grant parent artifact/art approval.

## Parent integration order

After W's independent review permits artifact integration, **merge W history so
original `fceaac00` remains an ancestor**, then cherry-pick the separate package
policy commit. Do not cherry-pick the local fixture merge. Cherry-picking W's
artifact into an unrelated identity will deliberately leave its revision files
unregistered and fail preflight. No future parent merge hash is guessed.

The registry has small, separate named entries:

- `foundry-r5`: original activation `7ae3f2f5`, original manifest/hash and 63 files
  retained; status `staged-not-runtime-promoted`.
- `foundry-r6`: activation and artifact identity `fceaac00`; status
  **`unpromoted-artifact-review-pending`**. Exclusion does not approve the artifact.

`gitStagedResources` determines each required entry solely from the explicitly
recorded commit's ancestry. Pre-W `5f5a58c7` still requires only R5; pre-R5
artifacts require neither manifest. Ambient HEAD cannot activate a later entry.

## Exact R6 scope

Pinned manifest:
`tools/godot-multiplayer/new-maps/gravemill-foundry/revision6/evidence/W/final-manifest.json`

SHA-256: `234cdbe8118cddf0d10b605e4eebd1fb512ddad73f35fcc9bde745715f5766fc`.
Only its exact non-test Godot file entries become shipping exclusions. No W logs,
masters, report archives or test-only fixtures are added to the runtime policy.
The original manifest remains provenance; its individual resource SHA-256 and
byte lengths are required for every excluded file.

The native-candidate subset equals the complete non-test Godot diff in original
artifact commit `fceaac00` exactly:

| R6 resource | Count | Bytes |
|---|---:|---:|
| `godot/multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb` | 1 | 15,012,396 |
| Extracted PNGs | 36 | Included in total below |
| GLB and PNG import sidecars | 37 | Included in total below |
| **R6 total** | **74** | **19,007,243** |

No non-test R6 JSON was added by this artifact commit. The GLB contains 36 embedded
images. Exact GLB SHA-256:
`945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c`.
This matches W's actual production report and final manifest. Native/visual
acceptance qualifications in those reports are not modified or waived here.

Together: **R5 63 + R6 74 = 137 excluded files / 35,918,999 bytes**.
The accepted native selection remains **2,494 files**. The accepted Foundry
runtime GLB/data/profile and all seven producer receipts remain unchanged.

## Enforcement

The existing build path consumes the combined exact registry: both candidates
are absent before native project copying/import and receive exact export-filter
entries. Raw-resource, explicit JSON, import-sensitive and runtime-copy bypasses
reject. Production literal path/filename/UID references reject. Unknown revision
files remain errors; no filename-prefix or wildcard hash exemption is introduced.
Separate entries cannot overlap. A required manifest or declared resource missing
from the recorded source is an error, not a reason to silently deactivate R6.

Later public promotion needs a separately reviewed package policy/dependency
transaction and the parent's required acceptance. Connecting a consumer or
changing a staged resource alone cannot promote it.

## Source-only verification

**54 Node tests passed**, including eight R5/R6 policy tests, 45 artifact-history
tests and one source-state test. **Three Python builder fixtures passed** using
the combined 137-file exclusion set and the real copy/filter helper functions.
The independent committed-Git seven-unit check runs after the policy commit.

```sh
node --test tools/godot-package/staged_resources.test.mjs tools/godot-package/manifest_validation.test.mjs tools/godot-package/source_state_windows.test.mjs
python3 -B tools/godot-package/test_staged_build.py
node --test tools/godot-package/promoted_assets_git.test.mjs
```

Positive checks compare all 74 actual R6 resource bytes with `fceaac00`, compare
manifest scope with its Git diff, inspect the GLB's embedded-image count and prove
the accepted native count unchanged. Negatives cover missing/changed R6 manifest,
missing/changed artifact, unknown R7, R6 files without R6 activation, production
path/UID references, and raw/import/copy-list bypass. Historical R5 and pre-R5
fixtures remain independent of later artifacts.

No engines, imports, exports, rendering, servers, child agents or visual/source
helper edits occurred. W's release and the parent's botanical X slot remain
separate from this package-only task. Independent R6 review remains pending.
