# Foundry R7 promotion into the runtime world (2026-10-05)

The reviewed and fully closed Foundry R7/Y artifact is now the runtime
Gravemill Foundry art. This is a parent promotion transaction; it does not
re-run or restamp any native evidence.

## Transaction

- Commit **`e7e330ae`** on `feature/relay-campaign`.
- Reproducible helper: `tools/godot-multiplayer/new-maps/gravemill-foundry/revision7/promote_r7.mjs`
  (verifies every staged byte against the pinned Y manifest before copying).
- Promoted: `godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb` →
  `6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f`
  (15,012,592 bytes, 36 embedded images), plus the 36 extracted PNGs and 36
  sidecars renamed `gravemill-foundry-r7_*` → `gravemill-foundry_*`
  (`source_file` rewritten to the runtime paths).
- Removed: the 74 `godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7*`
  staged files. `staged_resources.mjs` now carries only R5/R6 (137 exclusions);
  the R7 entry is gone.
- Geometry identity is unchanged (`geometryHash 8ebb148f…`); no world JSON,
  route, probe or receipt was modified. No production unit receipt pins the
  Gravemill GLB, so no receipt advance was needed.

## Verification

- `staged_resources.test.mjs`: 11/11 — promoted runtime bytes match the Y
  manifest (PNG hash equality; sidecars differ only by the −6-byte path
  rewrite), the revision namespace is empty, and R5/R6 exclusions still fail
  closed.
- Full `tools/godot-package` suite: **309 pass / 1 fail**, the single failure
  being the pre-existing horde harness that needs `COCS_SOURCE_DERIVATIVE`.
  (One fewer test than before: the three R7 staged tests were consolidated
  into two promotion/remaining-exclusion tests.)
- Runtime inspection after reimport (`godot/tests/new_maps/gravemill_foundry/inspection.gd`):
  R7 art loads from the runtime path; 5,880 nodes, 109–228 draw calls,
  ~437k primitives per view, `geometryHash 8ebb148f…` unchanged.

## Follow-up surfaced

The R7 art introduces ten new embedded finish materials (`R6 / …`, `G4 / …`)
that the existing `gravemill-foundry` dressing profile does not cover, so the
runtime dressing reports `incomplete_coverage` with those ten selectors
matched by no panel/sign/mote rule (the original seven `GM / …` materials are
still covered). The dressing profile needs the new selectors added — this is
queued with the richer-dressing pass; the map still renders and races
normally, and `errors` remains empty.

## Scope

Promotion only: no new native capture, no hosted/manual acceptance, no
presentation/weather claim. R5/R6 remain staged exclusions; the earlier
staging records (`FOUNDRY_R5/R6/R7_*`) stay immutable as history.
