# Explicit user test preview — grant G

User requested a current Windows test build before the final production queue is
complete. `build.py --preview` is the explicit opt-in. Default builds still require
all seven production units. Preview validates all nine fighting rigs/import
policies and all promoted Parallax/robot/vehicle assets, masters, PNG/import inputs
and source identities; a missing or tampered promoted unit fails rather than
falling back. The four unpromoted units are scenery, Vesper Viaduct, Abyssal
Pressureworks and Stormglass Causeway. Current registered maps remain ten worlds /
60 pairs; no candidate world is registered. Campaign retains its existing stock
scenery fallback.

Manifest fields `build_channel`, `build_flags`, `pending_production`,
`verification_limits` and `build_intent` are checked against recorded source and
production requirements. The packaged `build-intent.json` and exact preview README
must agree with that intent and are included in the artifact file hashes. Historical
builders cannot acquire a preview channel. Final manifests cannot simply change a
channel field or hide pending names. Published archive/manifest hashes remain the
external integrity anchors; no unsigned artifact claims cryptographic authenticity.

Windows retains bundled pinned Node, executable-relative launch/replay and the
same resource/import safeguards. Preview is not final manual/audio, accessibility,
GPU/performance, full production or release acceptance. Latest HUD source needs
its own native review; E's historical screenshots are not relabeled fixed.

Grant `PREVIEW-PACKAGE-20261003-G` authorizes serial imports/exports, local extraction
and bounded Linux native smoke after scenery F released its owned groups. Parent
owns Windows CI dispatch and publication. No full 142-check ledger is required
for this explicitly labeled test preview, but launch failures block delivery.

Pinned archive cache:
`/home/mojo/.tmp-on-disk/cocs-mode-parity-windows-770-package/toolchain/`
contains `editor.zip`, `templates.tpz`, `node-v22.22.0-win-x64.zip`, `ws-8.21.3.tgz`.
New owned states are outside Git under `/home/mojo/.tmp-on-disk/`.

After committing and freezing `CANDIDATE=$(git rev-parse HEAD)`, Windows first:

```sh
LP_NUM_THREADS=1 COCS_PACKAGE_DISK_ROOT=/home/mojo/.tmp-on-disk \
python3 tools/godot-package/build.py --preview --target windows \
  --candidate "$CANDIDATE" --source-derivative \
  --state /home/mojo/.tmp-on-disk/cocs-preview-g-windows \
  --archive-directory /home/mojo/.tmp-on-disk/cocs-mode-parity-windows-770-package/toolchain
# Repeat with --target linux and --state .../cocs-preview-g-linux, same candidate.
```

Source channel/historical-manifest tests: `preview-channel-tests.log` in the
packaging evidence directory. Build logs and failed attempts will be retained.
