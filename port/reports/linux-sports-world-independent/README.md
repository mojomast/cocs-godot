# Linux rebuild after sports and world-command integration

Lead build at runtime `8a58c97`, containing LATTICE world commands (`511bb8d`)
and passive soccer coaching / practice-option validation (`8a58c97`).

```sh
python3 tools/godot-package/build.py --state /tmp/opencode/lead-native-linux-package
python3 -B tools/godot-package/verify.py \
  --build-result /tmp/opencode/lead-native-linux-package/builds/1790049033430669279/build-result.json \
  --output port/reports/linux-sports-world-independent --world-commands-capture
```

- Archive: `/tmp/opencode/lead-native-linux-package/builds/1790049033430669279/cocs-native-linux.tar.gz`
- Archive SHA-256: `32d0189e7bb004807835e54418d88173666a981eb6f3d24048f91b7484f865de`
- Manifest SHA-256: `babb513fe1ad519aa929dadd1a3a0d8347d747934358b1dc94ce9b21192d0814`
- Build inputs SHA-256: `acb7ec42ae6c50229dd40e851f54831d474b1a11e830c58d43e8e2cd21639cbe`
- Retained extraction: `/tmp/opencode/cocs-package-play-zy9iy9k0/cocs-native-linux`

[Verification](verification.json) passes: setup, real combat/world startup and
recipient snapshots, window close, Ctrl+C, native crash, invalid options and
missing executable cleanup. All owned clients/authorities exit and ports close.
Play PATH has Node only; there is no editor, Git, npm, checkout path or symlink
dependency in the archive. Package bytes remain identical after play. The release
probe confirms five scenes, all nine maps, no embedded tests/probes and disabled
debug assertions. Locked source remains unchanged.

Direct image review of `host-setup.png`, `combat.png` and
`lattice-world-commands.png` passes. The world panel was opened in the real
release client using the verifier's optional XTest C key, with the co-op window
correctly unavailable. This establishes exported UI opening, not command execution
or sports completion in the exported build. Independent editor-client gameplay
acceptance is documented in the adjacent sports/world-command reports.

The archive is local and has not been uploaded as a public binary release.
To play this extraction locally:

```sh
node /tmp/opencode/cocs-package-play-zy9iy9k0/cocs-native-linux/run.mjs
```
