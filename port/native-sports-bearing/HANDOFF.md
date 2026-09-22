# Sports bearing correction — ready for lead integration

**Fixed:** Ion gate and Aurora ball/opponent-goal Left/Right labels now agree with
the chase camera. Runtime/test commit: **`99c0a93`**. Base: **`5445295`**.
Branch/worktree: `fix/sports-bearing`, `/tmp/opencode/sports-bearing`.

## Change and test audit

`godot/sports/guidance.gd` and `soccer_guidance.gd` compute the signed angle with
`atan2(offset · right, offset · forward)`, where forward is `(sin(yaw), cos(yaw))`
in XZ and screen-right is `(-cos(yaw), sin(yaw))`. The **0.22 Ahead / 2.4 Behind**
thresholds and distance formatting are retained.

The new **synthetic** `bearing_projection_test.gd` instantiates the real Chase
helper and a Godot Camera3D. It compares both sports' labels to actual projected
pixel positions at eight cardinal/oblique/wrap-seam headings and both resolutions.
Fixtures are explicitly synthetic, built in the camera basis; the oracle is
`Camera3D.unproject_position`, not a repeated sign formula. It also checks both
sides of the Ahead/Behind thresholds.

Existing expectations audited:
- `soccer_test.gd` had two erroneous lateral assertions. At yaw PI/2 the camera
  looks +X, so +Z projects **Right**, -Z **Left**. Those assertions and their
  rationale are corrected. Its Ahead/Behind, selection/team and stale-HUD checks
  remain valid.
- `progression_test.gd` only asserts an Ahead gate; it is still correct.
- `practice_test.gd` checks alignment/approach coaching, not lateral labels.
- `test_polish.gd` and `test_controls.gd` check camera geometry/HUD and source-input
  projections. Their expectations remain valid.
- Read the four existing gameplay steering observers (`progression_observe`,
  `progression_goal_observe`, `soccer_observe`, `practice_soccer_observe`). Their
  signed errors drive source yaw/steering; they are not HUD label expectations.

| Focused suite | Passed checks |
|---|---:|
| New camera-projection/threshold regression | 896 |
| Soccer guidance | 45 |
| Sports progression | 32 |
| Practice coaching | 21 |
| Sports polish | 41 |
| Sports controls | 27 |
| **Total** | **1,062** |

[Before-fix run](tests/baseline-projection.log): **64 failures / 896 checks**,
covering both sides in both functions at all headings/resolutions. Post-fix:
**zero failures**, six suites pass. [Results/commands](tests/results.json).
Semantic export, final Godot import and `git diff --check` passed.

## Directly opened native PNGs

All eight primary PNGs below were opened directly with the image tool. Target
placement and HUD text match on both sides. These are actual native scenes using
accepted public source state, captured without overlays or image editing.

| Scene / viewport | Target visibly right; HUD Right | Target visibly left; HUD Left |
|---|---|---|
| Ion 960×640 | [gate](live/ion-speedway-960x640/00-spawn.png) | [gate](live/ion-speedway-960x640/02-turn.png) |
| Ion 1280×800 | [gate](live/ion-speedway-1280x800/00-spawn.png) | [gate](live/ion-speedway-1280x800/02-turn.png) |
| Aurora 960×640 | [ball + attack goal](live/aurora-stadium-960x640-goal/00b-right.png) | [ball + attack goal](live/aurora-stadium-960x640-goal/02-turn.png) |
| Aurora 1280×800 | [ball + attack goal](live/aurora-stadium-1280x800-goal/00b-right.png) | [ball + attack goal](live/aurora-stadium-1280x800-goal/02-turn.png) |

At 960×640 the distant ATTACK caption is partly behind the upper panel, but the
goal opening/ground stripe and its lateral placement are visible. The 1280×800
captions are unobscured. This correction makes no broader HUD-legibility claim.
The original Aurora 960×640 [right ball](live/aurora-stadium-960x640/00-spawn.png)
and [left ball/goal](live/aurora-stadium-960x640/02-turn.png) were also opened.

Auditor's three original PNGs were extracted byte-for-byte from **`29b0a59`**,
retained and opened: [Ion](before/ion-right-labelled-left.png),
[ball](before/soccer-ball-right-labelled-left.png),
[goal](before/soccer-goal-right-labelled-left.png). Their git object IDs and hashes
are in [provenance.json](provenance.json). The audit commit was not cherry-picked.

## Live method, receipts and limits

Five fresh sessions lasted **62.22 seconds total**, including startup/cleanup.
`bearing_observe.gd` instantiates the actual `sports/demo.tscn` and only reads
state/camera/HUD and captures frames. `run.py` supplies ordinary external XTest
Enter, A/D and Escape events. Stationary steering uses the existing source Puma
low-speed assist. The source-selected Ion gate is `(-36, -68)`; Aurora's opponent
goal is `(44, 0)`; ball positions are the accepted public soccer selections.

Each run has `session.json` with exact process commands, `actions.json` with key
durations, raw PNGs and adjacent receipt JSON, passive `wire.json`, logs and cleanup.
`audit.py` validates **12 projected target-side/HUD receipts**, static source
geometry, original PNG equality and all five cleanup receipts.

The receipt's `seq`/`race` are the newest accepted snapshot at capture; the moving
ball's HUD selection can be one frame older. Two primary left-ball receipts
explicitly report `selection_matches_latest_snapshot: false` in provenance.
They are source-derived selections, not fabricated positions. Do not attribute
their exact ball coordinates to the newer sequence or treat projection pixels
as exact image-centroid measurements. Both versions have the same lateral side.

Retained failure/limit evidence:
- [Initial fixture parse failure](tests/fixture-parse-failure.log): Variant loop
  arithmetic needed explicit `Vector3` typing; fixed before the red regression.
- [Initial receipt-audit assumption failure](tests/receipt-audit-initial-failure.log):
  diagnosed the selection/newest-snapshot distinction above; captures preserved.
- Later soccer `03-turn`, `04-turn`, `05-released` images turn targets partly or
  wholly off-screen. They are retained raw, excluded from the two-sided visual
  pass. The first soccer run had no opponent-goal Right label (Ahead threshold);
  the short `-goal` runs add D for 0.2 s to obtain that view.
- Runtime logs contain only the private software-driver VSync warning, no Godot
  errors. Audio was explicitly Dummy. No human usability, OS feel, hardware,
  exported-package, full lap/goal, or full aggregate-suite acceptance is claimed.

## Provenance and reproduction

- Runtime: `99c0a9392c62ddbb0226c5e3ff842e1d096c0fc6`.
- Unchanged locked source: `51289b79c627a26a381ba556b92bab71f93f3732`.
- Source file-tree SHA256: `98b1d0868893d21ad83ffe5b844b954340abbcc250506e0185d33e304a93b96c`.
- Runtime file-tree SHA256: `da4e24f62213de3ce25172fe4b0db68899d766d06c7466ccdc618db521bbce43`.
- Godot **4.5.2.stable.official.6ce3de25a**, binary SHA256
  `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
- Pinned dependency path:
  `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules`.
  Per-file runtime/source/ws hashes, semantic manifest, observer and evidence
  hashes are in `provenance.json`; tree digests hash sorted compact JSON maps.

From a fresh worktree/evidence directory (runner refuses to overwrite evidence):

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode PORT=0
export XDG_DATA_HOME=/tmp/opencode/sports-bearing-xdg/XDG_DATA_HOME
export XDG_CONFIG_HOME=/tmp/opencode/sports-bearing-xdg/XDG_CONFIG_HOME
export XDG_CACHE_HOME=/tmp/opencode/sports-bearing-xdg/XDG_CACHE_HOME
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
python3 -B port/native-sports-bearing/verify.py
python3 -B port/native-sports-bearing/run.py ion-speedway 960x640
python3 -B port/native-sports-bearing/run.py ion-speedway 1280x800
python3 -B port/native-sports-bearing/run.py aurora-stadium 960x640
python3 -B port/native-sports-bearing/run.py aurora-stadium 960x640 --goal-right
python3 -B port/native-sports-bearing/run.py aurora-stadium 1280x800 --goal-right
python3 -B port/native-sports-bearing/audit.py
git diff --check
```

Each supervisor owns a fresh port-0 loopback authority, private Xvfb with
`-nolisten tcp -nolisten unix`, and isolated temporary XDG directories. Cleanup
confirms all 15 owned PIDs absent and ports **44359, 45085, 33617, 34321, 43703**
closed. Server receipts report zero remaining sockets. Native SIGTERM exit -15
is intentional bounded cleanup; server and Xvfb exit 0.

Lead integrates the two scoped commits and rebuilds the package. No merge,
push, deployment, other-agent work or reserved-lane edits were performed.
