# Native lifecycle cleanup

Base: edc222fe0c8e7338a17c4324e581c055fe38b4ea
Branch: fix/native-lifecycle-cleanup
Worktree: /tmp/opencode/cocs-native-lifecycle-cleanup

## Discovery and ownership

No subagent tool was available. Both read-only investigations were completed
before implementation, followed by a separate diff review and test pass.

The original verbose reproduction (`before.log`) passes 12 assertions but leaks
one renderer instance and two Nodes: WorldEnvironment and DirectionalLight3D.
`godot/world/viewer.gd:12-13` constructs these as members; lines 21-22 parent
them in `_ready`. Commit edc222f moved them from local `_ready` allocations to
constructor-time members. `round_boundaries.gd:49` originally manually adopted
other Session members but omitted these two while deliberately bypassing
`_ready`. Freeing the detached Session therefore could not free these Nodes.
This is fixture ownership, not evidence of a production round teardown leak.

Runtime inspection: Session._ready calls the viewer's _ready; on_started and
on_error clear presentation/pickups/combat and stale pose/control state.
Presentation and Pickups remove and synchronously free their owned children;
ActorVisual parents every mesh; PickupVisual parents its meshes and Label3D,
and frees previous children on a kind rebuild. No production change is needed
for the reproduced failure. A Session constructed and abandoned before _ready
still requires explicit ownership, as do the existing detached fixtures.

## Change and regression

Only `godot/tests/protocol/round_boundaries.gd` changes executable code. The
fixture now parents environment and sun. All original assertions remain.
Three additional cycles exercise actual Session.on_started/on_snapshot/on_error
methods, populated actors and pickups, healthy remote visibility, waiting for
fresh authority, disabled stale controls and idempotent teardown. WeakRefs verify
that visuals AND mesh/label descendants are freed, rather than merely dropped
from dictionaries, and that freeing the fixture frees its environment/light.
Final result: PORT_ROUND_BOUNDARIES_OK synthetic_checks=34, no RID/ObjectDB leak.

## Commands and results

Environment:
```
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode PORT=0
```
Primary node_modules was symlinked read-only for dependency use; no installs.

Executed:
```
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
"$GODOT_BIN" --headless --verbose --path godot --script res://tests/protocol/round_boundaries.gd
"$GODOT_BIN" --headless --verbose --path godot --script res://tests/protocol/presentation.gd
"$GODOT_BIN" --headless --verbose --path godot --script res://tests/protocol/pickups.gd
"$GODOT_BIN" --headless --verbose --path godot --script res://tests/protocol/entity_visuals.gd
python3 tools/godot-dev/verify.py
```
All four focused tests passed using the unmodified gate_runner (exit code AND
error-output checks); full verbose outputs are the *-after.log files.
An initial implementation parse error (Variant inference from weakref) was
corrected with explicit WeakRef types before the passing runs.

The first full verifier lacked generated GLB probes in the fresh worktree
(missing-generated-probes.log). Generated them with the existing exporter:
```
node tools/godot-export/browser-export.mjs
node tools/godot-export/browser-export.mjs meridian-exchange
python3 tools/godot-dev/verify.py
```
The second verifier passes through round-boundaries, native-lifecycle,
combat-feedback, audio-feedback, local-lifecycle, pickup-presentation and
entity-visuals, then FAILS native-trace. See verification.json for exact commands,
statuses and timings. Subsequent gates were not reached; no full-suite pass claim.

native-lifecycle.log proves a real normal-rate local authority session passed:
starts=2 results=1 restarted_actors=3 restarted_ack=11 map=meridian-exchange.
It also passed the gate runner's shutdown checks. Synthetic repeated-error
coverage complements this live restart gate; it is not live disconnect evidence.

## Remaining integration blocker

The occupied `godot/tests/protocol/native_trace.gd` has TWO detached fixtures
with the same missing environment/sun ownership. A separate --verbose run
(native-trace-failure.log) confirms two WorldEnvironments, two DirectionalLights,
and two renderer instances leaked despite 28 assertions passing.

`native-trace-integration.patch` is the exact minimal proposed fix: add the two
members to each fixture's adoption list. It passes `git apply --check` at this
base but was NOT applied or runtime-tested, respecting file ownership. The
integration owner should apply it and rerun the full verifier; later fixtures
may also require analogous ownership updates. No shared production patch is
proposed. Historical port/reports rewrites and generated UID files are not part
of this delivery.

Review: no production changes, warning suppression, sleeps, removed assertions,
source-rule changes, service restarts, deployments or modifications to primary.
`git diff --check` passed. Only the test and this evidence directory are committed.

Residual acceptance: human visual inspection, live error/disconnect interaction,
other map/mode runtime combinations and complete native recording acceptance
remain open. Headless Node.visible assertions are not screenshot evidence.
