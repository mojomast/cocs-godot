# Gameplay repair O — two gates repaired

Grant `GAMEPLAY-REPAIR-20261003-O`; owner `ses_f0294303bffed6Fb8UJLKe4ZDz`.
Adopted `17807ab977cacb4d2a43d2621999b143fb597a2c` as merge `a8494ece`.
Runtime/fixture candidate: `f22fcc1e95c0b890f1ad656f16ab2b406b5b069b`.
Evidence: `/home/mojo/.tmp-on-disk/cocs-gameplay-repair-O-20261003`.
No child agents. All native invocations used the shared nonwaiting acceptance
lock, bounded process groups, isolated user data and `LP_NUM_THREADS=1`.
Each job has candidate/source/cache identity and cleanup in `receipt.json`.

## Ordinary world vehicle

`world-01`/`world-02` show valid focus, fresh snapshot, live phase, no overlay,
empty mapper release ledger, yet pointer capture stays released. Actual GUI hit
testing identifies the click at (500,350) inside PlayerAbilityReadout and its
label, both MOUSE_FILTER_STOP while released. This is intentional scrollable UI
ownership, not authority, epoch, ACK, or physics failure. The fixture now clicks
the uncovered world at viewport-relative (0.85,0.5). No synthetic packet,
actor warp, authority pause or deadline modification.

The strengthened Home check found a real runtime defect: the button labeled
"Leave match · Return Home" called quit. `f22fcc1e` hides the panel, clears its
old focus reference and defers the ordinary scene transition to Home instead.
The journey now opens F12 and clicks that real button, asserts the Home scene,
and captures it. It no longer directly changes scenes on behalf of the user.

Clean committed-candidate receipts:

- `world-final-01`: ordinary approach, E mount, source driver relationship,
  W drive in both F4 views, mouse look, E demount, F12/Return Home all passed.
- `combined-home-regression-01`: same full journey passed separately on the
  combined-arms route. It is not substituted for the world route.
- Both retain `artifacts/native.json`, `wire.json`, `teardown.json`, native logs
  and infantry-approach/third-person/first-person/demounted/Home PNGs.

Earlier full-journey attempts exposed missing vehicle import cache artifacts.
Restored only absent artifacts from the acceptance checkout after checking
source asset bytes match; manifests `*cache-restored.json` retain SHA-256s.
No GLB/assets/import settings changed and no asset reimport was run. Metadata
blocking the initial merge was preserved under `premerge-metadata/` with hashes.
Fallback UID warnings remain on restored binary resources; strict scans found
no engine errors or leaks in final journeys. This is llvmpipe evidence, not
production-GPU/full-speed visual acceptance.

## Controls: actual texture attribution and owned disposal

`controls-baseline-correlated-01` replays the canonical fixture (retained as
`baseline_controls.gd`) and correlates **GL IDs 28/29** to six cubemap faces each,
128x128, GL_RGB10_A2 / GL_UNSIGNED_INT_2_10_10_10_REV. Neither handle is deleted;
both appear verbatim in the 87,380-byte leak errors. They are not 2D UI icons.

The weak owner probe identifies `session.style.atmosphere.env.sky` and the Arms
equivalent, radiance size 128. Godot 4.5's
`drivers/gles3/rasterizer_scene_gles3.cpp::_update_dirty_skys` allocates the
paired sky radiance/raw-radiance cubemaps; `_init_radiance_texture` accounts each
using Image::get_image_data_size(128,128,RGBA8,true), exactly 87,380 bytes.
The fixture constructed and freed both owners before their dirty-sky rendering
transaction. The first actual render then allocated orphaned backend textures.

`5235e5f4` completes frame_post_draw **while each fixture-owned session is still
alive**, then frees it normally. This is an ownership-order correction at the
render boundary, not a sleep, global resource free, renderer setting, or scan
exception. All original 90 assertions remain intact.

- `controls-fixed-gl-01`: same handles 28/29 allocated AND deleted, 90/90,
  zero leaks. `correlation-summary.json` joins native GL allocation/deletion.
- `controls-fixed-01` and committed-candidate `controls-final-01`: stock binary,
  no GL interposer, 90/90, clean exits.
- All failed attempts remain. `controls-gl-02` was a diagnostic interposer
  crash (incorrect dynamic-symbol lookup), not a product result; corrected
  interposer source/binary and subsequent successful attribution are retained.

The production source authority, combat stats, deadlines, assets, fighting,
package pins and admission harness are untouched. Only runtime change is the
advertised Settings Return Home action. Parent must reconcile exact package
runtime pins for `f22fcc1e` before packaging; no wildcard is appropriate.

## Scope and release

These are focused repairs, not final-142 acceptance. Campaign performance,
Horde, live-kick, audio/device/human/Windows obligations remain as recorded by N.
Three empty ownership audits and explicit O release are recorded in external
`HEAVY_GRANT_RELEASE.json`. No next-owner execution is authorized by these tests.
