# Complex external task: native LATTICE command vertical slice

## Project context

Repository: `github.com/mojomast/cocs`, Godot port branch
`port/godot-destinations`.
Primary checkout: `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`.
Known integration base: `9dc82c8` (includes native environments/entities, compact
HUD, weapon switching, standalone Puma renderer and round-boundary fixture fix).
Source simulation lock: `51289b79c627a26a381ba556b92bab71f93f3732`.

Create a NEW branch/worktree under `/tmp/opencode/` from that integration base.
Keep primary and all existing worktrees untouched. Read local instructions,
`port/README.md`, `port/RELEASE_MATRIX.md`, `port/contracts/CONTRACT.md` and
`port/contracts/map-selection.json` before implementation.

## Primary goal

Deliver the first **usable standalone Godot LATTICE command scene**, backed by
the real source server on **Asterion Relay** and **Monsoon Foundry**. A user must
be able to see recipient-authorized team/objective state, issue a meaningful
order, and perform at least one legitimate economy action with visible server
outcome. It must be actual interactive native UI, not just a protocol script or
a static dashboard.

This is a substantial vertical slice, not a demand to complete every LATTICE
system. Preserve both locked `cocs` and `cocs-coop` identities. Target full action
acceptance in `cocs`; verify truthful connection/state presentation for
`cocs-coop`, enabling actions there only where the source supports them.
Simpler, better Godot-native UX is welcome; 1:1 web rendering is unnecessary.

## Ownership / hard requirements

Own only new files under:

- `godot/lattice/` — standalone scene, transport adapter, command UI and visuals
- `godot/tests/lattice/`
- `port/tools/native_lattice_demo/`
- `port/native-lattice/` — documentation, concise evidence, handoff

Read existing viewer/network/presentation/helpers freely. Reuse through
composition or a narrow subclass rather than copying whole shared modules.
Do not edit shared `godot/world/`, `godot/net/`, `godot/ui/`, existing tests,
launcher/full verifier, root docs, `game/`, `server/`, contracts, exporters or
dependencies. If a shared hook is indispensable, provide a minimal unapplied
integration patch and rationale; keep a useful standalone deliverable.

Other agents own infantry mode expansion, live HUD acceptance and fixture cleanup.
External Puma work owns `godot/vehicles/`, `godot/sports/`, their tests and demo.
Pulse-rifle preview paths remain reserved. No overlap with those lanes.

Source authority remains unchanged. Never infer hidden enemy state or fill
missing recipient fields from an omniscient server snapshot. Missing information
must display as unknown/hidden, not zero. No invented budgets, local authority
mutations, modified timers, test-only privileged roles or gameplay rule changes.
No new packages, paid assets, pushes, deployments, destructive git operations or
shared-service restarts. Preserve unrelated modifications and failed attempts.

## Phase 1 — parallel discovery only

Launch three bounded read-only discovery subagents. Do not implement until all
three return with exact file/line findings and recommended APIs:

1. **Wire/action lifecycle:** inspect `game/protocol.mjs`, `server/room.mjs`,
   `game/cocs-wire.test.mjs`, order/economy/spend tests and the web caller.
   Determine role permissions, actual targets, rejection semantics, round/action
   identities, duplicate handling and which observable state proves application.
2. **Recipient state / map identity:** inspect `game/cocs.mjs`,
   `game/cocs-intel.mjs`, `game/cocs-orders.mjs`, `game/cocs-economy.mjs`,
   `game/cocs-coop.mjs`, destination LATTICE maps/tests and snapshot construction.
   Identify useful authorized state, meaningful first action paths on both maps,
   resource names and PvP/co-op differences. Do not assume identical schemas.
3. **Native scene / UX:** inspect the Godot viewer, network client and passive UI
   patterns. Design a readable command board with map landmarks/targets, selection,
   team resources, order status and rejection feedback at 960×640 and 1280×800.
   Determine what can be reused without editing occupied files.

Known findings to verify:

- Source v3 has `order`, `economy`, `terminal`, `command`, `buy`, and
  `cocs-reject` frames. Order verbs include HOLD/ATTACK/SCAN.
- Action parsers accept bounded optional `roundRev` and `actionSeq`; source room
  logic scopes/deduplicates actions and emits structured rejections.
- `godot/net/client.gd` exposes `send_frame`, but currently silently ignores
  unknown message types such as `cocs-reject`. Do not build UI that loses rejects.
  A narrow LATTICE-specific subclass/adapter should preserve ordinary validation,
  size bounds and ordering while explicitly handling the supported added frame.
- Infantry ACK high-water belongs to movement inputs, not command-card success.

## Phase 2 — synthesize before coding

Summarize source findings, the smallest useful end-to-end workflow, recipient
visibility rules, proposed UI and exact owned files. Select one order and one
economy path that ordinary players can actually perform under normal rules.
List concrete blockers; do not replace blocked behavior with fabricated success.

## Phase 3 — sequential implementation agents

Run these dependent implementation units one at a time, with narrow ownership:

1. **Transport/state adapter:** normal create/configure/start and optional join,
   both map choices, actual round revision/action sequence, bounded pending
   actions, structured reject handling, recipient-safe projections and reset.
   Distinguish queued, pending, confirmed and rejected. Disable action submission
   when identity/role/round/fresh-state requirements are absent. No automatic
   spending retries. Explicit user retry gets an appropriate new identity.
2. **Interactive command scene:** source-derived targets and team/resource
   display; real clickable order/economy actions; selection labels, costs where
   known, pending outcome and clear rejection reason. One action per deliberate
   activation, no double-spend on repeated clicks. Reconcile with actual server
   state instead of optimistic authoritative changes. Optional world map view
   may reuse native geometry; a readable tactical view is sufficient.
3. **Runtime integration and tests:** owned launcher, normal-rate sessions,
   focused regressions, screenshots and documentation. A final review agent
   checks only minimal integration issues after those implementations complete.

Movement is optional for this command-board slice. If the chosen action requires
physical proximity, either implement properly gated native movement or select a
legitimate remotely issued source action. Never teleport to manufacture success.
No full main-menu integration: the lead will wire that after acceptance.

## Phase 4 — meaningful verification

Pinned engine:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
export TMPDIR=/tmp/opencode
export PORT=0
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
node --test game/cocs-wire.test.mjs game/cocs-spend-surface.test.mjs game/destination-lattice.test.mjs
git diff --check
git status --short
```

Use existing dependencies read-only. Create focused Godot tests under your owned
test path, document exact commands and execute them. Cover recipient-field
absence, invalid/rejected action, duplicate activation, round reset, stale state,
disconnect and accurate pending/confirmed presentation. Keep malformed-frame
coverage relevant to this adapter instead of building a second protocol suite.

Run real native command UI sessions on **both maps**, normal-rate owned loopback
server, OS-assigned port, ordinary config/role acquisition. Exercise:

1. Connect/start and receive the correct map/mode and recipient snapshot.
2. Select a legitimate target and issue an order through native UI activation.
3. Observe authoritative action/card status or effect tied to its identity.
4. Perform a legitimate economy action and reconcile its outcome/cost against
   source rules, accounting for passive income instead of assuming raw deltas.
5. Exercise one genuine rejected action, with readable reason and no false success.
6. Exercise restart/reset or disconnect; old targets/pending actions must clear.
7. Smoke `cocs-coop` state on both maps; report action compatibility separately.

Do not count queue success or input ACK as action application. Do not inject
authoritative snapshots into live runs. Bound each attempt to 120 seconds and
retain failed/inconclusive attempts. If no affordable/legal economy action is
available in that window, document the source reason and delivered scope rather
than changing starting resources or simulation timing.

## Phase 5 — graphical review / rebuild / cleanup

Use a newly owned private Xvfb, never the shared desktop. Render actual native UI
at both target sizes; inspect screenshots directly and distinguish synthetic
fixtures from genuine sessions. Check long target/rejection text, keyboard
navigation, disabled controls and repeated-action feedback.

Rebuild semantic content/import after relevant changes, then relaunch only your
own demo process. Verify its owned server readiness and actual native connection.
No persistent shared deployment or service restart is requested. Existing
Tailscale screenshot reference is `http://100.125.104.79:43595/`; leave it alone.

Clean up only owned children/server/display/temp resources; verify no remaining
sockets/processes. Evidence must omit welcome credentials and use compact
recipient-state projections. Native recording completion remains unproven;
normal process exit does not prove a complete native trace.

## Phase 6 — docs, commits and return

Write `port/native-lattice/HANDOFF.md` with exact API, launch/test commands,
manual flow, source decisions, intentional simplifications and limitations.
Include a useful README and concise evidence. Run the affected checks after fixes.
Commit only owned files in attributable units; no push or primary merge.

Return ordered hashes, base/branch/worktree, implemented user workflow, actual
test results by map/mode, action identities and source-observed outcomes,
screenshot paths with classification, cleanup results and minimal integration
hooks. State remaining manual checks and larger unimplemented LATTICE systems.
Do not claim all LATTICE gameplay is complete from this command-board slice.
