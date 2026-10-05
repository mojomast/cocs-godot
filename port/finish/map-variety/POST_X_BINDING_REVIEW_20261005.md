# Post-X Vesper native-binding correction — independent focused source re-review

Reviewer: independent subagent (source/evidence only; no engine, no import, no
push/merge/rebase). Review date 2026-10-05.

| Item | Value |
|---|---|
| Delivery reviewed | `525b9fbe468361889d745b350a1c058af23e9b04` (tree `e36e9c68c1f13b73b6e036b983f3145553fd8278`) |
| Subject | Pin exact Vesper art pairs in future native movement diagnostics |
| Producer branch | `astra/botanical-post-x-source` (tip at the delivery commit, preserved in refs) |
| Review branch | `review/post-x-binding-20261005` (created at `525b9fbe`, nothing pushed) |
| Read-only worktree | `/home/mojo/.tmp-on-disk/cocs-botanical-post-x-source` |
| Predecessor commit | `902c3bbb` (the commit whose P1 this closes) |
| Parent reference | `70995941` "Record actual R7 tangent closure, verified staged integration and post-X review" |
| Merge-base with parent | `32eba401155856e50e31698b41d132f6ded0a50c` — identical against parent tips `91b0b801` and `5c66f32f`; the shared parent checkout was being advanced by another session during this review, so the merge-base is the load-bearing fact, not the tip |
| Toolchain used | Python 3.13.7, Node v22.23.1 |

## Verdict

**APPROVE** — the P1 artifact-binding correction in `525b9fbe` is approved for
**selective source integration** of `902c3bbb` + `525b9fbe`. The originally
reported P1 ("candidate journeys use accepted art, or can succeed without art")
is **closed at the source level**, by evidence reproduced in this review.

**Native journey readiness remains WITHHELD and is not granted by this review.**
The GDScript binding gate has never been parsed or executed by an engine, so
every claim about *imported* geometry, material names, import UIDs and import
policy is still a source-level claim. Four pre-grant conditions are listed in
"Conditions before any future native grant" below; they are conditions on the
**grant**, not on this delivery.

## What was actually run

No native engine, no Blender, no import, no capture, no subagent, no queued work.
All commands were read-only apart from the two scripts that create and then
remove their own uniquely named scratch attempt directory.

### 1. Portable Python suite (13 tests)

```sh
cd /home/mojo/.tmp-on-disk/cocs-botanical-post-x-source
env -u COCS_BOTANICAL_X_FIXTURE_ROOT -u COCS_BOTANICAL_U_FIXTURE_ROOT \
  python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/botanical-post-x -p 'test_*.py' -v
```

Result: **`Ran 13 tests in 0.940s` / `OK`** (exit 0). Breakdown:
`test_art_binding.ArtBinding` 4, `test_contacts.Contacts` 3,
`test_native_fixture.FutureFixture` 3, `test_tangent.Tangents` 3.
Full log: `/tmp/opencode/postx-review/py-portable.log`.

This reproduces the producer's "thirteen portable tests" claim exactly, and it
runs **without** any X/U archive root — the fixtures are committed.

### 2. Node suite (12 tests)

```sh
node --test tools/godot-multiplayer/new-maps/botanical-post-x/movement.test.mjs game/arena-movement.test.mjs
```

Result: **`# tests 12 / # pass 12 / # fail 0`** (exit 0), including
`ok 11 - production movement crosses both full stair runs across five lanes both
directions at walk and sprint` and
`ok 12 - production mover stops on a genuine raised obstruction rather than
waiving staircase contacts`. Log: `/tmp/opencode/postx-review/node-tests.log`.
This matches the README's unchanged "12 Node tests" statement.

### 3. Pinned-X integration check (the "actual pinned-X negative checks" claim)

```sh
export COCS_BOTANICAL_X_FIXTURE_ROOT=/home/mojo/.tmp-on-disk/cocs-botanical-source-correction
python3 -B tools/godot-multiplayer/new-maps/botanical-post-x/verify_art_fixture.py
```

Result: exit 0, printing

```
Actual accepted/X pairs, both full GLB inventories, 60 source cases, immutable attempt,
missing import/art, tamper and accepted fallback checks PASS; native unparsed
```

`git status --porcelain` was empty afterwards — the scratch attempt directory was
removed and no residue was left. Log: `/tmp/opencode/postx-review/verify-art-fixture.log`.

### 4. Frozen archive re-verification (600 X + 264 U)

```sh
export COCS_BOTANICAL_X_FIXTURE_ROOT=/home/mojo/.tmp-on-disk/cocs-botanical-source-correction
export COCS_BOTANICAL_U_FIXTURE_ROOT=/home/mojo/.tmp-on-disk/cocs-map-variety-botanical-astra
python3 -B tools/godot-multiplayer/new-maps/botanical-post-x/verify_frozen.py \
  /tmp/opencode/postx-review/frozen-recheck.json
```

Result: `X: 600 files, 0 mismatches` and `U: 264 files, 0 mismatches`
(`inventorySha256` `440a1291…` / `ce0dd0ec…`). My recheck output is
**byte-equal (as parsed JSON) to the committed
`tools/godot-multiplayer/new-maps/botanical-post-x/frozen-integrity-binding.json`**
(checked programmatically: `True`).

### 5. Independent negative matrix (my own probes, beyond the shipped tests)

I rebuilt a scratch fixture with `prepare_native.setup()` and then attacked it,
printing the actual rejection reason for each mutation
(`/tmp/opencode/postx-review/negative-matrix.log`):

| Mutation | Outcome |
|---|---|
| `candidate.glb` ← `accepted.glb`, manifest untouched | `ValueError: Art SHA256 mismatch; accepted fallback forbidden` |
| `candidate.glb` ← `accepted.glb` **and** `source.json` manifest edited to match | `ValueError: Art SHA256 mismatch; accepted fallback forbidden` |
| `candidate.json` ← `accepted.json` | `ValueError: Authority bytes mismatch` |
| `candidate.json` last byte flipped | `ValueError: Authority bytes mismatch` |
| `candidate.glb` last byte flipped | `ValueError: Art SHA256 mismatch; accepted fallback forbidden` |
| `pin_import` on a fixture with no `.import` sidecar | `FileNotFoundError: …/accepted.glb.import` |
| `setup()` on an existing attempt | `FileExistsError: Existing/symlinked attempt refused` |
| final `validate_prepared()` after restoring all bytes | `OK` |

The second row is the decisive one for the P1: **editing the manifest does not
defeat the substitution**, because the art pin in
`art_binding.py:33,42` is checked against actual bytes inside `inspect_pair`,
independently of any manifest hash.

### 6. Independent identity verification (no producer code in the loop)

I recounted both GLBs with a from-scratch glTF parser (not `glb_geometry`):

| Variant | SHA-256 | triangles | mesh nodes | primitives | materials |
|---|---|---|---|---|---|
| accepted | `6afe34c82d45f06c30dedc780f59ac6afa5200835b487d41705902d771fc0bfd` | 54804 | 11 | 11 | 11 |
| candidate X | `f859d49cc1b462b4a88e351d915508c49940ce24a7b8c2047c2d8f94f419e1db` | 64311 | 29 | 29 | 17 |

These match the producer constants **and** the candidate GLB's own embedded
`extras.export_triangles = 64311` and `extras.export_materials` (same 17 names).
Both GLBs are simple: no skins, no `extensionsUsed`, all primitives `mode 4`
(triangles), no node matrices, mesh nodes equal to scene root children — so the
GDScript `MeshInstance3D`/surface count gate is structurally plausible (still
engine-unproven).

Cross-language constant check: I parsed `art_binding.gd:5–8` `IDENTITIES` and
compared every field against a live `art_binding.preflight()`:

```
== accepted | all 8 fields OK
== candidate | all 8 fields OK
GDScript IDENTITIES == Python ARTS/preflight records for all compared fields: True
```

Provenance verification (`binding-followup-provenance.json`):

* `historicalProvenanceSha256` `d906c829…` == actual
  `source-provenance.json` SHA — **match**.
* 15/15 `original15DependenciesMatchCheckoutAndParent` hashes match this
  checkout **and** the blobs at `70995941` (verified with `git show`).
* 10/10 `files` pins match the checkout.
* Accepted GLB in this checkout is byte-identical to `70995941`'s tracked
  `godot/multiplayer_worlds/art/worlds/vesper-viaduct.glb`, and to the blobs at
  `902c3bbb` and `525b9fbe`.
* Candidate GLB resolves to the same pinned bytes both in the branch tree and in
  the X archive root.

## Requirement-by-requirement findings

### R1 — Both the authority data variant and the GLB art variant are pinned ✅

* Authority pins: `tools/…/botanical-post-x/fixture_inputs.py:14–17`
  (`accepted` → `godot/multiplayer_worlds/generated/vesper-viaduct.json`
  `e273264a…`; `candidate` → `port/new-maps/vesper-viaduct/variety/urban-v3/authority.json`
  `397cedc8…`), enforced at `art_binding.py:38` and `fixture_inputs.py:28–31`.
* Art pins: `art_binding.py:10–21` (per-variant path, art SHA-256, geometry hash,
  recipe hash), enforced at `art_binding.py:33` (bytes), `:40` (authority
  id/geometry/recipe), `:42` (art bytes), `:46–47` (identity embedded in the
  **GLB** itself: candidate `extras.geometry_hash`/`recipe_hash`, accepted
  `extras.recipe_sha256`).
* No fixture binds "accepted art" for a candidate run: `art_binding.py:26–29`
  requires an explicit `COCS_BOTANICAL_X_FIXTURE_ROOT` for the candidate and
  raises `…no fallback` otherwise; there is no discovery/search path. Both the
  authority JSON and the GLB are copied into the attempt directory
  (`prepare_native.py:22–24`) and re-verified there
  (`prepare_native.py:66–78`).
* The runtime identity set is duplicated independently in GDScript
  (`art_binding.gd:5–8`) and compared field-by-field against the manifest before
  anything is loaded (`art_binding.gd:60–61`).

**Root cause of the original P1, confirmed in production code:**
`godot/multiplayer_worlds/map.gd:24` resolves
`"res://multiplayer_worlds/art/" + ("worlds/" if data.has("recipeHash") else "") + data.id + ".glb"`.
Both authority JSONs carry `recipeHash` (verified: both `id=vesper-viaduct`, both
`arena.art.ground` present), so **both variants resolve the accepted
`vesper-viaduct.glb`**. And `map.gd:105–110` only instantiates art
`if ResourceLoader.exists(art_path)`, so `build()` can also succeed with no art
at all. The reviewer's P1 statement is therefore accurate.

### R2 — Explicit imported-art binding/verification before physics runs ✅ (source-level)

* `controller_journey.gd:38` calls `ArtBinding.make_world(...)`, and the first
  `await physics_frame` is at `controller_journey.gd:41` — binding precedes all
  physics.
* `art_binding.gd:54–105` does, in order: for **both** variants, verify the
  manifest fields against the GDScript identity set, verify authority bytes and
  authority id/geometry/recipe, load the real `.import` sidecar, require
  `deps.source_file` to equal the staged path, require a retained
  `uid://…` that matches `ResourceLoader.get_resource_uid()`, require the
  sidecar's own SHA to equal the post-policy `afterSha256`, require
  `meshes/force_disable_compression=true` and `meshes/generate_lods=false`,
  require the imported cache file to exist; then `imported_art()` loads the
  PackedScene with `CACHE_MODE_IGNORE`, checks the loaded/instance resource
  paths, refuses gameplay collisions, and counts imported
  `MeshInstance3D`/surfaces/triangles/materials, rejecting nonempty-mesh,
  finite-position/UV, compression and material-override violations
  (`art_binding.gd:15–52`).
* Only after that: `WorldMap.build()` for the selected variant, runtime
  `geometry_hash` equality (`art_binding.gd:88–89`), `Binder.cleanup` of
  inherited dressing, removal of the helper-loaded `BlenderArtNoGameplayCollision`
  node, and **explicit instantiation of the selected staged GLB attached to the
  world before the first physics wait** (`art_binding.gd:92–102`), with
  `assert(world.get_node_or_null("BlenderArtNoGameplayCollision")==null)` and a
  parent/`scene_file_path` identity assertion.
* The journey receipt carries both variants' authority/art hashes, import UID,
  sidecar and imported-cache hashes, loaded/instance resource paths, actual
  counts and material names, the selected runtime geometry hash, and
  `bindingReady` / `bothVariantsRuntimeVerified`
  (`art_binding.gd:81–83, 103–105`; emitted at `controller_journey.gd:90–92`).
* Source manifests keep `nativeReady: false` (`art_binding.py:53`,
  `binding-followup-provenance.json:43`).

This is genuinely stronger than "the bytes were pinned at setup time": the
imported result is re-censused from `ArrayMesh.get_faces()` at runtime and
compared to the pin, and the sidecar hash is compared to the post-policy value
recorded by `prepare_native.pin_import` (`prepare_native.py:42–64`), so a
re-import or edited sidecar fails closed.

### R3 — Historical X/U files preserved unchanged ✅

* `git diff --name-status 171ffddb..525b9fbe` restricted to the historical X/U
  trees (`godot/tests/new_maps/botanical_correction`,
  `tools/…/botanical-correction`, `tools/…/botanical-stage`) is **empty**.
* The only non-source file added since the X artifact commit `171ffddb` anywhere
  is `godot/tests/new_maps/botanical_post_x/.gitignore` (content `/*/`).
* `git diff 902c3bbb..525b9fbe` touches 11 files, all in
  `tools/…/botanical-post-x/` and `godot/tests/new_maps/botanical_post_x/`.
* SHA comparison `902c3bbb` vs `525b9fbe`: `contacts-evidence.json`,
  `movement-evidence.json`, `parallax-tangent-evidence.json`,
  `parallax-tangent-evidence-v2.json`, `source-provenance.json`,
  `frozen-integrity.json`, `movement.mjs`, `movement.test.mjs`,
  `diagnose_contacts.py`, `test_contacts.py` and
  `tools/…/botanical-correction/X_HANDOFF.md` are all **IDENTICAL**. The new
  `frozen-integrity-binding.json` and `binding-followup-provenance.json` are
  purely additive; the original `frozen-integrity.json` is untouched.
* Nothing was restamped: no evidence JSON, manifest or receipt from `902c3bbb`
  or earlier was edited.

### R4 — Rejection/guard outcomes and the 184-contact limitation untouched ✅

* `contacts-evidence.json` still holds **368 records at 184 distinct positions**,
  `candidateOnlyContactPositions == 13`, and *every* record's
  `originalCapsule.overlaps` and `gameEnvelopeCapsule.overlaps` is `true`
  (recomputed by me directly from the file).
* `test_contacts.py` (unchanged) still asserts all 184 failures, the exact nav490
  counterexample, and the 13+1 roof delta; it passed.
* The Node suite still contains `ok 12 - production mover stops on a genuine
  raised obstruction rather than waiving staircase contacts`.
* The only change to `controller_journey.gd` is 13 lines, all strengthening: the
  binding call replaces the bare `WorldMap` preload, a new
  `group_id.begins_with(variant+"-"+run+"-")` case/variant substitution assert
  was **added**, and the receipt gained the `binding` object plus
  `walkOnly`/`sprint` and a widened scope string. No tolerance, stall threshold,
  reset rule or arrival criterion was relaxed
  (`controller_journey.gd:68` still requires
  `absf(delta.y) <= walker.safe_margin + .001`; `:83` still breaks at
  `stalled >= 120` or `reset_count != 1`).
* No allowlist, contact waiver, dropped or lifted capsule point, radius shrink,
  controller change or geometry change exists in the delivery. Grepping the new
  and changed binding code for `waiv|allowlist|skip|ignore` returns nothing but a
  `CACHE_MODE_IGNORE` load flag and the negative-test `except` clauses.
* No production file is modified: `godot/exploration/walker.gd`,
  `godot/multiplayer_worlds/map.gd`, `binder.gd`, `game/*.mjs` are byte-identical
  (15/15 pin verification above).

### R5 — Real tests, actually runnable here ✅

See "What was actually run": 13 portable Python tests, 12 Node tests, the
pinned-X integration script, and the 600+264 frozen re-verification all ran and
passed in this environment with the exact commands from the package README and
`NATIVE_BINDING_FOLLOWUP.md`. The producer's headline claims
("13 portable Python tests", "actual pinned-X negative checks") are accurate.
I did **not** have to fall back to static review for the Python/Node side. The
GDScript side is unparsed by design and is reviewed statically only — stated
plainly below rather than papered over.

### R6 — No rejected artifacts merged; scope is source-only ✅

* `902c3bbb..525b9fbe` adds/modifies 11 files: 2 `.gd`, 8 Python/JSON/Markdown
  under `tools/…/botanical-post-x/`, 1 `.gd` change. No `.glb`, `.blend`,
  `.png`, capture, or any other binary. No master, no export, no capture report.
* Neither `accepted` nor `candidate` Vesper **artifacts** are added by this
  branch: the accepted GLB is the pre-existing tracked production asset
  (byte-identical to parent `70995941`), and the candidate GLB is read from the
  **explicit X archive root** at test time, never copied into the branch by this
  delivery.
* `171ffddb` (the X artifact commit) is **not** an ancestor of the parent
  (`91b0b801` or `5c66f32f`), and neither `171ffddb` nor `902c3bbb` is an
  ancestor of the parent. Integration must remain **selective commit selection**
  (`902c3bbb` → `525b9fbe`, plus the already-selected `e3497a21` → `5b40a15b`
  chain), consistent with `BOTANICAL_X_REVIEW.md:93–97` and
  `BOTANICAL_X_SELECTIVE_INVENTORY.json`. Do not merge this branch's ancestry
  wholesale; the X artifact/rejected-attempt material lives there.
* No push, merge, rebase or branch deletion was performed by this review; only
  `git checkout -b review/post-x-binding-20261005` in the designated worktree
  plus one documentation commit.

## P1 blockers

**None found.** The specific P1 recorded in
`port/finish/map-variety/POST_X_SOURCE_REVIEW.md:1239–1253` is closed:

1. Preparation no longer copies "only accepted/candidate JSON": it copies and
   pins both GLBs, and refuses to create the attempt directory unless both
   complete authority+art pairs pass (`prepare_native.py:19–24`).
2. The test-only stage binding no longer inherits `WorldMap`'s accepted-art
   default: it removes the helper-loaded art and instantiates the selected
   staged GLB before the first physics frame, after checking the imported
   scene, its UID, its sidecar, its policy and its imported census.
3. Missing / tampered / unbound art now fails, at three independent layers:
   setup preflight (Python bytes + identity), `validate_prepared` (re-verified
   copies + manifest), and the GDScript runtime gate (bytes, sidecar hash, UID,
   path, census). I demonstrated each failure mode with its exact reason.

## Non-blocking observations

1. **Stale test count in the package README.**
   `tools/…/botanical-post-x/README.md:159` still says "**8 Python tests**".
   That was accurate for `902c3bbb` (3+2+3) but the delivery now has **13**
   (`4+3+3+3`). `NATIVE_BINDING_FOLLOWUP.md:94` states 13, which is correct.
   Suggest a one-line README correction so the two package documents agree.
2. **No portable test asserts the GDScript `IDENTITIES` constants equal the
   Python `ARTS`/preflight records.** Cross-language drift would only surface
   natively. I verified equality today (all 8 fields × 2 variants) by parsing
   `art_binding.gd` by hand, but a small portable test that regex-extracts the
   GDScript literal and compares it to `art_binding.preflight()` would make this
   a permanent, engine-free check. Recommended, not required.
3. **`assert()`-based verification and release binaries.** The entire GDScript
   gate is `assert(...)`. That matches house style in this repo
   (`godot/tests/new_maps/botanical_correction/x-0{1,2,3}/…/physics.gd`,
   `staged.gd`, `import.gd`) and Godot's default 4.5.2 headless build keeps
   asserts. But if a grant ever points `$GODOT` at a **release export template**,
   asserts are compiled out and the journey would still write
   `bindingReady: true` with no verification performed. Cheap hardening: record
   the build mode in the receipt (e.g. `OS.is_debug_build()` /
   `Engine.is_editor_hint()`) and fail when asserts are compiled out.
4. **Assertion failures surface as a 170 s internal timeout, not a distinct
   binding error.** `controller_journey.gd:15` arms a 170 s timer that
   `quit(2)`s, so a failed binding gate is fail-closed but is reported as
   "Controller journey bound exceeded" and will consume most of the 180 s
   runner budget. Consider setting the failing assertions' messages into a
   receipt, or failing fast with a nonzero code before the timer. Fail-closed
   direction is correct, so this is a diagnosability note only.
5. **The candidate-only `MeshInstance3D` sweep is defensive-but-dead for these
   two authorities.** `art_binding.gd:95–97` frees `MeshInstance3D` children only
   for the candidate, yet `map.gd:75–79` only emits per-surface `MeshInstance3D`
   children when `art_covers_surfaces` is false — and both authorities carry
   `arena.art.ground`, so it is true for both. Harmless belt-and-braces; the
   meaningful evidence is the explicit instantiation plus the
   `BlenderArtNoGameplayCollision == null` assertion. The reviewed X staging
   helper uses exactly this pattern
   (`godot/tests/new_maps/botanical_correction/x-03/parallax-observatory/staged.gd:60–70`:
   free old art, sweep `MeshInstance3D` children "Keep every collider", load and
   instantiate the candidate GLB, assert no `CollisionObject3D`), so keeping it
   is consistent with already-reviewed X code.
6. **Write-once coverage moved to the X-root integration test.** The previous
   `test_source_setup_is_write_once_and_has_sixty_native_trials` exercised a
   successful `setup()`; because `setup()` now legitimately requires the
   explicit X root, that success/write-once path now lives only in
   `verify_art_fixture.py` (which I ran, pass). The portable suite keeps the 60
   case/radius/height assertions by invoking `native_cases.mjs` directly and
   adds a fail-closed missing-art test. Coverage is preserved and honestly
   disclosed in `NATIVE_BINDING_FOLLOWUP.md:94–100`; a reviewer without the X
   root simply cannot run that one file. Note also that authority-JSON
   substitution is rejected in code but has **no** shipped test (I verified it
   manually: `Authority bytes mismatch`); adding it to
   `verify_art_fixture.py` would be cheap.
7. **Generated `.uid` housekeeping.** The future `--editor --import` will create
   `art_binding.gd.uid` / `controller_journey.gd.uid` in
   `godot/tests/new_maps/botanical_post_x/`. The directory `.gitignore` is
   `/*/`, which ignores attempt subdirectories only, so those generated files
   will appear untracked. Either extend the ignore file or decide explicitly
   whether generated `.uid` files are committed — do not let them slip into a
   follow-up commit unnoticed.
8. **`world.metrics.art` would still name the accepted path.** `map.gd:114`
   records the resolved (accepted) art path in metrics; the journey receipt does
   not include `world.metrics`, which is correct, but any downstream reader must
   take the selected variant from `binding.selectedVariant` /
   `binding.selectedLoadedResourcePath`, never from a WorldMap metric.
9. **Residual, accepted: no import-cache freshness check.** The gate compares the
   `.scn` hash only by *recording* it (`importedResourceSha256`) rather than
   pinning it, because the cache is engine-generated. A stale import is caught by
   the imported census/material gate rather than by a timestamp/hash comparison;
   the recorded `importedResourceSha256` plus the two-pass import/pin/reimport
   procedure in `NATIVE_BINDING_FOLLOWUP.md:65–84` is an adequate substitute.
   Nothing in the source needs changing for this.

## Conditions before any future native grant (not conditions on this delivery)

1. The granted `$GODOT` must be a build with **asserts enabled** (Godot 4.5.2
   official headless/editor binary), and the receipt should record that fact
   (observation 3). Otherwise the binding gate is decorative.
2. Treat the first group's outcome as a **binding-calibration** run: the
   imported-census gate (54804/11/11/eleven materials; 64311/29/29/seventeen
   materials), `material.resource_name` equality, the `ARRAY_FLAG_COMPRESS_ATTRIBUTES`
   readback and the retained-UID check have never been observed. A failure there
   is a gate-calibration failure, not a movement result, and must not be reported
   as either a pass or a step-up failure.
3. Keep the existing fail-closed discipline: a failed group stops the sequence,
   failed receipts are retained, retries need a fresh namespace, and the
   two-pass import/pin/reimport order must be preserved.
4. Native success, even if all 60 walk-only journeys arrive, remains a
   **movement-API diagnostic** only. It is not map acceptance, not Binder/Weather
   or presentation lifecycle certification, and not a waiver of anything below.

## Explicit scope statement

This review is **source and evidence only**. It does **not** establish, claim or
imply any of the following:

* **No native step-up success.** No Godot process was run. `Walker.step`
  traversal of either stair run remains unproven natively; the 60 walk-only
  `Walker.step` cases are unexecuted.
* **No map acceptance.** No full-map journey, mode coverage, session, keyboard,
  focus, network or presentation acceptance is claimed.
* **No promotion.** Vesper's artifact approval stays **withheld**; no
  acceptance/promotion decision, no final-art approval, and no release or
  packaging conclusion follows from this review.
* **The 184 static Vesper contacts remain failed and unwaived.** 184 positions,
  368 records, 13 candidate-only positions — all still `overlaps: true`, and the
  Vesper parapet P1 closure in `BOTANICAL_X_REVIEW.md:77–83` remains the only
  artifact-level closure.
* **The sixty native journeys remain open**, as do candidate feasibility at
  `.18`, production accounting, the Walker `.42` positive (`AM` remains failed),
  the Parallax three-corner tangent repair and any `urban-v4` successor.
* The imported-art binding is verified here **as source and as a fail-closed
  design**, not as an observed runtime fact.

## Integration guidance

Apply the two post-X source commits selectively — `902c3bbb` then `525b9fbe` —
on top of the already-selected `e3497a21` → `cef20865` → `3d50291a` →
`5b40a15b` chain. Do **not** merge this branch's ancestry: `171ffddb` carries
the X artifact tree (masters, exports, captures, failed attempts) that the
parent handles through its own selective inventory
(`BOTANICAL_X_SELECTIVE_INVENTORY.json`). No rejected artifact, capture or
historical restamp is present in the two commits reviewed here.

## Reproduction index (this review)

| # | Command | Result |
|---|---|---|
| 1 | `env -u COCS_BOTANICAL_X_FIXTURE_ROOT -u COCS_BOTANICAL_U_FIXTURE_ROOT python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/botanical-post-x -p 'test_*.py' -v` | `Ran 13 tests` / `OK` |
| 2 | `node --test tools/…/movement.test.mjs game/arena-movement.test.mjs` | `# tests 12 / # pass 12 / # fail 0` |
| 3 | `COCS_BOTANICAL_X_FIXTURE_ROOT=… python3 -B tools/…/verify_art_fixture.py` | PASS (exit 0), no residue |
| 4 | `COCS_{X,U}_FIXTURE_ROOT=… python3 -B tools/…/verify_frozen.py /tmp/opencode/postx-review/frozen-recheck.json` | 600 X + 264 U, 0 mismatches; equals committed `frozen-integrity-binding.json` |
| 5 | independent negative matrix against a scratch `setup()` fixture | 7/7 mutations rejected with specific reasons; restore → `OK` |
| 6 | independent glTF census of both pinned GLBs | 54804/11/11/11 and 64311/29/29/17; matches GDScript + Python + GLB self-declared values |
| 7 | `art_binding.gd` `IDENTITIES` vs live `preflight()` | all 8 fields × 2 variants equal |
| 8 | provenance: 15 deps (checkout + `70995941`), 10 file pins, historical provenance SHA | 15/15, 10/10, exact match |
| 9 | `git diff 902c3bbb..525b9fbe` / `171ffddb..525b9fbe` / historical-dir diff | 11 files, all source text; historical X/U trees untouched |

Logs: `/tmp/opencode/postx-review/{py-portable.log,node-tests.log,verify-art-fixture.log,frozen.log,frozen-recheck.json,negative-matrix.log}`.
