# COCS: DESTINATIONS — Playable Menu & Upgrades

A development prerelease for Windows x64 and Linux x86_64, with the unified game menu and the reviewed loadout, Horde-upgrade and LATTICE improvements in one build.

## Download and play

- **Windows:** download `cocs-native-windows.zip`, right-click → **Extract All**, open `cocs-native-windows`, then double-click **Play.cmd**. Godot and Node runtimes are included; no editor, npm install or account is needed. Do not launch from inside the ZIP.
- **Linux:** install **Node.js 22.13.0 or newer**, extract `cocs-native-linux.tar.gz`, enter `cocs-native-linux`, and run **`node run.mjs`**. The Godot runtime is included.
- Both require an OpenGL 3.3-compatible graphics driver. Local bot matches work offline.
- For a quick first match: **Native → Native Deathmatch → Start**, then start the match in the native setup screen. Closing the game window returns to the menu; **Quit** exits.

WASD moves; mouse looks; left click fires; right click aims; Space jumps; Shift sprints; R reloads; number keys/wheel switch weapons. Escape releases the mouse rather than quitting the match. Use F9 to lower combat effects if needed.

## What changed

- One in-game menu with Play, Native, Modes, Extras and Cheats categories, route options, match launch, return-to-menu and clean shutdown.
- Operator/harness controls in source combat setup and multiplayer lobby. Native-arena modes retain their restricted loadout rules.
- Horde upgrade offers are selectable through numbered buttons or matching keys, with authoritative applied/refused feedback.
- LATTICE shows authored links, supply status and next-target guidance without exposing hidden information. Guidance is advisory; the server owns legality.
- Preserved native arena combat, Domination, blood/fluid effects, detailed weapons, source operators and graphics showcases.
- Corrected native-arena client signature compatibility and hardened test/process lifecycle handling.

## Verification and limits

The integrated runtime source passed all **167 canonical gates**, ten additional original-checkout smoke gates, and independent reviews. A real source-launcher menu → native Deathmatch → menu → Quit journey passed on a private Linux display. Release-archive test results are attached/linked on the GitHub release after they finish; source tests alone are not packaged-platform acceptance.

This remains a development prerelease, not a finished game. Natural complete Horde/LATTICE rounds, full Arms Race ladder completion, persistent settings, local movement prediction and campaign are outside this release's completed scope. Horde's upgrade wire test uses an accelerated reward offer, not a natural ten-wave run. Linux rendered verification uses software rendering; hardware-GPU performance and audio quality require testing on your computer.

The source asset-rights audit remains unresolved; this package does not establish or grant new rights to original assets. Existing Godot, Node and ws notices are retained. Each download has a `.sha256` sidecar and includes a manifest with source/runtime provenance and file hashes. Previous releases remain untouched.
