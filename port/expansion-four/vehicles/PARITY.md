# Source coordinate and collision contract

## Metres, +Y up, +Z vehicle/weapon forward

| Identity | Source W × H × L | Native wheel centres X / Z | Radius | Native turret mount |
|---|---|---|---|---|
| Puma | 2.1 × 1.7 × 3.6 | ±0.9 / ±1.18 | 0.42 | (0, 1.1, −0.95) |
| Titan | 3.0 × 2.2 × 5.4 | ±1.28 / −2.1 + i·0.6, i=0…7 | 0.37 | (0, 1.5, −0.72) |
| Scout | 1.1 × 1.3 × 2.2 | ±0.45 / ±0.75 | 0.245 | (0, 0.79, 0.04) |

Puma rolls using signed source forward velocity / 0.42, exact snapshot angle and
bounded ≤100 ms lead, with existing reduced-motion/overlay rules. Secondary
wheels keep the fleet's existing signed bounded snapshot integration divided by
their centre Y. Neither recipe nor adapter writes steering or wheel roll.

### Turret correction requiring integration review

`vehicleMuzzles` (`game/vehicles.mjs:376`) rotates each entire authored offset
about the **vehicle origin**, by heading + turretYaw, ignoring hull pitch/roll.
The existing visual turret mount is offset; simply parenting new art to it would
make the barrel mouth trace the wrong circle. Recipe geometry remains native
mount-local, but `attachment.gd::apply_source_pose` uses:

```
turret_local = inverse(hull_transform)
             * Transform(yaw(heading + turretYaw), position + yaw * mount)
```

Thus `turret_global * (source_muzzle - mount)` equals the actual source muzzle,
including hull bend. All barrels face local +Z; no unsupported aim-pitch channel
is introduced. The authored receiver rotates around the source origin, not the
historical offset gun stand. This corrects authored art only; fallback keeps its
existing presentation. Camera shot endpoints remain source-owned.

Seat metadata comes directly from `seatLayout`; those coordinates are actor feet,
not cushion centres. Seat pan height is feet +0.29 m. `vehicleSeatPosition:436`
rotates by heading only; authoritative crew rendering remains outside the mesh
adapter. Physical seat/cage clearance under full body bend needs native review.

## Neutral LOD0 bounds measured from recipe vertices

| Identity | X | Y | Z | Source world-contact radius |
|---|---|---|---|---|
| Puma | −1.05…1.05 | 0…1.625 | −1.69…1.69 | 2.0838665984 |
| Titan | −1.49…1.49 | 0…1.96 | −2.54…2.565 | 3.0886890423 |
| Scout | −0.56…0.56 | 0…1.115 | −1.085…1.085 | 1.2298373876 |

Scout inherits the current native 0.22 m tire width, putting the sidewall 1 cm
outside each 0.55 m source half-width. This is explicit; hull panels do not grow
to that extent. All neutral vertices fit the source world-contact circle.
Barrel yaw and cosmetic body roll can extend beyond the neutral OBB; no source
collider is rescaled to chase visual animation.

`game/core.mjs:361` uses a yaw-only, feet-to-height solid OBB for bullet hits;
`:400` uses half-diagonal radius for world obstruction; ramming uses the smaller
half-side circle. These are different source contracts. Open cage/crew spaces
are **not** per-triangle bullet openings; the full source OBB remains hittable
cover. The new Node oracle executes the actual private `hitVehicle` routine
extracted from the source text, testing front/rear/side faces at three headings
and above-height misses. It also checks geometry against the world-contact
circle. Existing source regressions exercise blocked movement, slope support,
ram separation/damage, mounted fire, seat release, repair heartbeat and respawn.

No runtime collision mesh is generated. This evidence does not establish native
pixel alignment, natural handling, source crew clearance under bend, or actual
Blender-export bounds; those require the queued gates.
