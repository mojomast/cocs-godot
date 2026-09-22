# Private native Linux package lane

Scope: local build/run prototype from port base `6116f12`, locked source
`51289b79c627a26a381ba556b92bab71f93f3732`, and exact Godot
`4.5.2.stable.official.6ce3de25a`. No public release, upload or asset-rights claim.
The committed deliverable is build/launch/verification code and bounded evidence;
executables, PCKs, archives and toolchain caches stay outside the repository.

The lead has independently rebuilt the integrated code and verified exported
combat/world startup from a fresh Node-only directory, including failure cleanup.
See [independent build and evidence](../reports/linux-package-independent/README.md).

## Build, verify, run

Build prerequisites: Linux x86_64, full repository history, Node >=22.13.0,
Python >=3.12, git, and HTTPS access to the official Godot release and npm's locked
`ws` tarball. The builder does not invoke npm or execute package install scripts.
The verifier additionally uses Xvfb, libX11 and ffmpeg from the build/test machine.

```sh
python3 tools/godot-package/build.py \
  --state /tmp/opencode/my-private-native-package
```

To avoid downloading already available official archives, add
`--archive-directory /absolute/read-only/archive-directory` containing
`editor.zip` and `templates.tpz`. The builder **copies** those files to its own
state and verifies both against the pinned hashes and freshly fetched official
`SHA512-SUMS.txt`. It extracts only the editor and Linux x86_64 release template.
The builder never installs into shared XDG directories or shared toolchain caches.

The printed build result identifies the archive, its SHA256, the manifest SHA256,
and the unique build directory. Keep that result for verification:

```sh
python3 tools/godot-package/verify.py \
  --build-result /tmp/opencode/my-private-native-package/builds/BUILD_ID/build-result.json \
  --output /tmp/opencode/my-private-package-evidence
node --test tools/godot-package/options.test.mjs

cd /tmp/opencode/my-private-native-package/builds/BUILD_ID
sha256sum -c cocs-native-linux.tar.gz.sha256
mkdir /tmp/opencode/my-private-play-directory
tar -xzf cocs-native-linux.tar.gz -C /tmp/opencode/my-private-play-directory
cd /tmp/opencode/my-private-play-directory/cocs-native-linux
node run.mjs
```

The output directory for verification must be new, preserving earlier attempts.
See [PLAY.md](PLAY.md) for all seven experience routes and direct exported-scene
commands, including `--experience=zones` and `--experience=combined-arms`.
Current commands and controls are also in the root
[README](../../README.md#zone-control-and-combined-arms). The expanded seven-scene
rebuild is verified in [the integration report](../reports/linux-zone-vehicle-independent/README.md).
Only Node and normal Linux desktop runtime libraries are prerequisites at play
time. All runtime dependency files are already copied; no installation is needed.

## Discovery: authority and data closure

`tools/godot-package/discover.mjs` asks V8's `SourceTextModule` parser for actual
static import specifiers. Starting at `server/game-server.mjs`, the locked source
has **84 local modules** and exactly one external package, **ws 8.21.3**. The full
edge list is written to `logs/server-closure.json` and the package manifest. The
builder compares every copied authoritative module directly with `git show` of
the source lock, in addition to the existing `verifySource()` checks. It rejects
shallow history, altered source/dependencies, unexpected external dependencies,
source changes during build, symlink inputs and Godot version mismatches.

Source audit findings:

- `server/game-server.mjs:1–12` imports HTTP, ws, the registry and stores, protocol,
  identity, config/outcome/ranked helpers and crypto. Its ordinary
  `createGameServer` defaults use a 1/60 timestep, normal timer cadence, original
  random source and original snapshot settings. The package calls it with only
  `{historyPath:null, progressionPath:null}`, matching the ordinary native dev
  launcher. It binds its HTTP/WebSocket server to `127.0.0.1`, port **0**.
- `server/rooms.mjs:133–142` creates the default empty `local` room. Consequently,
  healthy setup already reports one room and zero players; a started native host
  adds its own room. The verifier checks this real baseline rather than assuming
  an empty registry.
- `server/history.mjs:13–29` and `server/progression.mjs:86–90` perform the only
  filesystem reads in this server closure. Null paths skip those reads and the
  related persistence writes. The direct server entry point's persistent JSON
  defaults are not invoked when its exported factory is imported.
- Map registries and the rules/data they use are JavaScript module imports.
  `game/maps.mjs` pulls in all required destination and legacy map modules; the
  complete import closure is retained rather than rewriting/pruning authority
  registries. There are no dynamic imports or runtime asset fetches in this
  authoritative closure. `game/moth-assets.mjs`/`moth-baked.mjs` are metadata;
  browser media URLs inside them do not cause Node to fetch/read media files.
- `ws`'s locked registry archive is checked using the lockfile SHA512 integrity.
  Its real files and MIT license are copied to `runtime/node_modules/ws`.
  Optional `bufferutil`/`utf-8-validate` accelerators are not required by ws and are
  absent. The full web dependency tree, browser server, tests and dev tools are
  outside this runtime closure.

## Discovery: export pipeline and native resources

The repository already has `godot/export_presets.cfg`; this lane does not change
it. That existing diagnostic preset uses an embedded PCK and all resources.
Instead, the builder copies only tracked native runtime project files into a new
external staging project, generates a package-only preset **there**, and performs
semantic generation, isolated editor import and a release export. Separate
`cocs.x86_64`/`cocs.pck` files make the runtime and content boundary inspectable.

- `tools/godot-export/semantic.mjs` verifies locked lineage/bytes and writes the
  nine-map JSON catalog and hash-bearing map entries.
- `godot/world/catalog.gd` reads that catalog and verifies every selected map
  JSON against its SHA256. Those JSON files need explicit export inclusion because
  `FileAccess` paths are resolved at runtime, not just through resource references.
- The current native scenes construct their visuals procedurally from semantic
  geometry. `godot/world/viewer.gd:39–49` loads the GLB probe **only** for the
  explicit `--visual-probe` branch. The package launcher does not expose that
  diagnostic mode. No GLB, CI probe, source audio/media or imported asset cache
  is needed by the production scene paths in this prototype.
- The staging project contains no `tests/`, `content/probes/`, or copied `.godot`
  cache. Its fresh `.godot` metadata/compiled export resources are generated by
  the exact editor. The final PCK includes the engine-required compiled/resource
  metadata, not a copy of the editor cache directory.
- All five existing scene paths are exported unchanged: combat, sports,
  objectives, LATTICE board and LATTICE world. Routing is package-local and does
  not depend on an uncommitted common-launcher hook. The package keeps all nine
  catalog identities while rejecting unsupported native map/mode combinations.

## Verification and limits

`godot/tests/package_inspect.gd` runs as an **external** script against the release
executable/PCK. It verifies all nine semantic maps, all five compiled scenes,
absence of test/probe directories, `editor=false`, `debug=false`, and an assertion
side-effect witness proving assertions are disabled. All acceptance conditions
use explicit failures; the fixture itself is not shipped in the production PCK.

The artifact verifier extracts the tarball into a fresh unrelated directory and
copies only Node into the play `PATH`. It checks no `.git`, no symlinks (including
node_modules), no original checkout paths, every file hash and archive/manifest
hashes. It starts a private Xvfb with `-nolisten tcp -nolisten unix` and uses a
private null ALSA sink on this test machine (no shared audio service). Actual
graphical exported combat and LATTICE-world clients produce the existing
`PORT_NATIVE_TRACE` **round_start** and recipient **pose snapshot** records;
owned-server HTTP health independently shows a joined player and snapshots.
The trace audit follows `godot/world/session.gd:231–245` (started callback) and
`297+` (snapshot callback), not a synthetic server receipt or a `--quit-after`
timer. Screenshots capture native setup and both started scenes.

Normal window close, Ctrl+C, native process failure and missing executable are
tested for expected launcher exit and absence of surviving native processes or
server listener. Invalid arguments fail before a server is created. The extracted
package bytes and locked source bytes are rechecked after play.

This is **startup/package portability evidence**, not a new gameplay acceptance
claim. Existing scene limitations, presentation gaps and source asset-rights
questions remain recorded by the project. Interactive launcher sessions have no
time limit; bounded timing is confined to external verification. Shared-session
lobbies and external multiplayer ownership belong to other lanes.

Recorded artifact hashes and actual test results are in the scoped `evidence/`
directory after a completed build/verification run.
