# Foundry R7 — actual Y production handoff

**Production and strict native tangent proof completed; Y released.** Independent
artifact review, manual art/hosted acceptance and an explicit parent shipping
transaction remain separate. No accepted runtime binding or package policy changed.

Base: `10d9938f`; branch `astra/foundry-r7-Y`; worktree
`/home/mojo/.tmp-on-disk/cocs-foundry-r7-Y`. Authorization is `grant-Y.json`, not the
historical source queue (which remains null-grant/null-art-hash/autostart-false).

## Actual identity and preservation

| Item | Result |
|---|---|
| R7 GLB SHA-256 | `6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f` |
| R7 packed master SHA-256 | `96314db722902c12c8b5866edfd0d12844db3a99527eb746c58f61376dc09472` |
| Pinned R6 input SHA-256 | `945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c` |
| Unchanged geometry authority | `61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879` |
| Actual GLB / master bytes | 15,012,592 / 6,352,538 |
| Triangles / mesh nodes / primitives / materials | 87,566 / 16 / 32 / 18 |
| Images | 36 embedded PNGs; all 36 extracted payloads byte-exact |
| Tangent change | Seven records; exactly 59 changed BIN bytes within 112 permitted positions |

All other BIN bytes are identical to R6, including valid tangents, positions,
normals, UVs, indices and material image payloads. JSON asset/node successor
metadata and container length legitimately differ. No geometry stripping,
quantization, material reassignment or new art direction was introduced. The GLB
still exceeds the 7 MB design target by 8,012,592 bytes.

All 226 W manifest file hashes matched. R5 accepted history, W/R6 artifacts and
the original R7 source reports/corrective receipt remain unchanged. The final
manifest inventories the new/changed R7 scope; generated unrelated sidecars were
removed only after recording 691 hashes and verifying their absence at Y start.

## Master and actual native proof

Pinned Blender **4.5.14**, `-t 1`, built the actual packed R7 master. A separate
fresh Blender process reopened it, verified its embedded deterministic recipe,
exported its actual editable polygons and passed semantic material/sampler/emission
and oriented per-corner geometry matching before canonical re-export equality.
Position and normal maximum error were **zero**; UV error was
`4.76837158203125e-7`. The saved master has 16 editable export meshes, 270 hidden
editable geometry references and 40 packed images. A final read-only master
inventory confirmed those counts without modifying its hash.

Blender's plain glTF exporter is an intermediate: the packed recipe plus pinned
canonical baseline and repository compiler are explicit dependencies. Canonical
output was emitted only after the actual editable export audit passed; master
drift is not silently discarded. The R7 recipe is a truthful persisted post-export
contract, not a claim that Blender stores arbitrary custom loop tangents.

Pinned Godot **4.5.2** imported the actual R7 GLB with the generated UID retained,
mesh compression disabled and generated LODs off. Fresh readback proved:

- Exact native positions, UVs and oriented triangle multiplicity.
- Maximum normal component error `0.00010782480239868164`.
- Maximum tangent component error `0.0001665949821472168`, with every corner's
  direction and handedness checked; **zero undefined-tangent waivers**.
- All **18 material field sets** and **51 decoded channel image comparisons** passed.
- Eight fresh targeted authority rays passed in the exact R7 stage. R5's broader
  capsule report remains prior same-geometry evidence, not a Y rerun.

`evidence/Y/seven-corner-native-map.json` maps each corrected source accessor/vertex
to its actual native node/surface/face/corner/vertex and tangent. Ground remains
`w=-1`; copper faces 2283/2303 are `w=+1`, and the other four are `w=-1`.
All seven native errors are below `7.3e-5`; none uses the old zero-direction fallback.

Native sampler/alpha/occlusion state was **not recorded by the probe**; equivalence
for those settings is established by the source material-semantic gate, not a new
native readback claim. No tolerance was widened. Sixteen packaged source tests
passed under Y, including both actual R6 material counterexample rejections.

## Captures and observations

All **26 original 1280×720 PNGs** were examined, with no image postprocessing:

- `evidence/native/`: eleven matched staged-R6-before / candidate-R7-after pairs,
  preserving the approved camera fixture.
- `evidence/native-targeted/`: two additional matched pairs aimed at the affected
  high copper members and tiny ground sliver.

These before images are **fresh staged R6 comparisons**, not accepted-original
captures or relabeled W receipts. Both variants use the production WorldMap/Binder/
WeatherService bridge, identical camera/lighting/weather settings and unchanged
authority. Capture execution passed Off/Low/Full orange preservation and weather
restoration assertions; traversal remained uncapped.

No broad visual change was evident in the standard pairs. The high-copper close
view shows subtle narrow-edge shading changes. The ground close view is a pale
surface field; the thin triangle cannot be isolated visually there. Its correction
is established by the native corner basis, not a forced obvious image difference.
Numeric pair changes range from 30–1,811 pixels in standard views, 12,678 in the
copper close-up, and six in the ground close-up. These counts are not an attribution
of every changed pixel to a repaired tangent; raster/resource-order effects can
also contribute. Broad pale surfaces and repetitive ribbing remain the prior
manual-art concerns.

## Measured backend scope

Actual warmed-cache headless load/instantiate: **97.901 ms**.
Eleven short eight-frame static-view samples on **llvmpipe, LLVM 20.1.8**:

| Variant | Min / median / max ms | Draw calls | Peak reported video bytes | Peak static bytes |
|---|---|---|---|---|
| Fresh staged R6 | 120.142 / 214.171 / 322.094 | 112–227 | 74,140,225 | 121,178,944 |
| Actual R7 | 121.658 / 212.426 / 315.765 | 112–227 | 74,140,225 | 121,349,744 |

These are software-renderer static samples, not gameplay FPS, hosted movement
cadence, a performance improvement claim or dedicated-GPU acceptance.

## Attempts, corrections and release

The build, fresh reopen, import, strict native checks, rays and captures passed on
their first Y attempts. The first **report collector** failed because matching an
affected copper vertex only by position/normal/UV also found an existing valid
coincident vertex with opposite `w`. Its source snapshot and failure log are
retained. The collector now matches the complete oriented incident triangle and
then the corner; the strict artifact/native verifier was unchanged.

The first capture logged missing audio-device fallback and unsupported V-Sync
warnings but completed every assertion and image. The supplemental capture used
the Dummy audio driver. No native geometry/material waiver was introduced.

Y used the nonwaiting lifetime lock, serial bounded process groups, kernel start
ticks and one LP/OMP thread. Renderer receipts include Xvfb and Godot descendants.
Y released at **2026-10-03T21:58:29.061117+00:00**. The manager exited; three audits
at **21:58:34.912101**, **21:58:35.146237**, **21:58:35.382909 UTC** found all 16 owned
command groups empty and the lock available. Preexisting viewer PID 2598700,
PGID 2598689 and inventoried Xvfb displays remained unchanged. No heavy work is queued.

### Review files

- `evidence/Y/production-report.json` — actual identities, proofs, paired captures,
  preservation checks and measured scope.
- `evidence/Y/seven-corner-native-map.json` — complete source-to-native repair map.
- `evidence/native-import/native-proof.json` — strict new R7 native proof.
- `build-report.json`, `reopen-report.json`, `evidence/Y/master-inventory.json`.
- `evidence/Y/final-manifest.json`, `evidence/Y/release-receipt.json`.
- `evidence/Y/attempts/` — immutable command logs, source hashes, failure and ownership receipts.

**Next:** independent actual-artifact review, user/manual visual acceptance and
explicit parent shipping inventory decision. Full hosted mode journeys remain
pending. Any further engine work requires a new explicit heavy grant.
