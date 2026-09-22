# Independent LATTICE world-command integration

Integrated `7439f055e55e0f4a43e856a2b96f916606e1f437` as `511bb8d`.
The lead independently reran the owned suite against the integration checkout:

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  python3 -B port/native-lattice-world-commands/verify.py
```

[Evidence](../../native-lattice-world-commands/evidence/1790048714008175713/):
**8/8 cases pass**, including semantic export/import, existing traversal contract,
27 new boundary/consent checks, both command panels and both traversal observers.
Asterion passes 25 native checks and the external audit: one player connection,
HOLD executed by source, exactly one Fighter request, 12 cumulative FLUX spent
and one additional source actor. Monsoon passes 20 native checks: HOLD executes,
and recruitment is correctly unavailable outside the between-wave window.
There is no new live co-op purchase or local-capture claim.

Directly opened `commands-small/commands.png` (960×640) and
`commands-large/commands.png` (1280×800). Objective selection, budget, receipts
and return-to-play instructions fit both panels. The background diagnostic HUD
is dimmed, and command controls remain legible. ACK is labeled as a high-water
receipt, separate from source events and resource/spawn changes.

## Exported-client check

The lead rebuilt the Linux package at `511bb8d` and independently extracted it
into a fresh directory with Node as the only developer executable on PATH.
All setup/combat/world, window-close, interrupt, native-crash and missing-binary
checks pass. See [export evidence](../linux-world-commands-independent/).

The optional `--world-commands-capture` verifier flag sends a real X11 **C** key
through XTest to the exported world window. The resulting
[`lattice-world-commands.png`](../linux-world-commands-independent/lattice-world-commands.png)
was directly opened: it shows the actual tactical panel and the correctly closed
co-op recruitment window. This is an exported UI-opening check, not exported
command execution or human/hardware acceptance.

Archive SHA-256:
`992284f3e5aa254ccab1a66a4905a83f6a1a2bd027d1511dcb1682750dd7b0ae`.
Build result:
`/tmp/opencode/lead-native-linux-package/builds/1790048738739943824/build-result.json`.
This archive predates the subsequently integrated sports coaching changes.
