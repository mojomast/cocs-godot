# Native impact FX lane: shader surface damage + blast treatment

Owner request: *"weapon projectiles effect the environment using shaders or
whatever the best way to do it is."* This lane adds persistent, material-aware
surface damage for confirmed projectile/blast contacts and a bounded explosion
treatment, wired through the existing combat composition. Presentation only:
no gameplay, damage, collision or network behaviour changes.

## Files

| Path | Role |
| --- | --- |
| `godot/player_fx/mark.gdshader` | The decal shader. One quad in the confirmed surface plane; an analytic height field (pock dish + radial cracks + scorch blobs + shockwave band) is shaded with a presentation light so damage reads as displaced geometry, not a flat sprite. |
| `godot/player_fx/mark_pool.gd` | Bounded pool of marks. Preallocated at configure/quality time (nodes, materials, mesh), oldest-live recycling, F9 caps/lifetimes, per-slot fade/age uniforms, counters, and an evidence-only enable switch. |
| `godot/player_fx/impacts.gd` | Extended composition consumer: confirmed shots now place a burst flash **and** a persistent pock; blast events place a scorch, a dust puff and (large blasts) a shockwave band; the occlusion/segment probes, dedup and burst pool behaviour are preserved. |
| `godot/world/combat_feedback.gd` | Minimal wiring: F10 metrics now expose the mark counters (`impact_marks_pool`, `impact_marks_live`, `impact_marks_recycled`, `impact_marks_skipped`, `impact_scorches`). Event routing already delivered explosions/deaths; nothing was restructured. |
| `godot/tests/player_fx/marks.gd` | Headless contract suite (64 checks): shader source contract, pool preallocation/caps/lifetimes, recorded shot on the real semantic map, dedup, occlusion/far/edge skips, recycling, explosion scorch/puff/shockwave, death-scorch rules, reset/quality switching. |
| `godot/tests/player_fx/marks_capture.gd` | Rendered evidence harness (63 checks per size). |
| `port/native-impact-fx/run-checks.mjs` | Lane runner: semantic export, import, every headless player-fx gate, blood-fx contracts, and rendered captures at 960x640 and 1280x800 under xvfb/llvmpipe. |

Read but never edited: `godot/blood_fx/surface_query.gd` (surface-query
patterns), `godot/blood_fx/controller.gd` (pooled-stain style),
`godot/moth/**`, `godot/world/combat_occlusion.gd`.

## What a mark is (and what it is not)

* **Authority-confirmed surface only.** A mark is placed at the authoritative
  shot endpoint (or the confirmed floor under a blast) after the composition's
  own geometry confirms it: `occlusion.segment_blocked` around the endpoint,
  the camera is not behind it, and the camera-to-contact segment is not blocked.
  Semantic maps use the same block/terrain logic as the existing occlusion; the
  native path reuses the existing physics ray. A blast floor is found by a
  bounded 6 m descent (0.25 m steps) through the same geometry, then the same
  camera/occlusion check. Nothing is ever guessed from gameplay state.
* **Never through walls.** The decal keeps world depth testing enabled and only
  skips depth writes, so geometry in front of a mark always wins. The quad is
  offset along the confirmed normal (`0.02 m + 0.012 × size`).
* **Edge-safe.** Four corner probes plus the centre confirm the normal axis is
  still a real surface at the quad corners; a mark that overhangs is shrunk once
  to half size and skipped if it still overhangs (`marks_skipped_edge`). No mark
  is ever drawn floating past a wall edge.
* **No per-impact allocation.** Each pool slot owns its node + `ShaderMaterial`
  from configure/quality time. Placing a mark only writes uniforms and a
  transform; `marks.gd` asserts the node and burst-pool counts do not change
  while placing many marks.
* **Dedup by authoritative event ID.** The composition already dedups public
  events; `impacts.gd` remembers consumed IDs as well, so focus loss, stale
  snapshots or a replay cannot place a mark twice.

## Pool, lifetime and quality table (F9)

| F9 level | Mark pool / concurrent cap | Mark lifetime | Fade window | Crack detail | Burst pool (unchanged) |
| --- | --- | --- | --- | --- | --- |
| Low | 20 | 6 s | last 35% of life | off (plain lit dish) | 6, 0.18 s |
| High | 44 | 14 s | last 35% of life | on | 12, 0.28 s |
| Extreme | 72 | 22 s | last 35% of life | on | 20, 0.32 s |

The pool never grows: at cap the oldest live mark is recycled
(`marks_recycled`) and the node count stays exactly at the cap (verified in the
harness: 140 shots into a 72-slot pool → `marks_recycled = 68`, `marks_live =
72`, `pool_nodes = 72`). Shockwave bands are 0.45 s slots in the same pool.

Material table (pock sizes in metres; shader look):

| Family | Pock size | Shader character |
| --- | --- | --- |
| metal | 0.24 | deep pock, dark blue floor, burnished bright rim, tight cracks, sparkle |
| stone | 0.30 | chipped dish, dark interior, pale dust rim, wider radial cracks |
| ice | 0.32 | pale chip, blue shadow, bright fracture lines |
| ground | 0.38 | shallow warm crater, dust rim, fewer/softer cracks |

Blast treatment:

* `explosion` / `vehicle-destroyed` → scorch decal on the confirmed floor
  (`scorches_placed`), plus a bounded dust/debris puff (`puffs`) that reuses the
  preallocated burst slots.
* Large blasts get a 0.45 s shockwave band quad (`shockwaves_placed`). Large is
  a presentation-only classification: vehicle kills, any `alt: true` explosive,
  any event carrying `radius >= 3`, or weapon index 1/5 (Rocket Launcher /
  Grenade Launcher in the public table). Small blasts (e.g. plasma) scorch but
  never ring.
* `death` events scorch **only** for the authoritative `combust` style (fire
  deaths). Every kill is deliberately not scarred; `death_scorches` reports it.
* No scorch is fabricated when the descent finds no floor:
  `blasts_skipped_no_ground`; far/occluded blasts are skipped with
  `blasts_skipped_far` / `blasts_skipped_occluded`.

## Counters (all readable from `impacts.snapshot()` and F10)

Pre-existing counters are untouched (`shown`, `actor_hits`, `no_geometry`,
`occluded`, `legacy`, `deduped`, `dropped`, `probes`, `confirmed`, `too_far`).
Added: `marks_live`, `marks_placed`, `marks_recycled`, `marks_expired`,
`marks_denied`, `marks_skipped_occluded`, `marks_skipped_far`,
`marks_skipped_edge`, `marks_dropped`, `blasts_seen`, `scorches_placed`,
`death_scorches`, `shockwaves_placed`, `blasts_skipped_no_ground`,
`blasts_skipped_occluded`, `blasts_skipped_far`, `puffs`.

`snapshot().active` keeps its old meaning (live transient bursts); the
persistent layer is `marks_live` / `marks_pool` / `marks_limit` / `marks_life`.
F10 additionally prints `impact_marks_pool`, `impact_marks_live`,
`impact_marks_recycled`, `impact_marks_skipped`, `impact_scorches`.

## Measured evidence

Evidence: `port/native-impact-fx/evidence/render-1790270721960/`
(PNGs per size, `measurements-<size>.json`, one log per gate, `runner.json`).
Camera poses: the recorded-shot frames use the locked semantic
`meridian-exchange` map built as meshes; the four-family gallery, the blast
floor and the wall edge are explicitly labelled fixtures (the locked maps do not
put all four families on one camera). "before" = the same event with the mark
pool disabled (`marks.set_enabled(false)`, evidence-only switch) so the frame
shows exactly the previous transient-flash behaviour; "clean" is no event.

Determinism: with composition ambience hidden the two identical probe frames
differ by **0 px** at both sizes. (`whole_clean_to_after` includes the animated
first-person weapon and ambient effects and is therefore larger than the ROI
numbers below.)

Changed pixels, 960x640 / 1280x800:

| Scenario | Comparison | Changed px |
| --- | --- | --- |
| Recorded server shot 164 (real map, ground) | before → after (0.04 s) | 301 / 478 |
| Recorded server shot 164 | before → after, settled 0.4 s (flash gone) | 348 / 531 |
| Recorded server shot 164 | clean → after (flash + mark + world) | 8464 / 13110 |
| Aged mark at 75% lifetime | settled → aged | 321 / 500 |
| Four families (fixture) | before → after | 7142 / 7409 |
| Four families (fixture) | clean → settled (marks only) | 6347 / 6598 |
| Close-up stone pock | clean → settled | 9806 / 12078 |
| Wall edge (corner overhang) | before → after | **0 / 0** (`marks_skipped_edge = 1`, `marks_placed = 0`) |
| Large blast (scorch+ring+puff) | before → after | 2940 / 4597 |
| Large blast | before → settled (scorch persists) | 3065 / 4790 |
| Small plasma blast | clean → after (scorch, no ring) | 1489 / 2309 |

Frames proving the requested reads: `recorded-after` (fresh ground pock),
`recorded-aged` (aged), `recycled-after` (140 shots → recycled pool, counters in
the JSON), `materials-*` (metal/stone/ice/ground), `edge-*` (wall edge, no
floating decal), `blast-*` (scorch, puff, shockwave, settled scorch),
`relief-settled` (shader relief close-up), `quality-*` (F9 levels).

## Performance on llvmpipe (gl_compatibility)

Measured in the same frames: `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`
and `RENDER_TOTAL_OBJECTS_IN_FRAME`, and the CPU cost of
`impacts.advance(1/60)` over the full pool.

| F9 level | Live marks | Draw calls (baseline 26) | Δ draw calls | Objects | `advance()` µs/frame |
| --- | --- | --- | --- | --- | --- |
| Low | 20 | 46 | +20 | 524 | 17 |
| High | 44 | 70 | +44 | 560 | 36 |
| Extreme | 72 | 98 | +72 | 615 | 61–74 |

Each live mark is one unshaded, depth-tested quad → exactly one additional draw
call; the shader does no texture fetch, no per-frame GPU readback and discards
early below 0.6% alpha. At Extreme the full pool costs ~60–75 µs of CPU per
frame on the CI host under llvmpipe software rasterization, and the complete
run (nine headless suites + both 29-frame capture sizes, ~5.4 MB of PNGs)
finishes in ≈12 s wall-clock. Mark nodes are hidden when idle, so an empty pool
costs nothing (26-call baseline).

## Gates (exact commands and results)

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
node tools/godot-export/semantic.mjs                        # Exported 9 semantic maps
"$GODOT_BIN" --headless --path godot --import               # exit 0
"$GODOT_BIN" --headless --path godot --script res://tests/player_fx/direction.gd    # PLAYER_FX_DIRECTION_OK checks=23
"$GODOT_BIN" --headless --path godot --script res://tests/player_fx/low_health.gd   # PLAYER_FX_LOW_HEALTH_OK checks=19
"$GODOT_BIN" --headless --path godot --script res://tests/player_fx/lifecycle.gd    # PLAYER_FX_LIFECYCLE_OK checks=19
"$GODOT_BIN" --headless --path godot --script res://tests/player_fx/impacts.gd      # PLAYER_FX_IMPACTS_OK checks=42
"$GODOT_BIN" --headless --path godot --script res://tests/player_fx/overlay.gd      # PLAYER_FX_OVERLAY_OK checks=19
"$GODOT_BIN" --headless --path godot --script res://tests/player_fx/integration.gd  # PLAYER_FX_INTEGRATION_OK checks=37
"$GODOT_BIN" --headless --path godot --script res://tests/player_fx/marks.gd        # PLAYER_FX_MARKS_OK checks=64
"$GODOT_BIN" --headless --path godot --script res://tests/blood_fx/contracts.gd     # BLOOD_FX_CONTRACTS PASS checks=84 failed=0
xvfb-run -a -s "-screen 0 960x640x24" "$GODOT_BIN" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tests/player_fx/marks_capture.gd -- --size=960x640 --output=<dir>
# PLAYER_FX_MARKS_CAPTURE_OK size=960x640 checks=63 failures=0 adapter=llvmpipe (LLVM 20.1.8, 256 bits)
# 1280x800: PLAYER_FX_MARKS_CAPTURE_OK size=1280x800 checks=63 failures=0
```

One command re-runs everything and writes a timestamped evidence directory:

```sh
node port/native-impact-fx/run-checks.mjs   # IMPACT_FX_VERIFY_OK evidence=... (≈12 s)
```

The runner fails on `SCRIPT ERROR`, `PARSE Error`, `SHADER ERROR` or a non-zero
exit, so a shader that does not compile on gl_compatibility/llvmpipe cannot pass.

## Deliberately left out / judgement calls

* **Screen-space heat-haze distortion: dropped.** It would need a
  `hint_screen_texture` backbuffer copy every frame the shockwave lives; on the
  Compatibility renderer under llvmpipe that copy is the single most expensive
  pass this lane could add, and a fullscreen distortion pass is another owner's
  post-process territory. The shockwave band + dust puff already give large
  blasts their read; no half-tested distortion was shipped.
* **No scorch on every death.** Only the authoritative `combust` style scars
  the ground, so ordinary kills do not turn maps into black fields.
* **Large-blast classification is presentation-only** and derived from the
  public event (`vehicle-destroyed`, `alt`, `radius`, weapon index 1/5). It does
  not read or change gameplay tables.
* **Edge handling shrinks once then skips.** The corner probes prove the normal
  axis is still geometry; they cannot prove it is the *same* surface (a corner
  over a floor beyond a wall edge can pass). That is documented rather than
  hidden, and the wall-edge harness case is asserted to skip.
* **Marks are not network-synced.** Like the rest of the presentation layer,
  each client derives marks from the same authoritative events and geometry, so
  they are deterministic per client without extra traffic.
* Mark life deliberately does **not** scale with the burst pool's short lives;
  `snapshot().active` semantics are unchanged so existing contracts and tests
  keep their meaning.
