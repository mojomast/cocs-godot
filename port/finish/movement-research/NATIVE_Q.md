# Movement native Q — completed and released

## Candidate and scope

- Grant: `MOVEMENT-NATIVE-20261003-Q`.
- Tested candidate: `f61f6156d9575d8dcf44ca4daf7a09bef727b034`.
- Isolated worktree: `/home/mojo/.tmp-on-disk/cocs-movement-native-Q-20261003`.
- Branch: `finish/movement-native-Q`; verified clean before execution.
- Godot: `4.5.2.stable.official.6ce3de25a`, binary SHA256
  `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
- Evidence: `/home/mojo/.tmp-on-disk/cocs-movement-Q-evidence-20261003`.

Read IMPLEMENTATION.md, SOURCE_GENERATION.md and REVIEW_CLOSURE.md before
execution. Full tracked checkout was materialized in the new worktree after
`git worktree add --no-checkout`; 88 GiB disk space remained before import.
P's frozen worktree, cache, receipts and canonical 89/22/31 result are unchanged.

## Actual results

| Stage | Bound | Actual wall time | Result |
|---|---:|---:|---|
| Native version | 20 s | 0.015 s | Passed, pinned Godot 4.5.2 |
| Headless editor import | 900 s | 8.577 s | Passed |
| campaign-input-flow | 60 s | 0.332 s | **1,970 checks, 0 failures** |
| first-person-slide | 60 s | 0.428 s | **10 checks, 0 failures** |

All four commands exited zero, with **zero ERROR, SCRIPT ERROR or WARNING lines**.
Both fixture success summaries were required. The weapon-0 GLB import sidecar's
actual cache destination existed before the slide gate was launched. No fixture
or production correction was needed; no failed attempt was discarded.

The input-flow gate executes the real campaign, arena and Horde client classes
through fixture subclasses with intercepted `send_frame` transport. It checks
the four-outstanding window under delayed FIFO consumption, applied/cancelled
ACK credit, received-ACK rejection, pending melee/weapon selection, cancellation
bypass, epoch/disconnect reset, transport failure and inactive Horde cancellation.
This is native client-method execution with controlled ACKs, not a live server
or physical-input journey.

The slide gate executes the actual imported weapon rig: bounded convergence,
unchanged camera transform/FOV, settled ADS removing slide offset/cant, immediate
reduced-motion clearing, and hidden/dead/spectating/mounted lifecycle clearing.
These are headless presentation contracts, not rendered comfort or human fun.
The changed source movement speed/buffer behavior remains covered by the prior
source suites; these two native gates do not remeasure locomotion speed.

## Commands and receipts

The serial supervisor `/tmp/opencode/movement-Q.py` acquires
`/tmp/opencode/cocs-finish-acceptance.lock` with `LOCK_EX | LOCK_NB`, uses
`LP_NUM_THREADS=1`, isolated HOME/XDG stores in the evidence root, and calls
`tools/godot-dev/gate_runner.py::run_gate`. Each engine owns a new process group.
Warnings and missing/failed fixture summaries also reject acceptance.

```sh
"$GODOT_BIN" --version
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --editor --import
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/campaign/input_flow.gd
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/first_person/slide.gd
```

Logs: `native-version.log`, `editor-import.log`, `campaign-input-flow.log`,
`first-person-slide.log`. `report.json` retains exact commands, durations,
log hashes, process groups, imported cache hashes and cleanup audits.
`input-before.json` / `input-after.json` retain every tracked file hash and
the pinned binary hash. Before and after tracked-input manifest SHA256 match:
`5c4dcc6dc237501108a0bcc114e9655059c2bb624d511fe04f1e5fe5d180df51`.

All **712 tracked import sidecars are unchanged**, and no tracked input changed.
Fresh import generated **2,560 cache files and 681 untracked UID/import files**;
their inventory is retained rather than pretending the fresh cache was unchanged.
This report-only commit postdates the tested candidate and does not re-stamp its
identity. No package, art, audio, hardware or canonical release pass is implied.

## Capture follow-up

Existing first-person capture entries were inspected (including handling,
finishes, kick and hip-kick capture). They do not expose a slide-state comparison
entry; the handling capture covers a larger weapon/pose matrix rather than this
cue. No capture was launched and no PNG was fabricated. A future bounded staged
capture should apply the public actor cue with `sliding=true` and preserve its
input/timestamp for neutral/slide, settled ADS and reduced-motion comparisons.
Rendered readability, comfort and human fun evaluation remain pending.

## Explicit resource release

**MOVEMENT-NATIVE-20261003-Q is released.** Three consecutive `/proc` scans of
owned groups **3915252, 3915266, 3916148, 3916211** were empty:

- `2026-10-03T16:24:10.081125+00:00`
- `2026-10-03T16:24:10.099057+00:00`
- `2026-10-03T16:24:10.116424+00:00`

The shared lock is closed, no engine remains and Q has no queued heavy work.
Parent may coordinate the next separately granted Moth/Blender producer.
