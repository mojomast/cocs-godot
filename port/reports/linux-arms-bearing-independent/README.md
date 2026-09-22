# Eight-scene Linux export: Arms Race and corrected sports bearings

Initial rebuild and fresh-extraction verification **PASS**. The lead opened the
actual exported Arms Race, Ion and Aurora images. Source startup, current/next
ladder text and corrected Right guidance are legible. This is exported startup
acceptance, separate from the independent kill/promotion and sports victory runs.

Initial archive:
`/tmp/opencode/lead-native-linux-package/builds/1790051417471077831/cocs-native-linux.tar.gz`

- Archive SHA256: `a0cf88490c1395d607ca48685ebe67cf643785da665fd3549f56daf85d1f1e64`
- Manifest SHA256: `de5f3785a0499a26df645f4eed969c0fec9f2c48602a3597890ea103154a6136`
- Build inputs SHA256: `02fef01d28e4efa75056477150ef9bba4d8d4752bc13856eb411f6af77d9a4cf`

The first build preceded staging the newly generated Arms Race `.gd.uid` files.
It imported/compiled all scripts correctly from their resource paths. A final
metadata-complete rebuild is tracked separately under `final/`; initial evidence
and hashes here remain unchanged.

## Final archive and playable extraction

Final archive:
`/tmp/opencode/lead-native-linux-package/builds/1790051601694072777/cocs-native-linux.tar.gz`

- Archive SHA256: `28aa12761bfa854a5cde1d9b7fb5b24997c1e69e68675f15f47118d5643c1172`
- Manifest SHA256: `37609fd630a23e2739238c688e9947ba23535d1297b5a664f91d65877e1ed086`
- Build inputs SHA256: `b5b7b65040475e1f4b574ea4626eb19f3cbaa6b1c3e55d13a2cb7e66a0b4c720`

Fresh final extraction validates archive/manifest hashes, exact file inventory,
absence of symlinks and every packaged file checksum. **All111 packaged runtime
files, including executable and PCK, are byte-identical to the successfully
exercised initial build.** Only the manifest records the five added UID inputs.
The unchanged runtime therefore retains the initial live/visual evidence; no
second live run is claimed. `final/verification.json` records this distinction.

```sh
node /tmp/opencode/cocs-final-arms-play-bp_3jss5/cocs-native-linux/run.mjs --experience=arms-race
node /tmp/opencode/cocs-final-arms-play-bp_3jss5/cocs-native-linux/run.mjs --experience=sports --map=ion-speedway
```

```sh
python3 -B tools/godot-package/build.py --state /tmp/opencode/lead-native-linux-package
python3 -B tools/godot-package/verify.py --build-result /tmp/opencode/lead-native-linux-package/builds/1790051417471077831/build-result.json --output port/reports/linux-arms-bearing-independent --world-commands-capture
```

Release probe: **8 compiled scenes, 9 maps**, no tests or probes, release assertions
disabled. Fresh play PATH contains only Node; no editor/git/npm or source checkout
paths/symlinks are needed. All package bytes and source-lock checks pass.

Real exported windows: setup, combat, LATTICE world and C-command panel, Meridian
Domination, Verdant KOTH, Sunscar combined arms, Arms Race, Ion race and Aurora
soccer. Trace-equipped clients have round-start/pose snapshots; other scenes have
real player/room/full-frame traffic and separately reviewed PNGs. No fixed wait
is treated as a full gameplay-completion test. Interrupt, crash, bad arguments,
missing binary and normal window-close cleanup pass with owned listeners closed.

The private ALSA null sink does not prove audible quality. Full Arms Race ladder,
hardware/Wayland, human play, lobby/Horde packaging and asset-rights remain open.
