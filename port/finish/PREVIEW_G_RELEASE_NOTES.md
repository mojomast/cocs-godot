# The Quiet Relay — Fighting, Robots & Vehicles Test Preview

A fresh playable preview of the integrated changes. **This is a non-final test
build**, provided before the remaining production queue is complete.

## Download and play

**Windows 10/11 x64:** download `cocs-native-windows.zip`, choose **Extract All**,
then open the extracted folder and double-click **Play.cmd**. Godot and Node are
bundled; no development tools or account are required. Keep the extracted files
together. An OpenGL 3.3-compatible graphics driver is required.

- **Fighting:** choose **FIGHTING** on Home, then AI, local versus or training.
- **Campaign:** choose a chapter on Home or launch **Campaign.cmd**.
- **Vehicles:** choose **Combined Arms / Sunscar Convoy** from Home.
- **F12:** Settings and return-to-Home controls in the FPS modes.

Fighting keyboard defaults: P1 uses **WASD** to move, **F/G/H** for attacks,
**R/T/Y** for special/mobility/grab, and **C/V/B** for guard/dash/super.
P2 uses arrows, **J/K/L**, **U/I/O**, and **N/M/P** respectively.
Use the fighting move list and bindings screen for details; **Esc** pauses.

**Linux x64:** extract `cocs-native-linux.tar.gz`, open its folder, and run
`node run.mjs --experience=menu`. Node 22.13 or newer is required on Linux.

## Included changes

- Nine-operator fighting mode with actual animated rigs, four stages, AI/local/
  training options, responsive camera and controller-recovery improvements.
- Three produced robot skins and six Emberline service props.
- Authored Puma, Titan and Scout models with three LODs each.
- Refined map/operator finishes, restored Foundry lights and Parallax interiors.
- Compact vehicle HUD layout correction and previously integrated gameplay,
  accessibility, replay and multiplayer changes.

## Preview scope

Three production units are package-approved: Parallax interiors, robots and
vehicles. New four-chapter scenery integration and Vesper Viaduct, Abyssal
Pressureworks and Stormglass Causeway remain outside this preview. Existing
campaign scenery remains available. Cinematic v3 is also pending.

This build does not claim completion of the final 142-job acceptance matrix,
physical-controller/accessibility review, real-driver audio checks, full campaign/
Horde completion or hardware-GPU performance testing. Please report crashes,
control issues, camera problems, clipping and performance observations with the
mode/map, operator or vehicle, resolution/UI scale and reproduction steps.

**Known verification issue:** the broader Windows suite timed out waiting for
Helix Conservatory deathmatch startup. That case is under investigation. The
same run passed all 23 baseline cases (including Home and all four Campaign
chapter smoke checks) and all six Parallax mode startup checks. This preview
does not claim that the broader suite passed.

## Build identity and checksums

Both archives use candidate `cb6e4c9f6bff09aafe4d9ef6262c5996a6219329`.

```text
4072b99b82902da9c46f348edb3d185b280ab62d4ded5e717e093cc2cd25089c  cocs-native-windows.zip
9fe22e32e227b235f52255de8b69f04398095dd22615401b07f6e57623612c02  cocs-native-linux.tar.gz
```

Fresh extraction and recorded-commit artifact checks passed for both archives.
The extracted Linux build passed the declared resource/nine-rig probe, graphical
Home → Fighting AI/local/training → Home, Rootfall Campaign smoke and graphical
Sunscar vehicle startup. Windows recorded-artifact validation and source preflight
passed. Focused graphical Windows Fighting/vehicle checks are recorded separately
before this draft is published. Existing releases remain available.
