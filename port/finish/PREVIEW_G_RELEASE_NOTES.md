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

## Build identity and checksums

Both archives use candidate `9857b33ef32025e360f05fa1c611b3e3747a9481`.

```text
c20d89175dd103c53fc15a6c8a7133a32738127b597e6063bdf082bca167586b  cocs-native-windows.zip
83a7e7012c10a8772014d720b0bf2b29d313ccfea0e2414ee213e1c0d1743709  cocs-native-linux.tar.gz
```

Fresh extraction and recorded-commit artifact checks passed for both archives.
The extracted Linux build passed the declared resource/nine-rig probe, graphical
Home → Fighting AI/local/training → Home, Rootfall Campaign smoke and graphical
Sunscar vehicle startup. Native Windows verification is recorded separately
before this draft is published. Existing releases remain available.
