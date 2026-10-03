# Preview G3 — actual Windows dependency preflight passed

Frozen build candidate: **`cb6e4c9f6bff09aafe4d9ef6262c5996a6219329`**, pushed to
`preview/windows-source-preflight-g3`. This later report does not change its anchor.

## Portable closure fix and Windows proof

G2 run `37092554409` reached committed discovery but failed on `game\ranked.mjs`:
native Windows `path.relative` output had entered the POSIX runtime allowlist.
Failure retained at `/tmp/opencode/preview-windows-ci-37092554409-failed.log`.

Discovery now uses `dependencyPath`: resolve with native path semantics, verify
repository containment, then convert inventory separators to `/`. Backslash/URL
escape specifiers and escaped-root imports are rejected rather than normalized
into admitted resources. A synthetic graph is tested with both `path.win32` and
`path.posix`, including spaces/non-ASCII roots and unsafe traversal cases.

Related audit: package file inventories already canonicalize `relative(...).split(sep)`;
production helper identities use `path.posix`; root/catalog imports use
`fileURLToPath` / `pathToFileURL` or URL-aware filesystem reads. Committed discovery
materializes native filesystem paths separately from Git/POSIX identities.
No asset recipe, runtime, fingerprint, promotion or receipt input changed.

**Real Windows source-only preflight passed before rebuilding:**
https://github.com/mojomast/cocs-godot/actions/runs/37092862744

It ran Node 22.22.0 on Windows with exact checkout bytes (autocrlf disabled),
Windows path/long-command regressions, locked source/derivative verification,
recorded-Git discovery, final resources, fighter import checks and preview
production validation: **86 source modules, 39 adapters, 10 worlds, nine fighter
imports, 814 Git-byte comparisons**. Default final mode still refuses four pending
units. No engine/downloaded package or native game was run by that preflight.
The incidental general CI run triggered by the branch push was cancelled; only
the specifically authorized source preflight was allowed to finish.

Local targeted source tests: **49/49 passed**. Preflight log retained in packaging
evidence as `windows-source-preflight-g3.log`; local log `preview-g3-source-tests.log`.
The existing full Windows artifact workflow is unchanged and remains parent-owned.

## Same-candidate replacement previews

Windows ZIP (**148,557,455 bytes**):
`/home/mojo/.tmp-on-disk/cocs-preview-g-windows/builds/1790997760246901337/cocs-native-windows.zip`

- SHA-256: `4072b99b82902da9c46f348edb3d185b280ab62d4ded5e717e093cc2cd25089c`
- Manifest SHA-256: `ad5b860a436499f253dcc4110d1f34a0e5158d681bd91f16c6687f2e1227fbe0`

Linux archive (**108,295,199 bytes**):
`/home/mojo/.tmp-on-disk/cocs-preview-g-linux/builds/1790997831825348904/cocs-native-linux.tar.gz`

- SHA-256: `9fe22e32e227b235f52255de8b69f04398095dd22615401b07f6e57623612c02`
- Manifest SHA-256: `b2e71013064aca82ac1fd6393a4da2a0dfcd3e93bab4bda1628be780b53c988d`

Both rebuilt serially with verified cached binaries, `--preview --source-derivative`,
`LP_NUM_THREADS=1`. Fresh `extracted-g3/` directories pass recorded-Git artifact
validation (`archive-validation-g3.json` in each state). Earlier archives retained.

Linux exact-runtime comparison with G2 (`runtime-equivalence-g3.json`) finds only
README/build-intent inventory changes; executable, PCK and all runtime files are
byte-identical. New-package `smoke-g3/final/final-native.log` passes the complete
declared resource/raw probe, all nine fighter rigs/finishes and Home → Fighting
training → Home: `PACKAGE_FINAL_OK ... raw_resources=56`, no engine errors.
Prior graphical AI/local/training, Campaign and vehicle startup results retain
their original anchors and apply to these identical runtime bytes.

## Grant release / parent handoff

**G3 explicitly released at 2026-10-03T03:25:38.918268Z.** Fresh process-table audit
found zero processes, including zombies, in owned groups 1159124, 1165360, 1171831.
Receipt: `/home/mojo/.tmp-on-disk/cocs-preview-g-linux/HEAVY_GRANT_RELEASE_G3.json`.

Parent should replace the unpublished draft assets with this pair and run full
Windows artifact/game verification using the exact frozen candidate. The successful
source-only preflight is not native Windows gameplay proof. No full-runtime CI or
release publication was dispatched by this lane. Preview remains three promoted /
four pending; final production/native freeze/manual/audio/accessibility/GPU gates
are not waived.
