# Independent Linux prototype build and play verification

Agent delivery `0c2dc2b` / `47c0ba2` integrated as `7f694ce` / `1b0949b`.
The lead reviewed authority dependency discovery, isolated official toolchain
validation, native release export, package-local routing and process ownership.
An independent build reused read-only official archives, reverified them against
the freshly fetched official checksum manifest, and generated a fresh artifact:

```sh
python3 tools/godot-package/build.py \
  --state /tmp/opencode/lead-native-linux-package \
  --archive-directory /tmp/opencode/cocs-linux-package-state/toolchain
python3 tools/godot-package/verify.py \
  --build-result /tmp/opencode/lead-native-linux-package/builds/1790046589254829387/build-result.json \
  --output /tmp/opencode/lead-native-linux-package-verification
node --test tools/godot-package/options.test.mjs
```

## Artifact

**PASS**, build runtime `1b0949b`, pinned official Godot 4.5.2 release template,
unchanged locked authority, all nine maps and five compiled native scenes.

Archive (28,293,203 bytes):
`/tmp/opencode/lead-native-linux-package/builds/1790046589254829387/cocs-native-linux.tar.gz`

SHA256:
`1eaf10a8de987267d33d2eb72da6abaf2734d45de81d0ddb8a26945e76cd7462`

Manifest SHA256:
`956f90fd211d23b8f30a81d7a2afb043cea0ade857483520aa36521ac8e0f6c9`

The input inventory hash matches the agent's build exactly. Generated-resource
and archive hashes differ; byte-reproducible export is not claimed. The new
archive is independently identified and validated. Binaries/archives stay
outside git; this is a local prototype artifact rather than a public release.

## Fresh-directory runtime checks

Extraction:
`/tmp/opencode/cocs-package-play-osf0pa8q/cocs-native-linux`.
The caller ran from an unrelated sibling directory with only a copied Node
binary on PATH, no `.git`, no symlinks and no original checkout paths in package
files. The verifier inspects every manifest file hash before and after play.

| Case | Observed result |
|---|---|
| Default setup | Visible native host menu, no joined player; ordinary window close exits 0 |
| Meridian combat | Real `round_start`, 7 recipient pose snapshots and independent source health; window close exits 0 |
| Monsoon co-op world | Real `round_start`, 7 recipient pose snapshots and source health; window close exits 0 |
| Ctrl+C | Exit 130, native process and owned listener gone |
| Native crash | Exit 1, owned listener gone |
| Missing executable | Explicit ENOENT, server and temporary launcher state cleaned |
| Invalid arguments | Rejected before server allocation |
| Final inventory/source check | Exact package bytes/file set and locked authority unchanged |

The lead opened all three actual release-client screenshots: `host-setup.png`,
`combat.png`, `lattice-world.png`. Setup, native geometry/HUD and the source
actors are visible. The private Xvfb and null ALSA test sink did not touch shared
display/audio services. All native PID/listener absences were rechecked after
verification. The extracted package remains available locally for manual play:

```sh
node /tmp/opencode/cocs-package-play-osf0pa8q/cocs-native-linux/run.mjs
```

Normal play requires Node **>=22.13.0** and Linux desktop libraries. No editor,
Git, npm, source checkout or dependency install is needed at play time.

The release probe explicitly checks conditions because release `assert` is
disabled. It proves all nine catalog identities/five scene resources exist and
tests/probes are absent. Two package option test groups pass. This is real
exported-client startup/ownership verification, not new driving, combat, scoring,
strategy victory, audio listening or recording-finalization acceptance.
The combined **63-gate verifier passes**, including the new package-options
gate; the actual archive build/export/extraction checks remain scoped to this
independent package report rather than attributed to headless CI.
