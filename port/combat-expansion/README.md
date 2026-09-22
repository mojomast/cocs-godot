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

## Integrated ADS acceptance

`evidence/input-01/` records a normal-rate production Deathmatch session with
actual X11/XTest mouse and keyboard input and a passive snapshot observer.
All seven checks pass: authoritative RMB ADS and camera FOV response, release,
Escape cancellation with RMB held, real focus-loss cancellation, fresh input
after refocus, clean native exit, and source-confirmed local fire.
The camera starts at 75° and was observed narrowing to 67.8769° during entry;
this is an intermediate animated observation, not the final zoom target.
The lead inspected the 960×640 hip and 1280×800 ADS captures directly.

Reproduce into a fresh directory:

```sh
python3 port/combat-expansion/input_review.py --output /tmp/opencode/combat-input-review-new
```

The first-person session binding applies the rig's recommended FOV against an
immutable unzoomed baseline. Combined Arms does the same and restores it when
leaving infantry presentation. The overlay fades its hip reticle during ADS so
the exported sight geometry remains the aiming reference.

## Acceptance remaining

Native route integration `f6427dd` corrected the authority endpoint path, source
bot bounds (1–7), frag-limit configuration, and epoch-aware handshake. Prism
passed its recorded real-authority startup. Lead `evidence/cinder-live-01/` also
passes Cinder: three actors, public movement/fire, matching geometry hash and
ACK 15, with the owned listener and client cleaned up.

Aurora's first live attempt failed round-start timeout. Lead cold-construction
diagnostics at `evidence/native-construction-01/timings.json` measured 39.002 s
in Match construction versus 12.39 ms for its first step, with 948 navigation
nodes and 17,166 edges. Prism/Cinder construction measured 2.834/1.769 s in the
same run. These are development-host CPU diagnostics under current load, not
rendering benchmarks. Geometry/navigation optimization is assigned to the map
owner; the failure is retained rather than hidden by extending the timeout.

Combined effects integration, native-arena live combat, final resource checks and
package publication remain in progress. Component fixture/benchmark results are
documented in their individual reports and do not imply full-match acceptance.
The Three.js operator import proof is a newly requested parallel lane. The
separate three-map visual-identity assignment is a delivered prompt at
`port/handoffs/visual-identity-three-maps.md`, not three additional implemented maps.
