# Compare-only bounded wiring — source review deliverable

**No native grant exists.** Phase `snap-query-compare-only-v1`, mode
`compare-only`, singleton group `query-compare`. This is a first-phase collection
contract, not parity-candidate execution. All 60 candidate map walks remain
unrun. AE remains a failed positive archive; actual final uplift support remains
unqualified. No endpoint tolerance or response guard is changed.

## Controller and measurement

The new driver directly extends SceneTree and constructs only the unchanged
`res://exploration/walker.gd`. Its staged dependency closure contains no candidate
controller, parity planner, admission pipeline or original diagnostic driver.
The original proposal and pinned query comparator are read-only PhysicsServer
queries. No UP move is applied. Actual body transform, velocity, floor/wall state,
platform velocity, slide count, motion and accounting are compared exactly before
and after all queries; any observed mutation fails collection. These snapshots
do not claim to inspect every internal backend cache.

At the first eligible original proof, all three raw requests are recorded in
one physics frame, while the actual body is still the baseline body:

* old short32 DOWN from the hypothetical raised-plus-forward edge pose;
* modeled parent snap4 DOWN from that same hypothetical edge pose;
* modeled parent forward6 from **raised**, before hypothetical forward advance.

Each request records from/motion, flags, contact capacity, margin, exclusions,
actual RIDs/shapes/offsets and raw results. The driver also records collision
layer, actual body transform, physics time/frame, target RID/shape, source/engine
hashes and the returned configured physics-engine setting. `DEFAULT` is not a
backend identification. These are modeled parent-policy requests, **not an
internal move_and_slide trace**. Query equality or inequality is not proof of a
root cause. Raw travel differences are measurements, not acceptance predicates.

Only then may one ordinary baseline `Walker.step` run. The driver stops after
that response. `comparisonCollected=true`, `failed=false` means only that the
three finite query results were collected without observed query mutation and
the ordinary response completed. `queryAgreementQualified=false` and
`nativeStepAdmission=false` remain explicit. Post-step support belongs to the
ordinary baseline, not an uplift. There is no completed-tread claim.

Fixed fixture: unchanged synthetic flat .15m step, radius .35, yaw −45°, 20 settle
frames, at most 40 input frames. Clock must be actual physics60Hz/timeScale1;
missing eligible event, mutation, invalid query, reset or timeout fails. Driver
internal deadline170s; supervisor child execution deadline180s followed by
owned-process cleanup and release audits. No retry or group continuation.

## Preparation and authorization boundaries

`prepare.py` writes a new lowercase `snap-compare-…` attempt once. It verifies
the explicit external AE root against the frozen `c0761dbe` inventory SHA256 and
all46 inventory file hashes/sizes before writing anything. It also verifies all
15 production dependencies and the exact reviewed script bytes in
`review-pins.json`. Python preparation/policy/supervisor hashes and the review-pin
file hash are also bound into the source receipt and rechecked before launch.
The minimal generated project has no autoloads, world GLBs,
copied engines, X/AA assets, imported resources or game main scene. Only nine
script dependencies plus project settings are staged, each hashed in source.json.
No grant, import or launch is generated. Symlinks, escape paths, uppercase or
noncanonical attempt names and existing destinations are rejected.

The source receipt has `grant:null`, `autoStart:false`, `queued:false`. It does
not self-authorize. Future explicit grant fields are exactly:
`phase`, `mode`, `allowedGroups`, `grantId`, `authorized`, `expiresUnix`,
`sourceSha256`, `engineSha256`. Both Python and GDScript reject missing/extra
fields, wrong phase/mode/group, duplicate allowed groups, expired/nonfinite
expiry, wrong identity and wrong hashes. Python rejects duplicate JSON keys.
GDScript receives only supervisor-validated JSON; its JSON parser alone cannot
detect duplicate keys. CLI accepts only the enumerated options and rejects
duplicates, unknown options and abbreviation. No debug/simulation override exists.
Preparation's injectable root/pins arguments exist for Python unit testing;
neither is a CLI authorization override. The supervisor always uses repository
review pins and revalidates staged bytes, external AE and production dependencies.

`supervisor.py` requires a caller-specified absolute nonsymlink binary path and
its exact grant-bound hash; it does not select from PATH or install an engine.
The runtime must report Godot4.5.2. It takes
`/tmp/opencode/cocs-finish-acceptance.lock` with nonblocking flock, then starts
one new kernel session/process group, records PID/PGID/startTicks, samples group
membership, and stops on script/parse error or180s deadline. Signal handling and
cleanup target only this invocation's owned group; residual groups are audited
three times before releasing the lock. Failure to demonstrate an empty group
fails the supervisor receipt. Existing viewers/displays are never targeted.
Worker threads, software-renderer threads and OpenMP threads default to1, with
single-threaded scene processing. The command does not request import/editor.
Any future explicit parsing/import check requires its own authorization.

## Review status and verification

This wiring and new GDScript remain **unparsed/unrun**, for focused independent
source review before any native grant. Python tests execute policy functions,
negative CLI parsing and real preparation code against disposable synthetic
46-file inventories under `/tmp/opencode`; they never launch a child or create
a repository attempt. Source assertions additionally enforce baseline factory,
read-only helper closure, ordering and policy vocabulary. They are not a native
GDScript parser or substitute for one.

The original `2b0f1f6a` commit and provenance remain historical. P1 correction
`2e8fc0bc` changes only the legacy diagnostic, its documentation/plan and a
baseline regression. The new supervisor cannot invoke that legacy driver or any
parity candidate. Future candidate execution needs a separate reviewed contract.
