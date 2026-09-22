# Cinder guard-rail trap fix (trap-fix lane, follow-up to `bdfa4203`)

Lead task: remove the Cinder seed-20260922 landed locks (97.5 s / 22 s / 16.25 s
windows reported in `REPORT.md` §7), keep every gate green, and land before the
release build. Reproduce first, then fix; stop and report if a lock cannot be
removed without breaking routes/parity.

## 1. Reproduction and exact geometry

`node port/native-arena-trap-fix/trap-audit.mjs --map=cinder-array --seed=20260922`
on the accepted revision (`2d5e5cfa…`) reproduced three landed locks:

| # | Window | Site | Floor | Blocking band |
| --- | --- | --- | --- | --- |
| 1 | t=78.75–176.25 (97.5 s) | (-14.68, -31.91) | 12.71 | RimAscent causeway guard rail, band y=[12.62, 14.20] |
| 2 | t=19.75–41.75 (22 s) | (-17.67, -26.45) | 14.77 | same rail class, band y=[14.46, 16.36] |
| 3 | t=22.25–38.5 (16.25 s) | (19.4, -2.78) | 12.00 | `ReactorServiceCover` side, band y=[12, 14] |

Attribution: `port/native-arena-trap-fix/diagnose-cinder-sites.mjs` maps each
blocking movement band to its source collider through the compiler's
`NATIVE_DM_WALL_SOURCES` debug dump. Sites 1–2 are the base map's thin
(0.19 m) 1.28 m safety walls (`WalkableCollision/@CollisionShape3D@1622/1624`);
site 3 is this lane's own 2 m service cover.

All three are the same mechanism as the original prism defect: source
`moveActor` refuses every axis step while the destination is inside the 0.42 m
contact band, and the bot's stuck handler only re-routes (it does not jump), so
a landing inside the band is immobile for as long as its re-routes keep pushing
into it. The fix therefore has to remove the band from walkable ground, not
just lower it: measurements with trimmed bands still produced 5.75 s windows
because the bot bounced without ever taking a one-hop escape.

## 2. Authored change

1. **Cinder guard rails carry a walkable cap** (`cinder-array.gd::_rail` sets
   `dm_walkable` on each newly created safety-wall collision shape, the same
   adaptation Prism and Aurora already use). The compiler's capped-short-barrier
   rule then drops the rail's movement band: walking across the rail is refused
   by the source step limit (the 1.28 m cap is the destination floor), the
   visible panels and full ray/projectile collision are unchanged, and an actor
   that lands beside or on a rail is never inside a movement band.
2. **The five `ReactorServiceCover` boxes carry a walkable cap** (`DM.box(...,
   true)`), so their bands drop the same way, walking into them stays refused
   by the step limit, and a fall onto a cover lands on its visible top instead
   of the footprint support hole a non-walkable solid leaves in the deck.
3. **Compiler: low thin guard bands become jump-clearable** (`compile.mjs`).
   A band whose source collider is thin (footprint width ≤ 0.6 m) and whose top
   is 0.45–1.55 m above the higher adjacent support is trimmed to that support
   + 0.35 m: walkers are still refused (their body spans the band) while a
   single hop clears it, so no landing inside such a band is unrecoverable.
   Thick cover volumes are excluded so a jump can never enter their footprint.
4. **Compiler: burial tolerance 0.3 → 0.45** so obstacles a hair above the
   source 30 cm step limit (e.g. the 0.31–0.52 m lips the audit hit at
   (-4.03, -27.48)) are dropped instead of being refused pockets.
5. **Cinder opts into the source spatial navigation** (`nextGen: true` in
   `compile.mjs`, matching Aurora). The walkable rail caps would otherwise bake
   as isolated nav islands (measured: 16 disconnected cap nodes, which fails
   the delivery gate). The source builder's `pruneToLargestComponent` removes
   exactly those unreachable islands; the authored route nodes stay dense, so
   route coverage, bot-usable node counts and spawn/pickup legality are
   unchanged. This is a navigation-mode switch, not a mover change, and it is
   reported here explicitly for re-acceptance.

## 3. Verification (all after the fix)

Trap audit (1 human + 7 bots, 180 s per run; landed-lock detector = immobile
> 1.5 s while refused at r = 0.42 and standing):

| Map | Seeds | Landed locks | Reviewer-detector inside windows |
| --- | --- | ---: | ---: |
| cinder-array | 20260922, 777, 424242, 11 | **0** | seed 20260922 max 1.5 s (the bar); one 3.5 s bouncing window at seed 777 (§5) |
| prism-foundry | 20260922, 777, 424242 | **0** | 0 |
| aurora-basin | 20260922, 777 | **0** | 0 |

Rounds ran to time/sudden-death with kills, deaths, respawns, pickups, results
and a clean 30 s restart on every seed (`logs/trap-audit-*.json`,
`logs/audit-045-*.out`).

Gates:

- `rebuild.mjs --check-determinism` exit 0, byte-identical hashes.
- `node --test port/native-arenas/tests/actual-maps.mjs` 3/3.
- `tools/godot-native-arenas/movers.mjs` all routes finished, 0 errors.
- `tools/godot-native-arenas/verify.mjs` all parity checks (floors/rays,
  sealed volumes, nav connectivity 234/234 cinder, spawns, pickups, routes).
- `port/native-arena-review/trap-min.mjs` unchanged: trap spot free at
  r = 0.06/0.42, escape in three directions and by jump.
- Launcher smoke `--experience=native-dm --map=<id> --smoke` 3/3
  `NATIVE_DM_SMOKE_OK` with the new hashes.
- Evidence refreshed for all three maps (asserted dimensions, llvmpipe/Xvfb
  labels); the previous accepted set is archived under
  `port/native-arena-geometry/evidence/final/history-bdfa4203/`.

## 4. New geometry hashes (report for re-acceptance)

| Map | Accepted `bdfa4203` | Delivered now |
| --- | --- | --- |
| prism-foundry | `1901d0aed12c…` | `c727d8ca82f761c710af0c535c8502ccfbbaed2299ace1f9923cb74e3b3e9c13` |
| aurora-basin | `8457812f7845…` | `94f1c30664dfcf058c005a7aa2dea296e8528b1acf772b4f04e66421d243382d` |
| cinder-array | `2d5e5cfa4453…` | `f372c98c4172b7885218748031c9eed7f7a087dc9f347491ac04bb558ac10cca` |

Band counts: prism 590→580, aurora 4849→4842, cinder 848→138 walls.
Cinder navigation: one connected component, 234/234 bot-usable nodes.

## 5. Residuals / still unproven

- **Bore causeway lip at (-3.87, -27.5).** A 0.31–0.52 m movement band on the
  bore's north edge remains (dropping it would open a fall-through hole into
  the sealed bore, whose non-walkable footprint carries no support). It is a
  one-hop escape (the jump apex clears the band top by ≈1 m) and my
  landed-lock detector reports zero at every seed; the reviewer's
  duration-only detector still records one 3.5 s bouncing window at seed 777
  (`maxRadius 0.04`). This is the only residual window above their 0.5 s
  threshold, and it is not a landed lock.
- **Navigation mode switch for Cinder** is reported for lead re-acceptance
  (§2.5): it changes `nextGen` from false to true, with Aurora as the
  precedent. Aurora's spatial navigation already required this flag; the
  isolated-cap problem it solves is a direct consequence of the walkable-cap
  trap fix.
- This set of measurements is Linux GL Compatibility/llvmpipe, not
  Windows/GPU.
