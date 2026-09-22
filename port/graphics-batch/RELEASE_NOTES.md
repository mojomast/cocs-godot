# COCS: DESTINATIONS — Native Graphics Demo

A new Windows x64 demo with three explorable native maps, restored Moth graphics,
first-person weapons, and interactive shader/particle laboratories.

## Play

1. Download **cocs-native-windows.zip** and extract the entire archive.
2. Open **Graphics Showcase.cmd** for the five new experiences.
3. Open **Play.cmd** for a bot match, or **Demo Menu.cmd** for other game modes.

Godot and Node are bundled. Windows 10/11 x64 and an OpenGL 3.3-compatible driver
are required; local play needs no editor, installation, account or internet.

## What’s new

- **Prism Foundry:** a reactor atrium, turbine hall, coolant garden, raised loop
  and observation deck.
- **Aurora Basin:** a frozen lake, ice arches, polar observatory and elevated
  skywalk beneath animated aurora curtains.
- **Cinder Array:** a volcanic caldera, suspended bridge, extractor gantry,
  basalt tunnel and elevated deck.
- **Particle Observatory:** four effects, two clearly labeled backends, and
  selectable **8K / 32K / 128K / 512K / 1M** particle counts. The default is 32K.
- **Moth Shader Gallery:** interference-shell, flowing-energy and phase effects
  with interactive pause, orbit, intensity and transition controls.
- **Existing gameplay:** ten source-derived first-person weapons, restored Moth
  materials/effects, nine-map atmosphere and bounded scenery. **F8** cycles scenery
  detail. The original nine maps and source gameplay modes remain available.

## Controls

New maps: **WASD / mouse**, **Shift** sprint, **Space** jump, **R** return to spawn,
**Escape** release mouse, **click** recapture. Close the window to return to the menu.
Prism also offers **P** photo views and **F1** help. Lab controls are shown on screen.

Combat: **WASD / mouse**, **left click** fire, **R** reload, **1–9 / 0 / wheel**
weapons, **Tab** scores. Click the window to engage controls. Full instructions
are in the archive’s README and `port/native-windows-package/PLAY.md`.

## Acceptance and limits

The new maps are unarmed exploration showcases with native collision. They are
additional experiences; campaign remains deferred.

Native Linux graphical tests exercised actual OS keyboard/mouse input, focus
loss, capture, scene cleanup and all five new experiences. The million-particle
experiment genuinely rendered 1,048,576 GPU-simulated slots and 2,097,152 particle
triangles. On software llvmpipe it measured about **462 ms/frame**; the 32K galaxy
case measured about **18 ms median**. These are software-renderer observations,
not hardware GPU performance claims. Use the lab’s measured cadence and count
controls on your own machine.

Candidate third-person operator models remain preview-stage. Windows graphical,
audio and human usability acceptance, broad gameplay scenarios and hardware
performance remain open. Detailed evidence and inherited gameplay gaps are in
`port/graphics-batch/README.md` and `port/RELEASE_MATRIX.md`.
