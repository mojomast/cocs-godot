# Play The Quiet Relay

Four connected single-player chapters follow a maintenance operator and ECHO's
archive signal from the forest relay to the Crown Array. Each chapter targets
**5–10 minutes**; first-time human completion times have not yet been measured.

## Start

[Download the combat-feel and multiplayer expansion playtest (Windows / Linux)](https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-feel-expansion-2026-10-01).
Build `091b1333` includes the balance, movement, weapon-feedback and F3 cheat-menu
improvements below. Both platforms passed 23 base and 44 expansion package cases.
Two earlier Windows attempts disconnected at Crown startup; the unchanged ZIP
passed the complete third run. The cause remains unresolved. Release notes and
`playtest-acceptance.json` preserve all attempts. The [earlier campaign build](https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-playtest-2026-10-01)
remains available unchanged.

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
Reach the relay at its supported height. Interaction objectives require a press
of **Interact**; rushing the console before clearing its guards disables their
shield network. You still need to finish the guards. Restoration requires one
press and remaining nearby until the connection completes; you can begin while
fighting, and dodge away without losing progress. Hold objectives progress while
you remain inside their marker, including under enemy pressure. Completing one
also requires eliminating its guards and being inside the marker.

Checkpoints restore the current encounter after death; choose **Retry**. They
last for the current play session. Chapter selection permits returning directly
to a later chapter after closing the application. There is no campaign clock
failure. Supply/flanking routes provide additional resources and firing angles.

Normal starts with **140 health / 60 armor**. After three damage-free seconds,
health recovers even while returning fire; after five seconds armor recovers to
40. Nearby robot kills restore up to 8 health / 6 armor. Easy grants more reserves
and fewer overlapping attackers; Hard tightens recovery and attack pressure.
These changes are included in build `091b1333`.

## In-game cheats

Press **F3** or release the pointer with **Esc** and click **Cheats**. Opening
the menu pauses the single-player action. Choose:

- **Invulnerability** — protects the player and restores health/armor when enabled.
- **Unlimited ammo** — refills your available weapons as you play.
- **Give all 10 weapons + ammo** — immediately grants the full arsenal.
- **Restore health and armor** — a one-time refill.
- **Fly / noclip** — WASD moves, Space rises, Ctrl descends, and Shift flies faster.
  Switching flight off lands on supported clear ground or returns to takeoff.
- **Switch off all cheats** — disables the toggles; granted weapons remain yours.

Press **F3**, **Esc**, or **Resume game** to return to play. Enabled cheats are
shown on the HUD. Toggle choices carry across campaign chapter/retry transitions
within the connected session and reset on a new connection. The same menu is
available in ordinary solo Horde launches. These controls are included in the
linked `091b1333` playtest; the older `614e11ad` package predates them.

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
- **Bulwarks:** flank their slab armor, or concentrate fire to break the guard
  for 2.2 seconds. The lowered shield shows the opening.
- **Warden:** leave its marked slam circle, then attack during the 1.6-second
  recovery window for increased damage. Later phases still allow escape time.

Robot body hit volumes are authoritative. Thin antennae and extended decorative
limbs are not damage targets. Ground warning rings follow the authoritative
attack position, radius and timing.

Settings and Leave are available in the campaign interface. Esc releases the
mouse; click back into gameplay to capture it. Standard controls and remapping
are listed in the main README and in Settings.
