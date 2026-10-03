# G4: bounded Helix startup diagnostic, unchanged G3 artifacts

Windows runtime job `37093303717` passed manifest validation and earlier runtime
cases, including all six Parallax pairs, then timed out on Helix deathmatch before
the later Fighting probe. Existing Windows evidence:
`/tmp/opencode/preview-windows-37093303717/expansion/07-helix-conservatory-deathmatch.log`
and `expansion-result.json`. Its uninstrumented timeout alone does not identify
which startup stage failed. Parent owns focused Windows checks and publication.

## What was actually reproduced

Three serial, single-case runs against the **unchanged extracted G3 Linux PCK and
extracted source authority** at `cb6e4c9f6bff09aafe4d9ef6262c5996a6219329`:

1. Original external probe, selected Helix deathmatch: passed.
2. Opt-in phased observer probe: passed.
3. Phased observer plus authority CPU profile: passed.

The third run establishes a concrete local startup bottleneck:

- Native art load completes at 93 ms; production `_ready` completes at 828 ms.
- Socket opens and client sends ordinary create/host/start. Authority receives
  `start` at **1,004 ms** (observer runs before the existing production handler).
- Native remains connected, phase **20**, awaiting the source start response.
- Authority heartbeat cannot run until **10,687 ms**: approximately **9.68 s** of
  synchronous startup work blocks its event loop.
- Native start signal arrives at 10,755 ms; first/third snapshots at 11,168/11,171 ms;
  correct Helix geometry hash, three actors and six snapshots pass the probe.
- CPU samples: **4.450 s `walkEdge`**, **3.804 s `segmentDistance`**, **0.522 s GC**.
  Both hotspots are in extracted `runtime/port/multiplayer-worlds/derived/core.mjs`.
  `Match` construction calls `matchNavigation` → `navigation` → edge checks; the
  map-keyed navigation cache is cold in each newly spawned per-case authority.

Thus local evidence points to **cold source-navigation construction**, not native
resource loading, a missed start signal or a disconnected client. It does **not**
prove the Windows worker's 35-second timeout has the same cause: Windows needs the
phased single-case run below. No locked core, source geometry, cache policy, actor
state, scene, resource or timeout was changed based on that hypothesis.

## External diagnostic changes

`verify_expansion.mjs` accepts `--case=helix-conservatory/deathmatch` only for an
actually registered pair, and explicitly marks its report single-case/non-complete.
Default invocation still executes the full existing suite. Unknown/empty/traversal
selectors fail. `--diagnostics` adds read-only source socket-event observations,
wall-clock heartbeats and a Node CPU profile saved into the evidence directory.

The external `godot/tests/package_expansion.gd` adds opt-in timestamps for resource
checks, scene construction, `_ready`, observer attachment, lobby/start/snapshots,
five-second waiting reports and timeout state. Reports include wall time, summed
delta age, process frames, product phase/startup error, socket state and identities.
Signal registration order and production state are unchanged. These scripts are
not in the product PCK. The **35-second probe / 55-second harness bounds remain**.
On Windows a forcibly terminated busy authority may not flush its CPU profile;
phase and inbound-event logs still identify the stalled boundary.

## Exact parent-run Windows command — no rebuild

Use a checkout containing this external diagnostic change and the already extracted
G3 archive. Keep the product manifest candidate unchanged. In PowerShell:

```powershell
$env:LP_NUM_THREADS = '1'
& "$env:DEMO_ROOT\node.exe" tools/godot-package/verify_expansion.mjs `
  "$env:DEMO_ROOT" "$env:RUNNER_TEMP\helix-single-diagnostic" `
  --case=helix-conservatory/deathmatch --diagnostics
if ($LASTEXITCODE -ne 0) { throw 'Helix diagnostic failed; retain phase logs and CPU profile' }
```

Retain `01-helix-conservatory-deathmatch.log`, `expansion-result.json` and any
`*.cpuprofile`. The new external verifier does not relabel or rewrite the archive.
No workflow was edited/dispatched by this lane. A slower source constructor must
not be silently treated as successful final acceptance or hidden by a larger bound.

## Evidence, tests and local grant release

Root: `/home/mojo/.tmp-on-disk/cocs-preview-g-linux/diagnostic-g4/`.
`baseline/`, `phased/`, `profile/` hold case results/logs; the latter also contains
the actual Node CPU profile. Wrapper process receipts sit alongside run logs.
All three cases shut down their authority with the existing acknowledged STOP
handshake and listener-closure assertion. Source harness suite **8/8 passed**,
including default-complete vs registered-single-case selection.

**PREVIEW-DIAGNOSTIC-20261003-G4 released at 2026-10-03T03:43:18.530036Z.** Fresh
process-table audit found no processes, including zombies, in owned groups
1212407, 1219667, 1224351. Receipt: `HEAVY_GRANT_RELEASE_G4.json` under that root.

No asset build, import, export, archive change or publication occurred. G3's Windows
ZIP remains SHA-256 `4072b99b82902da9c46f348edb3d185b280ab62d4ded5e717e093cc2cd25089c`.
The seven-unit strict final gate and full 142-case/manual/audio/GPU obligations
remain unchanged; parent may independently publish an honestly limited preview.
