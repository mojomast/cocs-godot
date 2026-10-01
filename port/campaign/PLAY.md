# Play The Quiet Relay

Four connected single-player chapters follow a maintenance operator and ECHO's
archive signal from the forest relay to the Crown Array. Each chapter targets
**5–10 minutes**; first-time human completion times have not yet been measured.

## Start

[Download the October 1 campaign playtest (Windows / Linux)](https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-playtest-2026-10-01).
Build `614e11ad`; see release notes and `playtest-acceptance.json` for recorded
verification and known intermittent automation/startup failures.

- **Windows package:** extract the whole ZIP, then run **`Campaign.cmd`**.
- **Either platform:** open **The Quiet Relay** from Home to choose a chapter
  and difficulty.
- **Linux package** (Node ≥22.13): `node run.mjs --experience=campaign`.
- **Development checkout:** `node tools/godot-dev/launch.mjs --experience=campaign`
  with the pinned `GODOT_BIN` configured.

The chapter order is:

1. `rootfall-verge` — Rootfall Verge
2. `siltwake-crossing` — Siltwake Crossing
3. `emberline-ascent` — Emberline Ascent
4. `crown-array` — Crown Array

Add `--map=<id>` to start a specific chapter, or `--difficulty=easy` / `hard`.
The default is Rootfall Verge on normal difficulty. At a chapter's exit, choose
**Continue** to move to the next map. Continue after Crown Array resolves the
ending.

## Objectives and recovery

Use the objective text, relay marker and terrain beacons to follow the route.
Clear the guards, then reach the relay at its supported height. Interaction
objectives require a press of **Interact**; restoration requires one press and
remaining nearby until the connection completes. Hold objectives progress while
you remain inside their marker, including under enemy pressure. Completing one
also requires eliminating its guards and being inside the marker.

Checkpoints restore the current encounter after death; choose **Retry**. They
last for the current play session. Chapter selection permits returning directly
to a later chapter after closing the application. There is no campaign clock
failure. Supply/flanking routes provide additional resources and firing angles.

## People along the relay

Mara and Ivo appear along the service route with optional, proximity-triggered
story moments. Patch, their puppy, reappears across the chapters. Approach him
and press **Interact** when the pet prompt appears; he reacts to the accepted
interaction and remembers earlier pets during the campaign session. Main relay
interactions take priority if their interaction ranges overlap.

## Close-range kick and feedback

Press **F** for a melee kick. Each press makes one attempt; holding does not
repeat. The 0.3-second cooldown supports rapid tapping. A confirmed damaging hit
adds a contact smack, short shockwave and bounded collision-aware knockback.
Floating damage numbers show authoritative damage totals, including absorbed
damage, rather than an estimated change in health alone.

## Robot counterplay

- **Scrappers:** low quadrupeds close into melee; move and aim down at the body.
- **Skirmishers:** narrow bipeds pressure the flanks; watch their charge posture.
- **Sentinels:** tripod units reinforce nearby robots with shield pulses.
- **Mortars:** heavy walkers mark a ground circle before firing; leave it before
  the impact rather than relying on cover alone.
- **Bulwarks:** slab-armoured units reward a flank and focused body shots.
- **Warden:** the large guardian has phase changes and telegraphed area attacks.

Robot body hit volumes are authoritative. Thin antennae and extended decorative
limbs are not damage targets. Ground warning rings follow the authoritative
attack position, radius and timing.

Settings and Leave are available in the campaign interface. Esc releases the
mouse; click back into gameplay to capture it. Standard controls and remapping
are listed in the main README and in Settings.
