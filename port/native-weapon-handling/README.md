# Native weapon handling (first-person)

Pre-release FX lane on `port/godot-destinations`. Scope: authored handling
anchors, carrier/charging/magazine animation and barrel heat for the ten source
weapons, presentation only. Owned paths: `godot/first_person/**`,
`tools/godot-weapons/**`, `godot/tests/first_person/**`,
`port/native-weapon-handling/**`.

## Delivered

- **Authored anchors in the existing exporter** (`tools/godot-weapons/export.mjs`
  + `tools/godot-weapons/handling.mjs`), rebased into the same moving assemblies
  the source `game/weapon-models/*.mjs` builders author:
  - `Bolt` and `Charging` — children of the reciprocating `bolt` group
    (carrier and charging paddle), all ten weapons;
  - `Ejection` — casing port on the receiver, weapons whose mechanism has one
    (0, 2, 3, 4, 5, 7, 8, 9); the existing weapon-effects casing hook consumes it;
  - `Magazine` (0, 8, 9), `Cell` (2, 4, 6), `Drum` (5), `Feed` (1, 3, 7) —
    children of the moving `feed` assembly, distinct from the existing
    `GripReload` hand station;
  - `HeatZone` — forward barrel region on the lower barrel surface, child of the
    `barrel-assembly`/`shock-emitter`/`flak-barrel` group so it follows recoil,
    the break-action hinge and weapon switching.
- **`godot/first_person/handling.gd`** (new, owned by `rig.gd`, presentation
  only): carrier/slide cycle per shot at the weapon's own source rate, charging
  handle on the first shot after a pause and inside every reload, magazine/feed
  handling mapped purely to the authoritative reload progress, and barrel heat
  (barrel emissive glow plus a bounded heat-haze/smoke micro-effect at
  `HeatZone`).
- **`rig.gd`** drives the channels instead of the old ad-hoc feed/bolt nudges;
  `_clear_motion()`/`reset()` drain every channel and the FX pool.
- **Bounded tests**: `godot/tests/first_person/handling.gd` (5,295 checks) and
  the rendered `godot/tests/first_person/handling_capture.gd` (482 checks, 140
  images at 960x640 and 1280x800).
- Review tooling: `tools/godot-weapons/handling-contact-sheets.mjs`.

## Measured (final run)

Anchor rest error (authored weapon-space station versus the live anchor):
**0 m for eight weapons, 2.9e-8 m and 1.2e-7 m** for the Rail Lance and
Scattergun, whose feed/barrel groups are rebased at their hinge centres.

| id | weapon | anchors | feed station | casing port | cycle (s) | stroke (m) | hip clearance / need (deg) | ADS clearance / need (deg) |
|---|---|---|---|---|---|---|---|---|
| 0 | Pulse Rifle | 12 | Magazine | yes | 0.055 | 0.0517 | 8.55 / 4.39 | 5.58 / 3.40 |
| 1 | Rocket Launcher | 11 | Feed | – | 0.088 | 0.0480 | 9.76 / 4.39 | 8.84 / 3.40 |
| 2 | Rail Lance | 11 | Cell | – | 0.068 | 0.0600 | 6.21 / 4.39 | 5.03 / 1.22 |
| 3 | Scattergun | 13 | Feed | yes | 0.073 | 0.0277 | 8.20 / 4.39 | 6.05 / 3.40 |
| 4 | Plasma Driver | 12 | Cell | yes | 0.044 | 0.0506 | 9.91 / 4.39 | 7.17 / 3.40 |
| 5 | Grenade Launcher | 12 | Drum | yes | 0.088 | 0.0237 | 7.41 / 4.39 | 6.94 / 3.40 |
| 6 | Shock Beam | 11 | Cell | – | 0.055 | 0.0550 | 7.82 / 4.39 | 5.49 / 3.40 |
| 7 | Flak Cannon | 12 | Feed | yes | 0.080 | 0.0393 | 7.83 / 4.39 | 7.33 / 3.40 |
| 8 | Marksman Rifle | 12 | Magazine | yes | 0.063 | 0.0594 | 7.83 / 4.39 | 5.19 / 1.47 |
| 9 | Submachine Gun | 12 | Magazine | yes | 0.040 | 0.0347 | 7.86 / 4.39 | 5.46 / 3.40 |

- Carrier travel measured at the fired frame: 15-55 mm, always at or below the
  authored stroke, always returning exactly to the imported rest pose.
- Feed travel inside the authoritative window: 205 mm (box magazine), 170 mm
  (cell), 75 mm (drum), 15-50 mm (breech/tube) — zero outside the window, and
  exactly at rest at progress 0.0 and 1.0.
- Charging handle: one rack per pause, none under sustained fire; racks inside
  the reload window (progress 0.60-0.96) for every weapon that has one.
- Heat: reaches the cap under sustained fire for all ten, cools to under 0.01
  after 25 s idle, and never exceeds its cap.
- Casings: exactly one pooled casing in flight for the three weapons whose
  shipping profile pools a case (0, 8, 9) and zero for the rest; the effects
  controller pool stayed at 24 slots maximum (cap 64) and the handling FX pool
  is a fixed four nodes.
- ADS: settled sight axis error 0.000000 degrees, open target gap 0 opaque
  pixels, `haze_alpha == puff_alpha == 0` at the cheek weld, and the authored
  heat station clears the reticle corridor in hip and ADS.

## Reproduce

```sh
node tools/godot-weapons/export.mjs
node tools/godot-weapons/verify.mjs
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT" --headless --path godot --editor --import
"$GODOT" --headless --path godot --script res://tests/first_person/lifecycle.gd
"$GODOT" --headless --path godot --script res://tests/first_person/ads_contract.gd
"$GODOT" --headless --path godot --script res://tests/first_person/handling.gd
# Display gates (the binding gate needs a real mouse mode; see gaps):
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --audio-driver Dummy --path godot \
  --rendering-driver opengl3 --script res://tests/first_person/binding.gd
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --audio-driver Dummy --path godot \
  --rendering-driver opengl3 --script res://tests/first_person/framing.gd -- --evidence-out=<dir>
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --audio-driver Dummy --path godot \
  --rendering-driver opengl3 --script res://tests/first_person/ads.gd -- --evidence-out=<dir>
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --audio-driver Dummy --path godot \
  --rendering-driver opengl3 --script res://tests/first_person/handling_capture.gd -- --evidence-out=<dir>
node tools/godot-weapons/handling-contact-sheets.mjs <dir>
```

## Evidence

- `evidence/logs/` — every gate log from the final sweep.
- `evidence/handling-metrics.json` — all 140 rendered states with measured bolt,
  feed, heat, FX-pool, casing, centre-region and corridor values.
- `evidence/sheets/` — one review sheet per pose, all ten weapons, both sizes.
- `evidence/fixtures/` — selected full-resolution captures (firing with a pooled
  casing, break-action and drum reloads, hot barrel, hot ADS).

## Gaps and cross-lane notes (nothing below was edited outside this lane)

- **`Hammer` is not exported.** No source chassis authors a hammer mesh, and the
  lane contract is source-derived geometry; inventing one would break the asset
  provenance story. "Where applicable" therefore yields no hammer channel.
- **`Slide` is not exported as a separate anchor.** Every chassis authors one
  reciprocating carrier (`bolt` group) with a charging paddle; there is no
  distinct slide assembly to anchor. `Bolt` + `Charging` cover the mechanism.
- **Casing pooling stays profile-gated.** `godot/weapon_effects/profiles.gd`
  (another lane) sets `case: true` for 0, 8 and 9 only; the other seven weapons
  have authored ports but the hook does not pool a case for them. Changing that
  is a values update in their file, reported here rather than edited.
- **`binding.gd` cannot pass headless.** Godot's dummy display server ignores
  `Input.mouse_mode = MOUSE_MODE_CAPTURED`, so the source-policy check on line
  41 never opens. This predates this lane; it passes under Xvfb with the X11
  driver. `tools/godot-dev/verify.py` is not owned by this lane, so the gate
  entry was left alone.
- **New gate registration requested (release owner owns `tools/godot-dev/**`)**:
  add `res://tests/first_person/handling.gd` (headless) to the gate list. The
  rendered capture is deliberately not a gate (it needs a display and writes
  images).
- **Not proven here**: no live network session was re-run after the handling
  work (`live.gd` needs an allocated loopback server), no GPU/hardware timing
  and no human visual review. Rendering was verified on llvmpipe only. The heat
  smoke is a bounded analytic quad plume, not a GPU particle system.
