# Botanical/urban source review — rejected pending correction

Independent reviewer: Astra `ses_efd55fd04ffedSQ6q14ztgmqaa`.
Reviewed commits: `8cff03b0`, `ddf8c70d`, `0351e1d1`, foundation `190fa2a2`.
The reviewer reproduced 18 passing Node tests using source-only probes. No Blender,
Godot, import, render or server ran. The passing tests do not establish buildability
or traversability. Following the user's escalation instruction, Astra reviewer
`ses_efd55fd04ffedSQ6q14ztgmqaa` now owns corrective implementation in a fresh
isolated worktree. Original Flash owner `ses_efdbaaa61ffesiVbXI7pmlS04Q` stopped
at `0351e1d1`, preserving one unverified partial edit to `kit_expander.py` in its
own worktree. That incomplete patch is not an accepted correction.

Paths below are relative to `tools/godot-multiplayer/new-maps/`, except the shared
Kit at `tools/map-variety-pipeline/blender_kit.py`.

## Blocking findings

1. **Compound-object placement:** `map_variety/kit_build.py:29–31,117–119`
   treats `Kit.framed_bay()` as a single object, although it returns a list of two
   jambs and creates additional unreturned objects. Placement must transform the
   entire created assembly; iterating just the returned jambs is insufficient.
2. **Invalid pipe profile:** `kit_expander.py:268–269` requests six-sided stall
   posts; the real Kit requires 8–24 sides and raises `Invalid manifold profile`.
3. **Oversized source mesh:** Helix's verdigris surface bucket has 27,504 triangles,
   exceeding the Kit's 24,000-triangle single-mesh limit before batching. Split
   authority buckets into bounded source meshes before export batching.
4. **Mixed coordinate conventions:** conversion to `(x,-z,y)` precedes compound
   handlers that still add heights to Y. A tower with source origin `[48,12,-48]`
   and height 40 produces Blender center `[48,68,12]` instead of `[48,48,32]`.
   Child offsets also ignore directive heading. Helix ridge world-space paths are
   treated as local paths. Use explicit local geometry and a single rigid transform.
5. **Incorrect box height:** `kit_expander.py:433–444` translates centered boxes
   by `min_y`, rather than the interval midpoint. Parallax's collider interval
   `[12,34]` renders as `[1,23]`. Verify emitted vertex bounds against authority.
6. **Incomplete map composition:** 5,240 Helix non-colliding art meshes, including
   clerestory panes and the new grotto pool, are omitted. Vesper clock/tram forms
   also lack handlers. Compose all supported representations, deduplicating actual
   terrain-backed geometry rather than dropping decorative categories.
7. **Covered Parallax descent:** the court floor at height 12 covers the proposed
   well floor at 8 and its descending steps. Actual support at `(34,-34)`,
   `(32,-34)` and `(28,-34)` remains 12. Cut the higher floor and construct a
   physically continuous, reachable descent with head clearance.
8. **Invalid portal probes:** recipes supply two-component directions while the
   probe reads a third component, producing NaNs and silent passes. A solid-wall
   fixture reports zero failures with `[1,0]`, six with `[1,0,0]`. Normalize valid
   2D directions and reject malformed/non-finite inputs; test blocked portals.
9. **Insufficient route/stacking checks:** proximity-based connectivity ignores
   edge blockers/support; stacking checks overwrite intended heights with highest
   support; Vesper/Parallax omit preserved-route auditing and disable congruence.
   Vesper's new roof-access step at `(31,52.5)` claims 15.5 but actual support is
   20.4 from `civic-stair-55`. Preserve intended heights and probe continuous old
   and new route edges, support, blockers, head clearance and actual entry transitions.
10. **Contradictory material contract:** `ADAPTER_CONTRACT.md` requires linear
    source albedo bytes, correct sRGB GLB output and identical source/export hashes.
    These cannot generally all hold. Preserve original provider files and record
    separate hashes for correctly encoded export images. Sol owns the adapter.

## Additional required corrections

11. **Shared curved-rib winding:** actual Kit geometry yields signed volume
    approximately −4.69894 for a semicircular rib whose expected volume is positive
    (approximately +4.71239). Sol, the exclusive R/shared-Kit owner, is assigned
    verification and correction; Flash must not concurrently edit that helper.
12. **Incomplete budgets:** counts omit evaluated bevels, compound trim and full
    scene geometry. Label source estimates honestly and enforce evaluated/export
    triangle and primitive counts, rather than merely recording intended caps.
13. **Missing review cameras:** preserved Parallax/Vesper camera definitions are
    never instantiated after scene deletion. Recreate their positions and target
    orientations with the same explicit coordinate convention.

## Positive evidence and disposition

The simple shell transform and glTF Y-up export are mutually correct. Shells use
triangle indices, and source probes found unchanged support at preserved ordinary
and team spawns and objectives. Those positives do not resolve the blockers.

**All three candidate revisions remain unmerged and unapproved for Blender
execution.** Foundry production continues independently under R. Corrective source
tests must exercise the concrete failures above; actual master/export/render and
gameplay acceptance follow independently reviewed source correction.
