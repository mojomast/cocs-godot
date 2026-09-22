# First-person weapon detail — lead verification (`e1634d2f`)

- `tools/godot-weapons/verify.mjs`: source hashes verified, **byte-identical re-export**,
  10 weapons, 8 batches each, triangles 4,484 / 5,204 / 6,472 / 4,752 / 5,992 / 5,152 /
  5,640 / 4,828 / 5,996 / 4,448 (+9,280 detail triangles from 519 reusable primitives).
- Gates re-run by lead and green: `first_person/detail.gd` (345 checks), `ads_contract`,
  `handling`, `lifecycle`, `weapon_effects/{rig_integration,lifecycle}`,
  `combat_integration/contracts`.
- Lead inspected `evidence/sheets/contact-1280x800-hip-ads.jpg`: all ten weapons show
  distinct receiver massing, muzzle devices, feeds, sights and greeble motifs; the
  magnified optic picture is unchanged.

Disclosures accepted: weapons 2 and 8 sit above the 6,000-triangle soft target
(6,472 / 5,996) because their locked source construction is already 6,092 / 5,228 and no
source geometry was decimated; tubular ring collars re-tessellate 32→16/20 segments while
sight-assembly rings keep 32 segments so the ADS picture stays pixel-identical. No live
network session or hardware-GPU timing in this lane; rendering is llvmpipe.
