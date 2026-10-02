# Windows final release preparation — source checkpoint

**Latest source update:** see [PACKAGING_ASSETS.md](PACKAGING_ASSETS.md). Parent
`bb02e34b` now supplies all nine real fighter exports/masters/sidecars. Their
strict source closure passes; the seven queued production units and final native
acceptance still block release. The earlier checkpoint below is retained.

## Candidate and grant boundary

Canonical content baseline: **`e38b3662`**. Packaging history was reconciled with
that exact committed parent in merge **`88cbc406`**. No files from the integration
worker's dirty tree were read or copied. This is source preparation, not a frozen
release candidate: the nine fighting rig exports are still absent at this anchor.
Implementation commit: **`97e95a4c18044c5e15bcaebb5013878d4fe0ea01`**.

No engine, Blender, import, export, archive creation, workflow dispatch or release
publication was performed. Parent must supply the final **40-character commit**
and export/CI/publication grant. `build.py --candidate` now rejects a different or
abbreviated revision before creating build state. Both platform artifacts should
record the same final candidate if Linux is built as well.

## Audited closure

`tools/godot-package/final_resources.mjs` reads exact manifest-declared inputs,
not arbitrary files found in candidate directories:

- Fighting `data/{roster,rules,schema}.json`, nine exact operator identities, FX
  catalog bound to roster SHA-256, FX manifest and all 54 unique named PCM files.
- Each future `assets/operators/<id>.{json,glb}`: identity, roster/rules timing
  hashes, nonempty clips, content-bound timing, original GLB SHA-256 and GLB header.
  The six-file authoring-pipeline hash, committed Blender master and unchanged
  source operator GLB are checked against each future manifest; explicit FX
  authoring/synchronization inputs are also included in build provenance.
  Production build requires all nine. `--audit` reports pending IDs without
  granting acceptance. Shared bone/victim tracks are currently transported inside
  each GLB; no nonexistent shared-library runtime is assumed. If the asset owner
  later externalizes them, `shared_resources` must explicitly declare scoped
  `res://fighting/assets/shared/*.{glb,tres,res,json}` paths and hashes. This contract
  must be reconciled with the actual asset owner's committed format before export.
- Operator Moth finish manifest, all nine profiles and 116 PNG hashes; every
  referenced finish/texture must exist. Records the generator, original baked Moth
  source, source art references and nine unchanged source operator GLBs.
- Original and derived Moth manifests: original bake hash, derivation tool hash,
  original-manifest relationship and every declared original/derived PNG hash.
- Registered map dressing retains its existing registry-scoped profile closure;
  the extracted feature probe now includes those profile hashes too.

At `e38b3662`, source audit yields **337 runtime resource paths, sixteen provenance
paths and 55 required raw resources** (54 PCM files plus Helix GLB). All nine
fighter exports remain pending. Strict source preflight rejects this incomplete
state before any engine/toolchain work. It must not be bypassed for the release.

New manifest fields `final_resource_sha256`, `final_provenance_sha256`,
`raw_resource_sha256` and `raw_export_plugin_sha256` are re-derived from the
artifact's recorded Git objects. Refreshed/forged hashes cannot substitute for
committed content. Older recorded artifacts retain their historical contract.
Source `515daf07`, reviewed derivative and core identities are unchanged.

### Raw files and Godot imports

The fighting director uses `FileAccess.get_file_as_bytes` for WAVs; the Helix
stage uses `FileAccess.get_sha256` for the original GLB. Merely adding JSON/WAV
include filters cannot guarantee these reads: Godot's importer normally exports
the converted resource and `.import` remap instead of the original bytes.

The staged, export-only `raw_export_plugin.gd` adds precisely the hashed raw paths
alongside their normal imported resources using `add_file(..., false)`. Builder
records the source plugin hash and raw inventory. Its generated addon/config is
excluded from the production PCK. No production GDScript is rewritten. Mechanism
was checked against the pinned Godot implementation:
<https://github.com/godotengine/godot/blob/4.5.2-stable/editor/export/editor_export_platform.cpp>
(`_export_file`, `extra_files`, imported-resource export). Actual plugin execution
and final PCK bytes remain unrun until the export grant.

`package_final.gd` is an external probe under the packaging tools. It checks raw
and JSON hashes, loads imported resources, configures all nine real fighter rigs
and finishes, presses the real Home Fighting button, starts a production training
match, observes advancing simulation ticks, pauses/resumes and returns Home.
`verify_final.mjs` runs it against the extracted PCK from a clean CWD with spaces,
isolated user paths and the target's actual executable. Native syntax/type/runtime
acceptance of this prepared probe remains pending.

## GitHub and Windows CI: actual observations

- `gh auth status` succeeded for `mojomast`, with repository/workflow access.
  Every subsequent command explicitly selected **`mojomast/cocs-godot`**: the
  worktree's `origin` is a different repository. The initial implicit repository
  lookup returned “release not found”; it did not change any release.
- Windows workflow `364017730` is active and uses `windows-latest`. Prior native
  run **36972400600** succeeded at runtime `e731fd53`:
  <https://github.com/mojomast/cocs-godot/actions/runs/36972400600>.
  This is proof of the earlier runtime only.
- Explicitly read and preserved
  `quiet-relay-source-expansion-2026-10-02`. GitHub's unqualified “latest” endpoint
  instead selected the older stable gallery tag `lattice-live-gallery-2026-09-28`;
  do not confuse stable-latest metadata with the latest runtime prerelease.
- Prepared workflow now requires an exact candidate SHA, checks out full history
  at that SHA, verifies ZIP checksum, downloaded manifest candidate/target and
  bundled Node hash, then runs recorded-Git manifest validation with bundled
  Windows x64 Node. Runtime verification runs with PATH restricted to Windows
  system directories: no installed Node, SDK or checkout runtime dependencies.
- Existing suite already invokes **actual `Play.cmd` and `Campaign.cmd`** from
  a fresh CWD and extraction path containing spaces. It retains cleanup checks,
  all previous cases, platform guard, expansion cases and four-file replay helper.
  The new final PCK/Home Fighting probe is an additive report section.

## Executed source checks

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-finish-packaging-evidence-20261002`.

- `windows-prep-nonengine-tests.log`: **234/234 passed**, all package Node tests
  except the engine-dependent `career_native.test.mjs`; reviewed derivative
  explicitly selected. This includes current 24-bot factory cases, preserved
  older-artifact integrity checks and four new final-content negative tests.
- `windows-prep-focused-tests.log`: final resource/integrity focused suite passed.
- `windows-prep-final-content-tests.log`: **4/4 passed** after adding explicit FX
  generator and six-file animation-pipeline/master provenance requirements.
- `final-content-audit.json`: actual content inventory and nine pending exports.
- `final-assets-required.log`: retained expected strict failure for missing rigs.
- `windows-prep-discovery.json`: current committed-source graph inspection;
  accepted catalog is **nine worlds / 54 pairs**, not seven/43. All previous
  startup cases remain; Helix/Foundry add eleven pairs (86 startup cases before
  additive feature/final report sections). Future pairs continue to derive from
  accepted catalogs, not a fixed total.
- `windows-prep-committed-discovery.json`: actual recorded-object re-derivation at
  implementation commit `97e95a4c` passed: **86 source modules, 39 port adapters,
  nine worlds**, without reading current checkout runtime bytes.
- `previous-windows-run.json`, `windows-workflow-status.json`,
  `preserved-runtime-release.json`, `recent-godot-releases.json`: read-only GitHub
  observations. Python AST, workflow YAML syntax and whitespace checks passed.

## Parent-granted release commands

These are **prepared commands, not executed actions**. The final candidate is not
`e38b3662`: it must include packaging fixes, integrated native fixes, all accepted
assets and final source/native acceptance. Parent supplies the exact value below.
Choose a new suffix on every attempt; never overwrite prior artifacts or tags.

```sh
REPO=mojomast/cocs-godot
CANDIDATE=REPLACE_WITH_PARENT_GRANTED_FINAL_40_HEX_COMMIT
test "$(git rev-parse HEAD)" = "$CANDIDATE"
SHORT=$(git rev-parse --short=12 "$CANDIDATE")
TAG="quiet-relay-operator-clash-2026-10-02-${SHORT}-rc1"
TITLE="Quiet Relay · Operator Clash Windows candidate ${SHORT} (RC1)"

# Source preflight, then export only after the granted slot:
node tools/godot-package/final_resources.mjs "$PWD"
node tools/godot-package/world_resources.mjs "$PWD"
python3 tools/godot-package/build.py --candidate "$CANDIDATE" \
  --state "/tmp/opencode/windows-${SHORT}-rc1" --target windows --source-derivative

# Use exact paths printed in build-result.json, then freshly extract elsewhere.
ARCHIVE=/ABS/BUILD/cocs-native-windows.zip
PACKAGE=/ABS/BUILD/cocs-native-windows
EXTRACTED=/ABS/FRESH-EXTRACTION/cocs-native-windows
node tools/godot-package/manifest_validation.mjs --package "$EXTRACTED" --repo "$PWD" --json
(cd "$(dirname "$ARCHIVE")" && sha256sum -c "$(basename "$ARCHIVE").sha256")

# After parent grants draft upload/CI, create a new frozen verifier branch.
git push godot "$CANDIDATE:refs/heads/release/windows-${SHORT}-rc1"
# Confirm TAG does not already exist (distinguish not-found from auth/network errors).
gh release view "$TAG" --repo "$REPO"
# Only after confirmed absence:
UPLOAD=/ABS/NEW-UPLOAD-DIRECTORY
mkdir "$UPLOAD"
cp "$PACKAGE/manifest.json" "$UPLOAD/windows-manifest.json"
sha256sum "$ARCHIVE" "$UPLOAD/windows-manifest.json" | sed 's|  .*/|  |' > "$UPLOAD/SHA256SUMS"
gh release create "$TAG" --repo "$REPO" --target "$CANDIDATE" \
  --title "$TITLE" --draft --prerelease --notes-file /ABS/REVIEWED-RELEASE-NOTES.md \
  "$ARCHIVE" "$ARCHIVE.sha256" "$UPLOAD/windows-manifest.json" "$UPLOAD/SHA256SUMS"
gh workflow run windows-demo.yml --repo "$REPO" \
  --ref "release/windows-${SHORT}-rc1" -f tag="$TAG" -f candidate="$CANDIDATE"
# Record the specific resulting run ID and inspect/upload its retained evidence.
gh run watch PARENT_RECORDED_RUN_ID --repo "$REPO" --exit-status
```

The draft remains a draft until the parent reviews **that candidate's** Windows
results and remaining acceptance. If publication is then separately granted,
`gh release edit "$TAG" --repo "$REPO" --draft=false --prerelease` publishes only
the new prerelease. No `--clobber`, deletion, old-tag mutation or latest-release
promotion is part of this procedure. Recheck that manifest `port_commit` and CI
checkout equal `CANDIDATE` immediately before publication.

If Linux fits the granted schedule, use a separate fresh state directory with
the same `--candidate`, run its real extracted Linux suite and upload uniquely
named Linux manifest/hash assets. Windows remains the requested priority.

## Native Windows end-to-end checklist (pending)

1. Clean extraction, ZIP/hash/manifest identity, bundled x64 Node, real Windows
   engine version; launch without installed Node/Godot/SDK and with spaces in CWD.
2. Play.cmd Home startup, every Campaign.cmd chapter startup/teardown, original
   route cases, all nine accepted worlds/54 pairs and retained cheat entrypoints.
3. Home Replays without authority; all four helper hashes, valid library lifecycle,
   missing/corrupt helper error without checkout fallback. No orphan helper/listener.
4. Final PCK raw 54-WAV/Helix bytes and imported resources; all nine fighter
   manifests, timing hashes, imported bones/clips and installed finish profiles.
5. Real Home Fighting selection → advancing training → pause/resume → Home;
   graphical AI/local-versus/Settings/input/restart journeys and all accepted stages.
6. Inspect nine distinct animations/effects, paired throws/tech/interruptions,
   combat readability, operator texture/material identity and dressed-map views.
7. Actual Windows audio-driver playback/listening and mixed-effect checks;
   real-input/controller and human acceptance; measured GPU performance/frame
   budgets on identified hardware. Headless Dummy audio and hosted CI do not
   establish these properties.

Cross-export success is **not Windows execution**. A successful hosted Windows
headless probe is **not human, real-driver listening or real-GPU acceptance**.
Unfinished gates must remain explicit in candidate release notes.
