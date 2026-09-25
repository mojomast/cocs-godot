# Cinderwake Drydock — scripted Horde development preview

Windows x64 and Linux x86_64 builds from the isolated
[`port/cinderwake-drydock`](https://github.com/mojomast/cocs-godot/tree/port/cinderwake-drydock)
branch. The authoritative source rules are pinned to the reviewed upstream
feature commit `48264858af820c69a833ef8b15c09ebac69e8cc3`. The packages'
manifests record their exact port and source commits.

## Play

- **Windows:** extract `cocs-native-windows.zip`; from its folder run
  `Play.cmd --experience=horde --map=cinderwake-drydock --waves=10`.
- **Linux:** extract `cocs-native-linux.tar.gz`, install Node.js 22.13+ and run
  `node run.mjs --experience=horde --map=cinderwake-drydock --waves=10` from
  `cocs-native-linux`.
- For a shorter route through the first transition, replace `--waves=10` with
  `--waves=3`. Use WASD and mouse for movement/aim; Space jump, Shift sprint,
  left click fire, F kick and Enter restart after results. The source-controlled
  bulkheads open after wave clears; walk to the lit destination to start the
  next wave. The E service spine is a separate always-open route.

## What has been checked

- Serial aggregate verifier: **188/188 gates passed** on the Cinderwake pin.
  Godot 4.5.2 import, source transition/ray rules and native gate collision
  fixtures passed. Rendered startup was observed at 960×640 and 1280×800.
- A normal-rate, ordinary-input three-wave session cleared waves 1–2,
  observed the source's three-second warning and BC gate opening, completed
  the grounded arrival hold in C, won wave 3 and restarted. A strict validator
  checked source event causality, rendered native gate state, hashes, input
  receipts, simulation pacing and cleanup (2,734 input receipts; 2,723 source
  samples in that run).
- A freshly extracted Linux package passed the full Linux package smoke suite.
  Its exported PCK passed the Cinderwake physical gate/ray test; the packaged
  launcher started the Cinderwake scene and a private Horde server, then
  stopped cleanly. The extracted Windows archive passed all **144** file hashes.

This is a development preview, not a completed ten-wave acceptance run. A
longer scripted attempt reached wave 5 after four natural clears but expired
before the second (C→D) arrival. Natural ten-wave/champion completion,
hardware feel and native Windows execution remain for owner testing. The
[implementation ledger](https://github.com/mojomast/cocs-godot/blob/port/cinderwake-drydock/port/native-identity-horde/CINDERWAKE_IMPLEMENTATION.md)
distinguishes live observations from controlled rule fixtures. Cinderwake is a
separate map; the earlier Nacre Engine Horde build and LATTICE preview keep
their own source pins and acceptance records.
