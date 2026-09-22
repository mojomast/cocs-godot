# Native-only graphics launcher routes

Both launchers expose these standalone exploration/lab experiences:

| `--experience` | Scene |
| --- | --- |
| `showcase` | `res://showcase/demo.tscn` |
| `aurora-basin` | `res://aurora_basin/demo.tscn` |
| `cinder-array` | `res://cinder_array/demo.tscn` |
| `particle-lab` | `res://particle_lab/demo.tscn` |
| `shader-lab` | `res://shader_lab/demo.tscn` |

These live in the separate exported `NATIVE_EXPERIENCES` registries in
`tools/godot-dev/launch_options.mjs` and `tools/godot-package/options.mjs`.
The existing `EXPERIENCES` registries retain the ten source-match routes and
their nine locked source-map identities. Native-only plans have
`nativeOnly: true`, `endpoint: null`, and no map or mode arguments.

## Launch contract

From an exported/imported source checkout with `GODOT_BIN` set to the locked
Godot binary:

```sh
node tools/godot-dev/launch.mjs --experience=showcase
node tools/godot-dev/launch.mjs --experience=particle-lab --smoke
```

From the extracted package:

```sh
node run.mjs --experience=showcase
node run.mjs --experience=shader-lab --smoke
```

`--smoke` adds engine arguments `--headless --audio-driver Dummy` and forwards
the literal user argument `--smoke` after Godot's `--` delimiter. Scene owners
implement that diagnostic and its automatic exit. Interactive launches have no
launcher deadline. `--mute` is rejected because the launcher does not establish
a scene-level mute contract. Endpoint, map, mode, source-match controls, unknown
options, and ambiguous native smoke/experience arguments fail before launching.

Native-only routes skip both authority imports and all listener/readiness logic;
they also omit `--endpoint` entirely. Both launchers inherit Godot stdio, propagate
its exit status, terminate the owned child on SIGINT/SIGTERM (130/143), and force
termination after the existing three-second grace period. Temporary XDG
directories are removed after the child exits. The package resolves executable
and PCK paths against its own directory, including when launched from another
working directory. Source startup retains source-lock and exact Godot-version
validation, and uses the normal imported `godot` project.

## Windows entry and integration hooks

`tools/godot-package/Graphics Showcase.cmd` delegates to the existing `Play.cmd`
with quoted script paths. Double-clicking defaults to `--experience=showcase`.
When arguments are supplied, they are forwarded verbatim, without adding a
duplicate experience. Choose the experience explicitly when passing flags:

```bat
"Graphics Showcase.cmd" --experience=aurora-basin
"Graphics Showcase.cmd" --experience=cinder-array --smoke
```

Lead integration:

1. Add `Graphics Showcase.cmd` to the Windows command-file copy list in
   `tools/godot-package/build.py` (alongside `Play.cmd`, `Demo Menu.cmd`, and
   `Operator Preview.cmd`). No new launcher runtime module needs packaging.
2. Integrate the five scene directories and their resources from their owners,
   then perform normal Godot import and exported-PCK validation.
3. The package prints `PACKAGE_NATIVE_ONLY` with `authority: false`, followed by
   the existing `PACKAGE_NATIVE_STARTED` and `PACKAGE_STOPPED` lifecycle markers.
   Native routes must emit neither `PACKAGE_SERVER_READY` nor
   `PACKAGE_EXTERNAL_AUTHORITY`. The source launcher prints
   `Native-only <experience>; no authority; this launcher owns the native client`.

## Verification

New option and process-boundary tests:

```sh
TMPDIR=/tmp/opencode node --test tools/godot-package/native_showcase*.test.mjs tools/godot-dev/native_showcase*.test.mjs
```

Existing launcher regressions:

```sh
TMPDIR=/tmp/opencode node --test tools/godot-package/options.test.mjs tools/godot-package/lobby_options.test.mjs tools/godot-package/lobby_ownership.test.mjs tools/godot-package/horde_ownership.test.mjs tools/godot-dev/launch_options.test.mjs
```

`fixtures.mjs` uses explicitly synthetic Godot and source-validation stubs in
isolated directories. It fails on authority-module imports or Node listeners,
checks all five interactive/smoke routes, and exercises nonzero exits, crashes,
missing executables, signals, forced termination, source-validation/version
failures, and spawn failure after version validation. It checks child exit and
temporary-directory cleanup, with fixture cleanup in `finally`.

These tests establish launcher routing and ownership only. Real scene resources,
rendering, native smoke behavior, exported PCK contents, and execution of the
Windows batch entry require the integrated native/package checks.
