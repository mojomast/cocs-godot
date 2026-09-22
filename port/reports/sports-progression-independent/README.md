# Independent sports progression and round flow

Delivery `0a07f5c` integrated as `e76acdb`. The lead reviewed source-driven
guidance, passive HUD/results, event handling and F5 lifecycle before integration.

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
python3 -B port/native-sports-progression/run.py --map ion-speedway --resolution 960x640
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
python3 -B port/native-sports-progression/run.py --map aurora-stadium --resolution 1280x800
```

Both **PASS** against the real normal-rate source in private projects/displays.
All original controls27/Puma19/polish41 and new progression32 checks pass in each
clean import: **119 assertions**. Tested script manifest hash:
`121afbbd5e0cdb3d9d77f4d15f628fd266b8b90db0cbad14c2ad06bbfe2cdde0`.

| Case | Evidence under `port/native-sports-progression/evidence/` | Result |
|---|---|---|
| Ion 960×640 | `eaa86bda-7e43-4146-82ff-8581826b8b1d` | All 17 gates crossed; one completed lap observed at source elapsed **43.1 s**; natural 90 s results |
| Aurora 1280×800 | `fdddc567-b43c-47ee-809a-b422a29180f5` | Natural 60 s results, 0–0 draw; no goals in this run |

Both run F5 restart and verify native cleanup, fresh source round, held-W
blocking, Enter-only neutrality and movement only after a fresh W. Ion has
2,171 input receipts, 99 neutral second-round receipts before fresh movement,
and **7.361 m** subsequent source displacement. Aurora has 1,699 receipts,
117 neutral receipts and **7.229 m** displacement. One/two final neutral receipts
after results are not claimed applied: the source rejects round-over inputs.
Source/wall clock ratios were 1.006 and 1.003; no tick/rule acceleration.

The lead directly opened Ion lap and results PNGs, Aurora results and
Enter-only-neutral PNGs. The lap notification, mint next-gate frame, elapsed
clock, honest “1 lap completed” time-limit result, 0–0 draw and stationary
re-engaged vehicle are visible. HUD/panels fit at both sampled resolutions.
Every child is reaped, each server closed with zero sockets and both copied
runtime trees removed. Engine-key input acceptance is not OS/human acceptance.

The agent's original four-case matrix covers both resolutions on both maps;
these two independent cases reproduce the material gameplay/lifecycle claims.
The race target was ten laps, so one completed lap is not a race-target victory.
No local-driver soccer goal is claimed. Earlier bot-scored goals and the
notification JSON-number failure remain separately documented in the original
handoff; the fixed notification has no post-fix live goal screenshot yet.

The common launcher now forwards validated `--time-limit=60..900` and
`--round-target=N` for sports; other experiences reject these options. Its
four routing checks pass. The combined **53-gate run passes**, including the new
progression32 gate and the bounded audio-finish fixture correction. Exact
results are in `../verification.json`. Native recording completion remains unproven.
