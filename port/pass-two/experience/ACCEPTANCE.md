# Second-pass experience acceptance checkpoint

**READY FOR ENGINE. No Godot, Blender, import, render or export was started.**
Await the parent's explicit serial native grant after Helix / Foundry / Parallax.
Evidence root: `/home/mojo/.tmp-on-disk/cocs-pass-two-experience-evidence-20261002`.

## Actually completed checks

| Check | Result / evidence |
|---|---|
| `node tools/experience/spectator-oracle.mjs --check` | PASS: 48 target-selection vectors, 30 assist boundary vectors, 63 visibility contexts, 40 source free-motion vectors and spectator snapshot redaction. `source-oracle-final-check.log` |
| `node tools/experience/extract.mjs --check` | PASS: inherited first-pass caption oracle unchanged. `first-pass-oracle-check.log` |
| `node tools/godot-multiplayer/generate-scenes.mjs --check` | PASS, including edited sports derivative. `generated-scenes-final.log` |
| `node --test game/hud.test.mjs game/cocs-intel.test.mjs` | 112 PASS / zero failures. `source-node-tests.log` |
| `node --test game/camera-ownership.test.mjs` | PASS. `source-camera-tests.log` |
| `gdparse` via `uv tool run --from gdtoolkit` | PASS grammar parse for new helpers, presenter, native contract, combined-arms HUD and all four session-hook files. `gdparse-final.log`. Not a Godot semantic/type check. |
| `git diff --check` | PASS |

The initial missing-`three` failure is retained in `source-oracle-attempt1.log`.
Resolved using the authorized parent `node_modules` symlink. No failed native
attempts exist because no native process was launched.

## Native gates prepared, not yet run

Use only after explicit grant, with `LP_NUM_THREADS=1` and pinned binary:
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.

1. Import/type-check, then `res://tests/experience/spectator_contract.gd`.
   Source vectors exercise exact target/fallback/cycle semantics, free-motion
   math, assist boundaries and source spectator event visibility. Native-only
   scenarios cover full-context injection, numeric/string duplicate events,
   same-batch assist, public spectator feed, backwards clocks, event-first seat
   handoff, modal/stale clearing, results/restart and unbind in both actual
   phase/transport shapes (`client`/3 and `net`/`active`).
2. Existing `tests/experience/{contracts,combined}.gd`, product-shell settings,
   relevant spectator/lobby, sports, combined-arms and gameplay input gates.
3. The connected matrix below; these require actual native peers and wire
   captures, not only the synthetic lifecycle contract.

## Connected acceptance matrix / execution plan

Every admitted route gets **two native players plus one late native spectator**.
Use existing authority/native journey launch utilities; retain a fresh directory
per attempt. Record source wire input/event frames and explicit source staging
actions. Source-controlled deaths/phase transitions must be identified as setup,
not unaided human play. Do not mutate locked game/server code to stage evidence.

| Family | Existing entry / required live proof |
|---|---|
| Mode/shared session | Lobby mode (e.g. juggernaut): host + player start; late join receives real spectator seat. Public follow, next/previous, free movement/look, return to follow. Death/leave of watched actor selects source fallback. Tab scoreboard remains shared-route-owned. |
| Infantry / LATTICE world | Existing multiplayer-world session (include Tern LATTICE if admitted): same public camera flow. Capture filtered authority snapshots/events and assert no REQ/intel/orders/cards/kit/cooldown, personal ASSIST or incoming recap enters target HUD after expired-seat reconnect. |
| Sports | Existing `multiplayer_worlds/sports_demo.gd` / Sirocco or Copper join route: real public actor targets, camera follows moving seated actors, free camera independent of chase rig; zero actor input frames from spectator in live and results phases. |
| Combined arms | Existing `combined_arms/demo.gd --join-room`: mounted/infantry player target, free/follow, target death/exit/leave fallback, no vehicle or infantry actor inputs from spectator. |
| Campaign solo | Regression only: actual campaign F12/F3, kit/comms and Home. No spectator launch or fabricated campaign spectator claim. |

For each supported multiplayer family:

1. Record identity/seat IDs on source and native sides. Drive keyboard and mouse
   target buttons, mode toggle, world click/Enter capture, Esc release, WASD,
   vertical move and boost. Assert camera changes while spectator wire input
   count remains **zero**, including neutral movement/fire packets.
2. While controls are held, open F12; inject movement/fire/ability keys; close
   without recapture. Repeat focus loss, stale snapshots, reconnect and target
   change. Assert held ledger and velocity clear, HUD target hides at stale/modal
   boundaries, and fresh input is required. Include chat/LATTICE modals where
   those routes actually expose them.
3. Disconnect/reconnect the same spectator, then exercise an expired player seat
   joining the live round as spectator. Old actor ability/recap/assist/context
   must clear before events. After results, explicitly leave and rejoin between
   rounds for spectator-to-player transition; do not assert unsupported in-place
   promotion. Source client intentionally rejects that promotion.
4. Use real positive damage/death events for player ASSIST within five seconds;
   test outside-window, duplicate event batches, spectator/no local damage and
   world/self deaths. Feed enrichment must match received feed time/victim.
5. Natural results, host restart and Home teardown. Assert the spectator stays
   read-only after restart, source clock/serial reset produces no old enrichment,
   persistent labels detach, and no test-owned process remains.

## Render proof still required

Capture and inspect **1280×800** and **760×520 at UI150** for target controls,
free captured/released indication, no-target/stale/results, feed/assist, F12,
combined-arms help/prompt and campaign regression. Record actual global control
rectangles plus shaped-text minimum sizes; verify readable wrapped/scrollable
content, viewport containment, no overlap with reticle/objective/other panels,
and no private/local actor text. Exercise mouse wheel and keyboard scrolling.
The combined-arms layout repair and new spectator panel are code-complete but
have no visual acceptance claim yet.

At checkpoint all invoked commands have exited. No native/server/render process
was started or left running by this lane. Parent owns final canonical gates,
package inclusion for the new runtime JSON, export, rebuild and publication.
