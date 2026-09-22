# Independently executed native death/respawn acceptance

Executed from private checkout `/tmp/opencode/cocs-native-integration` at
`7e505f2e173402412a56a0aff3e2d77e53f1afb7`, including runtime correction `ba32173`.
The lead reviewed the source, original successful and failed recordings, then
executed the following twice against the current integration runtime:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/native_death_respawn/run.mjs
```

Both runs exited 0, passing all 14 bounded native criteria:

| Run | Gameplay wall seconds | Correlated snapshots | Queues matched to receipt | Predeath active | Dead neutral | Postrespawn neutral before click | Active after fresh click | ACK high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `e94a6170-6a29-4070-8877-f7a8a09ce27f` | 13.406 | 406 | 774 | 424 | 117 | 120 | 90 | 773 |
| `40493827-d3a6-4a7e-923f-6dc3c391f92c` | 10.132 | 303 | 572 | 223 | 117 | 120 | 90 | 571 |

Both use a real Godot guest actor 1 and a supported-protocol attacker actor 0 on
an isolated normal-rate Meridian server, one round, no simulation/rule/state
edits. Ctrl and left mouse are delivered through `Input.parse_input_event`, held
before death through two seconds after respawn. Actual predeath active packets
establish a nonneutral stimulus. Dead/postrespawn packets remain neutral until a
new mouse release/press. This is real client input-path/program-state evidence;
it is separate from OS focus and virtual-pointer acceptance.

First run: authoritative samples 237/238/298 bracket alive→dead→healthy respawn.
Respawn eye `[44,1.45,-8]`, yaw 1.751 and pitch 0 agree with the native camera
within float tolerance; camera reseeding is true at that healthy snapshot.
Second run: samples 134/135/195; respawn eye `[44,1.45,-34]`, yaw 2.229, pitch 0,
again reseeded. Actual authoritative death and spawn events corroborate both.

The second run specifically sought recurrence of the previously observed
zero-health/zero-timer boundary. Neither rerun happened to include that rounded
sample. Its corrected behavior is established by the failing-before/passing-after
actual-session regression, **not claimed live-reobserved after the fix**. The
original genuine runtime failure stays archived unchanged and still fails the
updated native checker. See `../quantized-respawn.md` and
`../../native-death-respawn/INTEGRATION.md` for the deliberate health-aware
validation change.

Every queued input matches server receipt, but the last input in each run is not
claimed ACKed/applied. ACK high-water does not prove separate application of
intermediate inputs. No native terminal record exists: `completionProven=false`.
Each run records an explicit `post_respawn_window` harness boundary and normal
child exit; these do not establish native trace completeness.

Each original summary and compressed raw stream is retained once here. The lead
verified artifact size/SHA-256, current runtime hashes, and absence of all six
recorded importer/native/Xvfb PIDs. Both runs report owned server closed, zero
sockets, and private temporary projects removed. Credential-field/bearer/API-key
pattern scanning of decompressed artifacts found no matches.

This closes the bounded same-round lifecycle/input-path milestone on corrected
runtime, not full playable acceptance, hardware pointer behavior, all-mode
lifecycle semantics, or native recording completion.

After the runtime/analyzer integration, the lead also executed:

```sh
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
python3 tools/godot-dev/verify.py
```

Exit 0, all 29 implemented gates pass on the corrected runtime. Actual results
and logs are in `port/reports/verification.json` and the named gate logs.

## Combined focus/lifecycle runtime confirmation

After the immediate-window-focus correction was integrated and graphically
accepted, the lead reran the same live death command on private integration at
`bda5af2` (same runtime as graphical acceptance at `5e8136d`). Run
`a1e4d13d-b2a6-4db4-a36a-8d6a5b91be5b` exited 0, all 14 criteria pass: 352
correlated snapshots, 669 queue/receipt matches, ACK high-water 669, 320 predeath
active inputs, 117 dead-neutral, 120 postrespawn neutral and 90 active after the
fresh click. Samples 183/184/244 establish the same actor's lifecycle. Healthy
respawn reseeds at eye `[-44,1.45,10]`, yaw -1.347, pitch 0. No zero-health/zero-timer
sample occurred in this run. Native completion is still unproven. Raw artifacts
and summary are retained with original hashes; owned PIDs were independently
checked absent. The combined full verifier now has 30 passing gates; see
`../graphical-independent/README.md`.
