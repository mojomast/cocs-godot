# Combined playtest — pending verification and packaging

This is the draft change inventory for the next Windows/Linux playtest. Public
runtime `091b1333` remains available; this document does not announce a new build.

## Targeting and combat responsiveness

- Match campaign robot hit regions to imported bodies, with 6cm edge allowance,
  yaw-aware geometry and a separate raised shield surface.
- Remove the added 100ms solo-NPC display buffer; use current snapshot poses.
- Slower, more deliberate role-specific enemy motion, committed directions and
  planted attack windows. No further enemy-health reduction in this pass.
- Player plasma 46→138m/s, rocket 36→60m/s, grenade 28→36m/s; preserve arcs,
  splash, cooldowns and source swept collision.
- Bound campaign input admission by source acknowledgements. A traced Crown
  disconnect came from a full input FIFO, not an outgoing socket buffer.

## Eight optional service-route activities

Rootfall nursery/canopy receiver, Siltwake waterwheel/ferry salvage, Emberline
condenser/field forge and Crown signal choir/beacon garden. Reconnect machinery,
align receivers or choose resources, with visible restoration and once-only
rewards. All are skippable. Includes 24 approach/link routes and 34 shared solids.

## Animation and physics-informed presentation

Contact-aware operator and six-role robot gait, bounded shallow-ground foot
adjustment, smoother start/stop/airborne/landing transitions and action handling.
Mara/Ivo gestures transition continuously; Patch has quiet planted idle paws and
improved walk/sit/pet blending. Exact damped springs drive restrained weapon
inertia, recoil return and landing response. Workshop machinery spins up and
restores gradually; vehicle wheels render continuously with bounded lead.

These are cosmetic physics-informed systems driven by source state, not an
active-ragdoll replacement for the authoritative movement controller.

## Edge detection, round marks and shader effects

Campaign weapon rays intersect actual facade triangles rather than enclosing
boxes that filled visible gaps near building sides and pitched roofs. Shots
blocked at the muzzle report a surface contact; short close-cover cues now show.
Radial dust removes the square card around bullet marks. Same-plane footprint
checks, depth/backface handling and transparent corners keep impacts on surfaces.

New production shaders: material impact bursts, soft weapon trails, energy
discharges and authored beacon/conduit surfaces. Rocket/plasma/grenade blasts
have distinct bounded effects. Existing quality and reduced-motion controls apply.

## Evidence and remaining acceptance

Lane source/native/render tests and the animation real-wire scripted journey
passed. Parent combined canonical, fresh exports and extracted Windows/Linux
verification are required before publishing. Existing failures/evidence stay
preserved. Source movement still uses conservative campaign structure bounds;
weapon cover is more precise. Tiny bevel contacts may omit a scar. Human chapter
timing, subjective play feel and hardware performance are not established by
software-rendered fixtures. Full Blackwater chain/Warden acceptance remains open.
