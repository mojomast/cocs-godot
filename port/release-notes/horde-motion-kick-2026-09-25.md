# COCS: DESTINATIONS — Horde movement, hip-fire alignment and kick development build

Windows x64 and Linux x86_64 builds from port commit `e353522ac213abd06c2ce1cafbab6acbf764dee9`; source rules remain pinned to `515daf07589150dd3241f4ae1425cc1b093912f5`.

## Play

- **Windows:** extract `cocs-native-windows.zip`; run `Play.cmd --experience=horde --map=nacre-engine --waves=10` or choose **Native → Horde → Nacre Engine** in the menu.
- **Linux:** extract `cocs-native-linux.tar.gz`; from `cocs-native-linux`, run `node run.mjs --experience=horde --map=nacre-engine --waves=10` with Node.js 22.13+.
- Move with WASD. The shared first-person rig now points the hip-fire barrel toward the crosshair in Native and Horde. Press or hold **F** for a visible 0.19-second foot kick; the pinned source accepts repeated melee attacks at its 0.6-second cooldown. A kick animation follows a confirmed source melee event, including a miss, and does not invent damage.
- Horde-only source-paced camera translation and bounded catch-up smooth bursts of received snapshots; NPCs visually interpolate between authoritative positions. Native Deathmatch's existing camera policy is preserved. Use **F11** diagnostics if movement still feels uneven.

## Verification and feedback

- Final serial port verifier: **186/186 gates passed**. Focused geometry checks cover all ten weapons' hip barrel directions and sight paths. A rendered fixture showed the modeled boot and measured the Pulse Rifle hip barrel at about 0.73° from a distant crosshair target.
- Normal-rate Nacre Horde software-renderer trace: 8 seconds of ordinary held-W input, 640 source snapshots applied, 328 input ACKs, 34.1 m of camera displacement, and no observed step above the Horde render-speed cap. This is a software-rendered trace, not a measurement of the owner's hardware or subjective feel.
- Freshly extracted Linux archive passed 134 manifest-file hashes and 17 Linux package smoke cases. The extracted Windows archive passed all 141 manifest-file hashes and included the Horde adapter and Nacre data; native Windows execution awaits owner playtesting. The exported Linux launcher reached the Nacre identity-Horde scene with a loopback-only authority. Natural ten-wave/champion play and hands-on movement/kick feel remain open.

This is still the **Nacre Engine** Horde map. **Cinderwake Drydock**, the separate purpose-built scripted Horde map, is under construction; no staged transition is claimed in this build.

Please try both Horde and Native hip-fire, then hold F near a target and report how the kick cadence and foot visibility feel. In Horde, move through a busy wave and report any remaining camera jumps, especially after a short render stall. A F11 diagnostics capture and your GPU/resolution would help reproduce them.
