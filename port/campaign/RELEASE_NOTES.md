# The Quiet Relay — four-level campaign preview

A connected single-player campaign in the Canopy Divide / Basalt Reach visual
family. Follow ECHO's archive signal, restore the power corridor, confront the
quarantine guardian and broadcast the repair key.

| Chapter | Setting | Playfield | Authored route |
|---|---|---:|---:|
| Rootfall Verge | Wooded ravine and fallen relay | 320 × 224 m | 1,009.5 m |
| Siltwake Crossing | Riverbanks, causeways and pump works | 352 × 256 m | 1,207.7 m |
| Emberline Ascent | Terraced basalt service cuts | 384 × 256 m | 1,382.6 m |
| Crown Array | Nested service courts and guardian receiver | 416 × 288 m | 1,360.1 m |

The playfields are roughly **9–16× the area** of either original biome arena.
Each chapter targets **5–10 minutes** through traversal, combat and objectives;
human first-playthrough timing and balance remain to be measured.

## Included

- **20 authored encounters**, quiet travel between them, flank/supply routes and
  chapter-to-chapter story continuity.
- **Six articulated robot models:** Scrapper, Skirmisher, Sentinel, Mortar,
  Bulwark and the Quarantine Warden. Distinct silhouettes, source-driven attack
  tells, three distance-detail levels and bounded body hit volumes.
- Blender-authored enemy armor and mechanical assemblies, with beveled panels,
  exposed joints, vents, class-specific sensors and editable source models.
- Clear, interact, restore, contested relay-hold and guardian objectives.
- Checkpoint retry, chapter restart, difficulty selection, Continue transitions
  and a final ending.
- Terrain-following danger rings tied to authoritative mortar/boss attack state.
- Varied biome terrain: wooded shoulders, layered canyon benches, basalt shelves
  and highland plateaus, with irregular crestlines and selective crags.
- Persistent chapter daylight through briefing, gameplay, retries and results.
- Recurring maintenance operators Mara and Ivo, sixteen optional story beats,
  and Patch, a puppy you can meet and pet across the corridor.
- Textured operator armor panels, vents and circuit-board insets.
- Fresh-press melee kicks with a short cooldown, collision-aware knockback,
  a swoosh on the swing and a smack/shockwave on confirmed damage.
- Animated authoritative damage numbers and six distinct synthetic robot voices.
- The original **Relay / Warden** orchestral score, with synchronized adaptive
  exploration, combat and guardian layers.
- Research notes and implementation documentation in `port/campaign/`.
- A live in-engine scripted 3D demo behind the usable main menu, with an animation
  toggle and focus/overlay pausing. Story operators use finite, settling gestures.

## Launch

**Windows:** extract the entire ZIP and run **`Campaign.cmd`**. Godot and Node
are bundled. Home also offers **The Quiet Relay** with chapter/difficulty choices.

**Linux:** extract the archive, then run:

```sh
node run.mjs --experience=campaign --map=rootfall-verge --difficulty=normal
```

Linux requires Node ≥22.13. The other chapter IDs are `siltwake-crossing`,
`emberline-ascent` and `crown-array`. Difficulty may be `easy`, `normal` or `hard`.

WASD/mouse move and aim; LMB fires; **E** interacts. Restoration needs one press
and staying nearby. Near Patch, **E** pets him when the prompt appears. **F** kicks;
tap for each attempt, with a 0.3-second cooldown. **Enter** retries after death or
continues after a chapter.
Checkpoints last for the current session; chapter selection lets you return to
a later level after closing the game.

## Acceptance scope

Automated movement, progression, rendering and package checks are recorded in
the accompanying release acceptance record. Scripted screenshots are labelled
as fixtures. Human playtime, difficulty balance, physical feel, listening and
real-GPU performance are separate playtest work; software-rendered captures do
not establish hardware frame rates.
