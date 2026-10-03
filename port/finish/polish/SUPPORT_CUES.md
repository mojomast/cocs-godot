# Supplemental Moth support cues (integrated combat feedback)

Branch `feature/polish-flash-support-fx`, worktree
`/home/mojo/.tmp-on-disk/cocs-polish-flash-support-fx-20261003`, base `5b5c8791`.

## Gap

`PortCombatFeedback.apply_events` queues fresh public events and `flush_effects`
routes them to weapons, shields, world particles, blood, player FX and impacts.
It never routed the Moth world accents. The only Moth consumer was the detached
fallback (`apply_events` when `weapon_effects` is not integrated). So on the
shipping integrated path, accepted `pickup` (health/megahealth), `mender-heal`
and `teleport`/`teleporter` events produced no world cue, while damage sparks and
explosions are already owned by `weapon_effects` and `player_fx/impacts`.

## Change

Two files, 48 added lines, one new test.

- `godot/graphics_fx/moth_world.gd`
  - `static func support_only(event) -> bool`: the one non-overlap predicate.
    True only for `teleport`/`teleporter`, `mender-heal`, and `pickup` with
    `kind` in `health`/`megahealth`. Damage, explosions, shots and armour pickups
    are excluded.
  - `set_quality(level)` / `set_reduced_motion(value)` plus a presentation gate
    in `consume`. The accepted event ID is consumed (`seen`/sliding window)
    before the gate, so a dropped cue cannot replay when the preference changes.
  - Defaults (`quality = 2`, `reduced_motion = false`) preserve every existing
    direct caller (`tests/graphics_fx/regression.gd`, `live.gd`, fallback path).
- `godot/world/combat_feedback.gd`
  - `flush_effects` filters the drained fresh events through
    `MothEffects.support_only` and consumes only those, after the public-state
    mapping and the activity check, from `public_actors` (authoritative snapshot
    positions, never predicted render nodes).
  - `_quality_changed` propagates the combat quality preset to Moth.
  - `_ready` propagates `reduced_motion` at startup and on
    `audio_preferences_changed`.
  - `_sync_activity` now resets live Moth cues on focus/freshness loss (the
    existing `clear_round` reset is retained), so a hidden cue neither keeps
    flashing nor resumes from a stale frame.
- `godot/tests/combat_integration/support_cues.gd` (new, authored, not executed).
  Real integrated composition fixture: accepted health pickup + mender heal +
  both teleport ends spawn once at snapshot positions; no Moth explosion or
  damage spark duplicate; audio muted but visuals unaffected; quality `0` and
  reduced motion drop cues while consuming IDs and cannot replay after restore;
  fixed pool bound and round reset; immutable fixture dicts; hidden events
  dropped and unable to replay on resume.

Not changed: `weapon_effects/controller.gd` (Luna), `weapon_effects/flash.gdshader`
(shader lane), any gameplay/server source, any input node.

## Source parity (actual, inspected this commit)

- `game/view.mjs:3087` routes `teleport`/`teleporter` to `teleportEffect`, which
  emits `_mothFx('effect-teleport', ...)` at **both** ends (`3133-3147`).
- `game/view.mjs:3093` emits the heal accent for `mender-heal`, and `3095` for
  `pickup` with `kind` in `['health','megahealth']`; both are guarded by
  `!reduced`. Every Moth accent in the source is behind `!reduced`.
- `game/singleplayer.mjs:695` confirms the authoritative `mender-heal` payload:
  `{actor: mender.id, x, z, radius, healed}` with no `y`. The port therefore
  takes `x`/`z` from the event and the height from the authoritative snapshot
  actor, exactly as the existing `_present` branch already did.
- `godot/moth/generated/manifest.json` provides `effect-heal`, `effect-teleport`,
  `effect-explosion` and `spark-impact`; the module's existing
  `CAP 32` / `ID_WINDOW 4096` / `MAX_SCAN 512` bounds and prebaked sheets are
  unchanged.

## Verification

Source/actual-event tests only; no engine, import, render, server or live
authority was run.

- `node --test --test-name-pattern="mender" game/singleplayer.test.mjs` — pass
  (1/1), confirms the mender heal pulse and its emitted payload.
- `node --test game/lattice-zip.test.mjs` — pass (12/12), confirms the
  `teleport`/`teleporter` end-cue grammar.
- Integrated Godot fixture `support_cues.gd`: **authored, not executed**. It
  cannot be run here without the engine; the native grant must execute it and
  the existing registered gates. It is intentionally not added to the canonical
  `tools/godot-dev/verify.py` registry (acceptance owns that list); run it by
  path as shown in the fixture header.
- Existing non-overlap: `tests/combat_integration/contracts.gd` line 75 already
  asserts `moth_effects.slots.is_empty()` over source frames that contain only
  shot/launch/damage, so the new filter keeps it empty.
  `tests/combined_arms/graphics.gd` line 107 asserts `moth_effects.active_count()
  == 0` after shot/explosion/damage, all excluded by `support_only`.
  `tests/weapon_effects/alt_fire_capture.gd` and `tests/player_fx/marks_capture.gd`
  hide `moth_effects` and feed only non-supplemental events.

## Source vs native pending

- Source-verified here: the filter predicate, the source event grammar, the
  quality/reduced-motion propagation, the activity reset, and the fixture
  authored against the real composition API.
- Native pending (needs the engine grant, not claimed): executing
  `support_cues.gd`, confirming the Moth cues render at the snapshot positions,
  confirming quality/reduced-motion behaviour live, and GPU/visual acceptance.
- Package pin impact: none; no dependency or manifest changed.
- No source authority/health change, no new input nodes, no child agents, and K's
  native-UI source context is untouched (changes stay in the two owned effect
  files, the new fixture and this report). Keep this branch separate until K
  completes.

Commit: `e31de5d7` (code + test); this report is committed on top on
`feature/polish-flash-support-fx`.
