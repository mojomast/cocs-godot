# L4 entry-points handoff

Status: option/metadata implementation delivered; generated-route/menu integration and engine-facing verification pending. Base is `d23d02a56ba622defffc94c249a08af9b32350c6` plus accepted L1–L3 working-tree lanes and the lead-owned `endpoint.mjs` change that permits `lattice` and `lattice-world`. Source pin: `515daf07589150dd3241f4ae1425cc1b093912f5`.

## Owned changes

- `tools/godot-dev/launch_options.mjs`, `launch_options.test.mjs`: both existing IDs retain their distinct scenes. LATTICE map/mode allow-lists, 900-second default and 60..900 range, 0..16 Practice/Operations bots, PvP-only 4v4/8v8, source-owned rung fill (reject explicit `--bots` with rung), the 57 valid loadout pairs and Claude→Claude Code restriction are validated and forwarded. World supports `--native-trace`. Existing endpoint flow remains delegated to `lobbyEndpoint`; an endpoint reuses the existing service. World guest `--join-room=ROOM` requires an endpoint and rejects explicit host configuration. Unsupported/ignored generic flags are rejected.
- `tools/godot-package/options.mjs`, `options.test.mjs`: matching validation and emitted child arguments, including diagnostics/trace parity. Package test enumerates source `validLoadout` and confirms all 57 valid pairs on each route.
- `tools/godot-package/routes_meta.mjs`: kept the fixed 22 route IDs. LATTICE routes expose map, mode, 60..900 time limit (default 900), and Practice Bots 0..16 (default 2). Descriptions distinguish Practice/Operations from competitive rung hosting, which remains an in-scene setup path; no unconditional rung menu parameter is advertised.

## Exact menu/board integration request for Sol

The metadata edit makes the existing 22-route generator output stale by design; L4 did not edit generated `godot/ui/routes.json` or the consumer. Please run `node tools/godot-package/gen_routes.mjs` after reviewing the metadata and commit/integrate the generated registry with route-consumer acceptance. The schema emits every param as `--key=value`, so the selected LATTICE route currently resolves to validated CLI defaults/options.

Important seam: `godot/lattice/board.gd` currently reads `--endpoint` and initial `--map`; it does not consume launcher `--mode`, `--time-limit`, `--bots`, `--rung`, loadout, or `--join-room`. Do not claim menu selections for those parameters take effect on Board until the board consumer is integrated. Sol-owned consumer seam: parse/validate its LATTICE options and seed its setup/host/join flow from them, or reduce Board route metadata to only implemented menu params until that is available. The 22-route count/order must remain fixed. Competitive rung remains in-scene setup (no menu sentinel needed). World parses the L1 session options; `--native-trace` is world-only.

## Focused checks

- `node --test tools/godot-dev/launch_options.test.mjs tools/godot-package/options.test.mjs` — **PASS**, 20 tests. Includes dev/package equivalent argv for both IDs and each map/mode, bounds and negative matrix, endpoint guest/join behavior, source-validated 57 loadouts, and rung no-bot override.
- `node --test tools/godot-package/route_parity.test.mjs` — **6/7 pass**; generator idempotence fails because `godot/ui/routes.json` is not regenerated. This is the requested Sol-owned generated-route seam; no generated file was modified.
- `git diff --check` — **PASS**.
- Evidence class: Node option/schema tests and static route metadata only. No Godot, import, server, multi-client/full round or package build was run. No MVP-A/B/C claim.

## Diff/ownership and blockers

Only the five L4-owned implementation/test paths plus this handoff were edited for L4. Concurrent L1–L3 files, Horde/package build and lead endpoint changes were left intact. No commit made.

Remaining: Sol must regenerate and review the menu registry, integrate Board argument consumption (or keep Board menu params honest), and verify routed options in a native session after the engine marker. The optional rung selector is deliberately omitted from menu metadata; expose a UI `practice` sentinel only if the menu consumer can conditionally omit `--rung` for `cocs-coop` and ensure source host config rejects it. Existing L1 LATTICE config/session behavior and the source server remain runtime acceptance dependencies.

## Sol integration, after L4 handoff

Regenerated `godot/ui/routes.json` (22 routes); 27/27 focused option and route parity tests pass. Rejected newly parsed `--join-room`/`--rung` on unrelated routes, including early-return Horde paths, rather than silently ignoring them. Board option consumption landed in L5. The menu has no competitive rung selector; competitive hosts use explicit launcher `--rung` and eight source-validated human seats. The generated descriptions now say this rather than implying an implemented in-scene rung picker. Native runtime validation still awaits the engine slot.
