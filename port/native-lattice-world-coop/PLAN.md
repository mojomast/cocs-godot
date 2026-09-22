# Source-first acceptance plan

Baseline `8a58c97e48493e41903c2c9a729e753cb3579500`. Active lane record
read from primary on 2026-09-21; campaign deferred and other reservations respected.

Prior exact natural-window acceptance is
`port/native-lattice-economy/evidence/1790042899109757665/`: Asterion waited
129.6 s and Monsoon 132.5 s, with ordinary source bots and normal ticks.
That observer used `board.tscn`, whereas the current world observer stops during
initial deployment. This lane exercises `world_demo.tscn` and its actual panel.

## Source facts (read before live attempts)

- `world/session.gd:280–282`: ordinary host config, two bots. No injected config.
- `game/cocs-coop.mjs:49,303–335`: executor epochs last 600 ticks (10 s);
  the sole human retains the executor ID but `leaseUntil` changes naturally.
- `game/cocs-difficulty.mjs:25,47,67,87`: intermissions last 24–30 s,
  enough to let one epoch expire before fresh consent.
- `game/cocs-coop.mjs:431–432,532–565`: intermission-only REINFORCE costs
  50 FLUX; `675–713` increments source spawned count. No REQ debit.
- `server/room.mjs:298–317,358–374`: card settlement is a correlated spend
  receipt. Movement ACK is only input high-water, never purchase completion.
- `world_commands.gd:114–120,149–161`: consent consumed synchronously;
  map/mode/round/peer/actor/team/wave/executor/lease epoch invalidate consent.
- `transport.gd:141–169`: own human slice allowance, executor, free thread,
  source sink cost/availability and team FLUX gate the action.

## Purposeful live cases

1. Asterion 960×640, then Monsoon 1280×800, at most two attempts per map.
   Every attempt has an exclusive output directory and is retained on failure.
2. Ordinary source server on owned dynamic IPv4 loopback, isolated XDG runtime,
   pinned Godot 4.5.2, private Xvfb with both TCP and filesystem Unix listeners
   disabled. Shared primary node_modules is read-only by convention; no install.
3. Engine key/mouse events open C while W/fire held. Verify neutral transmitted
   controls while visible, stable authoritative own x/z, and same actor/socket.
   Select own frontier and issue one HOLD to reproduce prior setup.
4. Wait on actual recipient recruitment permission (no simulator or clock writes).
   Authorize 50 FLUX, wait for real leaseUntil change, click purchase with the old
   consent and verify no economy frame. Re-authorize explicitly; purchase once.
5. Match done/ok card to round, actor, peer and action ID, with cumulative spent
   +50, spawned +1 and unchanged REQ spent. Check repeated clicks and reopen
   cannot duplicate. Close, release held controls, fresh-click and move same actor.
6. Save and directly inspect actual viewport screenshots at both sizes. Retain
   native logs, allow-listed wire witness, exact commands, hashes and cleanup.

Each live attempt's outer deadline is 210 s; native waits end sooner so cleanup
can run. Fixture lease rotation checks are recorded separately from live proof.
No captures, full rounds, OS/human input or strict per-action spawned actor
attribution under multi-client races are claimed. Runtime defects are reported
with an unapplied minimal patch proposal; only new lane tools/tests are edited.
