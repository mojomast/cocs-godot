# Independent combined native weapon-selection acceptance

Executed at `3a049d5`, including compact HUD, world/environment, entities,
procedural audio and prior input lifecycle fixes:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/native-weapon-selection/run.mjs --output=/tmp/opencode/weapon-selection-independent
```

Exit 0, `status=PASS`. The runner independently passed the 64-assertion graphical
actual-session regression, then the real native route/rocket pickup and five
requested authoritative switches. It observed **470 received inputs**, including
**14 weapon-bearing packets**. Exact request protocol sequences, transitions,
events, runtime hashes and cleanup are in `summary.json`; ACK high-water is not
proof of each intermediate command's application.

The run used the unmodified normal-rate source, private copied runtime and owned
Xvfb. Native code drove physical keys/wheel/mouse through the input API, including
held-key suppression across release/recapture. No authority snapshots were
injected. `native.log` is an intentionally filtered excerpt, not a complete
native trace. Native recording completion remains unproven.

The lead opened `native.png`: the actual combined HUD, reticle and environment
are visible; the final display shows the authority-selected Pulse Rifle. This
still image alone does not prove the switch sequence; the live runner assertions
and retained authoritative events provide that evidence.
