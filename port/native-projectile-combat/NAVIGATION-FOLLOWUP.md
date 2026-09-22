# Deathmatch pickup route follow-up

The lead's independent Rocket Arena runs passed all three maps. Its subsequent
Deathmatch pickup approach failed before launch. The failure is retained at
`/tmp/opencode/projectile-independent/meridian-exchange-deathmatch.log`; the
original source-agent `evidence/` is also preserved.

## Cause and correction

The borrowed box-only planner returned this route from the authored `[8,34]`
spawn:

```text
[10,24] -> [10,14] -> [8,-6] -> [6,-14] -> [0,-18] -> [-14,-19]
```

Its third segment enters Meridian's raised causeway through its side. Read-only
source queries show:

- `floorAt(8,5.1) == 0`;
- `floorAt(8,4.9) == 0.9`;
- `obstructed(8,0,4.9,0.52) == false`;
- `walkEdge` between those nearby points is **false**.

Source `moveActor` rejects upward floor discontinuities of 0.3 m or more. The
lead's focused/captured actor therefore correctly stopped at about `[8,5.008]`.
This was a navigation-fixture error, not a rocket or input failure.

The new local `route.mjs` queries the unchanged source `floorAt`, `obstructed`,
and `walkEdge`. It restricts this acceptance approach to zero-height supported
ground with 1.2 m body/steering clearance, rather than trying to traverse ramps
or stacked surfaces. It checks both graph edges and smoothed segments. The
grid has a 16,000-cell bound and routes a 128-waypoint bound. A spawn already
overlapping a non-goal supply may leave that unavoidable initial overlap.

The corrected `[8,34]` route is:

```text
[16,9] -> [16,-7] -> [6,-7] -> [6,-15] -> [1,-18] -> [-14,-19]
```

All authored spawn routes are precomputed before starting the private server,
so that work does not pause its normal-rate timer. No spawn, actor, source map,
simulation state, physics, or rules are changed, and no spawn reroll is used.

Native steering uses the real mouse-look and movement keys at 20 Hz. It applies
the ordinary crouch key within 3 m of a turn: source movement tests exposed
inertial orbiting around tight waypoints at full speed, which this bounded
approach slowdown resolves. After collecting the real rocket supply, physical
1 then 2 key presses must receive authoritative Pulse/Rocket selection
acknowledgements before the 14-second fire interval. The runner also checks the
source's actual `weapon-switch` request events `[0,1]`.

## Focused verification

```sh
node --test port/native-projectile-combat/route.test.mjs
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  node port/native-projectile-combat/run.mjs --case=deathmatch \
  --output=/tmp/opencode/projectile-deathmatch-navigation-review
```

`--case` accepts `deathmatch`, `rockets`, or `all` (default). `--output` uses the
same one-line implementation as the lead's pending runner change. `smoke.mjs`
is not changed by this follow-up.

**12 route tests passed**, including reproduction of the actual causeway-side
stop and all ten authored Meridian spawns. Each new route is independently
audited with denser source support/collision queries, then followed by the
unchanged source `moveActor` at speeds **6, 8.6, and 10**, at 60 Hz with 20 Hz
steering and a two-tick-old observed position. All 30 synthetic movement
approaches reach the real pickup radius within their bound. These are synthetic
geometry/movement fixtures, separate from the graphical source-server run.

### Actual normal-rate native result

The **first live follow-up attempt** passed and happened to receive the exact
reported failing spawn, **`[8,0,34]`**, from the source. There was no retry or
spawn selection. See the new, separate
[`evidence-navigation-20260921/summary.json`](evidence-navigation-20260921/summary.json).

- Real rocket pickups: **1**; authoritative requested weapon switches: **`[0,1]`**.
- Local launch events: **12**, matching native combat counters; ordinary shots:
  **0**; explosion events: **10**.
- Actual projectile snapshot/mesh samples: **1,382**; peak flight meshes: **5**.
- Native input ACK: **1,447**; fire interval: **14.005 seconds**, **823 frames**.
- The [inspected screenshot](evidence-navigation-20260921/meridian-exchange-deathmatch.png)
  shows the actual in-flight rocket at roughly **672,420**, 3.58 units ahead,
  and finite Rocket Launcher ammo **5** in the real session HUD.
- Source hashes match the verified files. The final log has no script errors,
  engine errors, or leaked-object warning; only the known software-GL V-Sync
  warning. All owned children were reaped, authority closed, and sockets drained
  to zero. Full trace completion remains explicitly unproven.

The follow-up changes only this `port/native-projectile-combat/` directory.
