# Native upgrade fixture: software-renderer timing repair

## October 7 follow-up: inactive-input lease

The September readiness claim below predates the reviewed idle-input change.
`godot/tests/campaign/input_flow.gd` now requires exactly one inactive cancel
per epoch; the 250ms authority TTL then resets idle clients. Twelve clean frames
at the 30fps cap require at least 400ms, and five additional ACKs cannot arrive
from the idle client. The fixture now waits for one clean frame and the current
epoch's first ACK (`received_input >= 1`) before emitting KEY_2. The harness
isolates `COCS_SETTINGS_PATH` and requests `--windowed --resolution 640x480`;
the fixture also corrects a noncanonical viewport size.

Local llvmpipe baseline: `settle` at 24.02s, 51 stale-input resets, no intent,
58ms median / 2953ms maximum frame. Three changed-gate runs reached `confirm`:
two had matching intent/answer epochs and an applied snapshot; one had an intent
but no answer following a render stall. None passed the existing post-delivery
reset assertions: fifteen linger frames span several 250ms idle leases. These
strict checks remain unchanged, so a complete passing acceptance result is
**not established** by this change. Reverting only the gate reproduced `settle`
with 56 resets and no intent; requiring 999 clean frames likewise held `settle`
with 51 resets and no intent. Logs: `/tmp/opencode/horde-{before,after-1,after-2,after-3,revert-gate,unreachable}.log`.

The Node check now excludes resets **after the authoritative answer**, because
the product input-flow test specifies one inactive cancel per epoch and the
250ms TTL necessarily renews idle epochs during the 15-frame linger. It still
rejects every control reset strictly between the live intent and its answer;
the epoch-equality check independently rejects a changed selection epoch.
The native observer's post-delivery checks remain as written.

Three further Linux runs with the flight-window Node check (`/tmp/opencode/horde-flight-{1,2,3}.log`)
each reached `confirm`, applied one upgrade, matched intent/answer epochs
(16/16, 15/15, 17/17), and had no control reset between those records. All
three still failed the unchanged native post-delivery no-reset/epoch checks,
plus the unchanged Node requirement for five steps after application (three
in each run). Median frames were 51/49/51ms; maxima were
3013/3026/3002ms, with eight recorded frames over 100ms per run. The reset
check's actual source expression was evaluated in a scratch VM: a reset
inside the flight failed, a reset after the answer passed, and a missing
answer failed (`/tmp/opencode/horde-flight-falsify.mjs`).

The following September measurements and successful runs describe the earlier
product revision, not the current idle-input behavior.

The fixture instantiates the real Horde scene and selects the accelerated source
offer using engine `InputEventKey` dispatch. Its authority remains the real native
Horde adapter/source Match. This proves upgrade selection, not natural three-wave
gameplay.

## Diagnosis (2026-09-30)

The readiness predicate is achievable: it requires twelve consecutive frames
under 100ms in one input epoch, plus **five total ACK sequence advances** over
that interval. It does not require a new ACK on each rendered frame.

Exclusive-slot A/B measurements on Godot 4.5.2 Compatibility / llvmpipe with
`LP_NUM_THREADS=1` showed a software-rendering bottleneck:

| Live settle/selection/confirmation interval | Full 3D | Half-scale 3D |
| --- | ---: | ---: |
| Median wall frame | 93ms | 58ms |
| Median measured viewport render GPU time | 76.40ms | 46.01ms |
| Median node-process interval | 12.74ms | 9.51ms |

Full-scale confirmation encountered 252ms and 310ms frames, crossing the 250ms
authority input TTL even after a successful real key selection. Initialization
also had ~3s and ~1s stalls, predominantly between process callbacks. These
startup/warm-up stalls remain visible in the retained timing evidence; the
existing readiness gate waits for transport recovery. The measurements localize
the bottleneck to rendering but do not identify a particular shader revision.

The fixture now renders the 3D world at scale 0.5 while keeping the actual UI and
input viewport at 640×480. A harness assertion checks those dimensions and scale.
The 24s deadline, twelve-frame readiness predicate, authority TTL and post-choice
epoch/reset checks are unchanged. Direct `_input` handler fallback was removed;
both permitted delivery paths go through engine input dispatch.

## Verification and retained evidence

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/horde-upgrade-repair/`

- `baseline.log`: initial worktree setup failure (missing generated semantic
  catalog); canonical generated content was then copied from the parent.
- `baseline-generated.log`, `profile-scale1.log`: reproduced transport-reset
  failure, preserved in full.
- `profile-scale05.log`: controlled half-scale profile and successful loopback.
- `canonical-fixed.log`: exact canonical command, **23/23 harness checks and
  41/41 native checks**, completed in 13.58s.
- `native-ui.log`: screenshot-enabled acceptance, **23/23 + 41/41**, 13.63s.
- `native-ui/horde-upgrade-shots/horde-upgrade-{offer,final}.png`: actual UI.

Both final runs used `parse_input_event`, selected `overcharge` exactly once at
wave 3, and received `horde-upgrade-applied` with count 1 in input epoch 4.
There were no resets after delivery; ordinary input continued for 16/17 steps
after application. Earlier startup resets are explicitly retained, not hidden.

```bash
LP_NUM_THREADS=1 GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES="$PWD/node_modules" \
python3 tools/godot-dev/xvfb_run.py node godot/tests/horde/upgrade_loopback.mjs
```

For full per-frame diagnostics, set `HORDE_UPGRADE_PROFILE=1`. To reproduce the
full-scale control, also set `HORDE_UPGRADE_3D_SCALE=1`. These are explicit A/B
controls, not automatic retries. `HORDE_LOOPBACK_ARTIFACTS=/absolute/directory`
retains offer/final screenshots.
