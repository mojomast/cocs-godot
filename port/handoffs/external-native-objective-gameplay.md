# External single-agent task: native CTF and Payload gameplay

## Work alone

Your harness cannot use subagents. **Perform this task yourself, sequentially.**
Do not spawn agents, delegate research, or wait for another agent to investigate.
Use the phases below to keep the work bounded and reviewable. Parallel tool
execution is optional; agent delegation is not required or expected.

## Project context

Repository: `github.com/mojomast/cocs`, native Godot port.
Primary checkout: `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`.
Primary branch: `port/godot-destinations`.
Use base **`8e91969`** in a NEW isolated branch/worktree under `/tmp/opencode/`.
Source simulation remains pinned at `51289b79c627a26a381ba556b92bab71f93f3732`.

The current integrated native client has three combat maps, Deathmatch/TDM/
Instagib, compact HUD, weapon switching, native environments, actor/pickup models,
procedural audio and scoreboard. Standalone Puma driving works on both sports
maps. The combined verifier last passed 42 gates. All nine DESTINATIONS maps
and their locked identities remain required.

The owner favors usable, recognizable Godot-native implementations over exact
web-renderer parity. Source gameplay and network authority must remain intact.

## Goal

Build an interactive **standalone native objective demo** for:

1. **Tidal Citadel / `ctf`** — visible flags and bases, carried/dropped/returned
   states, readable team objective status, and real native flag interaction.
2. **Sunscar Convoy / `payload`** — visible authoritative payload, route/checkpoint
   guidance, push/contest status and real native escort interaction.

Deliver actual native controls and server-driven changes, not merely static
models or an offline protocol report. Prioritize one well-tested objective
interaction per mode over a broad unfinished set of modes. Do not claim either
mode fully complete unless its victory/results/restart flow is actually tested.

## Ownership and isolation

Own only NEW files under:

- `godot/objectives/` — renderer, objective HUD and standalone demo scene/adapter
- `godot/tests/objectives/`
- `port/tools/native_objective_demo/`
- `port/native-objective-gameplay/` — notes, evidence, integration handoff

Existing network, world, actor, pickup, lifecycle, control-math and UI modules may
be read/reused through composition or a narrow adapter. Avoid copying the entire
infantry client into a second implementation. A small standalone connection/input
coordinator is acceptable when necessary to stay isolated.

Do not edit shared `godot/world/`, `godot/net/`, `godot/ui/`, existing tests,
the main launcher/verifier or root documentation. The rocket agent currently
owns shared session/combat/setup changes. Sports polish owns `godot/sports/`.
Another external agent owns `godot/lattice/`. Vehicle and pulse-preview assets
also remain outside your ownership. No changes to `game/`, `server/`, contracts,
source lock, exporters, package files, dependencies or other worktrees.

If a shared hook is genuinely essential, write the smallest exact **unapplied**
patch in your handoff directory, with rationale and conflict notes. Deliver as
much usable standalone behavior as possible. Do not bypass the main menu's
capability checks or enable unfinished modes globally.

## Phase 1 — inspect and establish the contracts

Read local instructions and relevant files fully before editing:

- `port/README.md`, `port/RELEASE_MATRIX.md`, `port/contracts/CONTRACT.md`,
  `port/contracts/map-selection.json`.
- `game/destination-objective-maps.mjs`, `game/core.mjs`, `game/objectives.mjs`,
  `game/payload.mjs`, `game/config.mjs`, `game/protocol.mjs`.
- `game/destination-maps.test.mjs`, `game/objective-occlusion.test.mjs`,
  `game/payload.test.mjs`, `game/payload-layout.test.mjs` and relevant CTF tests.
- Existing source flag/payload rendering and native protocol/session lifecycle.

Write a concise discovery note identifying:

- Exact supported map/mode pairs and meaningful first interaction routes.
- Snapshot fields, stable identities, coordinate/height conventions, team IDs,
  event names and which fields prove pickup/carry/drop/return or payload progress.
- Capture/return/contest/proximity rules, carrier restrictions, team roles and
  actual interaction input semantics.
- How your native scene will reuse current modules while respecting ownership.

Known source details to verify rather than assume:

- Full state includes `flags`, `teamScores` and `objectives`. CTF's `objectives`
  subtree does not necessarily carry the same `kind` discriminator as other modes.
- Flags expose team/state/position/carrier; `carryingFlag` and carry-speed state
  also appear on actors. Source supports an interact-edge relay/drop mechanic.
- Payload snapshot data includes position, distance/total, pushing/contested,
  checkpoint progress and delivery state. Render the exact source height.
- Recipient snapshots and server events are authoritative. A renderer's local
  proximity estimate cannot declare captures, delivery, damage or contest.

Finish this investigation and state your implementation plan before coding.

## Phase 2 — implement presentation first

1. Create a reusable renderer with a documented API such as
   `apply_state(state, local_actor_id)` and `clear_round()`.
2. Use stable flag/cart nodes. Add team colors plus readable text/symbols so
   information does not depend on color alone. Distinguish base, carried and
   dropped states. Follow actual carrier/source coordinates without inventing
   motion when the carrier is absent.
3. Render a modest native payload/cart and authored route/checkpoint cues, with
   clear active/completed states only where source data supports them. Keep
   decoration visual-only and avoid creating new authoritative collision.
4. Add compact objective HUD: local team/role, score, carrier or flag status,
   escort/contest/progress, and contextual instructions matching source rules.
   Preserve unknown/missing values instead of fabricating successful state.
5. Bound transient effects/node counts, reject malformed shapes safely, and clear
   stale state on mode change, round start, disconnect and error.

## Phase 3 — make it playable in the standalone scene

- Provide an owned-server launcher and explicit map/mode choice. Derive legal
  choices from the locked catalog. Use ordinary create/configure/start messages.
  Host support is required; guest support is optional unless your live scenario
  needs it. Do not change the shared main menu.
- Reuse the native world and actor/pickup presentation. Support native movement,
  looking and required interaction through existing protocol inputs. Source
  actors, velocity, inventory and objectives must never be written locally.
- Preserve healthy-alive, ownership, snapshot freshness and focus/capture gates.
  Escape/focus loss/death/reset stop active commands; fresh eligibility alone
  must not replay held movement/interact. Show actionable connection/stall errors.
- Keep UI pass-through outside actual buttons. HUD must fit 960×640 and
  1280×800 and coexist with combat presentation where used.
- Results clear active controls and show authoritative outcome. If restart is
  implemented, rebuild from the new round and require deliberate input resumption.

Vehicles, every objective mode, audio parity, a full minimap and complete match
victories are outside the minimum slice. Do not expand into them before the two
requested workflows are usable and verified.

## Phase 4 — focused tests and real-session acceptance

Pinned toolchain and existing dependencies:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
export TMPDIR=/tmp/opencode
export PORT=0
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
node --test game/destination-maps.test.mjs game/objective-occlusion.test.mjs game/payload.test.mjs game/payload-layout.test.mjs
git diff --check
git status --short
```

Run meaningful native regressions for stable IDs, carrier changes including ID
zero, removal/reappearance, payload height/progress, state reset, absent fields,
stale/held controls and no locally inferred outcome. Document and execute their
exact commands. Do not weaken the existing verifier or suppress engine errors.

Perform two bounded **normal-rate live scenarios**, at most 180 seconds each:

### Tidal CTF

Use ordinary native physical input to approach an enemy flag and observe actual
source pickup/carry state, native flag attachment/position and HUD update. Then
exercise a legitimate source drop/pass/return transition. Aim for pickup → carry
→ drop → return; if one stage is genuinely blocked, retain the attempt and state
precisely which transitions were proved. A capture/victory is a bonus, not a
reason to alter rules or fake evidence.

### Sunscar Payload

Move an eligible native attacker into escort range; observe source payload
displacement/progress and matching rendered cart/HUD. Move out and verify source
behavior. If practical, a second ordinary protocol peer may approach and contest
the cart. Report push/idle/contest coverage separately; do not invent a checkpoint
crossing or delivery to make the scenario pass.

Protocol peers or ordinary bots may support the scenario, but the primary user
workflow must run through native inputs. Any navigation planner may read source
geometry; it may not teleport actors or write simulation state. Use legal normal
configuration with unchanged speed/damage/timers/spawns. Never alter source
starting state or accelerate ticks for purported live acceptance.

Retain source event/snapshot witnesses and corresponding native rendered state.
Distinguish queue success, server receipt, ACK high-water and objective application.
Use source sequences/identities to associate observations; do not assume each
input below an ACK was individually applied. No native recording-completion
claim may be inferred from ordinary exit or a harness-end marker.

## Phase 5 — visual inspection, failure handling and cleanup

Use a newly owned private Xvfb, never the shared desktop. On this Linux machine,
`Xvfb -displayfd <fd> -screen 0 1280x800x24 -nolisten tcp -nolisten unix` uses
abstract X sockets and avoids the unwritable shared pathname socket directory.
Validate the returned display number; do not change shared directory permissions.

Save and directly inspect actual gameplay PNGs showing flag/cart and objective
HUD. Label synthetic stress fixtures explicitly. If your harness cannot inspect
images, provide their paths and mark visual review pending rather than claiming
inspection. Record commands, source/runtime hashes and compact evidence without
welcome credentials. Preserve failures; do not repeatedly reroll until success
without explaining the original failure. Fix concrete blockers and rerun affected
checks, keeping attempt count and time bounded.

Rebuild/import after relevant edits; restart only your owned demo processes.
Verify server readiness, native connection and cleanup of server, sockets,
children, display and private files. No push, deployment or shared-service
restart. Reference screenshot gallery: `http://100.125.104.79:43595/`; leave it
untouched. Native demos are not browser-playable test links.

## Phase 6 — documentation and delivery

Create `port/native-objective-gameplay/HANDOFF.md` with:

- Discovery findings and source file/line references.
- Exact launch commands for both modes and complete controls/manual smoke steps.
- Renderer/HUD APIs, snapshot ordering/reset hooks and minimal shared integration
  requirements for the lead.
- Tests actually executed, live transitions actually witnessed, screenshots and
  their classification, cleanup results and remaining limitations.

Commit only owned files in attributable units. Do not merge primary, amend other
agents' commits, discard worktrees or push. Return ordered commit hashes,
base/branch/worktree, concise results and any essential unapplied shared patch.
Leave unrelated tracked/untracked work untouched.

Success is a usable, honestly verified CTF/Payload vertical slice—not a claim
that all objective modes, all nine maps or the complete Godot port are finished.
