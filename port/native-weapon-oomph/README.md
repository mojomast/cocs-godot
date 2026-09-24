# Native weapon oomph: recoil, muzzle flash, tracers, projectile flight, audio

Presentation-only pass on top of `283639bc` ("Record the passing 167-gate sweep
and refreshed report logs") for the owner request: *the projectiles for the most
part are too slow now; the guns need more oomph and to feel and sound more
powerful.* No gameplay or simulation value is read, written or faked: aim,
spread, ammo, damage, projectile speed/position from authority, snapshot cadence,
and the ADS sight-picture contract are untouched.

Toolchain: Godot **4.5.2.stable.official.6ce3de25a**, GL Compatibility for the
rendered captures, `--audio-driver Dummy` for the audio gates.

## What changed

| Path | Change |
|---|---|
| `godot/first_person/handling.gd` | Recoil presentation helpers: `recoil_heft`, `recoil_scale` (1.6–2.2x, derived from the source `feel.kick` the rig already reads), `pitch_hold` (1.12–1.22x), `recover_rate` (0.78x rate ≈ 28% longer settle), `punch_pitch/roll/back/rate`. Read-outs on `handling` for the evidence test. |
| `godot/first_person/rig.gd` | Sustained per-weapon shove (translation ×1.6–2.2), muzzle-rise hold ×1.12–1.22, and a transient camera punch (pitch + alternating roll + extra shove) that decays exponentially to exact zero. Reduced-motion path scales the punch to 35% and keeps a visible shove. No camera writes. |
| `godot/weapon_effects/profiles.gd` | Existing `size`/`life`/`smoke` kept; added `flash_scale`, `flash_life`, `bright`, `light`, `light_range`, `light_life`, `tracer_width`, `tracer_life`, `tracer_core`, `tracer_glow`, `tracer_fade`. |
| `godot/weapon_effects/flash.gdshader` | `core_gain` + `brightness` uniforms (hotter, whiter cores; defaults preserve the old card). |
| `godot/weapon_effects/controller.gd` | Bigger/longer per-weapon blooms and jets, pooled `OmniLight3D` barrel lights (max 2, quality 2 only, parented to the animated muzzle tip), layered tracers (soft trail + mid + near-white core + travelling head), per-weapon widths/lives/fades, compact ADS bloom so the open target gap stays clear. `LINE_CAP`/`CAP`/lifecycle unchanged; lights are a separate pool. |
| `godot/world/projectiles.gd` | Bounded dead-reckoned visual flight between authoritative samples (20 Hz and 60 Hz), snapping exactly on every sample, distance+time capped, with an exhaust ribbon per projectile, bounce/teleport resets, and a stale-trail fade. Muzzle-origin blend and occlusion checks kept. Marker per projectile + one ribbon child (no extra scene nodes). |
| `godot/world/audio_feedback.gd` | Per-weapon layered voices from the source `feel` hints: noise crack + filtered body + tonal report (source waveform) + sub-bass thump + family layer + tail. `launch` gets a deeper whoomp, confirmed `damage` uses the last local weapon's impact voice, `explosion` is rebuilt (0.30 s → 0.42 s rumble+sub). `hurt`/`pickup` are byte-identical in level. Deterministic seeded synth, 3 ms attack / 18 ms release, peak ≤ 0.65, 8 fixed voices, family cooldowns and pool semantics unchanged. |
| `godot/tests/first_person/recoil.gd` | New headless response contract + per-weapon measurements (190 checks). |
| `godot/tests/weapon_effects/projectile_flight.gd` | New headless flight/ribbon/bounce/teleport/bounds contract (22 checks). |
| `godot/tests/weapon_effects/oomph_capture.gd` | New 1280x800 rendered evidence harness (45 checks, 60 captures, contact sheets). |
| `godot/tests/protocol/audio_feedback.gd` | Extended to 287 checks: per-weapon cache bounds, peak/RMS/length distinctness, determinism, explosion cue, plus every original assertion. |

## Recoil before/after (real measured pose response, single shot, 240 Hz sampling)

"Before" is the branch-point rig measured with the identical probe
(`/tmp/opencode/oomph-base`, scratch only, not committed). Shove is the backward
pose travel in metres, lift the muzzle rise in degrees, recover the time for the
sustained scalar to reach exactly zero.

| W | Weapon | kick scale | shove before → after (x) | lift before → after (x) | transient roll (new) | recover before → after |
|---|---|---|---|---|---|---|
| 0 | Pulse Rifle | 1.72 | 0.019 → 0.049 m (2.58x) | 0.96° → 1.63° (1.69x) | 1.51° | 0.067 → 0.083 s |
| 1 | Rocket Launcher | 2.13 | 0.045 → 0.152 m (3.35x) | 2.70° → 5.32° (1.97x) | 6.42° | 0.104 → 0.129 s |
| 2 | Rail Lance | 1.98 | 0.032 → 0.098 m (3.07x) | 2.28° → 4.25° (1.87x) | 4.73° | 0.079 → 0.100 s |
| 3 | Scattergun | 2.20 | 0.051 → 0.179 m (3.50x) | 2.78° → 5.63° (2.03x) | 7.05° | 0.083 → 0.108 s |
| 4 | Plasma Driver | 1.65 | 0.012 → 0.031 m (2.46x) | 0.79° → 1.30° (1.65x) | 1.13° | 0.050 → 0.067 s |
| 5 | Grenade Launcher | 2.07 | 0.041 → 0.132 m (3.23x) | 2.47° → 4.75° (1.92x) | 5.55° | 0.104 → 0.129 s |
| 6 | Shock Beam | 1.81 | 0.023 → 0.064 m (2.76x) | 1.44° → 2.54° (1.76x) | 2.54° | 0.067 → 0.083 s |
| 7 | Flak Cannon | 2.20 | 0.049 → 0.172 m (3.49x) | 2.95° → 5.97° (2.02x) | 7.47° | 0.092 → 0.117 s |
| 8 | Marksman Rifle | 1.80 | 0.021 → 0.058 m (2.72x) | 1.46° → 2.53° (1.74x) | 2.48° | 0.075 → 0.092 s |
| 9 | Submachine Gun | 1.60 | 0.009 → 0.021 m (2.38x) | 0.62° → 1.01° (1.62x) | 0.84° | 0.046 → 0.058 s |

Peak response is the sum of the amplified sustained kick and the transient punch;
the sustained-only multiplier is the `kick scale` column. The pitch hold alone is
deliberately small (1.12–1.22x) so the heat station cannot enter the reticle
corridor: `weapon-handling` clearance margins stay ≥ 1.23° (Rail Lance) with no
check weakened. Reduced motion caps lift/roll at ≤ 55% of the full punch and
keeps the shove.

## Muzzle flash and tracers before/after

| W | Weapon | bloom before → after | bloom life before → after | bright | barrel light | tracer core before → after | tracer life before → after |
|---|---|---|---|---|---|---|---|
| 0 | Pulse Rifle | 0.480 → 0.696 m | 0.075 → 0.116 s | 1.20 | – | 0.018 → 0.021 m | 0.065 → 0.105 s |
| 1 | Rocket Launcher | 0.864 → 1.382 m | 0.140 → 0.196 s | 1.35 | 3.6 / 9.5 m | launch (no ray) → 0.030 m | – → 0.160 s |
| 2 | Rail Lance | 0.624 → 0.936 m | 0.120 → 0.192 s | 1.45 | 2.0 / 7.0 m | 0.035 → 0.036 m | 0.130 → 0.300 s |
| 3 | Scattergun | 0.816 → 1.428 m | 0.115 → 0.161 s | 1.30 | 2.8 / 8.0 m | 0.008 → 0.011 m | 0.075 → 0.090 s |
| 4 | Plasma Driver | 0.720 → 1.008 m | 0.130 → 0.202 s | 1.30 | 1.0 / 5.5 m | 0.018 → 0.026 m | 0.065 → 0.210 s |
| 5 | Grenade Launcher | 0.720 → 1.188 m | 0.160 → 0.232 s | 1.30 | 3.0 / 8.5 m | 0.018 → 0.020 m | 0.065 → 0.140 s |
| 6 | Shock Beam | 0.672 → 0.974 m | 0.130 → 0.202 s | 1.40 | 1.4 / 6.0 m | 0.035 → 0.036 m | 0.130 → 0.240 s |
| 7 | Flak Cannon | 0.960 → 1.728 m | 0.145 → 0.203 s | 1.35 | 3.2 / 9.0 m | 0.008 → 0.013 m | 0.075 → 0.095 s |
| 8 | Marksman Rifle | 0.552 → 0.828 m | 0.085 → 0.136 s | 1.30 | 1.8 / 6.5 m | 0.018 → 0.019 m | 0.065 → 0.150 s |
| 9 | Submachine Gun | 0.360 → 0.486 m | 0.055 → 0.093 s | 1.15 | – | 0.018 → 0.017 m | 0.065 → 0.080 s |

Tracers are drawn as a wide soft trail (×3.4), a mid trail (×1.7), a near-white
hot core (×1.0) and a travelling bright head over the unchanged instant
along-ray geometry; widths above are the core. Every weapon's ray now lives
longer or the same as before, with a per-weapon fade exponent (Rail 0.7 holds,
SMG 2.1 snaps out). `LINE_CAP`, pooling and expiry are unchanged.

## Audio before/after (cached voices, measured from the PCM the game plays)

| W | Weapon | shot s | shot peak | shot RMS | launch s | launch peak | launch RMS | hit s | hit peak | hit RMS |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | Pulse Rifle | 0.233 | 0.546 | 0.073 | 0.233 | 0.567 | 0.107 | 0.100 | 0.531 | 0.066 |
| 1 | Rocket Launcher | 0.471 | 0.636 | 0.069 | 0.500 | 0.638 | 0.134 | 0.230 | 0.611 | 0.067 |
| 2 | Rail Lance | 0.394 | 0.602 | 0.097 | 0.394 | 0.612 | 0.121 | 0.110 | 0.581 | 0.066 |
| 3 | Scattergun | 0.393 | 0.650 | 0.080 | 0.393 | 0.650 | 0.116 | 0.122 | 0.624 | 0.080 |
| 4 | Plasma Driver | 0.311 | 0.530 | 0.064 | 0.356 | 0.554 | 0.106 | 0.146 | 0.516 | 0.073 |
| 5 | Grenade Launcher | 0.500 | 0.622 | 0.067 | 0.500 | 0.628 | 0.109 | 0.218 | 0.599 | 0.056 |
| 6 | Shock Beam | 0.304 | 0.566 | 0.096 | 0.304 | 0.583 | 0.111 | 0.100 | 0.549 | 0.093 |
| 7 | Flak Cannon | 0.500 | 0.650 | 0.096 | 0.500 | 0.650 | 0.127 | 0.170 | 0.624 | 0.069 |
| 8 | Marksman Rifle | 0.212 | 0.562 | 0.086 | 0.212 | 0.580 | 0.131 | 0.100 | 0.545 | 0.070 |
| 9 | Submachine Gun | 0.156 | 0.520 | 0.095 | 0.156 | 0.546 | 0.106 | 0.100 | 0.507 | 0.059 |

Before (one generic voice each, measured at the branch point):

| Cue | Length | Peak | RMS |
|---|---|---|---|
| `shot` | 0.110 s | 0.532 | 0.107 |
| `hit` (impact) | 0.075 s | 0.571 | 0.154 |
| `launch` | 0.220 s | 0.391 | 0.096 |
| `explosion` | 0.300 s | 0.261 | 0.045 |
| `hurt` | 0.180 s | 0.538 | 0.175 |
| `pickup` | 0.220 s | 0.605 | 0.198 |

After: `explosion` 0.420 s / peak 0.650 / RMS 0.130; `hurt` and `pickup` are
unchanged to the sample. Weapon voices are cached lazily per weapon (32 cached
waveforms, 194 447 samples ≈ 380 KB PCM, 106 ms total synthesis, 3.6 ms for the
two base cues); playback never regenerates. Every cue: deterministic seed,
3 ms attack / 18 ms release, zero endpoints, peak ≤ 0.65; eight coherent voices
at −16 dB stay below full scale. Family cooldowns are unchanged, so the burst
gate's interval checks still hold.

## Projectile presentation

- Authoritative samples always snap exactly onto the marker (`apply_state` sets
  the exact position before any interpolation).
- Between samples the marker dead-reckons the last measured velocity for at most
  `0.12 s` and at most `3.0 m`, then waits for the next sample. At 20 Hz this
  removes the 1–2 m stair-stepping; at the lead's 60 Hz cadence the same code
  covers a dropped sample without visible lag.
- A reversal (dot < −0.25), a `> 3 m` jump, a time gap or a rewound sample clears
  the exhaust ribbon and restarts cleanly. Bounces never draw a ribbon across the
  turn; a teleport never drags a streak.
- Each projectile owns one `ImmediateMesh` ribbon (7 points, tapering, fading,
  0.3 s stale fade) as a **child of its marker**, so `get_child_count()` on the
  projectiles node still equals the marker count and the existing pool-bound
  assertions hold.
- The muzzle-origin blend, occlusion checks and per-weapon exhaust tint are kept.
  No collision, hit, damage, disappearance explosion or endpoint is invented.

## Gates (all run in this worktree, all green)

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --import
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/lifecycle.gd
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/ads_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/lifecycle.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/rig_integration.gd
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/handling.gd
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/detail.gd
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/recoil.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/projectile_flight.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/projectiles.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/combat_feedback.gd
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/protocol/audio_feedback.gd
```

| Gate | Result line |
|---|---|
| import | exit 0, `.uid` sidecars generated for the new tests |
| first-person-rig | `FIRST_PERSON_LIFECYCLE {"checks":57,"failures":[]}` |
| first-person-ads | `NATIVE_ADS_CONTRACT {"checks":93,"failures":[]}` |
| weapon-effects | `WEAPON_EFFECTS_LIFECYCLE failures=0` |
| weapon-effects-rig | `WEAPON_EFFECTS_REAL_RIG weapons=10 poses=2 max_projection_error_px=0.00001526 failures=0` |
| weapon-handling | `FIRST_PERSON_HANDLING checks=5295 failures=[]` (min hip corridor margin 1.23°, min ADS margin 2.06°) |
| weapon-detail | `FIRST_PERSON_DETAIL checks=345 failures=[]` |
| first-person-recoil (new) | `FIRST_PERSON_RECOIL {"checks":190,"failures":[]}` |
| projectile-flight (new) | `WEAPON_EFFECTS_PROJECTILE_FLIGHT {"checks":22,"failures":[]}` |
| projectiles (unowned, kept green) | `PORT_PROJECTILES_OK checks=27` |
| combat-feedback | `PORT_COMBAT_FEEDBACK_OK` |
| audio-feedback | `PORT_AUDIO_FEEDBACK_OK checks=287` |

Rendered gates under a private Xvfb (GL Compatibility, `--audio-driver Dummy`):

| Gate | Result line |
|---|---|
| first-person Ads (`tests/first_person/ads.gd`) | `NATIVE_ADS {"checks":910,"failures":[],"images":120}` |
| handling capture (`tests/first_person/handling_capture.gd`) | `FIRST_PERSON_HANDLING_CAPTURE {"checks":482,"failures":[],"images":140}` |
| weapon-effects framing (`tests/weapon_effects/framing.gd`) | `WEAPON_EFFECTS_FRAMING records=41 errors=0` |
| contact sheet (`tests/weapon_effects/contact_sheet.gd`) | `framing_records 40, max tracer start error 0.00007 px, endpoint delta 0.0 m` |
| moth coverage (`tests/weapon_effects/moth_coverage.gd`) | `passed: true` |
| weapon oomph capture (new) | `WEAPON_OOMPH_CAPTURE {"checks":45,"failures":[],"captures":60}` |

## Rendered evidence (1280x800, real rig + shipping effects controller)

- `evidence/muzzle-flash-sheet-1280x800.png` – hip blooms for all ten weapons.
- `evidence/tracer-sheet-1280x800.png` – mid-life rays; launch weapons show their
  launch bloom (projectile weapons have no hitscan ray in the shipping path).
- `evidence/firing-sequence-sheet-1280x800.png` – SMG, Scattergun, Rocket
  Launcher and Rail Lance, five real shots each with recoil + bloom.
- `evidence/ads-fire-sheet-1280x800.png` – settled ADS firing pose per weapon.
- Full-size samples: `flash-w1/w2/w3/w7.png`, `tracer-w2/w6/w9.png`,
  `ads-bloom-w3.png`, `ads-fire-w3.png`, `sequence-w1-2.png`, `sequence-w3-1.png`.
- `evidence/oomph-metrics.json` – per-capture flash/tracer/light/recoil numbers
  from the same run as the images.

The capture harness also asserts, per weapon, that the ADS bloom leaves **0
opaque pixels** in the open-sight target gap (`ads-bloom` frames) while the
hip bloom is at full per-weapon size. The same `handling_capture.gd` metrics
were run at the branch point and at this commit: the asserted `ads`, `hot-ads`,
`hip`, `reload` and `heat-hold` target-gap / 48 px-centre numbers are
**byte-identical** (0 gap pixels), so the bigger hip bloom never changes an
asserted sight-picture state.

## Judgement calls

- **ADS bloom is capped at 0.18 m.** At a settled cheek weld the muzzle sits only
  a few degrees below the sight axis, so a full-size card centred on it covers
  the open sight picture (the pre-change card did too, it was simply never
  measured). The aiming bloom collapses to a compact bright spark; the hip bloom
  and the barrel light keep the full per-weapon punch. This is asserted by the
  rendered gap check.
- **The per-weapon multiplier is carried by the shove and the transient punch,
  not by sustained pitch.** Muzzle climb rotates the authored heat station toward
  the reticle corridor; keeping the pitch hold at 1.12–1.22x preserves the
  handling gate's safety margins while the felt kick still measures 1.6–2.0x on
  pitch and 2.4–3.5x on shove.
- **Barrel lights are Extreme-only.** They never allocate at F9 Low (quality 1),
  and at most two pooled `OmniLight3D` nodes ever exist, so the light cost stays
  inside the existing F9 budget. They are excluded from the flash pool counts.
- **Confirmation uses the last local weapon.** `damage` events carry no weapon;
  the impact voice follows the last authoritative local shot/launch and is reset
  at round boundaries.
- **No aim/spread/ammo edits and no snapshot-cadence changes.** The projectile
  work only transforms presentation positions between samples; all authoritative
  positions, endpoints and disappearances are untouched.
- **`hurt`/`pickup` levels are unchanged** (byte-identical PCM levels) so the
  mix balance outside weapons is not disturbed.

## Deliberately left out

- No changes to gameplay/simulation files, `godot/first_person/generated/**`,
  `game/**`, `server/**`, `assets/**`, `public/**`, `package*.json`,
  `tools/godot-dev/verify.py`, `godot/world/combat_feedback.gd` or
  `port/handoffs/**`.
- No new imported assets, no release sweep (lead-owned), no push.
- Static projectile visuals for transports that never publish `time` degrade to
  the original exact-snap behaviour.
