# Combined-arms infantry graphics integration

`godot/combined_arms/graphics.gd` is a passive adapter for this composition's
`net`, `actor`, `vehicle`, string-valued `phase`, and `world.camera` API.
`demo.gd` attaches it after the world camera exists, forwards accepted snapshots
after the existing fleet/actor/lease handling, and subscribes to `net.events`.

## API and lifecycle

- Uses `first_person/rig.gd` directly: `attach_to`, `apply_actor`, `apply_events`,
  and `reset`. The isolated weapon viewport remains below the existing HUD.
- Infantry visibility requires `eligible()`, matching nonnegative connection and
  snapshot identity, a live nonspectating actor, nonspectating connection, open
  WebSocket, actual window focus, controls focus, controls engagement, captured
  pointer, and an empty resolved vehicle. The rig independently rejects a
  non-null actor `vehicleId`; a broken mounted lease cannot show infantry.
- Boarding and existing control release immediately hide the rig and clear
  motion. Dismount still requires the existing fresh engagement latch. Temporary
  hiding retains rig event history and consumes hidden events to prevent replay.
- Public combat feedback uses the existing `world/combat_feedback.gd`, including
  its Moth cues, projectile snapshots, audio, tracers, and damage feedback.
  It remains available while driving an eligible Puma. Its local hit/hurt overlay
  uses the infantry visibility predicate, preserving the existing vehicle HUD.
- Stale/unfocused/dead/identity-invalid/closed-socket states clear public effects.
  Authoritative start, results, and errors reset both graphics systems, including
  the feedback's source actor references. Results events are also rejected by
  the existing network round latch.
- Graphics read state and control policy only. No source simulation, protocol,
  input packet, input latch, aim, camera, or gameplay-state writes are added.
  Public event deduplication remains the network client's responsibility.

## Verification

Pinned runtime: Godot **4.5.2.stable.official.6ce3de25a**.

| Check | Result | Evidence |
| --- | --- | --- |
| Demo, adapter, fixture parser checks | Pass | `evidence/parser.log` |
| Composition API/lifecycle fixture | 65 checks, zero failures | `evidence/headless.log` |
| Existing combined-arms controls/lease/fleet regression | 43 checks | `evidence/controls.log` |
| Synthetic GL Compatibility run | 68 checks, zero failures | `evidence/graphical.log` |

The fixture subclasses the actual demo, retains its snapshot/event/start/results/
error callbacks, uses the actual protocol decoder, and opens a private loopback
WebSocket to exercise transport readiness. Decoded synthetic frames cover
infantry → Puma → broken mounted lease → infantry, stale recovery, independent
focus/capture/control-focus gates, death, identity revocation, spectator gates,
results, repeated IDs, new-round ID reuse, closed socket, and error reset.
It compares graphics-enabled commands against an independent controls instance,
checks pending interact/fire latches, and checks snapshot, aim, camera, and input
sequence immutability across repeated graphics refreshes.

From repository root, with `GODOT` set to the pinned executable:

```sh
"$GODOT" --headless --path godot --script res://combined_arms/demo.gd --check-only
"$GODOT" --headless --path godot --script res://combined_arms/graphics.gd --check-only
"$GODOT" --headless --path godot --script res://tests/combined_arms/graphics.gd --check-only
"$GODOT" --headless --path godot --script res://tests/combined_arms/graphics.gd
"$GODOT" --headless --path godot --script res://tests/combined_arms/test_controls.gd
```

The rendered run used a private Xvfb (`-displayfd`, `-nolisten tcp`,
`-nolisten unix`), private XDG directories, software Mesa/llvmpipe, and a private
ALSA null sink. On such a display, invoke the fixture with
`--audio-driver ALSA -- --graphics-probe`. It writes these **synthetic** captures:

- `evidence/synthetic-infantry.png`: weapon/arms visible.
- `evidence/synthetic-mounted.png`: weapon/arms hidden during the Puma lease.
- `evidence/synthetic-dismounted.png`: weapon/arms visible after re-engagement.

## Remaining limits

This is composition wiring evidence, not a live source-authoritative match or
desktop input acceptance run. Focus/capture values are explicitly injected by the
fixture; the production demo reads the actual window and `Input.mouse_mode`.
The screenshots use the read-only viewer's default map/camera backdrop and frozen
synthetic leases, rather than a driven Sunscar route. Audio dispatch is asserted
with a null output sink, not listening-based verification. The graphical driver
reports unsupported V-Sync configuration; there are no script/shader errors or
ObjectDB teardown warnings in the final run. Package/export and global gate
registration belong to the coordinating verification task.
