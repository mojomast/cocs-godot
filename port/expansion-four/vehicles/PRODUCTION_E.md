# Vehicle production E — parent review handoff

Actual Blender 4.5.14 / Godot 4.5.2 production, October 2–3, 2026.
This supersedes the earlier source-only vehicle delivery. Parent promotion and
full release acceptance remain separate. The fixed package receipt deliberately
retains `accepted:false`.

## Delivered and measured

Nine `.blend` masters, nine GLBs, nine recipes and nine builder reports are
committed. Post-modifier GLB triangles (also checked after native import):

| Vehicle | LOD0 | LOD1 | LOD2 |
|---|---:|---:|---:|
| Puma | 35,688 | 7,424 | 1,900 |
| Titan | 60,900 | 13,044 | 3,256 |
| Scout | 33,064 | 6,640 | 1,696 |

Total **163,612 / 456,000 configured aggregate cap**. Masters were independently
reopened and exports reimported. Reviewed palette roles use selective normals:
alloy has its bound normal texture, coating/rubber/fabric retain authored normals.
The first export was inspected before bulk production: a single UV stream serves
both base and alloy normal textures. Generic receipt validates actual embedded
images and source fingerprints across all nine outputs.

The package receipt at `tools/godot-package/production_receipts/vehicles.json`
binds **38 dynamically discovered package inputs**, nine masters, nine exports,
and six production runtime hooks. No production hook changed during E; there
are no newly changed robot/Parallax supporting-hook paths to reconcile.

## Executed gates

- Recipes, baseline import and genuinely asset-absent procedural fallback ran
  before the first vehicle build; fallback is a separate counterproof.
- Required-assets native gate: three rigid LODs per attachment, imported bounds,
  ground contact, muzzle transforms, wheel axes, materials, team ownership and
  controlled wet restoration. Scout's source envelope retains the documented
  1 cm wheel-side tolerance.
- Controlled 64-instance native lifecycle, atomic rejection of 65 and weak-ref
  retirement passed. This headless test is not GPU performance evidence.
- Final **serialized three-case connected run** passed on accepted
  `sunscar-convoy` / `combined-arms`. Each uses three real graphical native clients,
  physical controls, public create/join/loadout/host protocol and the ordinary
  source clock. All nine installed meshes are required, identity-checked and
  compared against recipient snapshots.
- Each case: driver mount, boost, bend, reverse, stop/brake, driver fire,
  mixed-team driver takeover while wet, restoration, passenger fire, ordinary
  damage, Codex reboard/repair, wreck, source respawn, natural results and Enter
  rematch cleanup. Puma/Titan additionally prove gunner fire; Scout correctly has
  no gunner. Personal fire accepts the actual source `shot` or `launch` event.
- No source pose, health or score writes. Damage is applied to an empty chassis
  before Codex reboarding because source hit selection can strike exposed crew.
- All nine final-run native children closed gracefully with exit 0, drained
  streams and no late errors/forced kills. Stage executor receipts record bounded
  commands and owned process-group cleanup.
- Final pure source/input-contract suite: **22/22**; Python AST passed.

## Evidence and visual review

`production-e/` contains final outcomes/stages, process receipts, imported native
checks, current generic receipt, inspection screenshots and a hash index of the
full external evidence tree. Full logs, snapshots, wire events, camera timestamps
and failed attempts remain under:

`/home/mojo/.tmp-on-disk/cocs-expansion-four-vehicles-evidence-20261002/production-e`

Final all-kind stage: `20261003T003539.486740Z/connected/journey-XWETCy`.
Compact Titan UI150 case: `20261003T001743.325786Z/connected/journey-70cXxA`.
Final native/stress: `20261003T003535.707648Z`.
Final inspection: `20261003T002957.415954Z`.

Close inspection captures all three LODs at equal scale, plus actual camera
distances 22/26 and 63/67 m around the 24/65 m transitions, and rear views.
Puma's open gun-truck body, Titan's tracked siege hull and Scout's compact cage
remain distinct. Sloping cowl/glacis and receiver geometry were refined after
the first inspection and rebuilt before the accepted journeys.

Gameplay frames are actual captures with source time, engine frame, wall ticks,
viewport and camera position in `VEHICLE_CAPTURE` records. Software-rendered
journeys disable shadows and use 50% 3D resolution; these are not GPU-speed or
full-quality performance claims. Weather is a controlled live-target material
probe, not natural map rain evidence. UI150 and wide captures are provided for
parent review; human visual approval, Windows/package execution and final
performance acceptance remain open.

Failed runs are retained, including missing semantic content, navigation-node
orbits, early source/native seat phase advancement, headless mouse-capture
ineligibility, approach overshoot, projectile event naming, exposed-crew damage
and a source-clock/wall-clock timeout. Fixture fixes were followed by the final
all-kind run; production controls and stock simulation were preserved.

## Reproduction (requires a new exclusive heavy grant)

Run from this checkout, with dependencies available:

```sh
COCS_SOURCE_DERIVATIVE=port/contracts/lattice-catalog-derivative.json node tools/godot-export/semantic.mjs
python3 tools/asset-production/run.py --unit vehicles --stage native --granted --evidence-root "$EVIDENCE"
python3 tools/godot-vehicle-assets/production.py journey --kind=all --granted --evidence-root "$EVIDENCE"
python3 tools/godot-vehicle-assets/production.py journey --kind=titan --compact --granted --evidence-root "$EVIDENCE"
python3 tools/godot-vehicle-assets/production.py inspection --granted --evidence-root "$EVIDENCE"
```

The vehicle wrapper uses the shared nonwaiting lock and owned-stage executor.
Safe source checks: `node --test godot/tests/vehicle_assets/{source,journey}.test.mjs`
and `node tools/godot-vehicle-assets/journey.mjs --plan`.
