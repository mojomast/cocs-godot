# LATTICE world discovery (before implementation)

Base `642c615`; source lock `51289b79c627a26a381ba556b92bab71f93f3732`.

## Ordinary recipient input is supported

- `game/protocol.mjs:212–227` accepts finite clamped world-space x/z, yaw/pitch, held fire/sprint/crouch/mobility and jump/reload/interact booleans.
- `server/room.mjs:1052–1097` rejects unassigned/spectator/disconnected/ended recipients, resolves actor ownership itself, rate limits and tracks input sequences. Held state replaces `peer.latest`; jump/reload/interact use edges.
- `server/room.mjs:1263–1293` routes each peer's input to `inputs[p.actorId]`, steps the unmodified authority, then ACKs the consumed sequence. ACK is receipt/consumption, not evidence of displacement or capture.
- `game/core.mjs:1183–1227` chooses external controls before bot controls for that actor. COCS does not replace ordinary infantry input with an abstract command cursor. No traversal blocker found.

## Capture and HOLD

`game/cocs.mjs:1638–1773`: living actors inside node radius and within 5 vertical units supply actual presence. Adjacency/live legality, contest, resistance and capture time apply. A live HOLD/ATTACK supplies order presence only without an enemy actor; it can advance an empty legal node but cannot contest an actual actor. Only the authoritative owner transition/capture event proves capture. Arrival alone, ACK, queued HOLD or accepted/running HOLD does not.

## Visibility and shape

`server/room.mjs:1299–1328` applies `filterCocsSnapshot` per recipient team before socket send. `game/cocs-intel.mjs:89–102,125–162,270–296` leaves public nodes, owner/progress/contest and actor positions visible, but removes enemy wallet/command/team-budget data. This source revision explicitly documents enemy-position visibility as a V1 limitation; do not invent client fog or obtain missing actors from `Match.snapshot()`/room internals. Render only received actors and retire visuals when absent. Display only own actor REQ and recipient-team FLUX.

`game/core.mjs:1310–1313` supplies actors with x/y/z, yaw/pitch, health/dead, eyeHeight, identity, gear and ammo. `game/cocs.mjs:1918–1936` supplies public node x/z, owner/progress/live/contested; **y/r are co-op-only additions**, not guaranteed in PvP. PvP markers must use authored static support height and must not invent a wire capture radius. Existing `world/presentation.gd` expects actor dictionaries and finite numeric poses, renders feet+0.9 and camera feet+eyeHeight, removes absent IDs, and uses source health for lifecycle. It does not need an omniscient actor list.

## Native contracts and reuse

Read all of `godot/net/client.gd`: 1 MiB cap, v3 welcome, allowlisted map matching at lobby/start/state, unique roster ownership, full-roster revocation, monotonic snapshot sequence/ACK, bounded history/event IDs, delta rejection and round-end suppression. Its own comment correctly says envelope hardening is not a full gameplay schema. LATTICE transport adds round identity, recipient projection and action reconciliation but assumes actors are dictionaries. A new world-only transport subclass will validate consumed actor/node shapes before signals, preserving shared files.

`world/session.gd` owns native WASD/look, socket cadence, pointer release, local actor camera, absent pose, owner changes, stale state, death/results/restart/error resets. Its `_ready()` is combat-menu-specific; follow the existing standalone objective subclass pattern: initialize owned scene, replace `client` with a compatible LATTICE subclass before attaching, and inherit control/handshake callbacks. No shared hook is required. Add release-before-recapture and clear presentation on revoked identity/missing COCS projection. The optional scene will allow only Asterion/Monsoon and cocs/cocs-coop with ordinary 2-bot host defaults, without editing the combat menu or launcher.

## Verification boundary

Use private Xvfb, pinned Godot 4.5.2, loopback ephemeral server and default simulation rate. Real key/mouse input must produce source-coordinate displacement; retain compact socket receipts and exact camera/rendered coordinates separately from ACK. Aim at a nearby public node only if the native path reaches it; no strategy win requirement. Tests must cover malformed/missing projection, owner revocation and focus/release/stale controls. All additions stay in owned `world_*` native paths and this directory.
