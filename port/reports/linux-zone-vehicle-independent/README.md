# Seven-route Linux rebuild and exported startup

The lead rebuilt the integrated zone/combined-arms runtime with shared launcher
hooks and independently verified a fresh extraction. This includes prior sports
coaching and world commands; no Node simulation changes.

```sh
python3 tools/godot-package/build.py --state /tmp/opencode/lead-native-linux-package
python3 -B tools/godot-package/verify.py \
  --build-result /tmp/opencode/lead-native-linux-package/builds/1790049841816607701/build-result.json \
  --output port/reports/linux-zone-vehicle-independent --world-commands-capture
```

- Archive: `/tmp/opencode/lead-native-linux-package/builds/1790049841816607701/cocs-native-linux.tar.gz`
- Archive SHA-256: `fe3ecd255baff2c66eee063af3f35401aa0b183a68aa79591633ad756f6ef0c9`
- Manifest SHA-256: `9f31b3d64fa39a80f2e106f0d76fc8d86d0a5664507fe74b201baa08606d3616`
- Build inputs SHA-256: `181598b6b37b09e5a2cc1a2f0587f456cd0850e52f24af8cedf135a364b7f815`
- Retained extraction: `/tmp/opencode/cocs-package-play-h22g3kk3/cocs-native-linux`

## Actual checks

[Verification](verification.json) **PASS**. The release probe loads seven compiled
scenes and all nine semantic maps, confirms release assertions disabled, and
checks tests/probes are absent. Node is the only developer executable on play
PATH. No editor, Git, npm, symlinks or original checkout paths are required.

Ten launcher cases pass: host setup, combat, LATTICE world, Meridian/Domination,
Verdant/KOTH, Sunscar combined arms, Ion race, Aurora soccer, interrupt and native
crash. Invalid arguments fail before authority startup; missing executable also
cleans up. Window close, SIGINT and crash leave no owned native PID/server port.
Play leaves all package bytes unchanged. Source lock is unchanged.

Combat/world startup uses native trace round/pose witnesses. The new standalone
routes lack that public launcher trace option: their readiness requires an
actual native window and authoritative player/room/full-frame traffic, followed
by direct image review. `readiness` records this distinction per case. A delay
alone is not accepted as gameplay evidence.

The lead directly opened `domination.png`, `koth.png`, `combined-arms.png`,
`race.png` and `soccer.png`. They show their actual named map/mode, source HUD,
controls and expected world/vehicle presentation. Zone HUD displays neutral
nodes and a running clock; vehicle startup shows infantry and a nearby Puma;
sports show racing/ball-in-play and fresh-input prompts. These are release
startup captures, not capture/drive/lap/goal completion in a release export.
The X11 C-key check also opens the real world tactical panel.

The archive is local, not a public uploaded release. Play with:

```sh
node /tmp/opencode/cocs-package-play-h22g3kk3/cocs-native-linux/run.mjs --experience=zones --map=verdant-reliquary --mode=koth
node /tmp/opencode/cocs-package-play-h22g3kk3/cocs-native-linux/run.mjs --experience=combined-arms
```
