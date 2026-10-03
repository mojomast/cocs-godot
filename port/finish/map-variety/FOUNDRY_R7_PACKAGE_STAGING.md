# Foundry R7/Y — unpromoted package exclusion

## Parent integration

Independently approved Y is merged as **`dd76b82a`**, preserving original
`f3b51b2c` ancestry. Package-only `0f108974` is integrated as **`dd6bc7c3`**.
Parent passed all 62 package checks (59 Node including committed-Git closure,
three actual builder fixtures), plus sixteen R7 source tests: **78 total**.
The pinned Y manifest and all 237 original files match after integration.
All seven tangent defects are closed by actual-art/native review; remaining
acceptance boundaries are recorded in `FOUNDRY_R7_REVIEW.md`.

Package-only branch `package/foundry-r7-staging` starts at parent
**`167ac4bc151877c3daeb685be0c3d35bdb8e8a93`**. Local fixture integration merge
**`4e401275808022a80271a88366ea91920418afb1`** preserves original Y source
`26da91b384abcf33c54180f72ad05c56b45cb2a3` and artifact
`f3b51b2c0017ed44cad96a2657e256e41766e805` (Y baseline `10d9938f`). This is an
isolated packaging fixture, not parent approval of Y artifacts.

After independent review permits integration, parent must **merge Y history**
preserving original `f3b51b2c`, then cherry-pick the separate package fix commit.
Do not cherry-pick the fixture merge. R7 files present without original Y ancestry
fail as unregistered revisions; a synthetic recorded-source test verifies this.

## Exact registry addition

`foundry-r7` has status **`unpromoted-artifact-review-pending`**, activated only by
original `f3b51b2c` ancestry. R5 and R6 entries and hashes remain unchanged.
Required manifest:

`tools/godot-multiplayer/new-maps/gravemill-foundry/revision7/evidence/Y/final-manifest.json`

Manifest SHA-256:
`8f928a24352ff69418b73e246e56aef5ccfa3a40104f4b55a317d3b2408fed29`.
All selected paths/lengths/hashes come from this exact immutable manifest. Its
non-test Godot subset equals the actual `f3b51b2c^..f3b51b2c` diff exactly.
No logs, master, evidence archives or unrelated tool/test files become resources.

| Candidate | Excluded files | Bytes |
|---|---:|---:|
| R5, unchanged | 63 | 16,911,756 |
| R6, unchanged | 74 | 19,007,243 |
| **R7** | **74** | **19,007,438** |
| **Combined** | **211** | **54,926,437** |

R7 consists of one GLB, 36 extracted PNGs and 37 import sidecars, with no new
non-test JSON. Exact art identity:

- `godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7.glb`
- **15,012,592 bytes**, 36 embedded PNGs
- SHA-256 `6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f`

This matches Y's production report. Its master identity is historical provenance,
not a shipping resource: `96314db722902c12c8b5866edfd0d12844db3a99527eb746c58f61376dc09472`.
This transaction makes no native acceptance determination or waiver.

## Shipping and history boundaries

The existing actual builder copy/filter helpers consume the combined registry:
all 211 files are absent before project import and receive exact export exclusions.
Raw/import/data/copy inputs and production literal path/filename/UID references
reject. Unknown revisions still fail; the native-candidate root guard is retained.
The accepted native file list is byte-for-byte the same list as the pre-Y fixture:
**2,494 paths**. Helix/Parallax X test/tool artifacts remain outside that list.

Pre-Y recorded `167ac4bc` requires only R5/R6 (137 files), not the Y manifest.
Pre-W `5f5a58c7` still requires only R5 (63). Historical R6 fixture tests now use
fixed pre-Y source rather than assuming ambient HEAD will forever exclude 137.
Pre-R5 and unrelated historical artifact identity tests remain independent of
ambient HEAD. No seven-unit production receipt or acceptance/history field changes.

## Verification

**58 Node tests passed**: 12 staging tests, 45 artifact-history tests and one
source-state test. **Three Python actual builder-helper fixtures passed** with
the 211-file registry. After adding the ancestry-negative synthetic fixture, the
12-test staging suite was rerun and passed. Independent committed-Git seven-unit
strict closure runs after commit.

```sh
node --test tools/godot-package/staged_resources.test.mjs tools/godot-package/manifest_validation.test.mjs tools/godot-package/source_state_windows.test.mjs
python3 -B tools/godot-package/test_staged_build.py
node --test tools/godot-package/staged_resources.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
```

Positive tests compare all 74 R7 resource bytes with the original artifact commit,
compare manifest scope with Git diff, inspect GLB byte/image counts and prove
accepted native selection unchanged. Negative cases cover unknown artifacts,
missing/changed manifest or files, production references, raw/import/copy bypass,
and an identical integrated artifact tree lacking Y ancestry. Copy fixtures use
tiny stand-ins and the real builder functions; no engine import or export occurs.

No artifact bytes, map visuals or source helpers owned by Y/botanical lanes were
edited. No engines, imports, rendering, servers or child agents ran. Independent
actual-artifact review and parent release verification remain separate. Inventory
exclusion grants no public promotion or native waiver.
