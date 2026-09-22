# Native world tactical commands

Optional **C** overlay in `res://lattice/world_demo.tscn`, developed in an isolated worktree from `6116f12`. It uses the world's existing recipient socket for public objective selection, explicit **HOLD**, and one-consent purchases through the existing LATTICE transport.

## Play

With the pinned Godot 4.5.2 binary and the primary checkout's dependencies available read-only:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
node port/native-lattice-world-commands/run.mjs --play --map=asterion-relay --mode=cocs
# Or:
node port/native-lattice-world-commands/run.mjs --play --map=monsoon-foundry --mode=cocs-coop
```

In an isolated worktree, create the `node_modules` symlink to the primary checkout only if absent. The runner creates an ordinary, normal-rate authority on ephemeral loopback port 0 with history/progression persistence disabled. Interactive `--play` has no runtime deadline. Closing the native window stops its owned authority and removes its temporary XDG directories.

- **C:** open/close tactical commands. **Esc** or the panel's Close button also closes it.
- Opening releases the pointer, clears pending weapon requests, and immediately queues neutral movement/action input through `client.send_input`.
- Choose a public objective, then press **Issue HOLD**. Opening and selecting are inert.
- PvP Fighter: authorize one **12 team FLUX** purchase, then click Recruit. Co-op REINFORCE: authorize one **50 team FLUX** purchase when the recipient transport permits it. The live gate explains unavailable recruitment, allowance, threads, budget, or executor lease.
- Closing clears selection and consent. Release movement/action/weapon keys and mouse buttons, then make a fresh world click to resume. Key release alone never recaptures.
- Focus loss, stale state, death, identity changes, missing projection, results, and disconnect clear selection and consent and disable actions. Unresolved action receipts remain owned by the transport until its normal lifecycle clears them; losing focus cannot silently permit duplicate spending.

The panel shows public nodes, own-team FLUX/spending, own REQ, and the last three action receipts. It is scroll-backed and fits both 960×640 and 1280×800. `label`, `world_label`, and existing observer APIs are preserved. The ordinary HUD now names C and explicitly calls movement ACK a **high-water receipt**.

## Authority and implementation

`godot/lattice/world_commands.gd` is presentation only. It binds to `world_demo.client` and calls `purchase_kind`, `action_gate`, `activate`, and `rejection_text`. Display prices come from the transport constants. Its own checks concern focus, lifecycle, selection, and fresh consent. Rules, queue identity, cooldown, unresolved-action suppression, and receipt reconciliation remain in the existing transport; its hash matches `642c615`.

Consent is consumed before queueing and invalidated by a changed map/mode/round/peer/actor/team, co-op wave/executor/lease, or unavailable purchase gate. No optimistic budget deduction, unit spawn, objective ownership, or order completion is displayed.

`world_demo.gd` adds only overlay construction, input routing, neutral/release behavior, lifecycle invalidation, and the control hint/ACK wording. The world adapter, shared session/UI/network, board, source, contracts, dependencies, launcher, and package/export settings are untouched by this commit.

## Verification

```sh
GODOT_BIN="$GODOT_BIN" python3 port/native-lattice-world-commands/verify.py
```

This owned verifier preserves every attempt under `evidence/`, runs source validation/import, the existing detached world contract, the new boundary/consent contract, two new live overlay cases, and both existing world traversal cases. Every graphical case uses private Xvfb with `-nolisten tcp -nolisten unix`, one native actor socket, normal server defaults, and no simulation reset, budget seeding, or privileged handler invocation.

Live automation uses **Godot engine input events**, not OS-device input or a human playtest. Boundary fixtures are separately labelled and substitute only the outbound queue. Manifests record source revision, file hashes, Godot version, invocation, display, and port; wire logs retain recipient-visible fields only. Own-team budget keys are audited. Purchase observations are correlated to exact recipient snapshot sequence and the source role-spawn event/actor delta.

See [ACCEPTANCE.md](ACCEPTANCE.md) for results, retained failures, screenshot review, and handoff details. HOLD acceptance/order execution is distinct from objective capture/completion. Co-op live coverage proves HOLD and the naturally closed recruitment gate; the 50-FLUX purchase reuses the already-proven transport and has a dedicated lease/consent fixture, without claiming a new live co-op recruit.
