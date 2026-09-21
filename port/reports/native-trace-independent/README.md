# Independent integration execution

Execution checkout: `/tmp/opencode/cocs-native-integration`, branch
`integration/native-acceptance`, commit `86ef71965e1a1e5c649bec660ab7c6660db09b89`.
This was created from the current primary after all six reviewed integrations.
The harness copied runtime sources from this checkout, not the subagent's older
checkout. Source status was clean. Actual Git trees and harness SHA-256 values
are retained in `index.json` and the original reports in `evidence.tar.gz`.

## Commands actually executed

From primary, after each corresponding cherry-pick:

```sh
python3 -B -m unittest discover -s port/tools/asset_audit -v
python3 -B -m unittest discover -s port/tools/gameplay_acceptance -v
python3 -B port/tools/gameplay_acceptance/validate.py port/gameplay-acceptance/catalog.json
node --test port/tools/guest_session_integration/test.mjs
node --test port/tools/native_trace_correlation/test.mjs
```

Results: asset audit 9/9; gameplay catalog 14/14, then analyzer 27/27, then
bounded recorder 29/29; guest harness 7/7; native correlation 13/13. These are
offline tests (including real owned subprocess/loopback mock cases), not live
death/respawn or graphical acceptance. The asset inventory is a frozen audit of
its original base, not a newly generated claim about current runtime hashes.

The designated saved subagent output was independently replayed after
integration, and again after archive extraction: PASS, actor 1, 333 snapshots,
647 received inputs, no unmatched successful queues, `completionProven=false`.
This replay is separate from the new live runs below.

From the private integration checkout:

```sh
TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/native_trace_correlation/run.mjs

# Same environment; intentionally exits 1:
node port/tools/native_trace_correlation/run.mjs --fault-timeout

node port/tools/native_trace_correlation/replay.mjs \
  port/native-trace-correlation/evidence/79fec637-27af-43cc-9372-e540d2ad79f3/enabled.stdout.log \
  port/native-trace-correlation/evidence/79fec637-27af-43cc-9372-e540d2ad79f3/enabled.json
```

## Actual independent live results

| Run/case | Result | Evidence |
|---|---|---|
| `79fec637…` enabled | PASS, exit 0 | 978 native records; actor 1; one round; 333 native/observer/server snapshot matches; 644 successful queues matched to 644 received input messages; no unmatched queues |
| `79fec637…` disabled | PASS, exit 0 | Joined before start; 336 observed snapshots; 651 received inputs; zero native trace records |
| `bce05a27…` deliberate timeout | Expected FAIL, exit 1 | Real guest join, then impossible 100ms predicate; no start/snapshots/inputs; SIGTERM reaped the owned child |
| Replay of `79fec637…` | PASS, exit 0 | Same 333 snapshot/644 receipt associations; no unmatched queues |

Enabled ACK high-water was 643. Input 644 is received but is not claimed ACKed or
applied. All correlated local snapshots remained health 100/dead timer 0.
No individual application claim follows from queue success, receipt, or an ACK
high-water. No native recording completion is proven by any of these runs.

Every run reports the importer/native children reaped, owned loopback servers
closed, zero remaining owned sockets, and private temporary trees removed.
The lead independently checked all recorded importer/native PIDs absent after
the runs. Archive members were checked against their SHA-256 and scanned for
credential-field/bearer/API-key patterns; none matched. The 17 original files
are retained losslessly in the 88,795-byte archive. Failed timeout evidence is
preserved as failure, not folded into positive gameplay acceptance.

This remains a complete-prefix, fresh-connection, single-round association
method. Snapshot IDs come from the synchronous post-handler passive observer;
input IDs come from ordered successful queues with no alternate senders or
reconnects. It must not be applied to arbitrary excerpts or truncated logs.

## Verifier environment failure retained

The first full verifier invocation inherited `PORT=4332` from the execution
environment. The `native-live` launcher failed with `EADDRINUSE` on loopback.
`verifier-port-conflict/` retains that failed report and log. No process using
that port was stopped. The corrective invocation explicitly selects `PORT=0`
for private OS-assigned ports; its outcome is recorded in the release matrix.

Actual corrective command from primary at integration commit `86ef719`:

```sh
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
python3 tools/godot-dev/verify.py
```

Exit 0: all 29 implemented gates passed, including release refusal, normal-rate
native results/restart, native movement/fire and two native clients. Current
`port/reports/verification.json` and gate logs are the actual rerun output.
