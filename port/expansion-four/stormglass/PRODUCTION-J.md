# Stormglass — grant J production / private native proof

Grant: `STORMGLASS-ASSET-PRODUCTION-20261003-J`.
Canonical `f0e76bf7` merged at `0f731b78`; corrected canonical wrapper retained.
**Private candidate only; all receipts keep `accepted:false`.** Parent owns visual
approval, public pair registration, package closure and releases.

## Produced assets

- Editable Blender 4.5.14 master, outside Godot:
  `tools/godot-multiplayer/new-maps/stormglass-causeway/stormglass-causeway.blend`
- Actual exported/reimported art:
  `godot/multiplayer_worlds/art/worlds/stormglass-causeway.glb`
- **56,552 triangles**, **30 surfaces** (nine material batches plus 21 signs),
  **3,901,880 GLB bytes**, six textured surfaces / eleven embedded Moth images.
- Role-preserving neutral sRGB swatches explicitly converted to scene-linear;
  actual Moth-derived fixed component UVs; selective mineral/alloy normals, flat
  teal coating, preserved glazing/ocean/amber. Native inspection confirms UVs,
  normals and imported tangents on all required surfaces.
- 9,682 individually editable original recipe meshes plus a separately editable
  coastal architecture collection. Added seawall foundations and buttresses,
  service lighting, deep window mullions/canopies, rooftop exhausts, continuous
  tunnel trays, pump hall/cistern island, weather observatory crown and gate ribs.
  Additional scenic geometry stays behind the source road boundaries; it creates
  no advertised traversable route or source collision.

The first representative native images were inspected before the detail revision.
They exposed a thin water ribbon and repetitive facade silhouettes; revised art
adds depth and distinct infield landmarks. Final overview and five road-eye views
were inspected. Source architecture remains angular/stylized, with a hard-edged
water boundary visible from overview. Parent architectural approval is pending.

## Identity and geometry preservation

| Artifact | SHA-256 |
|---|---|
| Canonical arena geometry identity | `6afb8a36ee954ff9457a5522a7412c809191fb070eb7fe9eda4d379753acce48` |
| Wrapper bytes | `cdbb72fd712bd09807c9c83ffc08f7ef7d7d397a974819b062d8125f96c05ee6` |
| GLB | `ff318582fd47ca633ef74da1aa4a6aa2b5b691800f12fb3210f3dac140cb5b33` |
| Editable master | `970d244fbec4d352dd3148c5e68f927037c224fa680c680050c83c8984d84e40` |

All **19,364 original recipe triangles** were found in actual GLB batches; maximum
vertex error **0.000009916 m**. The extra 37,188 triangles are scenic detail and
signs. The canonical geometry identity hashes the arena; the old source document's
`bfb395…` hash covered terrain only and is not the canonical transport identity.

The original recipe and all three generated JSON files remain byte-identical to
`f0e76bf7`. Frozen core hash `58ff1b9c…` is intact. No vehicle, control, camera,
animation or source-rule edits. Drivable relief stays **0 m**, as required by the
existing race gate/ground/respawn constraints; no invented jump or vertical road.
The new observatory is visual height, not playable relief.

## Actual verification

- Original editable-master reopen: passed all original mesh vertices.
- Independent generic master **and GLB** reopen: passed finish/UV/fingerprint gates.
- Godot 4.5.2 real import: passed; actual native tangent streams verified.
- Native geometry: **441 support rays, six overheads, 84 sustained body moves**
  (42 road faces × infantry/Puma-radius cylinders), **42 wall-shot rays**.
- Source and private-admission Node suites: **15/15 passed** on this merged tree.
- Current canonical candidate helper used exact private admission and the current
  wall broadphase. Hosted outcomes record all derivative module hashes; summary
  additionally pins `wall_candidates.mjs`, controls/camera and promoted Puma LODs.
  These runs are new proof, not transferred older-authority test claims.

### One private mode pair, two native profiles

| Profile | Finish | Countdown/reset/recovery | F5 restart | Teardown |
|---|---:|---|---|---|
| 760×520 / UI150 | 105.232138 source seconds | Passed | New source countdown, zero progress | Both peers code 0; server closed; no leak flags |
| 1280×800 / UI100 | 104.899357 source seconds | Passed | New source countdown, zero progress | Both peers code 0; server closed; no leak flags |

Each run uses two actual Godot clients, the production sports HUD/chase/fleet and
network serialization, and current promoted Puma GLBs. A read-only controller
produces ordinary input dictionaries through each native peer. No actor pose,
clock, checkpoint or score writes after setup. The source first-finisher rule ends
the match; the second racer is near the closing gate, not falsely labeled finished.
This is scripted native-input proof, not natural human feel or hardware performance.

The guest requests race reset via ordinary interact and recovers after the stock
two-second wait without gaining gates. Race damage is disabled by source rules:
**zero deaths/wrecks**, with no unrelated death injection. Reverse/skipped/airborne
gate refusal remains the focused source-negative evidence; no dedicated native
wrong-way-warning claim is made.

The host's canonical Settings **Leave match · Return Home** action is invoked.
In this standalone entry it quits the native process to the launcher; the test
does not claim an in-process Home menu was rendered. Both peers' sockets and the
private server close. F5 restart is an actual `InputEventKey` through inherited
production input handling.

### UI/lifecycle findings retained for parent

1. Stock sports HUD hardcodes **Ion Speedway**. The private fixture supplies the
   correct candidate title only; production HUD is unchanged.
2. Stock fixed-width result panel clips at UI150. Private compact fixture uses a
   bounded responsive result panel and wrapped text. Inspected final wide/compact
   result images show all standings/restart text. Shared responsive fix is pending.
3. Immediate post-restart exit leaked `AudioStreamWAV`/playback objects. Three
   failed runs are retained and correctly marked `processFailed:true`, despite
   their race wins. Explicit fixture stop/null/drain before shutdown fixed both
   final runs; no shared audio source change or suppressed error matching.
4. Promoted Puma attachment emits existing owner-consistency warnings from
   `vehicle_assets/attachment.gd:56`. Retained logs identify exact assets. No
   geometry/control/camera repair attempted while SOL owns that lane.
5. The captured forward race samples show no source teleports. The largest sampled
   chase displacement is 2.429 m across ~0.1–0.165 s capture intervals. This cannot
   exclude between-sample corner stutter or settle the user's backwards/camera
   feel reports; parent/SOL natural-input review remains necessary.

## Media and evidence

Everything below is private, unapproved evidence under
`port/expansion-four/stormglass/evidence/production-j/`:

- [Overview](evidence/production-j/overview.png), [terminal](evidence/production-j/terminal.png),
  [freight bore](evidence/production-j/freight-bore.png),
  [quay](evidence/production-j/quay-chicane.png), [surgeworks](evidence/production-j/surgeworks.png).
- [Wide results](evidence/production-j/wide-results.png),
  [compact results](evidence/production-j/compact-results.png),
  [wide restart](evidence/production-j/wide-restart.png).
- [Actual ordinary-input clip](evidence/production-j/ordinary-input.mp4):
  **155 captured frames over 21.168 s, 7.275 captured fps**, 115–165 ms gaps.
  Timestamp-derived variable-frame-rate encoding; no interpolated/high-fps claim.
  Renderer: **llvmpipe LLVM 20.1.8**, software OpenGL. Native inspection observed
  31–59 draw calls in selected views; this is not dedicated-GPU acceptance.
- `summary.json`, `capture-timestamps.json`, `art-audit.json`, generic receipt,
  stage process records, exact source/runtime hashes, wire input, outcomes,
  stdout/stderr and all failed hosted runs are retained.

Original external evidence remains at
`/home/mojo/.tmp-on-disk/cocs-expansion-four-stormglass-evidence-20261002/production-j/`.
Initial source preflight missing `ws` was resolved by reusing the parent's
`node_modules` symlink. Art audit initially assumed exported tangent streams and
exact quantization bins; actual native tangents and distance-based Float32
comparison establish the correct checks without changing geometry.

## Reproduction and slot release

After a **new explicit grant**, the owned executor supports `build`, `import`,
`representative`, `inspection`, `reopen-original`, `reopen`, `receipt`, `native`,
`hosted-puma-race` (optional `--compact`) and `encode`:

```sh
python3 godot/tests/new_maps/stormglass_causeway/stage.py <stage> --granted
```

Every heavy stage used `LP_NUM_THREADS=1`, a nonwaiting shared lock, a bounded
timeout and an independently owned/reaped process group. **J released at
2026-10-03T06:09:35.500713Z: 19 owned groups, three empty audits, zero heavy jobs.**
See [release-j.json](evidence/production-j/release-j.json). Parent may take the
next native motion/UI slot. No other asset unit, public promotion, packaging or
cinematic production was run under J.
