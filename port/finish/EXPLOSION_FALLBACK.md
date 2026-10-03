# Weaponless explosion presentation

The source `Core.detonate()` emits `explosion` with an authoritative `pos` and
any source-specific `extra` fields. `Core.emit()` wraps that payload with its
event `id` and simulation `time`. Ordinary detonation does not add a weapon;
alt detonations add `alt`, `altId`, and, for bomblets, `bomblet`.

The Godot weapon-effects consumer now validates the event ID, finite
nonnegative source time, finite bounded position, and any explicit weapon
identity before dispatch. An event with no weapon and no recognized alt kind
gets one restrained neutral burst at exactly `pos`; it does not read a weapon
profile or claim weapon attribution. A valid source radius, if present, scales
the card within a tight bounded range. Valid alt kinds and recognized primary
projectile weapons retain their distinct existing presentation paths. Unknown
alt events and malformed explicit weapons are not reclassified as generic.
Explosion ID/time deduplication applies to every dispatched blast. Quality 0
continues to suppress the consumer, and generic fallback is one card with no
secondary motion under reduced motion.

## Verification

- Source inspection: `game/core.mjs` `detonate()` and `emit()` contract confirmed.
- Targeted native fixture: `godot/tests/edge_effects/weapons.gd` covers the
  source-shaped weaponless event, authoritative position, replay dedupe,
  unknown alt, malformed weapon, and existing primary path. **Prepared only;
  Godot/native execution was not available in this environment.**
- No engine import, render, server, or live source authority was run or changed.
- Package pin impact: none; no dependencies or package manifests changed.
