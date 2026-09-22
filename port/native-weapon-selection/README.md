# Native weapon selection

Implemented against primary `edc222f` in `feat/native-weapon-selection`.

## Controls and integration

Click to capture, then use physical **1–9 / 0** for source weapon indices **0–9**:

| Key | Weapon |
|---|---|
| 1 | Pulse Rifle |
| 2 | Rocket Launcher |
| 3 | Rail Lance |
| 4 | Scattergun |
| 5 | Plasma Driver |
| 6 | Grenade Launcher |
| 7 | Shock Beam |
| 8 | Flak Cannon |
| 9 | Marksman Rifle |
| 0 | Submachine Gun |

**Wheel down** advances; **wheel up** moves backward, wrapping and skipping
zero/missing ammo. Positive numeric ammo and the authority's `"∞"` count as
available. Pulse is never assumed owned: it is available when its actual ammo
says so. Number keys use the same availability filter. A quick number press
released before the next send cadence is canceled; wheel notches are impulses.

`godot/world/session.gd` dispatches actual input to
`godot/world/weapon_selection.gd`, then includes the integer `weapon` in the
existing `client.send_input(controls)` call. The helper's optional display API is
`WeaponSelection.weapon_name(index)`; `NAMES` follows source ordering. HUDs should
continue displaying **`presentation.local_actor.weapon`**, never `pending`.
Selection never changes local actor weapon/ammo or predicts a successful switch.

Requests require a live phase, received fresh pose, healthy lifecycle, application
and window focus, and captured pointer. Key releases, Escape/pointer release,
death, identity change, stale state, errors, results and round starts cancel
pending work. Held keys remain latched across these boundaries until release;
recapture/respawn alone cannot rearm them. Key echo cannot rearm a request.

## Source contract and bounded requests

- `game/data.mjs:21–31`: ten weapon names and indices.
- `game/input.mjs:3–12`: ammo-based availability, infinity representation and wheel order.
- `app/page.tsx:889,917`: physical number conventions and signed wheel cycling.
- `game/protocol.mjs:210–221`: integer `input.weapon` accepted.
- `server/room.mjs:1052–1097,1263–1293`: every input replaces `peer.latest`;
  **weapon has no edge latch**. `appliedSeq` advances after the fixed simulation
  step. A switch-only packet followed by neutral before that step can be lost.
- `game/core.mjs:1005–1024,1192`: authority validates health, ammo, loadout and
  mode, owns switch delay/reload cancellation, and emits `weapon-switch`.
- `game/core.mjs:1313`: nonfinite inventory ammo becomes `"∞"` on snapshots.

The native helper retains only one target, repeated at the existing send cadence
for **at most 250 ms**, ending earlier on confirmation or an applied ACK covering
its first successfully queued protocol sequence. An ACK means the request was
considered, not accepted; mode/loadout refusals therefore do not retry forever.
Rapid wheel input starts at the pending target. Reversing an already queued
request explicitly sends the return target even if the last pre-command snapshot
still shows it. Release cancels future sends, including unsent requests.

Opt-in `trace_input` adds `controls.weapon` only when present in the real outgoing
controls. Trace defaults and cap are unchanged. Trace `sequence` remains a trace
index; only the wire projection in `summary.json.commands[].seq` is protocol
input sequence. ACK high-water marks do not prove each intermediate packet ran.

## Verification

Pinned Godot: `4.5.2.stable.official.6ce3de25a`.

| Check | Result |
|---|---|
| New graphical actual-session regression | **64 assertions**, production input dispatch/send cadence/sequence; synthetic final transport and state fixtures |
| Existing control safety | **2,497 assertions**, exit 0 |
| Existing input queue | **46 assertions**, exit 0 |
| Existing native trace | **28 assertions**, zero failures, exit 0 |
| Existing round boundaries | **12 assertions**, exit 0 |
| Source protocol/input/weapon-switch tests | **34 tests passed** |
| Direct source Room edge/ACK test | See `source_edges.test.mjs` / `evidence/source-edges.log` |
| Import + new regression + native gameplay | Exit 0, no `ERROR:` or `SCRIPT ERROR:` diagnostics |

Existing detached control-safety, native-trace and round-boundary fixtures emit
RID/ObjectDB cleanup diagnostics after passing; logs preserve those diagnostics.
The new regression and real session have only the software-renderer V-Sync
warning. Synthetic coverage includes ownership/ammo rejection, infinity,
pending-wheel ordering, in-flight reversal, ACK/refusal/timeout, trace omission,
key release, focus/death/respawn/stale/restart/results/identity boundaries.

### Real native result

[`evidence/summary.json`](evidence/summary.json) contains executed source hashes,
normal match configuration, wire input sequence projection, authoritative
transitions/events and cleanup. [`evidence/native.log`](evidence/native.log)
retains only weapon-bearing native trace records, weapon transitions and final
observer status; it is deliberately a filtered excerpt, not a contiguous trace.
[`evidence/native.png`](evidence/native.png) is the final native viewport.

Final run: Meridian ordinary deathmatch, zero bots, default server tick
`1/60`, no mutators. Native guest actor **1** started at **(-44, 0, -34)** and
walked via **(-14, -33) → (-14, -19)** using physical W and relative mouse motion
from `Input.parse_input_event`. It collected one rocket pickup at server time
**5.200**, gaining **6** rockets and selecting weapon **1** authoritatively.

Then real physical **1**, **2**, **wheel up**, **wheel down**, and a fresh **1**
after Escape/release-and-recapture produced five source `weapon-switch` events:
**1 → 0 → 1 → 0 → 1 → 0**. An uncaptured held 1 did not switch before or after
recapture until released and freshly pressed. All observed transitions retained
health **100** and rocket ammo **6**. **186** wire inputs included **11** bounded
weapon-bearing packets, matching native trace commands in order. The final
authoritative ACK was **185**. No actor/camera/authority state assignments or
smoke controls were used in this live run.

The runner uses a private Xvfb `-displayfd` display and private copied runtime,
read-only dependency symlink, and an owned loopback server. Its passive host only
creates/configures/starts through normal messages. The existing pickup route
planner is read-only. All owned children were reaped; server closed; zero sockets
remained; temporary runtime was removed. The retained live evidence covers this
ordinary pickup/switch route; lifecycle/ownership rejection coverage is synthetic.

### Reproduce

From the worktree root:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/native-weapon-selection/run.mjs --output=/tmp/opencode/weapon-selection-rerun

node --test game/protocol.test.mjs game/input.test.mjs game/weapon-switch.test.mjs
node --test port/native-weapon-selection/source_edges.test.mjs
```

The runner enforces import/regression/native deadlines and checks actual Godot
errors as well as process exit status. It verifies one real rocket pickup, the
exact authoritative weapon sequence, five request-driven switch events, bounded
wire commands and native/wire weapon-command correspondence.
