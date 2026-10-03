# Controller choice / recovery correction — source complete, native pending

Canonical `b6ab6782` merged cleanly into the existing presentation checkout. This
fix addresses the two source-identified production bugs in independent acceptance
`port/fighting/acceptance/UI_HANDOFF.md:184–199`. No independent acceptance fixture,
responsive camera, native camera gate, core, content, animation, GLB/import setting,
stage or FX file is modified.

## Production behavior

`presentation/device_choices.gd` is a pure projection of the two actual assigned
IDs, player index and connected IDs. Keyboard (-1) always appears. Connected
controllers are sorted by exact ID, de-duplicated and the other player's controller
is skipped. Therefore the ordinary order is usable: P1 selects the first pad;
P2's next choice is the free second pad. Both players can independently use their
keyboard layout. Exclusivity is still enforced again by `router.assign()`.

If the current assigned ID is missing, it is retained as an explicit last entry:
**Pad N · disconnected**. It is never displayed as Keyboard while routed to N.
Activating this entry once intentionally assigns Keyboard. Further activations
cycle the free connected pads. A disconnected ID that reconnects under the same
ID becomes truthfully labelled as connected, with ownership retained. A different
new ID is not silently substituted; recover to Keyboard and explicitly select it.
No connection event resumes a paused match.

The button recalculates choices on activation, instead of using an index captured
from an obsolete connection list. Menu/Settings captions refresh in place on
hotplug and application focus return. Cycling retains button focus instead of
rebuilding the screen and shifting focus to Start/Back. A fullscreen/size change
does not affect identity or selection. Destroyed menus clear their button references
before deferred freeing. Disconnected/unavailable captions are kept short for
compact layouts; their tooltip and pause message explain one-click Keyboard recovery.

Owned-pad disconnect continues through `router.unplug()` → `release_all()`:
**both actors' held maps and queued short-tap edges clear**; previously held physical
tokens require release and a fresh press. The match pauses and resume stays blocked
until the missing assignment is intentionally replaced or its exact ID reconnects.
Reassignment also clears both actors. Invalid player indices and IDs below -1 are
rejected. No automatic transfer, automatic resume, global bindings or authority
changes are introduced.

## Checks actually run

```sh
python3 -m unittest discover -s tools/fighting/presentation -p test_devices.py -v
```

**6 tests pass**:

1. Ordinary P1-first, P2-second assignment.
2. Truthful disconnected caption and one-activation Keyboard recovery.
3. Same-ID reconnect / changed-ID reconnect without silent transfer.
4. Exclusive cycling, shared keyboard, sparse/duplicate IDs and invalid boundaries.
5. Pure menu/Settings/fullscreen refresh and recalculation after stale enumeration.
6. Production wiring for both-actor release, pause, fresh press and resume blocking.

The tests execute the **actual pure helper source** through a narrow Python syntax
shim (type declarations removed, Array operations supplied). This is source-level
algorithm proof, **not execution in Godot**. The release/lifecycle test checks the
production call paths; real InputEvent behavior remains a prepared engine gate.

Expanded `godot/tests/fighting/presentation/input_gate.gd` prepares real mapper
InputEvent assertions for ordinary choice order, two actors held during disconnect,
both queues cleared, truthful missing label, both actors fresh-press rearming and
explicit Keyboard recovery. Calling `unplug()` in that unit gate is not evidence
of kernel enumeration/removal or physical unplug.

GDScript grammar, the existing 918 source framing checks, stage hashes/resources
and `git diff --check` pass. Evidence is under:
`/home/mojo/.tmp-on-disk/cocs-fighting-presentation-evidence-20261002/controller-recovery/`.

## Exact native follow-up (UNRUN)

`VEHICLE-ASSET-PRODUCTION-20261002-E` exclusively owns the heavy slot. No engine,
import, render, audio, encoding, device injection or nested agent ran here. The
independent UI producer's misleading-caption assertion and P2-first workaround
are retained unchanged. Parent should coordinate a separate **ordinary P1-first**
native case with its acceptance owner; the workaround alone does not establish it.

After a fighting-specific serial grant, run the prepared mapper gate, then the
unchanged independent `ui_driver.py` producer per `UI_HANDOFF.md`. Before that
producer can exercise controllers, provision writable `/dev/uinput` and readable
resulting event nodes; the parent reports the current device exists but is neither
readable nor writable. Do not replace kernel signals with forged signals or relax
the missing-access failure. The fixture establishes virtual-controller behavior,
not physical hardware compatibility.

Native cases required: P1 first pad then P2 second; hold both actors' buttons,
remove either device, inspect caption and router ID, prove both releases/paused
authority, block resume, recover via the one-click Keyboard choice; reconnect the
same and a changed ID without stale inputs; repeat through selection, Settings,
fullscreen/windowed and focus refresh. Existing responsive-camera/141-gate pending
acceptance remains pending; these source tests do not close it.
