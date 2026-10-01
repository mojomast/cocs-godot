# Targeting repair, 2026-10-01

## Root causes and boundaries

* Native campaign/Horde rendered NPCs through the multiplayer 100 ms remote
  interpolation buffer, although source collision used current positions.
  `presentation.gd` now uses current snapshot position/yaw for NPCs in these two
  modes only. Humans/multiplayer still use the existing interpolation policy.
* Campaign `npcHitVolume` **was consumed**, but its dimensions described the old
  procedural fallback, not the imported Blender body. Native measurements found
  sentinel sensor top 1.395 m vs old collision 1.120 m; skirmisher solid shoulder
  x=-0.378 m vs old left edge -0.163 m; bulwark sensor 2.625 vs 2.393 m.
* New campaign volume encloses imported chassis/sensor bounds, uses body yaw and
  asymmetric offsets, and adds **0.06 m per edge**. It excludes articulated legs
  and weapon barrels. Raised bulwark shield has a separate measured slab instead
  of widening the whole torso; dropping the shield removes that slab. Confirmed
  frontal damage reduction produces an amber plate flash, and guard break retains
  the existing lowered shield/cool-core exposure presentation.
* Source bot input normalizes even small strafes to full speed; bots can strafe
  while in seek/cover/flank states too. Campaign tracking caps speed, removes
  combat sprint/jump, commits direction for 0.9–1.6 sec, then plants for
  0.35–1.1 sec. Attack windups/stagger/exposure also plant. Easy scales speed by
  .85, normal by 1, hard by 1.12. No health reduction is part of this repair.
* Source `fire()` consumes `weaponFor`, but projectile stepping reads global
  `WEAPONS` directly. The explicit generator now replaces exactly that lookup
  with an optional `projectileWeapon(r)` hook. Campaign returns player-only
  clones; enemy weapons, alt fire, global tables, gravity/splash/lifetime,
  RNG/shot cadence and frozen source remain unchanged. The generator checks SHA
  `58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`;
  inverse comparison inventories all three permitted differences: imports,
  actorHit, projectile lookup. Do not patch the generated file manually.

## Measurements

Deterministic real source bot-input + movement, flat range, 10 seconds starting
15 m from a stationary invulnerable player. Character/harness match each role;
existing campaign NPC power restrictions are retained. This measures authority,
not human enjoyment or graphics performance. Reversals count adjacent movement
directions whose dot product is negative, so includes short-range oscillation.

|Role|Peak m/s before → after|Path m before → after|Reversals before → after|Planted sec after|
|---|---:|---:|---:|---:|
|Scrapper|10.77 → 3.20|43.25 → 19.60|73 → 4|2.72|
|Skirmisher|13.38 → 3.50|45.20 → 22.39|59 → 1|3.03|
|Sentinel|5.61 → 2.10|24.30 → 12.05|48 → 1|3.25|
|Mortar|5.64 → 1.80|26.43 → 9.76|10 → 1|3.55|
|Bulwark|5.00 → 1.70|21.77 → 9.14|43 → 0|3.55|
|Warden|8.37 → 2.00|31.20 → 11.46|63 → 1|3.25|

The executable benchmark also emits 30/50 m cases. At 50 m many roles are
outside source acquisition range, so their measured movement is patrol/recovery.

|Player primary|m/s before → after|15/30/50 m travel seconds before|After|
|---|---:|---|---|
|Rocket|36 → 60|.417 / .833 / 1.389|.250 / .500 / .833|
|Plasma|46 → 138|.326 / .652 / 1.087|.109 / .217 / .362|
|Grenade|28 → 36|.536 / 1.071 / 1.786|.417 / .833 / 1.389|

Grenade times are nominal distance/speed, not gravity-arc arrival predictions.
The other seven primaries already use hitscan. Actual source per-tick travel at
60 Hz is now 1.0 / 2.3 / .6 m respectively. Native projectile presentation derives
velocity from snapshots; measured plasma visual velocity is 138 m/s, with its
existing bounded between-sample lead. It does not use an obsolete speed table.

The benchmark's deliberately unled constant-lateral-motion skirmisher task fires
20 source shots per range: pulse rifle improves 0→20 hits at 15/30/50 m; plasma
improves 0→20 at 15 m, but still 0 at 30/50 m while the target continuously moves.
Long-range plasma still needs lead or the newly available planted windows. These
numbers are a controlled latency/geometry task, not a playtest success rate.

## Collision and presentation audit

* `fire()` constructs the authoritative eye ray, checks world cover, converges
  the offset muzzle toward that ray, and checks eye→muzzle and muzzle→goal cover.
  Projectile stepping is a **point segment sweep**, not discrete overlap or a
  spherical projectile collider. `radius` is splash radius; it is not extra body
  magnetism. Faster travel retains the same world-first swept collision.
* Source ally filtering uses team equality, independently of NPC/human identity;
  both paths are tested. Player-only speed selection additionally requires id 0
  and `isNpc !== true`.
* Local camera translation already consumes source clock/velocity and has 50 ms
  bounded extrapolation; no new camera authority or client-invented hit is added.
  The parent ACK-window repair separately reduces queued-input lag.
* Horde source scalar hit volumes already contain the six imported chassis
  silhouettes at their Horde-specific scales. Native-derived samples verify this
  through untouched source fire. No Horde stats or hitScale were retuned. Horde
  benefits only from removal of the added NPC render delay.

## Reproduction / integration

```
LP_NUM_THREADS=1 godot --headless --path godot --script res://tests/campaign/targeting_geometry.gd
node --test port/native-campaign/*.test.mjs
node port/native-campaign/targeting-measure.mjs
node port/native-campaign/generate-core.mjs --check
```

The native test extracts actual imported mesh triangle-centre fixtures at y=7.5,
three yaws, standing/moving and sensor pitch ±.4. The committed JSON permits Node
fire→damage checks without an engine slot. Regenerate it with the native test if
art changes. Native checks also exercise solo/multiplayer pose isolation, plasma
visual speed, and shield flash. Existing robot contracts and the parent's native
input-flow test were run separately. Evidence (including preliminary failures)
is under `/home/mojo/.tmp-on-disk/cocs-targeting-evidence-20261001/`.

Parent closure must include `targeting.mjs` and gate the new native/Node checks.
This lane did not modify package validation, chapter recipes, HUD or progression.
Headless geometry checks do not constitute a human playtest or a Windows release
test. Thin articulated limbs/barrels are intentionally not damage surfaces;
shield windup/recoil remains cosmetic around the measured slab.
