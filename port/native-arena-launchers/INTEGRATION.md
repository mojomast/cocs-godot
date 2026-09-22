# Native Deathmatch launcher integration

## Runtime contract

Both launchers dynamically select the named export
`createNativeArenaAuthority` from `port/native-arenas/authority.mjs` only for
`--experience=native-dm`. They await:

```js
createNativeArenaAuthority({
  port: 0,
  host: '127.0.0.1',
  mapId: 'prism-foundry', // or aurora-basin / cinder-array
  mode: 'deathmatch',
  bots: 2,
  roundSeconds: 180,
})
```

The owned result must expose `close()`. A ready `endpoint` string is supported,
as is the Horde-style `{server, wss, close}` result with an unstarted HTTP server.
When present, `server` is monitored for runtime errors and residual WebSocket
clients are terminated before closing. The endpoint must be
`ws://127.0.0.1:<ephemeral-port>` without credentials, query, fragment or extra
path. HTTP readiness at that port must return a successful JSON response with
`localOnly: true` and the numeric bound `port`.

Godot receives `res://native_arenas/demo.tscn`, followed by `--`, the owned
`--endpoint`, `--map`, `--mode=deathmatch`, `--bots` and `--round-seconds`.
`--smoke` adds `--headless --audio-driver Dummy` before engine routing arguments
and forwards the scene's own `--smoke` option. The launcher fails and tears down
the client/authority if the client exceeds 20 seconds; an uncooperative native
process is force-killed after a further three seconds. Normal play has no
launcher deadline. Native DM ignores `PORT` and uses an owned temporary XDG tree
under Node's `os.tmpdir()` (therefore respecting `TMPDIR`).

## Builder hooks

`tools/godot-package/discover.mjs` returns:

- `modules`: static source runtime closure, validated against the source lock.
- `adapterModules`: static port-owned closure, including Horde and the reviewed
  native-arena modules; builder validates committed HEAD bytes separately.
- `nativeArenaEntry`: `port/native-arenas/authority.mjs`.
- `routes.nativeArena`: transitive module paths for that entry.
- `nativeArenaAdditionalSource`: source modules absent from the ordinary route.
- `dataFiles`: the three exact paths below when the native adapter exists.
- `dataReads`: explicit catalog-module-to-data-files manifest, rather than a
  claim that static ESM parsing discovers computed filesystem reads.

```text
godot/native_arenas/generated/prism-foundry.json
godot/native_arenas/generated/aurora-basin.json
godot/native_arenas/generated/cinder-array.json
```

Builder integration must hash and require committed data bytes, then copy each
file to `package/runtime/<same repo-relative path>`. This preserves the catalog's
`new URL('../../godot/native_arenas/generated/<id>.json', import.meta.url)`
resolution from `runtime/port/native-arenas/catalog.mjs`. Include the JSON files
in the Godot export as well. Discovery does not open data files, so synthetic
closure fixtures and pre-generation discovery can run independently.

The initial exact native-arena allowlist is `authority.mjs`, `match.mjs`,
`schema.mjs`, and `catalog.mjs`; review any additional authority-lane helpers
before adding their exact paths. An existing adapter with a missing or
unreviewed static dependency fails discovery. An absent entry yields empty
native routes/data only for pre-integration work; final packages require all
three data files. The legacy `horde_closure.test.mjs` exact two-adapter assertion
needs lead integration to recognize the expanded reviewed adapter set.

## Windows copy list

Copy `tools/godot-package/Native Deathmatch.cmd` to
`package/Native Deathmatch.cmd` alongside the existing `Play.cmd`, `run.mjs`,
`options.mjs`, and `endpoint.mjs`. No launcher support modules from this folder
are required at runtime; its JavaScript files are test fixtures only.

No arguments opens the three-map menu plus Exit. Explicit arguments are
forwarded verbatim to `Play.cmd`, preserving its exit code and avoiding injected
duplicate flags. Supply the experience explicitly in this form:

```bat
"Native Deathmatch.cmd" --experience=native-dm --map=cinder-array --bots=4
```

The batch wrapper quotes its own paths for extracted directories containing
spaces. Actual Windows menu/forwarding execution belongs in the lead's Windows
verification; Linux fixture tests do not establish batch execution behavior.

## Verification

```sh
node --test tools/godot-dev/native_arena*.test.mjs tools/godot-package/native_arena*.test.mjs
```

Options tests exercise all three maps, range endpoints, defaults, duplicates,
unsupported controls, and the separation from the nine-map catalog, ten source
routes and five authority-free exploration/lab routes. Ownership tests use
private synthetic factories and native child processes on ephemeral loopback
ports. They cover normal exit, spawn/crash failures, readiness failures,
interrupts, uncooperative children, independent exploration routing, and both
real 20-second smoke deadlines. Static closure tests use private module
fixtures and reject arbitrary helpers, data imports and dynamic loading.
Real authority/protocol/Godot integration remains the lead's final probe.
