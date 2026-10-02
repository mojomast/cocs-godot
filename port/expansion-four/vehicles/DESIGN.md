# Fleet presentation — READY FOR BLENDER

Worktree: `cocs-expansion-four-vehicles-20261002`, branch `expansion-four/vehicles`.
Base: `e9d784a7`. No nested agents; Parallax retains the exclusive heavy slot.

## Audited scope

`game/vehicles.mjs` declares Puma, Hornet, Titan, Scout and Transport. The native
`godot/combined_arms/fleet.gd` instantiates those identities, with Puma delegated
to `godot/vehicles/renderer.gd`. `game/view.mjs` contains both historical additive
kits and current specialized models; those comments are not grounds for inventing
new fleet types. This lane authors **Puma, Titan and Scout**.

- **Puma:** open four-seat utility chassis, independent four-wheel assemblies,
  twin wide source gun mouths, tubular cage, cowl, service deck and fender arches.
- **Titan:** wide long siege hull, sixteen existing road-wheel pivots, stationary
  track belts/shoes, skirt segments, glacis, hatch/periscope and single cannon.
- **Scout:** narrow short two-seat recon chassis, compact cage and single light
  receiver. No invented passenger gunner seat, mast weapon or steering channel.

Recipe anatomy includes chamfered panel extrusions, chassis rails/crossmembers,
open wheel arches, wishbones and telescoping strut components, rubber tire annuli,
rims/hubs/bolts, seat pans/backs/harnesses, steering column/rim, loader boxes,
hollow barrels/collars/cooling jackets/grips, engine louvers, hollow exhaust,
tow eyes, lamps and unit-stencil strips. Suspension components are static rigid
anatomy: source body pitch/roll is the available suspension presentation; no
individual suspension simulation or suspension packet is invented.

## Deliverable format

`tools/godot-vehicle-assets/recipe.mjs` is the deterministic authoring recipe,
importing current source identities and seats/muzzles/dimensions. `write-recipes.mjs`
serializes nine JSON inputs. `build.py` consumes explicit meshes in Blender,
assigns eight named PBR materials, adds small real bevels at LOD0, consolidates
each rigid attachment, saves editable **assembled** masters outside `godot/`,
and exports one GLB per identity/LOD. Source seat/muzzle arrows are present in
masters for inspection. No GLB or `.blend` has been produced at this checkpoint.

The adapter attaches body/turret/wheel meshes in joint-local coordinates to the
existing native nodes. LOD ranges are 0–24, 24–65 and 65+ metres. Recipe triangles
are bounded separately from Blender evaluated triangles; export rejects budgets
above 100k/36k/16k. These are ceilings, not measured rendered budgets or quality
acceptance. Eight base materials per vehicle are shared across its LODs; actual
surface/draw counts, shadows and LOD transition inspection remain queued.

## Source ownership and compatibility

Root remains `Node3D`. No collision object, rigid body, source rule, authority,
weapon, camera, carrier-stow or crew-seat code is added. Existing procedural art
is hidden only after every LOD and attachment name validates. If any GLB is
absent/incomplete, the procedural assembly remains visible. The native fixture
will execute both missing-assets and generated-assets acceptance after grant.

Per-vehicle StandardMaterial3D clones preserve roughness/metallic and weather
texture/channel ownership. Team tint updates both retained dry bases and active
weather clones, avoiding stale team colors when wetness is cleared. Tint comes
from the existing driver's public team; unoccupied vehicles use neutral paint.
No local damage/repair state is fabricated. Existing source-position event
effects, hull disappearance at destruction and source respawn remain in charge.

## Shared hooks (separate integration commit)

1. Puma/chassis constructor: attempt optional attachment after procedural build.
2. Puma team setter: forward its established color to the authored material.
3. Renderer/fleet snapshot application: apply authored turret source transform;
   fleet also resolves the public driver's team for authored secondary vehicles.

No shared catalog, package manifest or global project setting is edited. Parent
must review the turret adapter and integrate with active shared-renderer work.
