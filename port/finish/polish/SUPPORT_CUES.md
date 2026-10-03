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

Parent review of `e31de5d7`/`cebc8d33` confirmed the event filter was correct but
found a real preference gap: `set_quality(0)`/`set_reduced_motion(true)` only set
a field, so cues already on screen kept flashing.

## Change

- `godot/graphics_fx/moth_world.gd`
  - `static func support_only(event) -> bool`: the one non-overlap predicate.
    True only for `teleport`/`teleporter`, `mender-heal`, and `pickup` with
    `kind` in `health`/`megahealth`. Damage, explosions, shots and armour pickups
    are excluded.
  - `configure`/`configure_resources` unchanged; resources and existing callers
    are untouched.
  - `clear_transient()`: immediately stops every live slot (remaining `0`,
    `visible = false`, `frame_texture` released) while retaining the bounded
    reusable pool, the accepted-ID history (`seen` + sliding `id_slots` +
    `highest_id`) and the injected sheets. Counters stay monotonic, so it is not a
    round boundary. `reset()` remains the round boundary that clears IDs.
  - `set_quality(level)`: no-op when unchanged; when the new value disables
    (`quality <= 0`) it calls `clear_transient()`. Restoring does nothing, so no
    old cue resurrects.
  - `set_reduced_motion(value)`: same, hiding on enable.
- `godot/world/combat_feedback.gd`
  - `flush_effects` filters the drained fresh events through
    `MothEffects.support_only` and consumes only those, after the public-state
    mapping and the activity check, from `public_actors` (authoritative snapshot
    positions, never predicted render nodes).
  - `_quality_changed` propagates the combat quality preset to Moth.
  - `_ready` propagates `reduced_motion` at startup and on
    `audio_preferences_changed`.
  - `_sync_activity` now calls `moth_effects.clear_transient()` on
    focus/freshness loss (hide and preserve history; only `clear_round` resets
    IDs), so a hidden cue neither keeps flashing nor replays on resume.
- `godot/tests/combat_integration/support_cues.gd` (new, authored, not executed).
  Real integrated composition fixture:
  - accepted health pickup + mender heal + both teleport ends spawn once at
    snapshot positions; no Moth explosion or damage spark duplicate;
  - toggles quality and reduced motion **while four cues are live** and asserts
    `active_count() == 0`, slots hidden/unbound and still inside `CAP`;
  - after restore, the same old ID (central and direct Moth) is dropped, a new ID
    cues normally, and the monotonic `spawned` count is preserved;
  - round reset frees cues *and* the ID history, so a consumed ID is reusable;
  - hidden events are consumed and cannot replay on resume;
  - compares deep JSON of the **actual derived state** and the **actual event
    input** (not the source fixture dict), and proves `quality 0` set before
    `configure_resources` is harmless.

Not changed: `weapon_effects/controller.gd` (Luna), `weapon_effects/flash.gdshader`
(shader lane), any gameplay/server source, any input node.

## Source parity (actual, inspected at base `5b5c8791`)

- `game/view.mjs:3087` routes `teleport`/`teleporter` to `teleportEffect`, which
  emits `_mothFx('effect-teleport', ...)` at **both** ends (`3133-3147`).
- `game/view.mjs:3093` emits the heal accent for `mender-heal`, and `3095` for
  `pickup` with `kind` in `['health','megahealth']`; both are guarded by
  `!reduced`. Every Moth accent in the source is behind `!reduced`, so a
  preference that disables the cue must also stop live ones.
- `game/singleplayer.mjs:695` confirms the authoritative `mender-heal` payload:
  `{actor: mender.id, x, z, radius, healed}` with no `y`. The port takes `x`/`z`
  from the event and the height from the authoritative snapshot actor, exactly as
  the existing `_present` branch already did.
- `godot/moth/generated/manifest.json` provides `effect-heal`, `effect-teleport`,
  `effect-explosion` and `spark-impact`; the module's existing
  `CAP 32` / `ID_WINDOW 4096` / `MAX_SCAN 512` bounds and prebaked sheets are
  unchanged. Defaults (`quality = 2`, `reduced_motion = false`) keep every direct
  caller identical.

## Verification (source only; no engine, import, render, server or benchmark)

- GDScript grammar parse with the parent-requested
  `/tmp/opencode/fighting-core-grammar/bin/gdparse` on the three changed/new
  scripts — all exit 0:
  - `godot/world/combat_feedback.gd` PARSE_OK
  - `godot/graphics_fx/moth_world.gd` PARSE_OK
  - `godot/tests/combat_integration/support_cues.gd` PARSE_OK
  - This is a source grammar parse only; it is not engine execution, resource
    import, or engine type checking.
- `node --test --test-name-pattern="mender" game/singleplayer.test.mjs` — pass
  (1/1), the mender heal pulse and its emitted payload.
- `node --test game/lattice-zip.test.mjs` — pass (12/12), the
  `teleport`/`teleporter` end-cue grammar.
- Integrated Godot fixture `support_cues.gd`: **authored, not executed**. It is
  intentionally not added to the canonical `tools/godot-dev/verify.py` registry
  (acceptance owns that list); run it by path as shown in the fixture header. The
  runtime line prints `executed:true` because the file is a runnable fixture, not
  an authored-only stub.
- Existing non-overlap: `tests/combat_integration/contracts.gd` line 75 already
  asserts `moth_effects.slots.is_empty()` over source frames that contain only
  shot/launch/damage, so the new filter keeps it empty.
  `tests/combined_arms/graphics.gd` line 107 asserts `moth_effects.active_count()
  == 0` after shot/explosion/damage, all excluded by `support_only`.
  `tests/weapon_effects/alt_fire_capture.gd` and `tests/player_fx/marks_capture.gd`
  hide `moth_effects` and feed only non-supplemental events.

## Native pending (separate; not claimed)

- Executing `support_cues.gd` on the engine and confirming the Moth cues render
  at the snapshot positions.
- Confirming the live quality/reduced-motion hide behaviour and GPU/visual
  acceptance.
- No package pin impact: no dependency or manifest changed.

## Boundaries

- No source authority/health change, no new input nodes, no child agents, and no
  new feature merged into K's live scope; this branch stays separate until K
  releases.
- Prior commits stay immutable; corrections are appended.

## Commits on `feature/polish-flash-support-fx`

- `e31de5d7` feat(fx): route supplemental Moth support cues through integrated feedback
- `cebc8d33` docs(polish): report supplemental Moth support cues
- `1216527c` fix(fx): hide live Moth cues when a preference disables them
- this report update on top
