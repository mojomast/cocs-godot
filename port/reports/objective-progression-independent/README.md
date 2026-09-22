# Independent objective progression and HUD acceptance

Runtime `ffa6aac`, integration of external follow-up `3a3799e`. The lead reviewed
the isolated adapter/HUD/renderer and reran both real normal-rate scenarios:

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
node port/native-objective-progression/run.mjs --map=tidal-citadel
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
node port/native-objective-progression/run.mjs --map=sunscar-convoy --small
```

Both **PASS**, with fresh owned source servers, a native primary and ordinary
opposing protocol player, private displays and unchanged source timing/rules.

| Mode | Evidence directory under `port/native-objective-progression/evidence/` | Accepted sequence |
|---|---|---|
| Tidal CTF, 1280×800 | `45c12f8c-de2d-486f-ad4d-b3d8b58f6e19` | Pickup/drop → defender return → second pickup → capture → 60s results → restart/fresh capture; **1,871 correlations** |
| Sunscar Payload, 960×640 | `b4803d47-bb7a-4e97-a5e7-83ce65b5f449` | Escort → **80 contested snapshots** → resumed push → checkpoint 1 → idle → 90s results → restart/fresh capture; **2,767 correlations** |

The validator requires source transitions, exact recipient/native objective
roots and matching round/sequence identities. Restart frees prior markers,
clears legacy HUD/capture/pose and resets source flags/checkpoints. Initial new
Payload distance uses the actual elapsed-time/source-speed bound: an ordinary
spawn near the cart can start escorting before its first snapshot. No artificial
zeroing, teleporting, altered ticks or forced results. ACK high-water is not
individual application proof; recording completion remains explicitly false.

The lead directly opened CTF capture/results and Payload contest/checkpoint/
results/restart PNGs. Panel-backed objective and combat HUDs are readable and
separate from the results scoreboard at both resolutions. Flags no longer
dominate the close-up; the inherited WEST CITADEL landmark is still oversized
at close range in these original captures. A later
[landmark-only correction](../landmark-label-independent/README.md) hides names
within 10 m; controlled far views remain byte-identical. Payload mesh presentation no longer masks the objective text.
The cart remains a simple bright model; human/art acceptance is separate.

Both summaries confirm native/display reaping and absence, server closed, zero
sockets and temporary runtimes removed. Native primary events are engine key/
mouse dispatch, not hardware/OS automation. The helper's second peer is an
ordinary protocol client, not another native rendering client.

The combined **57-gate verifier passes**, including new HUD/lifecycle33 and
replay/corruption10, original renderer19/adapter11/evidence8 and inherited
control-safety2,497. Original failures and accepted earlier slices remain
historical evidence. Full Payload delivery, live rollback, flag passing and
combat/death objective interactions remain open.
