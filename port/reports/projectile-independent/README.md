# Independent native projectile verification

Runtime: `23530f1`; the lead added `--output=` support to preserve source-agent
evidence and a shared projectile regression gate. Pinned Godot 4.5.2, owned
normal-rate source authority, scripted native input and private Xvfb.

```sh
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
node port/native-projectile-combat/run.mjs --output=/tmp/opencode/projectile-independent
```

The overall attempt is **FAILED** because its fourth Deathmatch pickup route
timed out. All evidence remains in `attempt-01/`, including its summary and
source hashes. The first three Rocket Arena cases passed independently:

| Map | Local launches | Explosions | Source-position mesh samples | ACK |
|---|---|---|---|---|
| Meridian | 17 | 28 | 549 | 603 |
| Verdant | 16 | 30 | 1,015 | 611 |
| Ember | 15 | 25 | 1,645 | 749 |

Each observed zero ordinary shots, real source movement and visible projectile
geometry during 14 seconds of gameplay. Native local launch counts equal the
server event counts. The lead opened all three PNGs; local rocket exhaust and
the compact Rocket Launcher/unlimited-ammo HUD are visible. Explosion events
and flight samples are separate; projectile disappearance is not treated as an
explosion or hit. This is bounded graphical acceptance, not full-round or human
audio acceptance. Recording completion remains unproven.

The fourth case stalled at `[8.002, 5.008]` en route to `[8, -6]` after starting
from the south-side route. Captured/focused remained true. The borrowed planner
only checks boxes, missing source support geometry. No gameplay rule or actor
state was altered; a harness-only follow-up is assigned to the original agent.
All children were reaped and the server closed with zero sockets after failure.

## Host smoke and graphical menu

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
node port/native-projectile-combat/smoke.mjs --output=/tmp/opencode/projectile-host-independent

PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/native-match-selection/run.mjs --menu-only --menu-mode=rockets --output=/tmp/opencode/rocket-menu-independent
```

All three actual host-scene smokes pass: one local launch, zero ordinary shots,
six health/armor markers, movement and ACK 15/16. The graphical menu case uses
physical keyboard selection and mouse Start, proves no connection before Start,
and observes source Verdant/Rockets after connection. Its PNG was independently
opened; mode text, instructions and Start fit the viewport. `menu/` preserves
the result/log/image. Other map identities remain pending in setup.

`rocket-verification.json` preserves the **43-gate full pass** before sports
polish integration, including 27 projectile assertions and prior shared features.
