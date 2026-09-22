# Native Payload cart guidance

**Ready for lead integration.** Isolated worktree `/tmp/opencode/native-payload-guidance`,
branch `native-payload-guidance`, baseline **`e1defc0`**. This closes the narrow
Payload approach-guidance recommendation in usability audit `29b0a59`.

## Delivered behavior

- A separate gold row identifies **Cart Ahead / Right / Left / Behind**, horizontal
  player-to-cart distance, and the **actual snapshot radius**. Route metres are
  explicitly labelled **Route**; checkpoint counts say **Checkpoints banked**.
- Camera-relative directions use infantry camera forward **−basis.z**, with
  screen right derived by crossing flattened forward with UP. No sports yaw sign
  assumption. Direction is a bearing, not obstacle-aware navigation.
- Range is geometry only: source `game/payload.mjs:149` requires living actors,
  horizontal distance **≤ radius**, and height difference **≤5 m**. Radius comes
  from the snapshot (Sunscar observed **4.5 m**), not a duplicated gameplay constant.
  Missing/nonfinite position/radius/health has explicit unavailable/unknown copy.
- Push/contest/delivery remain source-controlled. Attacker-only pushes; both teams
  contest; defender-only rolls back to bank. The new checkpoint-limit explanation
  handles source `pushing=defender` even when the cart is stationary at its floor.
  It preserves the existing **ROLLING BACK** acceptance category on arrival at bank.
- Beginner hints distinguish attacker escort from defender blocking/contesting.
  Dead/released states are explicit; being inside radius never labels the local
  player as pushing. Release does **not** stop source occupancy or pause the match.
- Only source `delivered=true` says DELIVERED. 100% or checkpoint counts cannot
  fabricate delivery; round-complete/winner remains tied to authoritative results.

Runtime changes: `godot/objectives/guidance.gd`, `hud.gd`, `renderer.gd` only.
New fixtures/drivers are `godot/tests/objectives/guidance_*`; tools, retained
evidence and documentation are entirely in this directory. CTF text, shared HUD,
scoreboard, controls, session/network, source, launchers and packaging are untouched.

## Verification

| Check | Result |
|---|---|
| Geometry, actual archived snapshots, unknowns and role fixtures | **823 checks**, `tests/final-guidance-malformed-checkpoints.log` |
| HUD layout/allocated row height, release, stale, results, CTF/error clearing | **99 checks**, `tests/final-guidance_hud.log` |
| Existing objective renderer / controls / progression HUD | **19 / 11 / 33**, `tests/final-*.log` |
| Existing parsed-key queued-release timing | Pass; same-callback held, released after two frames |
| Existing progression + completion replay/corruption tests | **32 passed**, `tests/replay-tests.tap` |
| Unmodified historical full-Payload replay | **3,792 exact matches**, `tests/archived-payload-replay.json` |
| Historical source sequence through **final new renderer**, then existing completion validator | **3,793 models / 3,792 matches**, `tests/final-current-renderer-replay.json` |
| Pinned import and graphical-driver parse | Pass, logs retained |
| Fresh bounded observation / raw PNG review | Final run **8/8 images** reviewed directly; source audit passes |

Projection fixtures use **synthetic locations** through real `Camera3D` projection
at two viewport sizes, 13 yaw angles and five pitches, checking both screen sides,
Ahead and Behind. Snapshot-state fixtures extract real public records from the
accepted historical Payload archive: idle, pushing, contest, rollback, bank and
delivered. Malformed fields, boundary geometry and changed local defender roles
are explicitly synthetic. These are not new live contest/death/delivery claims.

`replay.mjs` feeds the actual archived sequence through the current renderer and
substitutes only its model/root/HUD outputs into the old replay validator. Source,
inputs, results and restart witnesses stay **historical**, not fresh live behavior.
This specifically checks compatibility on the decreasing snapshot that lands at
the checkpoint floor. Existing CTF preservation is fixture-tested, not replayed live.

## Fresh graphical evidence and failures

Exactly **two** owned normal-rate scenarios; no additional gameplay reruns:

1. [`77dd0c9f…`](evidence/77dd0c9f-a066-4bad-84b2-c258d1932e3b/REVIEW.md),
   **11.869 s**, 960×640, 251 native/source root matches. Driver observation passed,
   but direct review of all four PNGs **failed visual acceptance**: the auto-wrapped
   label had zero height. Its natural spawn was already inside range; the planned
   `off-cart` filename is not a claim otherwise. All originals remain unchanged.
2. [`a3cec2b2…`](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/),
   **14.726 s**, 356 native/source root matches. Fixed label, actual off-cart state,
   ordinary arch-detour approach, escort and Escape release. Each stage was captured
   at **960×640 and 1280×800** by resizing the native window during the same scenario.

All eight final PNGs were opened with the image-capable read tool:

| Stage | Direct visual observation |
|---|---|
| [Off-cart 960](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-off-cart-960x640.png) / [1280](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-off-cart-1280x800.png) | **Right · 19.7 m · Get within 4.5 m · Controls released**; actual cart visibly right, IDLE, route 0% |
| [Approach 960](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-approach-960x640.png) / [1280](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-approach-1280x800.png) | **Ahead · 16.6 / 16.3 m**, outside radius; route still 0% |
| [Escort 960](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-escorting-960x640.png) / [1280](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-escorting-1280x800.png) | **Inside 4.5 m**, server PUSHING RED, route 4.6 / 4.8%; near-eye cart clipping preserved |
| [Release 960](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-release-960x640.png) / [1280](evidence/a3cec2b2-e154-4d7e-8468-87f070d4ef41/guidance-release-1280x800.png) | **Controls released**, CLICK TO PLAY, range 2.3 / 2.6 m; source cart correctly keeps pushing while actor remains inside |

The HUD/status/vitals remain separated and legible. Existing oversized distant
landmark labels and close-cart art remain visible; no art-polish claim. Fresh live
bearings observed are Right and Ahead; other sectors are projection fixtures.

Other retained failures: initial JSON-float team membership (fixed with numeric
equality); driver parse collision with inherited `elapsed` (renamed); early HUD
fixture lacked fresh-snapshot/settled-container setup (corrected); first live PNG
failure prompted the actual row-height fix and regression. See all original logs.

### Exact live versus final code

Live `launch.json` files record pinned binary, arguments, baseline revision and
per-file hashes including dirty runtime/helper content. `audit.mjs` verifies gzip
checksums, all unchanged source/runtime hashes, exact actor/cart roots by sequence,
shot dimensions/states/ranges, normal-rate source versus wall time, and cleanup.
Historical product files are reconstructed and **hash-verified against launch** as
`live-renderer.gd.txt`, `live-guidance.gd.txt`, plus first-run `live-hud.gd.txt` and
`live-driver.gd.txt`. No original receipt is relabelled.

After the final live run, fixture/replay-only refinements added rollback-category
compatibility at bank, defender/unknown-role wording, neutral dead-player copy,
and a malformed checkpoint-index guard. These branches were not exercised in the
short final attacker run; its sampled layout/geometry/idle/push/release behavior
is unchanged. Final renderer compatibility and these branches passed the fixtures
and historical-sequence replay. There was no third graphical run.

Source lock **`51289b79c627a26a381ba556b92bab71f93f3732`**.
Godot **4.5.2.stable.official.6ce3de25a**, binary SHA256
`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
Final runtime and generated-map hashes are in [`audit.json`](audit.json), alongside
PNG hashes and source/wall-time comparisons. Source Payload SHA256:
`13e357516af38fdfe6596dfa7a43cbeaae2445f492ad41df934deb8840bc92bb`.

## Reproduce / integration

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
node --loader ./port/tools/native_objective_demo/dependencies.mjs tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/guidance_fixtures.gd
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/guidance_hud.gd -- --map=tidal-citadel
node port/native-payload-guidance/replay.mjs
node port/native-payload-guidance/audit.mjs
# Optional independently authorized new graphical observation (new UUID):
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/native-payload-guidance/run.mjs
```

The helper owns loopback **PORT 0**, private `Xvfb -nolisten tcp -nolisten unix`,
private XDG, Dummy audio and a **115 s outer deadline**. Driver uses ordinary
Godot parsed native key/mouse events, not source/actor writes or direct control
handler calls. Window resize is presentation-only; no state/time/physics injection,
source seed selection or preferred-spawn reroll. This is automated native-event
evidence, not human/hardware/Wayland acceptance.

Both client/Xvfb pairs were reaped and independently absent; both source servers
closed with zero sockets, ports **39519 / 43239** closed, private runtime trees
removed. Supervisor PIDs and headless XDG cleanup are in `cleanup.json`.
The total graphical wall time was **26.595 s**. Shared servers were not used.

The lead owns integration and package rebuild. No fresh full delivery, contest,
rollback, checkpoint, results/restart, focus-loss or CTF gameplay claim; those are
covered by the explicitly separated historical/fixture evidence. No aggregate
gate, package build, merge, push or deployment was performed in this lane.
