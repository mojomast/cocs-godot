# Verification evidence

All evidence here is authority-owned. No test changes source Match state to
manufacture live damage, kills, score, death, respawn, time or results.

## Passed

- `tests-final.log`: **17/17 Node tests passed** (also passed in
  `tests-transport-second.log`). Source construction,
  strict schema/canonical geometry hash, three-ID filesystem allowlist, bounded
  DM config and launcher aliases, FIFO/ACK semantics, ADS true/false, stale/death
  cancellation, finite event ordinals/source ID retention, bot nav/shooting,
  player weapon damage/frags, death/respawn, real-time loopback results/restart,
  transport rejection/cleanup, and HTTP readiness.
- `godot-protocol-first.log`: pinned Godot **4.5.2** decoder fixture passed with
  **zero failures** for ordinary and epoch-aware clients.
- `godot-live-synthetic-first.log`: pinned Godot **4.5.2** connected through real
  WebSockets using **both** the native epoch client and ordinary `net/client.gd`.
  Both observed source ADS press, release, stale reset; ACK 3; finite/deduplicated
  construction and gameplay events. The source arena in this test is explicitly
  a synthetic platform, not a claim about generated-map playability.

## Retained first-attempt failures and corrected test assumptions

- `tests-initial.log`: the test expected `kill`; source emits `death` with
  `killer`. Corrected the assertion; source gameplay was already scoring frags.
- `tests-transport-first.log`: authority sockets/listener closed correctly, but
  the test asserted remote-client close propagation synchronously. It now waits
  for the peer close event before asserting remote state. Other live lifecycle,
  combat/results/restart and death/respawn tests passed on this attempt.

## Identity Deathmatch route (Lacuna Court / Vermilion Fold / Nacre Engine)

All four `tests/identity-maps.mjs` gates pass against the delivered identity
envelopes: strict family schema plus canonical arena hash, three deterministic
source Deathmatches (bot movement/routing, bot shots, source damage, kills,
results and a clean restart, print markers in the test log) and one real-time
loopback authority round with results and restart. The six-map launcher smoke
passes for `prism-foundry`, `aurora-basin`, `cinder-array`, `lacuna-court`,
`vermilion-fold` and `nacre-engine`, and `geometry_composition.gd` reports
exactly one environment and one sun for every map.

`port/native-identity-dm/` holds the route/package evidence: Xvfb captures at
960x640 and 1280x800 per identity map (arena + live action, first-person rig
active, real authority), the setup menu, the consolidated `verify-report.json`
(all eight steps exit 0) and a detached Linux package built from a committed
private worktree snapshot of the delivered bytes
(`evidence/package-staging.json`). The exported PCK probe
(`res://native_arenas/package_inspect.gd`) resolves the three identity JSONs,
the identity builder and the nine source-operator GLBs, and the detached
package `run.mjs` smokes pass for all three identity maps.

## Identity/route retained failures and fixes

- The first identity delivery wrote its JSON before `map.gd` had a valid
  `Mesh.ARRAY_NORMAL` and before all referenced FX scripts existed; the
  launcher smoke failed loudly (`renderer could not load`) and was re-run after
  the art lane's delivery.
- One intermediate Nacre Engine delivery carried `movement-barrier` collider
  sources with `null` bounds and `vertexCount: 2`. The strict schema rejected
  the file; the failure was re-run after the art lane corrected the data, not
  accepted by weakening validation.
- The first identity composition environment used a nonexistent
  `ProceduralSkyMaterial.sun_energy_multiplier`; the owned smoke caught the
  script error and the property was removed.
- The real-time identity authority gate was initially configured with `easy`
  bots and produced zero-kill rounds on some seeds; it now uses `hard`
  difficulty (source-supported, still ordinary controls) so the gate asserts
  real kills without depending on luck.
- The primary-checkout `build.py` run is still blocked by uncommitted
  `godot/native_arenas/generated/*.json` and `godot/identity_maps/**` bytes
  from the geometry/art lanes. The detached package verification above uses a
  private committed worktree snapshot of those exact bytes; the release build
  must be re-run from the primary checkout once those lanes commit.

## Generated assets: separate delivery gate

- `actual-schema-first.log`: the first delivered geometry shapes validated after
  aligning explicit metadata fields and source wall-segment schema. This run
  preceded the canonical-arena hash contract and is **not final acceptance**.
- `actual-maps-first.log`: all three assets rejected because their then-current
  hash was from the previous geometry hash algorithm. The strict new requirement
  is SHA-256 of recursively key-sorted `arena` JSON only. The authority does not
  rewrite/re-hash generated files or fall back to synthetic maps.

Run `node --test port/native-arenas/tests/actual-maps.mjs` after the geometry agent
regenerates the canonical hash envelope. Run the documented Godot protocol
command with `--actual --map=<id>` for each map. These gates deliberately fail
missing or invalid delivery. The integrating lead owns the final geometry,
native visual scene, packaged-closure, source-fire/movement and product smoke
acceptance after both agents' deliveries.
