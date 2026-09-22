# Native PICKUP-WEAPON acceptance

## Sanitized delivery

This README and the audit/package tools were brought forward from original commit `2d4e60a66761d79f79ef274cf6ba20d663ede968` with attribution and the corrections documented here. Delivery branch **`port/native-pickup-sanitized`** starts from `5e8e02e`, before the original credential-bearing evidence commit. The original branch **`port/native-pickup-acceptance`** remains at `2d4e60a`; that commit and its raw archive are not ancestors of this delivery.

**All 36 archive members and all three attempts are preserved.** Only six credential field values change to null: JSONL line **1**, `/frame/token`, `/frame/progressToken`, and `/frame/profile/ownerToken`, in each of:

- `evidence/2026-09-21T23-53-28.066Z/wire.jsonl.gz`
- `evidence/2026-09-21T23-55-34.524Z/wire.jsonl.gz`

`profile.ownerToken` repeats the progression credential. An initial four-field derivation stopped on its credential scan before writing artifacts; lead subsequently approved all six replacements. No gameplay fields or other JSON bytes were changed. The two wire gzip streams were recompressed; the other **34 members are byte-identical**, including failed-run history, original execution summaries/source hashes, every observation/trace, and all eight screenshots.

| Artifact | SHA-256 |
|---|---|
| Original archive, retained on original branch | `979fb551a934dcb4d563693c19a320f9d58e26a4c986d6854b76657a8f04c783` |
| Sanitized delivery archive, 897,910 bytes | `67bf58b4ff2eef64e16f7483730abc27af66fddc561cca963b37c59d7fce23c9` |

[`SANITIZATION.json`](SANITIZATION.json) gives exact field paths/counts, original and derived compressed/uncompressed member hashes, original archive/index hashes, and derivation source provenance. [`evidence-index.json`](evidence-index.json) indexes all original-versus-derived member hashes. These derived hashes supplement the unchanged execution hashes; they do not represent a new live execution. No credential values or value-specific digests are recorded in the manifest.

### Recorder and result-gate corrections

- `decodeRecordedFrame` nulls all three welcome credential paths **at decode, before wire/host retention**. Original bytes are still forwarded unchanged to the real peer. The compressed-round-trip regression includes the repeated profile alias; the package tool and offline audit reject non-null retained welcome credentials.
- Import and native success now require `child.failure === null`, exit 0, no termination signal, and no line-prefixed `SCRIPT ERROR:` or `ERROR:` diagnostic in either stdout or stderr. A late output-cap/deadline failure can no longer be hidden by an otherwise positive result.
- Future graphical pickup runs explicitly use `--audio-driver Dummy`. This avoids the old unavailable ALSA hardware error without asserting audio acceptance.
- The original archived runs retain their actual audio fallback `ERROR:` log. Their gameplay audit still passes; **the original runs do not satisfy the new no-error gate**, and legacy summaries do not record `nativeExit.failure`. A fresh live execution of the tightened harness is pending lead's independent rerun. No new live run was performed for this sanitization.

Verification commands executed: `node --test port/tools/native_pickup_acceptance/recording.test.mjs` (**4 passed**); `node --check port/tools/native_pickup_acceptance/run.mjs`; `git diff --check`; `python3 port/tools/native_pickup_acceptance/sanitize_evidence.py`; and the offline audit below against a private extraction of the **sanitized** archive. A separate credential/member scan checked all 36 decompressed member payloads against the removed values held only in memory, found no surviving credentials, verified all six nulls, and checked all other members/fields unchanged. See [`credential-scan.json`](credential-scan.json), [`audit-result.json`](audit-result.json), and [`recording-tests.tap`](recording-tests.tap).

The following live result remains attributable to its original execution, with unchanged gameplay conclusions.

**PASS for the observed baseline rocket pickup on Meridian.** Final live execution used committed harness `5e8e02e0f66be5f571649e06deb16a7f149ac71c`, based on primary `86ef71965e1a1e5c649bec660ab7c6660db09b89`. Runtime tree IDs and source SHA-256 values are in each run's summary. This lane contains only new acceptance tools and evidence.

## Final live result

Run: [`2026-09-21T23-55-34.524Z/summary.json`](evidence/2026-09-21T23-55-34.524Z/summary.json).

| Boundary | Snapshot seq | Server time | Rocket wait | Native marker | Native weapon / rocket ammo |
|---|---:|---:|---:|---|---|
| Before contact | 385 | 12.833 | 0 | visible | 0 / 0 |
| Useful contact | 386 | 12.867 | 15 | hidden | 1 / 6 |
| Left radius, waiting | 403 | 13.433 | 14.433 | hidden | 1 / 6 |
| Server-timed return | 836 | 27.867 | 0 | visible | 1 / 6 |

- Same actor **1**, same authoritative pickup **0** at **(-14, 0, -19)**, same native marker instance throughout.
- Pickup event **3**, time **12.867**, actor **1**, kind **rocket**. The event has no pickup ID; attribution combines its actor/kind with exclusive contact and the same-ID snapshot transition.
- Contact distance changed **1.20546 → 0.92809**, crossing the source's 1.05 radius. Waiting began at distance **3.935**; return occurred at **4.94451**, outside collection range.
- Exact baseline inventory arithmetic: Rocket Launcher magazine **6**, cap **18**, starting rocket ammo **0**, Adaptive verb (Tool Use bonus **0**), no attachments, unlimited ammo false. Result `min(18, 0 + 6 + 0) = 6`. Starting weapon 0 automatically selected rocket index 1.
- Return elapsed **15.000 authoritative simulation seconds**. Every retained consumed-to-return snapshot's marker visibility matched wait, and countdown differences matched simulation time within quantization tolerance.
- **867 native snapshots**, **1,666 received protocol inputs**, **2,534 native trace records**. Offline audit matches native snapshot IDs to actual outbound frames and native queued controls to received input controls by order.
- Whole server/capture/cleanup interval **29.597 seconds**. Native, importer and private Xvfb handles reaped; server closed; **zero owned sockets**; private temporary runtime removed.

### Screenshots

[Available](evidence/2026-09-21T23-55-34.524Z/available.png) · [Consumed/hidden](evidence/2026-09-21T23-55-34.524Z/hidden.png) · [Outside radius](evidence/2026-09-21T23-55-34.524Z/left_radius.png) · [Returned](evidence/2026-09-21T23-55-34.524Z/returned.png)

The captured native viewport shows the diagnostic marker and HUD changes. The observer also records the actual post-session-handler marker visibility/instance and HUD text. Screenshot writes wait for a rendered frame; their input/snapshot bracketing is retained in the observer log.

## Genuine stimulus and isolation

`observe.gd` instantiates shipped `res://world/session.tscn` unchanged. Its physical W key, capture-click and relative mouse-motion events enter **`Input.parse_input_event`**, then the shipped focus/pointer gates, physical-key polling, movement conditioning and network client. It never assigns session controls, actor position/health, camera pose, authoritative state or marker visibility. Smoke controls are false.

The Node host only creates/configures/starts an isolated room through real WebSocket messages. Native joins through the shipped guest option. Server creation uses the default `tickDt=1/60`, `tickMs=1000/60`; ordinary deathmatch, bots 0, damage/speed/gravity 1, respawn 2, frag limit 15, time limit 300, no mutators. The passive host never sends gameplay inputs. Node timer scheduling is not exact wall-clock simulation: the final retained wire span is 28.900 simulation seconds over 27.918 wall seconds under the unchanged server defaults. No acceleration override was used.

The authoritative spawn was **(-44, 0, 34)**. A read-only grid planner used authored Meridian collision boxes with clearance margin, producing `[-22,29] → [-22,15] → [-14,-15] → [-14,-19]`. Native observation steered toward these waypoints using mouse look and W. After collection it walked toward `[-14,-23]`, released W and looked back at the pickup. Braking drift is present in the real snapshots.

Dependencies were a read-only symlink to primary `node_modules`; runtime sources were copied to a private `/tmp/opencode/cocs-pickup-runtime-*` directory. The pinned Godot version was `4.5.2.stable.official.6ce3de25a`. Xvfb allocated its own display through `-displayfd`; `-nolisten tcp -nolisten unix` retained only the Linux abstract local socket. Display `:0` in this private run is an allocated owned Xvfb handle, not an inherited/shared desktop target. No OS input tools or shared desktop connections were used.

## Commands and retained attempts

Run from this worktree (same live command used for all three attempts):

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/native_pickup_acceptance/run.mjs
```

1. `2026-09-21T23-52-37.437Z`, source `b15c303`: **INCONCLUSIVE**, exit 1. Xvfb filesystem Unix socket could not bind because of existing `/tmp/.X11-unix` permissions; 5-second deadline. Import ran, but no game server/native gameplay capture began. Full failure logs retained. An owned 3-second Xvfb probe verified abstract-socket startup after disabling filesystem Unix transport, without changing shared directory permissions.
2. `2026-09-21T23-53-28.066Z`, source `6fcac57`: gameplay **PASS**, exit 0, 30.268-second capture. Full pickup sequence and four screenshots retained. Cleanup summary sampled one WebSocket before its close callback; do not infer zero sockets from this earlier report. Final harness awaits that condition explicitly.
3. `2026-09-21T23-55-34.524Z`, source `5e8e02e`: **PASS**, exit 0. Exact inventory verification and zero-socket cleanup condition passed. This is the accepted result.

The owned harness has a 90-second native observation boundary, a 95-second native hard deadline and a 105-second capture guard. Export/import precede the gameplay capture with their own 60-second deadlines. Cleanup only addresses retained owned process/server/temp handles.

Offline audit after extracting the archive into a private review directory:

```sh
mkdir -p /tmp/opencode/native-pickup-review
tar -xzf port/native-pickup-acceptance/evidence.tar.gz -C /tmp/opencode/native-pickup-review
node port/tools/native_pickup_acceptance/audit.mjs \
  /tmp/opencode/native-pickup-review/evidence/2026-09-21T23-55-34.524Z
```

The audit was executed against original retained files and subsequently the sanitized archive extraction, and passed with unchanged gameplay conclusions. `node --check port/tools/native_pickup_acceptance/run.mjs` and `git diff --check` also passed. Original packaging used `python3 port/tools/native_pickup_acceptance/package.py`; sanitized derivation uses `python3 port/tools/native_pickup_acceptance/sanitize_evidence.py`, which verifies every reconstructed member. `evidence-index.json` records original/derived member hashes and the derived archive hash. All three attempts are retained in `evidence.tar.gz` with only the six documented credential-value replacements; summaries and PNGs remain loose for review. Both packaging tools refuse to overwrite an existing archive.

## Claim boundaries

- **`completionProven=false`**: shipped native trace has no completion marker. Explicit observer `harness_begin`/`harness_end` records delimit this bounded capture; exit 0 and contiguous trace records do not establish a shipped completion protocol.
- Native trace `sequence` is a trace index, **not** protocol input sequence. ACK is the server's high-water mark, **not** proof that every individual input was applied. The audit's order/control comparisons prove queue/receive correspondence within the observed window only.
- This is automated, real native/server gameplay evidence for the default Adaptive, unattached rocket pickup. It does not establish Tool Use/attachment variants, all spawns/routes, health pickup, intentional damage, death/respawn, audio or full visual parity. Those remain outside this lane's result.
- Native stderr retains the unavailable audio-device/dummy-driver fallback and unsupported VSync warning. The graphical viewport and input path worked; audio acceptance is unproven.
- Lead's independent review/rerun remains pending. No merge, push or deployment was performed.
