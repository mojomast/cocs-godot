# Independent standalone LATTICE command verification

Integrated commits: `bc1b0cf`, `c8bf56c`, `658b4e7`. The lead reviewed transport
identity/recipient projection and action reconciliation, then ran:

```sh
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
python3 -B port/tools/native_lattice_demo/verify.py --live --graphical
```

All eight cases pass. The private-Xvfb command includes `-nolisten unix` to use
abstract sockets on this machine. Evidence remains under
[`1790040145342561478`](../../native-lattice/evidence/1790040145342561478/results.json).

- 38 adapter and 10 UI assertions pass.
- Asterion and Monsoon each pass ordinary PvP and co-op source sessions.
- HOLD is observed as a running, server-accepted card, not a completed capture.
- PvP Fighter recruitment confirms a done card, one new Fighter and exactly
  **12 cumulative FLUX spent**. Passive income is not mistaken for purchase cost.
- The verification-only unsupported request produces genuine `no-sink` rejection.
- Disconnect clears state, actions and selection; owned native/server processes
  close at the end of each case.

These cases call real UI handlers, not physical mouse/keyboard events. A separate
physical-input/layout follow-up is assigned; it is not included in these claims.
The lead directly inspected both new PNGs and both original delivery PNGs.
1280×800 shows resources/objectives/receipts; at 960×640 the receipt text lies
below the initial viewport and requires scrolling. This is documented rather
than accepted as an all-visible compact layout. The later `ttl` HOLD rejection
in a final capture does not undo its earlier observed server acceptance, nor
does earlier acceptance prove objective completion.

The complete shared verifier also passes **46 gates** at `658b4e7` plus the
LATTICE gate/helper changes committed with this report. No source rules changed.
Full LATTICE world interaction, co-op economy, captures, results/restart, human
usability and native recording completion remain open.
