# Grant Z — Vesper native diagnostic failed on the accepted civic ascent

**MOTH-BLENDER-20261003-Z is RELEASED.** No queued work or automatic retry.
Fresh branch `astra/vesper-native-z`, based on parent `33afe0ec`, isolated worktree
`/home/mojo/.tmp-on-disk/cocs-vesper-native-z`. Source instrumentation is commit
`eba8b633`; this report and immutable native evidence are a separate commit.

## Exact outcome: stop on first failed group

| Group | Passed | Failed | Unrun | Result |
|---|---:|---:|---:|---|
| `accepted-civic-r035` | 5 downhill | 5 uphill | 0 | **FAILED**, exit 1 |
| `accepted-civic-r042` | 0 | 0 | 10 | Unrun — sequence stopped |
| `candidate-civic-r035` | 0 | 0 | 10 | Unrun — sequence stopped |
| `candidate-civic-r042` | 0 | 0 | 10 | Unrun — sequence stopped |
| `candidate-roof-r035` | 0 | 0 | 10 | Unrun — sequence stopped |
| `candidate-roof-r042` | 0 | 0 | 10 | Unrun — sequence stopped |

Five lanes X30.5/31.25/32/32.75/33.5, complete civic endpoints Z66→24 and
Z24→66. Walk-only, no sprint or jump. **2,686 native input responses plus 200
settling steps**, all at actual 60Hz with time scale1 and consecutive physics
frame counters. The first failed *group* completed its ten prescribed trials;
no subsequent group ran. The .42 test-only envelope was **not exercised**.

- Every downhill walk reached the real lower landing, grounded, within the
  original .15m horizontal and safe-margin+.001m vertical arrival conditions.
  Input frames by lane: **410,410,411,410,410**. These are landing successes,
  **not** full-flight clearance or continuously grounded claims: downhill
  traces contain **690 non-grounded responses** in total.
- Every uphill walk stopped at **[lane,12.0166673660278,24.7000026702881]** with
  zero velocity, ground support `city-grade--25--140Collider`, resetCount1 and
  contact `civic-stair-0Collider` at **[lane,12.1499996185303,25]**.
- Each ascent has **127 input responses**, first tread contact at zero-based
  frame7, then **120 consecutive stalled frames**. Every ascent remains on the
  lower grade; no step-up is observed. No reset, teleport, manual height lift,
  endpoint change, retry or tolerance adjustment was introduced.

[Full native journey](../../../../godot/tests/new_maps/botanical_post_x/vesper-Z-01/accepted-civic-r035-journey.json)
contains every pre/post position, velocity, grounded flag, contact position and
normal, support collider/normal, reset count and engine-clock sample.
[Trace analysis](evidence/trace-analysis.json) verifies all responses and gives
each trial's maximum vertical/horizontal change, drift, frame span and contacts.

## Root cause: rounded-capsule tread contact, not absent/substituted art

The native controller is the unchanged production **exploration** `Walker.step`
with actual PhysicsServer capsule radius **.3499999940**, height **1.7999999523**,
collider offsetY **.8999999762**, walk6, gravity20, safe margin **.0199999996**,
floor snap **.3000000119**, maximum floor angle **46°**, maxSlides6. The actual
shape RID data and parameters are checked and written **before every trial**.
Initial spawn separation is .05m only; settling then uses the real controller.

The first tread spans X30..34, Z25..25.5 at Y12.15: a **.15m rise** from the
lower grade. The lower rounded capsule contacts its leading edge before the
body centre crosses Z25. Final contact normal is approximately
`[0,.6251514,-.7805035]` (centre lane `[0,.6273353,-.7787492]`), **51.15–51.31°
from up**, beyond the controller's 46° floor limit. Native `move_and_slide`
blocks the commanded forward motion; downward floor snap does not implement
an upward stair step. The first tread's actual triangles are identical in the
candidate (its indexing representation differs). That source fact is **not a
candidate native traversal result**.

The authoritative `game/core.mjs::moveActor` is a distinct movement owner: its
highest-floor centre query and explicit strict <.25m terrain snap / <.3m
horizontal rise rule traverse these .15m treads. Its previously qualified
60 required source trials / 13,530 frames remain valid. They do not establish
CharacterBody traversal. This run now demonstrates the baseline mismatch.

Native failed-trial contacts are at the low leading tread edge, not a ceiling.
Source-only replay of all 2,686 recorded positions produces **13,430 clear
headroom rays**, centre plus four .35m corners over foot+.25→foot+1.8. This
excludes the step band and is explicitly **not a full finite-capsule or native
head-clearance gate**. Maximum downhill single-response drop is .103124619m;
small recovery rises reach .018348694m. Ascent rise is zero. No stair solver
or model change is inferred from successful downhill landing alone.

**Vesper remains withheld.** The prior **184 static capsule contacts remain
failed**. Native movement also fails on the accepted civic ascent. No urban-v4,
controller change, GLB/master change or Parallax production repair was made.
Further native groups or a remedy require explicit parent steering and a new
grant; there is no automatic candidate-only continuation or baseline exclusion.

## Native JSON/art binding was verified before motion

Both exact scenes were imported and read back; accepted was selected and
instantiated in the world after removing the helper-loaded art. Candidate was
instantiated for its strict import census but **not used in a movement world**.
[Pre-trial binding receipt](../../../../godot/tests/new_maps/botanical_post_x/vesper-Z-01/accepted-civic-r035-binding.json)
has `bindingReady=true` and `bothVariantsRuntimeVerified=true` before any trial.

| | Accepted | Candidate X |
|---|---|---|
| GLB SHA256 | `6afe34c82d45f06c30dedc780f59ac6afa5200835b487d41705902d771fc0bfd` | `f859d49cc1b462b4a88e351d915518c49940ce24a7b8c2047c2d8f94f419e1db` |
| Authority SHA256 | `e273264a789036b26bda83bf8e390c8ae53f78e4357da241ce4a49368e8af885` | `397cedc8f5583a229bb3f65ed94d9a8c74c30fd4132b57bd4e754299a47c67ec` |
| Geometry hash | `27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7` | `fd8e7134c8933e908336d7b0409c66bdc90f4adc03fcfc6e596d5b4579f1c740` |
| Import UID retained | `uid://ck1nf8ky7d3h2` | `uid://c048mnlm2hdbb` |
| Actual triangles / meshes / materials | 54,804 / 11 / 11 | 64,311 / 29 / 17 |

The receipt also holds recipe hashes, exact loaded/instance paths, sidecar and
cache hashes, actual material names and selected runtime geometry hash.
Compression disabled / LOD generation disabled were checked against the actual
Godot sidecars; uncompressed imported mesh flags and loaded resource UIDs were
checked at runtime. Original first-import sidecars are archived separately,
proving genuine generated UIDs were retained during the second import.

Scope remains direct movement API with cleaned Binder state and exact JSON/art.
No keyboard/focus/network, Weather/material lifecycle or full-map acceptance.
No screenshots or rendering backend claims; the headless traces suffice.

## Execution and preserved attempts

Godot **4.5.2-stable official `6ce3de25a`**, `LP_NUM_THREADS=1`, `OMP_NUM_THREADS=1`.
Actual project setting readback for the physics backend was `DEFAULT`; we do
not relabel that as a measured renderer or game-performance result. Commands,
binary SHA256, owner and child PID/PGID/kernel start ticks, stdout and exit
statuses are in [evidence/attempts](evidence/attempts).

| Command | Bound | Start → end UTC | Exit |
|---|---:|---|---:|
| First isolated-worktree editor import | 900s | 22:43:47.787026 → 22:47:40.444939 | 0 |
| UID-retaining precision/LOD reimport | 900s | 22:48:02.078277 → 22:48:09.083843 | 0 |
| `accepted-civic-r035` | 180s; internal170s | 22:48:22.462018 → 22:49:11.255618 | **1** |

Fresh namespace: `godot/tests/new_maps/botanical_post_x/vesper-Z-01/`. Setup used
the explicit read-only X fixture root. Source-only additions accept this exact
grant namespace, record pre-trial binding/actual shape/clock parameters, and
retain support/contact telemetry. They do not change walker or map behavior.
The GDScript parsed and bound successfully on the first native attempt.

One supervisor setup error preceded job dispatch: the reused nested Foundry
runner's ROOT depth was off by one in this shallower namespace. Its complete
traceback and zero-heavy-job receipt are retained. ROOT was corrected before
the successful supervisor acquired its lifetime lock. This was not a failed
movement attempt or a bypassed import/identity error.

The full isolated project's first import generated unrelated sidecars; only
**709 provably Z-created**, untracked, release-hash-matching sidecars were
removed. All **1,468 preexisting sidecars** stayed identical. The attempt's
**50 sidecars**, generated texture PNGs, both exact GLBs, source scripts, JSONs,
all trial parameters and trace are preserved. **96 imported cache files** are
archived with original resource paths/hashes. No blanket untracked cleanup.

## Checks and release

- **13 portable Python tests passed.** Native trace analysis checked exact
  consecutive physics frames, shape parameters, reset counts, expected landing
  criteria, all five genuine stalls and clearly scoped source headroom rays.
- All **600 X and 264 U inventory files** match. All original 15 dependency
  hashes, historical post-X JSONs and all other parent-tracked artifacts remain
  unchanged. Parallax proposal is unapplied.
- Grant acquired **22:43:37.676017Z**; three empty audits of all **3 owned groups**
  at **22:49:40.435164Z**, **22:49:40.668919Z**, **22:49:40.905932Z**.
- Explicit Z release **22:49:41.170337Z**. Fresh nonwaiting lock-availability
  check **22:49:55.310797Z**. No queued work; supervisor exited.
- Preexisting viewer PID2598700 / PGID2598689 / startTicks522477875 and all
  inventoried preexisting displays remained intact.

[Release audits](evidence/attempts/release.json) ·
[Lock availability](evidence/lock-available.json) ·
[Frozen integrity](evidence/frozen-integrity.json) ·
[Source checks](evidence/source-checks.json) ·
[Owned sidecar cleanup](evidence/owned-sidecar-cleanup.json)
