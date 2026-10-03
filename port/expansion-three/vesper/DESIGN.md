# Vesper Viaduct — staged implementation

Stable ID: `vesper-viaduct`. Owner lane: `expansion-three/vesper`.

## City structure

H production adds four central mixed-use blocks, deepens the sloped row-building
footprints and supplies source-solid side counters. It retains the reviewed
bounds, terrain relief, spawn/flag/objective positions and 19-route topology.
Native art now includes articulated jambs/capitals, window reveals, stone courses,
roof trusses, counters, stair rails, clock stages and corrected facade lettering.

280 × 240 m bounds, 24 m playable relief, 70 m civic clock silhouette.
Seven through-buildings contain three connected rooms each: ticket concourse,
platform gallery, east station, west courtyard, east post office, bonded
warehouse, canal service. Thirty attached stepped row buildings enclose the
street districts. The three staggered station halls, two brick arcades and clock
tower define the skyline. This is a hillside station interchange, not a rail yard.

Three readable street types:

* **Upper boulevard (+24 m):** broad switchback approaches, charcoal tram rails,
  giant gabled train halls, actual end portals and a central cross-street portal.
* **Civic street (+12 m):** close brick/plaster facades, covered courtyard and
  post-office passages, clock square and warm sandstone signage.
* **Canal loading cut (0 m):** bonded warehouse, narrow service frontage, cobalt
  water behind physical quay rails and two supported bridges.

There are three major routes, ten inter-level crosslinks, four spawn exits and
two canal bridge routes. Crosslinks at X=-100,-32,0,32,100 provide alternatives
to the long outer boulevards. The east civic stair has 80 source-supported 150 mm
treads; its four-metre footprint replaces the upper slope. Adjacent ramp streets
remain available. The Blender script authors explicit curved tram control points,
cornices, recessed windows on sealed row buildings, chimneys, roof tiebeams,
clock face, signage and canal water.

## Authority and play

Walkable terrain rectangles have disjoint X/Z interiors. Ground is entirely absent
under the canal; the two bridges occupy separate support footprints. Roofs and
arcade ceilings are non-walkable. No rooftop route is advertised. All gameplay
walls are individual triangles. Hall windows are actual sill/mullion/lintel gaps;
no facade AABB fills a doorway or window. Stair support uses tread triangles;
adding vertical riser walls was tested and rejected because source body collision
prevents the step-up. Visual riser infill is explicitly decorative.

Team flags and spawn pools mirror across X. Each team has street and boulevard
exits; low furniture gives counterable cover off the main centerline. Three
objectives occupy west steps, clock square and east steps at the same elevation.
Health is on the canal flank, armor on the civic crosslinks, rail in the central
station gallery and rocket in the exposed canal middle. Source route checks cover
both directions, all spawn-to-square journeys and all pickup approaches.

The current candidate modes are DM, TDM, CTF, domination, KOTH and uplink. All six
have controlled source scored-round evidence. Native publication still requires
the remaining acceptance gates. No vehicle mode is requested.

## Visual direction

Warm red brick, muted terracotta plaster, charcoal rail metal, slate roofs,
cobalt canal and amber lettering. Source-authority architecture is already in
the recipe; Blender generation starts from those exact vertices rather than a
separate coarse layout. Master collections keep source walls, source surfaces,
facade detail, transit/signage and inspection cameras independently editable.

H production has real native overview/eye-level inspection imagery and measured
imported streams. Parent visual approval remains a separate gate; source test
success and mechanical native checks do not imply that approval.
