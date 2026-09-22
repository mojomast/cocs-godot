# Independent LATTICE native world traversal

Delivery `c1d13c0` integrated at `6116f12`. The lead reviewed standalone session
composition, recipient-only transport guards, actor projection and public node
markers, then ran:

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
python3 -B port/native-lattice-world/verify.py
```

**PASS**, source/semantic export, import, contract18 and two private graphical
normal-rate sessions. Evidence:
`port/native-lattice-world/evidence/1790045105721086042/`.

| Case, 1280×800 | Maximum source displacement | Final public-node distance | Exact render/socket samples |
|---|---:|---:|---:|
| Asterion / cocs | 56.075 m | 0.005 m | 444 |
| Monsoon / cocs-coop | 59.037 m | 2.316 m | 469 |

Each passes **17 native input checks and eight external checks**: received
movement, ACK high-water, actual actor/camera coordinates, recipient actor set,
own budget only, no command frames and ordinary host configuration. Escape
neutral stop, held-W recapture blocking and release/fresh-click resume pass.
Both finish within 20 seconds, close their owned servers/native children and
remove temporary runtimes; ports independently rechecked closed.

The lead directly opened both walk images. Asterion's geometry, public labels
and authoritative camera are visible. Monsoon's final image shows the player
**dead near the front node**, surrounded by source-visible enemy actors; its
HUD reports HP0 and the source respawn countdown. The successful approach
checks do not imply survival or capture. Public captures in these two runs
list **bots**, not local actor 0, as participants. No local capture is claimed.
The agent's earlier separate local-participant observation remains historical.

The scene consumes only its recipient socket. The locked source currently
includes enemy positions in that stream; native rendering does not reconstruct
withheld actors or read omniscient simulation state. Public PvP nodes lack y/r;
label elevation uses static authored support height, with no invented radius.

## Common launcher

```sh
PORT=0 node tools/godot-dev/launch.mjs --experience=lattice-world --map=asterion-relay --mode=cocs
PORT=0 node tools/godot-dev/launch.mjs --experience=lattice-world --map=monsoon-foundry --mode=cocs-coop
```

Both maps permit cocs/cocs-coop. Existing `--experience=lattice` remains the
command board. World movement uses inherited infantry controls; click to
engage, Escape to release, release action keys before fresh-click recapture.
This world slice has a diagnostic HUD and no tactical command widget yet.

Five routing regressions pass. A separate real-editor startup/cleanup probe
checks **all four world map/mode combinations** through the common launcher:
`port/native-launcher/evidence/1790045153865842451/summary.json`.
It adds only headless/quit-after flags; all children exit and ports close.
Startup checks are separate from the two graphical traversal cases above.

The new contract18 gate participates in the **62-gate combined PASS**. No full
strategy victory, co-op campaign, native multi-client world, OS-device/human
acceptance or recording-finalization claim is made.
