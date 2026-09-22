# Linux package verification — local rehearsal before the release run

The first Linux package build of the current tree exposed two real packaging defects
that the shipped Windows v2 build shares, both mine:

1. `tools/godot-package/discover.mjs` never included the reviewed Domination route
   (`port/native-identity-zones/authority.mjs`, `match.mjs`, `catalog.mjs`) in the
   runtime closure, so a packaged `--experience=identity-zones` failed with
   `Cannot find module .../runtime/port/native-identity-zones/authority.mjs`.
2. `tools/godot-package/run.mjs` still treated an identity-zone authority as
   "not native", so it tried to listen on an already-listening server and would have
   passed an endpoint without the `/native-zones` path to the scene.

Both are fixed, and the packaged route now runs a real Domination round:

```
PACKAGE_SERVER_READY {... "experience":"identity-zones","map":"vermilion-fold","mode":"domination",
  "health":{"service":"cocs-native-identity-zones",...,"geometryHash":"6253164eed12dc..."}}
PACKAGE_NATIVE_STARTED {... "scene":"res://native_arenas/identity_zone_demo.tscn"}
PORT_SESSION_SMOKE_OK actors=3 camera=authoritative movement=true fired=true ... map=vermilion-fold mode=domination
PACKAGE_STOPPED
```

A new `tools/godot-package/verify_linux.mjs` mirrors the Windows verifier case for
case (source-route smokes, preview resource, six native Deathmatch maps, Domination,
identity resources, five graphics routes, graphics resources) and additionally checks
the manifest, every packaged file hash, the external Node prerequisite and the
post-run cleanup. This local rehearsal passed **16/16** against the freshly built
tarball; the same commands run in the hosted `linux-demo.yml` workflow.

The Domination case was added to the Windows verifier too, so the next Windows build
verifies the route that v2 shipped broken.

Not covered here: Horde inside a package. The identity Horde scene extends
`res://horde/demo.gd` and has no smoke path, so a packaged headless Horde check is
not possible without new scene work; its acceptance remains the dev lane evidence.
