# Native combat input lane

## Delivered contract

`godot/world/session.gd` exposes `aim_requested() -> bool` for the first-person rig. It reads a locally responsive, eligible, recorded RMB latch. The rig owns camera FOV and visual blending. Shared mouse-look applies the source default ADS sensitivity multiplier **0.85** once. Horde keeps its existing sampler/look calculation and supplies only the aim hook.

The ordinary session now records desktop events instead of polling global held state:

| Control | Binding | Wire behavior |
| --- | --- | --- |
| Fire | LMB | Held + retained short-click pulse |
| ADS | RMB | Held; explicit false when released/ineligible |
| Alternate fire | Z / MMB | Held |
| Power | Q | Fresh-press pulse |
| Melee | F | Fresh-press pulse |
| Grenade | G | Fresh-press pulse |
| Mobility | X | Held |
| Reload / interact | R / E | Fresh-press pulse |
| Jump | Space | Held + retained short-tap pulse |
| Movement / sprint / crouch | WASD / Shift / Ctrl or C | Held |

**Intentional mapping change: F was the native session's legacy mobility binding. F now means melee; X means mobility**, matching source defaults and Horde. Lattice keeps its composition-specific C command panel. Arms Race keeps number/wheel weapon selection pinned while accepting combat/ADS input.

Queued pulses clear only after a successful transport queue. Physical-down latches survive cancellation, so releases are observed even while inactive and a held key/button cannot restart on focus return, stale recovery, respawn, or recapture. ADS also cancels on weapon changes and reload; RMB must be released and pressed again. Neutral samples explicitly include `ads`, `power`, `melee`, `grenade`, and `altFire` as false. Read-only spectator sessions queue no inputs, including neutral packets.

Combined Arms adds infantry-only ADS. Seat/focus/eligibility changes clear it, vehicle packets send false, and the passive graphics adapter calls `apply_aim` only when that runtime method exists.

## Verification

Pinned engine: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64` (4.5.2).

```sh
python3 port/native-combat-actions/verify.py
```

The runner owns a private Xvfb and, for the live fixture, an ephemeral loopback production server. It creates no repo copy. Tests may also be selected by script stem, e.g. `python3 port/native-combat-actions/verify.py combat_actions/live`.

Passing evidence in `evidence/`:

- `combat_actions-controls.log`: 90 assertions covering source bindings, pulse retention, held/repeated presses, capture-click fire, explicit neutral fields, movement normalization, ADS sensitivity, focus/stale/dead/spectator/results/weapon/reload boundaries, Arms Race ADS and Combined Arms seat gating.
- `combat_actions-live.log`: injected native `InputEventMouseButton` press/release through actual shared Session sampling and actual WebSocket transport to an **unmodified normal-rate production server**. Includes outgoing `PORT_NATIVE_TRACE` controls and returned `COMBAT_AUTHORITY` snapshots. Authoritative ADS became true and false; focus cancellation returned false. Held Q/F/G produced exactly one source `power`, `melee`, and `grenade` event, and the returned actor power cooldown became positive. The source default harness was `openclaw`; this demonstrates power activation, not a shield-specific visual.
- Existing read-only tests: control safety **2497**, attached-window focus **7**, weapon selection **64**, round boundaries **34**, spectator session **31**, native trace **28**, Combined Arms controls **43**, Horde source input **31** and source look **3**.
- Headless check-only loads of Combined Arms, Horde and Lattice scene scripts also passed.

The event fixture, focus notifications and death/respawn regression stimuli are synthetic. The live server, transport, authoritative ADS snapshots and action events are real. The live fixture's spectator identity transition is synthetic; the existing spectator scene test separately validates the decoded read-only roster contract. **No GUI acceptance is claimed.**

`checks.json` records the most recent selected verifier invocation. Individual logs retain the other test results.

## Original defect and diagnostic history

`evidence/original-missing-actions.log` reproduces the original packet from immutable native-session commit `a0db1604da047aa442fcf2a1358809450a716ccb`: ADS/power/melee/grenade/altFire are absent and the aim API does not exist. `godot/tests/combat_actions/baseline.gd` loads the old session source in memory with a recording transport; it never swaps the working source.

To reproduce that baseline:

```sh
git show a0db1604da047aa442fcf2a1358809450a716ccb:godot/world/session.gd > /tmp/opencode/native-combat-baseline-session.txt
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/combat_actions/baseline.gd -- --source=/tmp/opencode/native-combat-baseline-session.txt
```

Initial verifier attempts exposed harness issues, retained here rather than represented as clean first-pass runs:

1. Running the new 85-check capture test headless produced 17 ADS/capture failures because headless Godot does not retain mouse capture. The test passes on private X11 without weakening its capture assertions.
2. Xvfb allocation initially timed out with Unix socket-listener errors. The runner now disables filesystem Unix listeners as well as TCP, following the existing private-display harness convention, and bounds allocation time.
3. The spectator test initially lacked its required `--lobby-menu` argument, and the Horde test lacked its required `--vectors` fixture. Both invocations timed out; their corrected invocations pass. Existing test scripts were not edited.
4. Some immediate-exit synthetic tests print Mesa/Godot texture teardown diagnostics; those lines remain in their raw logs. The live transport fixture completes without them. Assertion results and exit codes are reported separately from those diagnostics.

No gameplay, projectile/hit authority, shared packaging, or root verification files are part of this lane.
