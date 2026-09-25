# Catalog test build — source derivative

The catalog test build is a development derivative of the LATTICE preview.
`port/contracts/source-lock.json` remains pinned to
`515daf07589150dd3241f4ae1425cc1b093912f5`; the seven changed runtime
source files are individually frozen by SHA-256 and commit in
`port/contracts/lattice-catalog-derivative.json`. The semantic exporter and
native package builder keep their original strict source-lock behavior unless
the builder is explicitly invoked with `--source-derivative`.

Build Linux and Windows **serially** with the pinned Godot 4.5.2 templates:

```sh
COCS_PACKAGE_DISK_ROOT=/home/mojo/.tmp-on-disk python3 tools/godot-package/build.py \
  --state /home/mojo/.tmp-on-disk/lattice-flagship-linux-package-state \
  --target linux --source-derivative
COCS_PACKAGE_DISK_ROOT=/home/mojo/.tmp-on-disk python3 tools/godot-package/build.py \
  --state /home/mojo/.tmp-on-disk/lattice-flagship-linux-package-state \
  --target windows --source-derivative
```

Each package manifest records the original source lock, derivative commit,
derivative manifest hash, exact packaged source-module hashes and current port
commit separately. The builder refuses any changed runtime source file outside
the manifest, altered bytes, missing ancestry, or a mid-build input change.

In the native LATTICE World (`--experience=lattice-world`), open the command
panel with its displayed Command binding and enter the REQ picker. Try Sentry
after earning 60 REQ on foot, Repair Tool by a friendly cut link, and Recon
Pulse with 60 REQ while holding the real commander seat and living uncloaked
enemies present. The source server decides and settles each purchase; a queued
request is not a completed spend. The native geometry instruments from the
Astra lane are included; its four Mothbake normal-map studies are archived
candidates, not runtime materials. Career/Arsenal visual comparisons are web UI
features and are not embedded in the native Godot executable.

This build is a hands-on test artifact, not MVP acceptance. Live native
purchases, Windows hardware execution, rendered usability, natural Operations
five-wave victory, and eight-human acceptance must be recorded separately.
