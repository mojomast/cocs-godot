# Stormglass Causeway — source candidate

Stable ID: `stormglass-causeway`. Branch: `expansion-four/stormglass`.
Base: `e9d784a7`. Status: **READY FOR BLENDER**, explicit slot grant required.

## Circuit and architectural sequence

The 1,191.045 m ribbon has 21 authored direction changes, 28 m clear road width,
painted shoulders at ±11.5 m and physical edge walls at ±14 m. Start/grid approach
enters the open coastal acceleration straight. The weather terminal curves toward
the freight bore; three continuous faceted barrel-vault sectors compress the view.
The stepped quay follows with alternating workshop chicanes, surgeworks hairpin
and long return counterview toward the glazed terminal. Gates, normals, driving
line, source floor and Blender pavement all derive from the same mitred vertices.

Three districts occupy different geographic sectors:

- **Weather terminal:** sectors 0–3 and 19–20; 16/22 m bays, glazed street-edge
  panels, deep piers, sills, roof machinery and first mechanical seawall gate.
- **Freight bore:** sectors 4–6; enclosing sidewalls and a continuous ten-facet
  barrel vault, arch spring 7 m, crown 16 m, ribbed service edges.
- **Stepped quay / surgeworks:** sectors 7–18; 8/11/14 m unequal workshop blocks,
  tight alternating street edges, service roofs, counterweights and two further
  monumental angled mechanical gates. Raised gate leaves start at Y=9 m.

Candidate art: 31 street-edge building modules, 9,682 editable mesh components,
19,364 triangles, nine material batches before sign text. Blender creates an
editable collection plus material-batched GLB from precisely these meshes.
Architectural density/silhouette and sign readability require actual eye-level
review; mesh counts alone are not art acceptance.

## Source constraint: road relief is deferred

The requested 15–25 m **drivable** relief cannot honestly be supplied under frozen
race rules. `game/race.mjs:184` rejects gates above absolute Y=3; `:208` respawns
at Y=0; `:303–305` passes `()=>0` as vehicle ground. `stepVehicle` does not consume
the collision callback's Y as terrain support. This affects slopes, banking,
wheel contacts and respawns, not just cosmetic checkpoint placement.

Thus this candidate road is Y=0 with no bank/crown, no jumps and no stacked road.
The source and GLB road match exactly. Architectural relief reaches 24 m; this is
**not claimed as meeting drivable-relief acceptance**. Parent must approve this
scoping concession or separately authorize a reviewed authority change before
claiming the complete original brief. No source workaround or invisible floor.

## Vehicle envelope and authority

Actual baseline Puma: 3.6×2.1×1.7 m, world collision radius 2.08387 m; race pair
radius 1.7 m. Measured stock dynamics: 3.10 s to 19.5 m/s, 19.9704 m/s after the
additional two-second sample, 6.801 m braking distance to ≤0.5 m/s in .75 s,
full-steer sampled radius 5.87175 m at yaw rate 3.03068 rad/s. Config: acceleration
14, brake 22, speed cap 20, boost cap 26, max steer .55, grip 8.

The input fixture approaches harder corners at 8 m/s, straights at 14 m/s; stock
AI independently uses its unmodified lookahead/boost/skill controls. The 28 m
ribbon permits two chassis to pass with substantial recovery shoulders. Opposite
track segments are separated by physical triangle barriers and unsupported void.
Cosmetic ocean is below the ribbon and supplies no gameplay floor.

All authority geometry is explicit: 137 support/overhead surfaces and 440 wall
triangles. Roofs, vaults and raised gates are non-walkable. Geometry hash:
`bfb395de4ba9432e588a5ae4852ab7fbf17854caaae27aaa4225e544329e1a99`.

Only `puma-race` is a candidate. `modeBindings` stays empty pending native proof.
No infantry mode or spectator traversal is advertised. Items/pads are empty for
this baseline road acceptance; existing stock countdown/checkpoint/contact/reset/
finish rules apply exactly.

## Relevant implementation audit

- `game/race.mjs`: ordered forward swept gates, finite opening/height, checkpoint
  anchor, two-second reset lock, 20-second checkpoint timeout, first-finisher end.
- `game/vehicles.mjs:29–70,764–825`: chassis configuration and actual dynamics.
- `game/core.mjs:108,173–174,220–344,794`: floor, triangle body contact, actual
  movement, world radius and vehicle collision acceptance.
- `godot/multiplayer_worlds/map.gd`: authority triangle collision and art-only GLB;
  empty `art.ground` deliberately marks complete art coverage, avoiding duplicate
  drawn pavement/ceilings after export.
- `godot/multiplayer_worlds/sports_demo.gd`: currently hardcodes Sirocco/Copper;
  parent must extend the generator/registration before hosted Stormglass use.
- `godot/sports/guidance.gd`: expected source gate and Ahead/Behind guidance.
  Wrong-way display remains native/UI acceptance; gate reversal refusal is proven.
