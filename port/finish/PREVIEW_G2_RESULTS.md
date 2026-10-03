# Preview G2 — Windows verifier command-length repair

Windows CI **37091988815** failed before game launch: passing the full tracked
source inventory to `git diff` exceeded Windows' command-line limit and raised
`spawnSync git ENAMETOOLONG`. Failed logs retained at
`/home/mojo/.tmp-on-disk/cocs-finish-packaging-evidence-20261002/windows-37091988815-failed.log`.
The original `a0866981` archives remain unchanged and are not relabeled.

## Fix and frozen candidate

**`9857b33ef32025e360f05fa1c611b3e3747a9481`** changes only the external validator
and its regression test. Locked source paths are obtained with NUL-delimited
`ls-tree`; a bounded commit-to-commit NUL-delimited diff is filtered against that
exact set. `--no-renames` exposes removed originals. No command receives the
thousand-path inventory as argv, and spaces/non-ASCII names are preserved. Source
ancestry, added-source checks and exact derivative blob hashes remain enforced.

**48/48 tests passed**: all 47 channel/historical tests plus a real 1,101-file
repository exceeding 100 KB of path arguments. Git trace confirms every command
stays below 4 KB; a changed late Unicode/space filename is rejected. No promoted
receipt/source fingerprint needed reconciliation. Runtime, builders and assets
are unchanged. The first test run exposed a remaining Array `.includes` call
after conversion to Set; `.has` was corrected before the passing run.

## Replacement artifacts

Windows, **148,557,311 bytes**:
`/home/mojo/.tmp-on-disk/cocs-preview-g-windows/builds/1790996939443061346/cocs-native-windows.zip`

- Archive SHA-256: `c20d89175dd103c53fc15a6c8a7133a32738127b597e6063bdf082bca167586b`
- Manifest SHA-256: `e8e77118bdfa49d62ba59a201a5dd2c244597003aa77bd4fb959bd9e8d85d158`

Linux, **108,294,946 bytes**:
`/home/mojo/.tmp-on-disk/cocs-preview-g-linux/builds/1790997010364761360/cocs-native-linux.tar.gz`

- Archive SHA-256: `83a7e7012c10a8772014d720b0bf2b29d313ccfea0e2414ee213e1c0d1743709`
- Manifest SHA-256: `e1e997897b948aa07eda58ea5eb4a21e1a37b7fcafce95ac92b6d9c330f3324a`

Both were rebuilt serially from the same new candidate using pinned retained
caches, `--preview --source-derivative`, `LP_NUM_THREADS=1`. Fresh extraction to
each state's `extracted-g2/` passes the repaired recorded-Git validator.
Logs: `build-g2.log`, `archive-validation-g2.json` in each state.

## New-package smoke and retained evidence

Linux `smoke-g2/final/final-native.log` passes the complete declared resource/raw
probe, nine fighters/finishes, Home → training → Home, with 56 raw resources.
`smoke-g2/gui.log` passes actual graphical AI, local and training starts with
advancing ticks, screenshots and Home teardown. No SCRIPT ERROR/ERROR/failure
markers appeared. New screenshots are retained under `smoke-g2/`.

`runtime-equivalence-g2.json` proves the Linux executable, PCK and every runtime
inventory file are byte-identical to G. Only README/build-intent files differ
within that inventory; the manifest independently records the new candidate.
Prior successful extracted Campaign and graphical vehicle startup evidence remains
applicable to those exact runtime bytes, without repeating the longer routes.

**Actual Windows execution remains pending the parent's CI rerun.** No workflow
validation was bypassed and no CI or release operation was performed by this lane.
Parent should push the exact new candidate and replace the unpublished draft's
old artifacts with this pair, preserving preview limits and pending four units.

## Exclusive grant release

**PREVIEW-PACKAGE-20261003-G2 released at 2026-10-03T03:12:15.944918Z.** Fresh
process-table audit found no processes, including zombies, in owned groups
1106619, 1112881, 1119708, 1120512. Receipt:
`/home/mojo/.tmp-on-disk/cocs-preview-g-linux/HEAVY_GRANT_RELEASE_G2.json`.
Final production/native freeze/manual/audio/GPU/accessibility obligations remain
pending. This report is a later documentation commit, not a new artifact anchor.
