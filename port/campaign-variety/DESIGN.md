# Quiet Relay: inhabited service routes

Eight optional, source-authoritative workshops turn two transit legs per chapter into places the player can affect. Combat objectives still determine campaign progression. There are no optional completion requirements, timers, precision jumps, moving collision surfaces, or new enemy waves.

## Bounded research actually consulted (2026-10-01)

* **Michael Booth, Valve, _Replayable Cooperative Game Design: Left 4 Dead_, GDC 2009.** Read the [full 71-slide developer deck](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf), not a talk transcript. Slides 36–40 distinguish exhausting constant combat from boring inactivity and describe peaks/relaxation; slide 65 explains designer-placed supplies as visual storytelling/intention. Applied: preserve combat-free transit, but offer a small action and a useful cache in an identifiable workplace. L4D's 30–45-second Director interval is **not** imported as a universal campaign pacing rule.
* **Christopher Dionne, Respawn, _Designing Unforgettable Titanfall Single Player Levels with Action Blocks_, GDC 2018.** Consulted the [developer session abstract](https://www.gdcvault.com/play/1025105/Designing-Unforgettable-Titanfall-Single-Player), not the full video/transcript. It identifies familiar production methods producing familiar results, and action blocks as rapid gameplay prototypes, discussing _Into the Abyss_. Applied: prototype bounded, distinct interaction families with real controls before embellishing them. No claim that the abstract specifies an _Effect and Cause_ recipe.
* **Harvey Smith / Matthias Worch, _What Happened Here? Environmental Storytelling_, GDC 2010.** Consulted the [developer session abstract](https://www.gdcvault.com/play/1012647/What-Happened-Here-Environmental), not the full talk. It explicitly connects interpreting spaces, props/composition, environmental reaction and agency. Applied: a dry nursery, stranded evacuation stores and a silent civilian receiver visibly react to the player; their short acknowledgement follows the action rather than substituting for it.

## Authored content

| Chapter / beat | Placement | Player action and payoff | Physical identity |
|---|---|---|---|
| Rootfall / Mara's seed nursery | After fight 1 | Connect the battery; follow copper cable; start irrigation. +35 armor. | Walk-in forest bench, three unequal relay ribs, grounded seed-bed base, fallen relay backdrop, spinning sprinkler. |
| Rootfall / Ivo's canopy receiver | After fight 3 | At the sighting control, face the gold receiver and press E. Loaded scattergun and carried-ammo refill. | Receiver station below broken forest relay architecture, gold sighting ring and illuminated cable. |
| Siltwake / sleeping waterwheel | After fight 2, at the first river crossing | Prime pump; follow pipe; engage wheel. Loaded scattergun and refill. | Broad dry service apron, relocated bridge abutments, tall wheel house and visibly rotating eight-spoke wheel. |
| Siltwake / abandoned ferry berth | After fight 3 | Spend the sole ferry battery on plating **or** ammunition; the other allocation is exhausted. | Two separated service racks, low berth sides, pump-house silhouette. |
| Emberline / cold condenser | After fight 1 | Couple return, traverse around condenser and vent it. +35 armor. | Four unequal cooling fins, foreground valve bed and three vent stacks. |
| Emberline / Ivo's field forge | After fight 3 | Choose plating press **or** scattergun/ammunition die. | Broad walk-in forge apron and graded foundry fins; chosen rack tilts open. |
| Crown / silent signal choir | After fight 1 | Face the gold choir receiver from the sighting control and lock the civilian band. Scattergun/refill. | Five piers forming a rising arc, high dish and rotating signal wheel. |
| Crown / Patch's beacon garden | After fight 2 | Connect cell and illuminate homeward beacons. +35 armor. | Garden shoulder beneath an arc of piers; seed trays, illuminated panels and full live cable. |

Three mechanical families: **spatial two-end reconnection**, **mutually exclusive resource allocation**, and **azimuth alignment with a visible receiver**. Alignment has a forgiving ~15-degree horizontal cone; it does not require precise pitch or weapon fire. Connecting a first terminal survives departure and retry. There are no wrong-answer penalties.

## Geometry and presentation contract

`interlude-definitions.mjs` authors chapter, route segment, local terminal placement, family, names and rewards. The campaign compiler makes six new reviewed routes per chapter (A approach, B approach and connecting cable per workshop), blends small walkable side benches, excludes scenery from the work areas and adds **34 grounded solid blocks** across the campaign. Existing Blender structure facades fit those authoritative blocks. All four geometry hashes change; source and native use the same static terrain/block recipe. Original `.blend` masters remain intact.

`interlude_director.gd` consumes the snapshots. Visible changes include half/full energized cables, control lamps, tilted allocation rack lids, lit machine panels, spinning wheel/receiver/sprinkler ornaments and restored signs. Ornaments carry no collision and sit above solid authored machinery bases. No bridge is promised or visually faked as a new support surface.

Workshop signs/actions are short-range world labels (23m). One nearby prompt uses the existing story widget; there is no optional waypoint list or checklist. A five-second result shares the existing caption slot. Main mission E has priority, then Patch, then workshop. Optional interaction is suspended while an encounter is deployed.

## Authority / lifetime

`interludes.mjs` owns state, rewards and events. A fresh E requires a preceding release, including after a retry. It checks live player, horizontal and vertical proximity, actual source support height, obstruction and visibility. Alignment uses the authoritative actor yaw. No client supplies a target id, stage, reward or position.

The only `match.mjs` hooks are import/construction, one progression update, `campaignCheckpoint().interludeCarry`, and `campaign.interludes`. No fire, aiming, enemy, damage, bot-input or spawn methods are changed. The generated core and frozen game/server/assets trees are untouched.

Each completed beat rewards once. Retry preserves partial links, completed claims and the resource choice; spent rewards do not re-grant on retry. Existing campaign retry recreates the standard combat loadout, so a previously used reward is not an inventory checkpoint. An explicit chapter restart resets that chapter's optional work, consistent with restarting its combat. Continuing to a new map constructs that map's independent workshops.

## Quantified transit, without a human-duration claim

`tools/godot-campaign/interlude-metrics.mjs f426e755` compares committed pre-change geometry with current recipes. It measures reviewed path arclength; transit ends approximately 36 route metres before the next encounter center (actual triggering uses Euclidean proximity). Completed combat is conservatively measured from its center. It does not pretend to measure human perception, combat duration, or speedrun time.

| Chapter | Ordered road before → after | Largest uninterrupted between-fight arc before → after, when stopping at workshops |
|---|---:|---:|
| Rootfall | 1010.02 → 1010.02m | 194.15 → 178.53m |
| Siltwake | 1207.95 → 1207.95m | 261.85 → 232.05m |
| Emberline | 1383.47 → 1383.47m | 297.12 → 271.96m |
| Crown | 1360.41 → 1360.41m | 290.64 → 225.02m |

The largest remaining values include untreated legs; eight activities do not eliminate every long stretch. Each optional loop is 50.38–52.23m and adds 9.59–13.48m relative to its bypass. At an assumed 8m/s, the entire loop is 6.30–6.53 seconds of walking, excluding looking, deciding and E presses. The intended 10–20-second micro-choice is a design target, **not a measured human result**. Skipping every workshop retains the existing mandatory road and all 20 encounters.
