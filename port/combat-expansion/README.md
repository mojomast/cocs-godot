# Combat expansion — implementation record

Owner requests the showcase's shield and material effects in actual gameplay,
additional effects, high-density in-game particles, working aligned/animated ADS,
barrel-tip weapon presentation, and deathmatch versions of all three new maps.
The owner reports smooth million-particle performance on their own GPU; machine
measurements here remain separately labeled software-renderer evidence.

The parallel ownership/contracts are recorded in `port/handoffs/ACTIVE_LANES.md`.
Baseline: `64da4bc`. Existing published demo:
`graphics-demo-2026-09-22`; this new pass has not yet been packaged or accepted.

## Integration goals

1. Actual source ADS input and authoritative actor state, with local responsive
   animation, aligned per-weapon sights, grip poses, recoil and reload transitions.
2. Source-state shield/armor/spawn effects and source-event weapon/particle effects
   in ordinary matches, with lifecycle reset and finite pools.
3. In-match particle quality controls, up to an explicit one-million total budget.
4. Three native deathmatch variants with safe spawns, pickups, cover, connected bot
   routes, source weapons/damage/kills/respawn, results and restart.
5. Normal-rate live and native graphical review, expanded regression/resource
   checks, self-contained Windows rebuild and new release after verification.

## Architectural findings

Source `Match` has no public arena-object option, but its construction assigns
`this.arena` before deriving navigation, actors and pickups. A narrowly scoped
port-owned factory is being verified to supply validated native-arena data there.
The frozen source map registry and original nine-map contract are preserved.

Source collision supports slopes and triangle raycasts, but movement/navigation
chooses a highest floor per XZ location. A native collider dump does not create
faithful walk-under/walk-over behavior. The DM art/collision variants must close
unsupported lower routes with matching visible architecture and verify their
remaining routes with the actual source mover and bot graph.

Source primary/alternate fire already tests eye→simulation muzzle obstruction and
muzzle→target convergence. The new first-person effects must start at animated
visible barrel anchors while retaining source-confirmed impacts and collision.

## Acceptance

Implementation in progress. No new gameplay, ADS alignment, million-particle
combat performance or native-arena kill/respawn acceptance is claimed yet.
