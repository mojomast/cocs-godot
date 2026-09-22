# Native first-person ADS / weapon-pose lane

Implemented in the primary checkout on source baseline `64da4bc`. Integration API: **[API.md](API.md)**.

## Delivered

- All ten source weapon GLBs now carry `SightRear`, `SightFront`, `OpticCenter`, `Muzzle0` (plus Scattergun `Muzzle1`), `GripRight`, `GripSupport`, and `GripReload`. The exporter reads the source builders' actual sight stations and chassis dimensions. Muzzles are children of the matching animated barrel assembly; reload grips are children of the feed.
- Native ADS solves the imported rear/front sight line onto the camera center ray. It uses the ten authoritative `ADS_PROFILES` enter/exit rates and source sight/magnification policy: integrated Rail Lance ×3.6 and Marksman ×3.0 scopes, iron sights for the other eight weapons.
- Animated hip → cheek-weld → hip poses, source-event recoil/recovery, switch lowering, authoritative reload pose and break-action barrel movement. Settled sights remain centered during idle/movement; recoil temporarily displaces them and recovers.
- A named `WeaponPose/ArmsRig/{RightArm,LeftArm}` hierarchy contains independently constrained wrists, elbows and forearms. Right wrist remains on the pistol grip; left wrist blends to the moving feed during reload, then returns to the fore-end. These are rigid articulated meshes with adjustable forearm spans and weapon-local elbow stations, not skinned full-body shoulder IK. Reload mechanics retain the native simplified feed/hinge animation; snapshot timing remains authoritative.
- Immediate hidden/dead/spectator/vehicle/focus/stale/round resets. Reload, source sprint posture, and source weapon-switch state reject ADS. Local `apply_aim` does not require snapshot ADS availability. Binding consumes `session.aim_requested()` and preserves Arms Race visuals when manual weapon selection is disabled.
- Animated muzzle world-transform/pixel APIs map the isolated viewmodel through the source camera, including its offsets. Barrel direction is physical `-Z`; ballistic convergence remains the source shot/FX integration's responsibility. `external_muzzle_fx` disables fallback flashes without disabling recoil.

## Verification

Pinned engine: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64` (4.5.2). Graphical runs used a private Xvfb display and private HOME/TMPDIR/XDG directories, OpenGL compatibility + llvmpipe. Logs and native captures: [evidence/run-01](evidence/run-01).

| Check | Result |
| --- | --- |
| Native graphical ADS fixture | **910 checks, 0 failures**, 160 numeric measurements |
| ADS timing/contract fixture | **93 checks, 0 failures**, all ten weapons at 30/60/120 Hz |
| Existing lifecycle/resource fixture | **57 checks, 0 failures** |
| Session/Arms Race/pointer policy fixture | **18 checks, 0 failures** |
| Existing hip framing/wall-depth fixture | **24 captures**, all ten clear the central 48×48 hip region |
| Deterministic source export verification | Ten GLBs byte-identical on re-export; source hashes verified |
| Fresh editor import and owned-path whitespace check | Passed; no script/import errors |
| Normal-rate stock-server native input | **Passed**: 435 snapshots, 34.27 m movement, Pulse + Rocket, 75 source recoils, actual reload, ADS enter/release |

The graphical ADS fixture captures **hip, enter, ADS, recoil, exit and reload for every weapon at both 960×640 and 1280×800**: 120 unmodified native PNGs. It uses the real game HUD and source GLBs. Checks include live grip contact, moving Scattergun muzzle/flash, source-world reprojection, HUD layer ordering, additional FOV 55/95 measurements, and target-gap alpha samples above the iron tip/through each scope. The separate live input probe emits engine physical-key/mouse events only and observes a normal-rate production server. Its six captures are labeled `live-*`; it does not pretend to provide live coverage of all ten weapons. Live median frame time was 33.33 ms under software rendering.

### Numeric maxima

From `metrics.json` (camera translated/rotated, with nonzero horizontal and vertical camera offsets):

- Settled rear/front sight center error: **0.0 px** at both sizes and tested FOVs.
- Settled sight-axis deviation from camera center ray: **0.0°**.
- Animated muzzle mapping error, source-camera projection versus isolated-camera projection: **0.00008632 px** maximum across hip/ADS/recoil/reload.
- Right grip contact error: **0.00000008941 m** maximum.
- ADS target-gap opaque pixels: **0** for all twenty weapon/size combinations. Iron posts terminate at the aiming point; the tested open target region is immediately above the tip, not the whole surrounding iron-sight silhouette.

### Review sheets

- [960×640: all ten hip / ADS](evidence/run-01/contact-960x640-hip-ads.jpg)
- [1280×800: all ten hip / ADS](evidence/run-01/contact-1280x800-hip-ads.jpg)
- [All ten animated pose sequences](evidence/run-01/contact-animated-poses.jpg)
- [Live Pulse ADS](evidence/run-01/live-pulse-ads.png)
- [Live Rocket ADS](evidence/run-01/live-weapon-1-ads.png)

Review sheets are labeled downscales of the native PNGs, generated with `tools/godot-weapons/ads-contact-sheets.mjs`.

## Reproduction

Use a fresh evidence output directory rather than overwriting this run. From the repository root:

```bash
node tools/godot-weapons/verify.mjs
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT" --headless --path godot --editor --import
"$GODOT" --headless --path godot --script res://tests/first_person/lifecycle.gd
"$GODOT" --headless --path godot --script res://tests/first_person/ads_contract.gd
"$GODOT" --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/first_person/binding.gd
"$GODOT" --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/first_person/ads.gd -- --evidence-out=/absolute/fresh/evidence-directory
"$GODOT" --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/first_person/framing.gd -- --evidence-out=/absolute/fresh/evidence-directory
```

For live input, run `node tools/godot-weapons/private-server.mjs`, use the printed ephemeral endpoint, then launch `res://tests/first_person/live.gd` with `--resolution 960x640`, `--endpoint=ws://127.0.0.1:PORT` and a fresh `--evidence-out` directory. The observer reuses the session's installed first-person binding.

Shared sessions should apply `get_aim_state(unzoomed_base_fov).fov` to their source camera and their HUD's reticle policy; the rig itself never writes input, camera aim, spread or damage. Set `rig.external_muzzle_fx = true` when the FX lane owns flashes.

## Retained environment failures

The first private Xvfb attempt (`-displayfd 1 -nolisten tcp`) could not create Unix listeners in the existing `/tmp/.X11-unix`; its full diagnostic is losslessly retained as `evidence/run-01/xvfb-unix-failed.log.gz`. A private TCP display `localhost:192` succeeded. The graphical logs contain the llvmpipe VSync-mode warning, with no script errors. An auxiliary contact-sheet attempt found Python Pillow unavailable (`ModuleNotFoundError: No module named 'PIL'`); the delivered generator instead uses the already-installed `sharp` dependency. No functional test failures were overwritten.
