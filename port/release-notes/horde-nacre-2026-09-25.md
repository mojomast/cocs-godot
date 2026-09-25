# COCS: DESTINATIONS — Nacre Engine Horde development build

Windows x64 and Linux x86_64 playable builds. Source rules remain pinned to
`515daf07589150dd3241f4ae1425cc1b093912f5`.

## Play

- **Windows:** extract `cocs-native-windows.zip`, run `Play.cmd`, choose **Native → Horde → Nacre Engine** and press Start. You can also run `Play.cmd --experience=horde --map=nacre-engine --waves=10` from Command Prompt.
- **Linux:** extract `cocs-native-linux.tar.gz`, install Node.js 22.13+, then run `node run.mjs --experience=horde --map=nacre-engine --waves=10` from the extracted directory.
- Select an operator and harness in the Horde menu. Claude requires Claude Code. Move with WASD, fire with LMB, use Q power/X mobility, switch weapons with 1–9/0 or the wheel. On an upgrade offer, use its numbered button or matching number key; Enter restarts after results.
- F9 cycles combat effects; F10 shows effect metrics; F11 toggles diagnostics. Local cheats are opt-in from the menu or `COCS_DEBUG=1`, not in multiplayer.

Nacre starts in the southern service bay and has two connected supply wings and
a northern heavy-weapon yard. Scattergun opens on wave 1; Plasma, Shock,
Rocket and Flak open on waves 3, 5, 7 and 9. The signs and Horde strip show
which caches are ready. Source waves, enemy damage, lives, pickups, upgrades,
results and restart remain authoritative; the new gates are local-only.

## Verification and feedback

The serial port verifier passed 185/185 gates. A software-rendered natural
three-wave run defeated 12 enemies with three lives, showed the wave-3 cache,
reached results and restarted. Accelerated source wave transitions proved the
five cache unlock points through wave 10. A natural ten-wave boss completion,
human feel/audio and hardware-GPU Nacre performance still need a playthrough.

The owner's separate Prism Foundry 12-bot RTX 4070 Laptop GPU benchmark at
1280×800 measured **High** preset, 88.8 median-derived FPS and 16.677 ms p95,
with 95% input-control coverage and a partial verdict. That is a useful
hardware reference for this build; it is not a Nacre or Extreme measurement.

Please play Nacre at ten waves and report whether the cache progression, wave-9
champion, upgrades, movement/barrel alignment and difficulty feel right. If you
run the F7 benchmark in Horde, share its `BENCHMARK_RESULT` and the selected
quality setting.
