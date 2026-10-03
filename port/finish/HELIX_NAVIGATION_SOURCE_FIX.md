# Helix cold-navigation candidate — source-only, native verification pending

## Confirmed Windows failure

Run `37094406934` evidence is retained under
`/tmp/opencode/windows-helix-37094406934/helix/`.
The authority receives `start` at 2,362 ms and cannot service its heartbeat until
24,998 ms. Native resources finish at 279 ms and `_ready` at 1,955 ms. Native
waits connected in phase 20, then enters phase -1 at 22,026 ms with
`Connection/round-start timed out. Relaunch to reconnect.` The product's existing
20-second deadline expires while synchronous source navigation is still building;
the external 35-second timeout reports the already-failed product later.

Actual Windows CPU profile `CPU.20261003.035047.7256.0.001.cpuprofile`:
9.882 s self samples in `walkEdge`, 9.812 s in `segmentDistance`, 1.078 s GC.
This confirms the cold-navigation bottleneck, rather than slow Godot art loading
or a missing observer signal. Published G3 preview bytes remain immutable.

## Candidate algorithm and correctness boundary

The port-owned derivative generator replaces only the full wall-segment scan with
`wallCandidates(terrainWallSegments(...),x,z,r)`. The original height inequalities,
`segmentDistance` expression, strict `< r` comparison, `walkEdge` samples, graph
construction, pruning, path ordering, cache key/version and bot logic remain exact.

The helper indexes segment X/Z bounding boxes into eight-unit spatial cells. A
query visits cells intersecting its radius square. Every distance-blocking segment
must intersect that square, so this is a conservative filter, not approximate
collision. Original segment indices are sorted before the unchanged narrowphase.
False positives are permitted; blocking segments are not intentionally discarded.

Bounds have 1e-7 outward slack, much larger than double-precision rounding at the
supported +/-1e6 index-coordinate range. Longer/extreme/non-finite segment bounds
remain in an always-tested list. Non-finite, negative, extreme or very large query
radii fall back to the original full scan. Per-box cell count is capped at 4,096.
The cache is keyed by the source's segment-array identity: `stampTerrainFloor`
invalidates that array, so subsequent queries rebuild the index. This shares the
source contract that generated terrain segments are immutable between invalidations.

## Source proof actually run

```sh
node --test port/multiplayer-worlds/wall_candidates.test.mjs
node port/multiplayer-worlds/generate-derivative.mjs --check
node --experimental-vm-modules tools/godot-package/discover.mjs .
node --check tools/godot-package/compare_navigation.mjs
```

Five tests pass (under one second total on this host):

- Every blocking segment, not just the first hit, retained in source order across
  seeded geometry, positive/negative cell boundaries, radius tangencies, diagonal,
  degenerate and very long segments; exceptional queries retain full-scan behavior.
- Actual locked `game/core.mjs` vs generated derivative collision outcomes at
  horizontal/vertical thresholds and all directed `walkEdge` pairs on a tiny map.
- Actual original/generated navigation nodes and ordered adjacency exactly equal
  on legacy and next-gen tiny maps with a jump link; nearest-node tie breaks and
  warm-index results equal. No path or bot policy is modified.
- Actual terrain stamping invalidates the cached segment identity correctly.
- A distributed synthetic case reduces 101 candidates to the two eligible
  segments, including the always-tested long segment. This is a work-reduction
  check, **not a Helix speedup measurement**.

Generator reproducibility and discovery pass. No full-map graph, server, Godot,
Blender, import, export, archive operation or native benchmark has run in this lane.

## Required follow-up, only after authorization

The prepared comparator runs original and candidate navigation in separate cold
processes, serially, with a 60-second bound each. It asserts exact SHA-256 equality
of serialized ordered nodes/adjacency and reports timing without asserting a
speculative speedup. It has been syntax-checked, **not executed on Helix**.

From the candidate checkout, on parent-authorized remote Windows or after a fresh
local grant (H is currently owned by Vesper):

```powershell
node tools/godot-package/compare_navigation.mjs helix-conservatory
if ($LASTEXITCODE -ne 0) { throw 'Cold navigation equality failed' }
```

Once parent authorizes and prepares a new candidate package, run the bounded native
case against its fresh extraction; do not point this command at the immutable G3
preview and claim it contains the fix:

```powershell
$env:LP_NUM_THREADS = '1'
& "$env:NEW_CANDIDATE_ROOT\node.exe" tools/godot-package/verify_expansion.mjs `
  "$env:NEW_CANDIDATE_ROOT" "$env:RUNNER_TEMP\helix-candidate" `
  --case=helix-conservatory/deathmatch --diagnostics
if ($LASTEXITCODE -ne 0) { throw 'Native Helix candidate failed' }
```

Require native start/snapshots before the unchanged product deadline, correct
geometry hash, three actors and clean acknowledged shutdown. Preserve phase logs
and CPU profile. Parent approval for remote work has been requested; no workflow
was edited or dispatched here. All-map graph comparisons and final full native
coverage remain follow-up obligations; synthetic equivalence is not Windows proof.

## Derivative, promotion and packaging consequences

- Locked `game/` and `server/` are untouched. The existing lattice source derivative
  contract therefore stays unchanged. The new behavior is an explicit, reproducible
  port-owned derivative seam in `generate-derivative.mjs` and generated `core.mjs`.
- `wall_candidates.mjs` is explicitly admitted in `discover.mjs`; the next package
  must bind its bytes and changed core/discovery bytes in its new source closure.
- None of these paths intersects `sourceHashes` or `packageInputs` in this lane's
  three promoted receipts (Parallax, robots, vehicles). No receipt was rewritten,
  no acceptance promoted and no historical native evidence re-anchored. Parent
  must recheck any newly integrated scenery receipt against its merged candidate.
- This is a runtime-authority change. G3 runtime-equivalence claims do not apply
  to future packages containing it. New native source-authority evidence and a
  newly frozen candidate/build are required before claiming the startup fix.
- Geometry/assets, source fingerprints for authored exports and deadlines are
  unchanged. Seven-unit strict final gating and the 142-case final obligation stand.

G4 remains released. No local heavy grant was reacquired and no persistent process
was started. Changes are prepared on the packaging lane for parent integration;
concurrent parent scenery/Vesper work has not been overwritten or merged here.
