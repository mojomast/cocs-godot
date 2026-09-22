# Linux release verification — `combat-expansion-2026-09-22-linux`

- **Release**: https://github.com/mojomast/cocs-godot/releases/tag/combat-expansion-2026-09-22-linux (prerelease)
- **Assets**: `cocs-native-linux.tar.gz` 40,078,745 B + `.sha256` sidecar
- **SHA256**: `136ee02a4f695c2e869458bc0cb07de794c2218143c4b33d2cb1150a1ed83b1a`
- **Manifest**: `be61bba7d951739b…`, port `3877c833b18e`
- **Frozen commit**: `3877c833` (tag + pushed to `godot/main`)
- **Pipeline**: state `/tmp/opencode/cocs-release-linux-exec3`, 6/6 steps ok
  (150/150 gates in verification, package 38.2 MiB)
- **Hosted run**: https://github.com/mojomast/cocs-godot/actions/runs/35789678210 — **success**
  - fresh runner, tarball downloaded and `sha256sum -c` re-checked, extracted to a new directory
  - `verify_linux.mjs`: **status passed, 16/16 cases, 132 files re-hashed** (`result.json` here)
  - cases include the packaged Domination round (identity-zones authority + capture
    scores) and the new launcher presence/exec checks (`Domination.sh`, `Cheats.sh`)

## First-run incident (recorded)

The first resume attempt omitted `--target=linux --workflow=linux-demo.yml`; the
pipeline defaulted to `target=windows` and dispatched `windows-demo.yml` against the
Linux tag, which failed as it must (zip expected, tar.gz present). Hard stop before
`push`; re-resuming `--resume-from=verify` with the correct flags passed. Publish had
already succeeded with the correct Linux assets, so nothing was re-published.
