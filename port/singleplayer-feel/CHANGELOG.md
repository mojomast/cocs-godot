# Campaign feel pass

## Implemented

* Campaign-only role durability, decisive light-chassis hits, breakable Bulwark guard, finite stagger, weaker bounded Sentinel support, and Warden post-slam vulnerability.
* Easy/Normal/Hard differ in player reserves, crossfire tolerance, active attack lanes and recovery. NPC generic grenades/powers are replaced by readable role attacks. Normal has 140 HP / 60 armor, 3 attack lanes, and a 34-damage/300 ms overlapping-hit budget before armor.
* Health recovery allows firing; bounded close-kill salvage supports aggression. Armor's passive recovery stops at 40. Existing chapter/checkpoint resource restoration remains.
* Twenty encounters retain four chapters, but alternate compact relief fights and set pieces. Flank/rear/front placement uses checked terrain sites with deployment clearance. Restoration overlaps combat; console rushes can disable shields without skipping guards. Final transmission is a short release after the Warden.
* Campaign camera consumes simulation time and transmitted velocity, including same-arrival packets; old source snapshots cannot rewind it, and collision stops cancel horizontal coasting. Direct look and source physics remain authoritative.
* Ballistic reports gain a delayed mechanical return under existing volume/peak limits. Confirmed damage bends robot chassis proportionally; exposed Bulwarks lower their shield. Existing muzzle flashes, tracers, impacts, weapon kick/return and reduced-motion controls remain integrated.

## Measured before / after

Ideal connected primary hits, zero spread/falloff, full pellet connection, center splash. Seconds run from first hit to last; no reload, travel, shield pulse or human reaction time. Measured by `measure.mjs` using real source clamp and damage/armor/death primitives, with frozen original enemy profiles for baseline. **These are balance envelopes, not observed human TTK.**

| Target | Weapon | Shots before → after | Seconds before → after |
|---|---|---:|---:|
| Scrapper | Pulse | 3 → 3 | .20 → .20 |
| Scrapper | Rail | 2 → 1 | 1.20 → 0 |
| Skirmisher | Pulse | 7 → 4 | .60 → .30 |
| Skirmisher | Rail | 2 → 1 | 1.20 → 0 |
| Skirmisher | Scatter | 2 → 1 | .78 → 0 |
| Sentinel | Pulse | 18 → 9 | 1.70 → .80 |
| Sentinel | Rail | 3 → 2 | 2.40 → 1.20 |
| Mortar | Pulse | 8 → 5 | .70 → .40 |
| Mortar | Rail | 2 → 1 | 1.20 → 0 |
| Bulwark front | Pulse | 96 → 15 | 9.50 → 1.40 |
| Bulwark rear | Pulse | 21 → 8 | 2.00 → .70 |
| Bulwark front | Rail | 13 → 3 | 14.40 → 2.40 |
| Bulwark rear | Rail | 3 → 1 | 2.40 → 0 |
| Bulwark front | Scatter | 16 → 3 | 11.70 → 1.56 |
| Warden | Pulse | 51 → 37 | 5.00 → 3.60 |
| Warden | Rail | 7 → 5 | 7.20 → 4.80 |

All **140 rows** (ten weapons × seven role/facing cases × two variants) are reproducible with `node port/singleplayer-feel/measure.mjs`. Raw run: `/home/mojo/.tmp-on-disk/cocs-singleplayer-feel-evidence-20261001/balance.json`.

Authored critical paths: Rootfall 1,010 m, Siltwake 1,208 m, Emberline 1,383 m, Crown 1,360 m. Unopposed traversal-only lower bounds at 8.6 m/s: **117 / 140 / 161 / 158 seconds**. Combat, exploration, supplies and conversations add time; the **300–600 second chapter target remains unvalidated by humans**. Route geometry is not shortened in this pass; fewer compulsory post-clear waits and relief encounters target pacing instead.

## Acceptance status

Node authority/campaign/provenance/feel suite: **41/41 passing**, including the final proportional boss-warning adjustment. Engine motion, presentation and live campaign acceptance await the exclusive slot. No claim of subjective fun or native visual acceptance is made from Node tests alone.
