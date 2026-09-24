# Horde hit and death presentation

Damage/death is never locally awarded. The existing `CombatFeedback` receives
the authority's `damage`/`death` events and owns the shared blood controller;
Horde only retains snapshot-identified NPC visuals on received `death` events
or the authoritative `enemy-detonate` (sappers die with no `death` event).
The last known public NPC pose bridges snapshot removal versus event delivery.
Each corpse falls over 0.8 seconds and remains for 3.5 seconds, capped at 24.
No player corpse is spawned here; the shared local lifecycle owns respawn.

A final kill can deliver `events` and `results` before the next render frame.
Horde flushes the already-received events before the shared round clear and
temporarily exempts the **same** configured blood controller from round-clear
draining so its burst can render through the result transition. It returns the controller to the
shared combat composition on the next round or after 3.5 seconds. No second
damage calculation or private blood implementation is used.

## Sequential verification after lane integration

Cheap native wire fixture: `node --test port/native-horde-deaths/wire.test.mjs`.

Run these Godot commands **one at a time**, not alongside package builds,
imports, other modes' captures, or concurrent worktrees (replace `GODOT` with
the local 4.5.2 editor binary):

```sh
$GODOT --headless --path godot --editor --quit
$GODOT --headless --path godot --script res://tests/horde_deaths/contracts.gd
$GODOT --headless --path godot --script res://tests/blood_fx/contracts.gd
```

These are code/state checks, not proof of visible graphics on owner hardware.
For graphical sign-off, a separate sequential Horde run on the local launcher
must visually inspect a normal hit, an NPC fall/burst, the last-wave result
transition, and a local death/respawn; do not substitute synthetic event tests
for that inspection.

## Integration dependency (shared map geometry)

Identity Horde (`nacre-engine`) currently cannot configure **any** shared
combat effects: `world/combat_occlusion.gd::native_root()` recognizes source
native builders but not the `res://identity_maps/map.gd` builder. This file is
owned by another lane; do not work around it by inventing collision geometry.
Lead should accept the identity builder only when its `get_arena_id() == id`:

```gdscript
if script != null and script.resource_path == "res://identity_maps/map.gd" \
        and node.has_method("get_arena_id") and node.get_arena_id() == id:
    return node
```

Insert this inside `native_root()`'s node scan in
`godot/world/combat_occlusion.gd`, before its final `return null`. Semantic
Horde maps also require a real `godot/content/generated/manifest.json` export;
produce it sequentially with
`node tools/godot-export/semantic.mjs godot/content/generated` before a live
source-map visual run. This directory is generated, not part of this commit.
