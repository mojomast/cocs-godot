# LATTICE Strike flagship — development preview

Windows x64 and Linux x86_64 packages built from runtime commit `fb7ac021` on
the isolated [`port/lattice-flagship`](https://github.com/mojomast/cocs-godot/tree/port/lattice-flagship)
branch. Source rules remain pinned to `515daf07589150dd3241f4ae1425cc1b093912f5`.
This preview is for hands-on evaluation; the eight-human acceptance rung has
not been run.

## Start

- **Windows:** extract `cocs-native-windows.zip`; run `Play.cmd` and select a
  LATTICE World route. From Command Prompt, a direct PvP example is
  `Play.cmd --experience=lattice-world --map=asterion-relay --mode=cocs --bots=2 --time-limit=900`.
- **Linux:** extract `cocs-native-linux.tar.gz`; from `cocs-native-linux`, with
  Node.js 22.13+ installed, run
  `node run.mjs --experience=lattice-world --map=asterion-relay --mode=cocs --bots=2 --time-limit=900`.
- For Operations, use `--map=monsoon-foundry --mode=cocs-coop` with the same
  `--experience=lattice-world` launcher. Shared-session setup and host/guest
  constraints are tracked in the branch's LATTICE flagship handoffs.

## Evidence and feedback

Pinned import, four Godot fixtures, 189 Node contracts and 20/20 ordinary
socket-seat floor cases passed. Engine-scripted ordinary-input PvP rounds on
Asterion and Monsoon ended in source dominance wins and restarted. A complete
Monsoon Operations run reached 900 seconds and source defeat after **4/5 waves**;
a five-wave victory was not established. Two independent native clients were
observed moving in a shared round, but shared full-round results/restart and
human participation have not been verified. Extracted Linux routes and menu
passed startup checks; all 141 Windows package hashes passed, while Windows
native execution remains for a Windows host.

Please test map readability, Board choices and legal target guidance on your
hardware, then schedule an eight-human session for the final acceptance rung.
Record a full match result and restart on both modes before treating MVP-A,
MVP-B, MVP-C1 or MVP-C2 as accepted. The full evidence classification and open
cases are in [`ACCEPTANCE.md`](https://github.com/mojomast/cocs-godot/blob/port/lattice-flagship/port/native-lattice/flagship/ACCEPTANCE.md).
