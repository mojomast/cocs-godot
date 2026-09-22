# Recorded private package build and fresh-directory verification

**Result: PASS.** Built from clean package-code commit
`0c2dc2be26931b776107fcc728db6fec3bd8b363`, based on `6116f12`, using the unchanged
locked authority and exact official Godot 4.5.2 editor/release template.

## Artifact identity

- Archive (28,293,178 bytes):
  `/tmp/opencode/cocs-linux-package-state/builds/1790046335078279470/cocs-native-linux.tar.gz`
- Archive SHA256:
  `212ca8c45d26b6256c874d3e0fafed8fb00ad1d18603a26174f8c032ae56b304`
- Packaged `manifest.json` SHA256:
  `e4070207865ec30deb39dcc4297c2b1de0edc0cb9f18d5479ae1893c76e685b2`
- Build-input inventory SHA256:
  `b7cd951accdd3e105120c84cdaab1c1489046fe04986a7cab9bc42bca6c03227`
- Generated-resource inventory SHA256:
  `808e37774f0d4b5b6195aa7b1a4b08ad10847e31759cd1897fb57e434059b9bb`
- Executable: 70,179,064 bytes; separate PCK: 4,314,168 bytes.
- Full package: 112 files / 78,459,033 bytes, including manifest.

[build-result.json](build-result.json) contains exact external paths and hashes;
[package-manifest.json](package-manifest.json) is the exact packaged manifest.
The archive/binaries/toolchain are intentionally outside git. This is a private
local prototype artifact; no release or redistribution rights are asserted.

## Actual checks

| Check | Result |
| --- | --- |
| Full-history / locked source / exact editor and release-template versions | Pass |
| Official Godot editor/template archive SHA512, locked ws tarball integrity | Pass |
| Semantic generation + fresh import + separate-PCK release export | Pass |
| V8-parsed authority closure | 84 local modules + ws 8.21.3 |
| Release-runtime resource inspection | All nine identities, five compiled scenes |
| Production tests / GLB probes / editor feature | Absent |
| Release `assert` side-effect witness | Disabled, as expected |
| Native default host setup | Visible; zero players before Start; window close exits 0 |
| Meridian combat `deathmatch` | Real started + 8 recipient pose snapshots; window close exits 0 |
| Monsoon LATTICE world `cocs-coop` | Real started + 18 recipient pose snapshots; window close exits 0 |
| Ctrl+C during active native play | Launcher exits 130; child and owned listener gone |
| Native process SIGKILL | Launcher exits 1; owned listener gone |
| Missing native executable | Explicit ENOENT failure; owned listener gone |
| Unsupported mode | Rejected before server startup |
| CLI routing / argument-boundary tests | 2 test groups pass, covering all nine identities and invalid combinations |
| Package bytes/file inventory and locked source after play | Unchanged |

Fresh play directory:
`/tmp/opencode/cocs-package-play-uurgp6qy/cocs-native-linux`.
The caller's working directory was its unrelated sibling. `PATH` contained only
a copied Node executable; no Godot editor, git or npm. The package had no `.git`,
no symlinks and no original checkout paths in any file. Test fixtures were copied
outside the package and invoked externally. Private Xvfb used
`-nolisten tcp -nolisten unix`; software GL and a private ALSA null sink provided
test-only graphics/audio facilities without touching shared services.

[verification.json](verification.json) records actual ports, client PIDs, health
responses, observed trace counts, exit results and verifier/fixture hashes.
The authority's default empty `local` room explains one room during setup and two
after the native client creates its own match. `commit: unknown` in HTTP health is
the original server's untouched default; the package manifest records the locked
source commit independently.

Screenshots:
[host setup](host-setup.png), [combat](combat.png),
[LATTICE world](lattice-world.png).
The corresponding logs include the existing client-generated
`PORT_NATIVE_TRACE` started/snapshot records. These prove actual release-client
startup and receipt/presentation, not completion of gameplay scenarios.

## Verification harness findings retained for future runs

Early bounded attempts are preserved outside git under
`/tmp/opencode/cocs-linux-package-evidence-1` through `-7`; final evidence is from
`/tmp/opencode/cocs-linux-package-evidence-final` and the final committed build.
The earlier attempts exposed verifier assumptions, which were corrected:

- The ordinary authority already creates its empty `local` room.
- A window-manager-free Xvfb must intern `WM_DELETE_WINDOW` before Godot starts:
  Godot 4.5.2 queries that atom with `only_if_exists=true`. The verifier registers
  the normal WM atoms before launch and targets the actual titled client window.
- A machine without audio hardware needs an isolated test sink; normal artifact
  audio-driver selection is unchanged.
- Polling a live trace file can see a partial JSON write; only newline-complete
  records are parsed.
- Resource-only inspection must not instantiate unattached native scenes, whose
  helper Nodes attach during `_ready`. The final external probe loads the actual
  compiled resources and the graphical cases instantiate scenes normally.

No authoritative rules, source assets, native runtime scene code, common launcher,
shared-session code, existing export preset, contracts, dependencies or root docs
were changed by this lane. No merge, push, upload or deployment was performed.
