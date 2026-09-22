# Native match selection increment

Based on `d06b681`, branch `native-match-selection`. Original Node game rules remain authoritative; this is a pragmatic native setup UI and infantry capability subset.

## Available now

- **Meridian Exchange, Verdant Reliquary, Ember Crucible**: **Deathmatch / Instagib**.
- `--setup`: host-only map/mode dropdowns and Start. No WebSocket connection, room request, or handshake timeout until Start.
- `--map=verdant-reliquary --mode=instagib` (also space-separated values): immediate host launch with explicit locked IDs.
- No selection arguments retains automatic Meridian Deathmatch, two bots, existing smoke behavior.
- Existing `--join-room=ID` remains available. Guests can add `--map=ID` to match a combat-map host; `--mode` and `--setup` are host-only.
- All nine locked map identities and their actual catalog modes remain visible. Pending selections disable Start. Invalid/pending CLI choices display an error before connecting; smoke invocation also exits nonzero. No fallback substitution.
- Gameplay HUD controls ignore mouse input; the setup panel is hidden before connecting. Round boundaries, respawn/focus freshness gates, and bounded opt-in trace behavior retain their existing logic.

Only the two free-for-all infantry modes are enabled: both use the existing movement, firing, health/frags, actor lifecycle, and remote-pose presentation. Team/objective/loadout modes, race, soccer and LATTICE are pending native presentation/control verification. Instagib deliberately has zero authoritative pickups, reflected in its mode-aware smoke assertion.

## Launch / integration handoff

With an owned local source authority listening, invoke the session directly:

```sh
"$GODOT_BIN" --path godot res://world/session.tscn -- \
  --endpoint=ws://127.0.0.1:PORT --setup

"$GODOT_BIN" --path godot res://world/session.tscn -- \
  --endpoint=ws://127.0.0.1:PORT --map=ember-crucible --mode=instagib
```

**Lead integration requirement:** `tools/godot-dev/launch.mjs` currently consumes only its existing flags and does not forward selection options. Forward `--setup`, `--map`, `--mode` (including their following values), and treat setup as a gameplay-session launch. That launcher and full `verify.py` are outside this agent's assigned ownership.

Viewer integration still expects `label`, `selector`, `camera`, `ids`, `current_id`, `world`, `catalog`, and `load_map(id)`. `label`'s parent is a Control under a CanvasLayer; the setup panel is attached to that CanvasLayer. `world/StaticPickupMarkers` is hidden after each session map load. Keep the existing `can_capture_pointer` immediate-window-focus and healthy-authority lifecycle behavior when merging other presentation work.

Presentation follow-up: Instagib uses the authority's unlimited-ammo representation; format that readably if the parallel HUD changes touch ammo rendering. Selection acceptance establishes functional input/authority correspondence, not complete visual/art acceptance or long-match balancing.

## Verification

Pinned binary:
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
Read-only dependencies:
`/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules`.

```sh
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/match_selection.gd
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
  node port/native-match-selection/run.mjs
```

Add the focused `match_selection.gd` command to lead-owned verification. It passed **33 assertions**: defaults, equals/space CLI forms, invalid/empty/unsupported choices, catalog-mode intersection, retained pending identities, guest conflicts, local wait state, outgoing selected configuration, and mismatched authority-mode rejection.

The focused runner passed all **six** enabled combinations against an owned loopback source server at default `tickDt=1/60`, `tickMs=1000/60`, with an overall 58-second deadline. Each native smoke observed three authoritative actors, movement, shots, ACKs, remote poses, and correct map/mode identity. It uses ordinary protocol inputs; no state injection or source-rule edits.

The seventh connection used the graphical menu on a private Xvfb display: keyboard dropdown selection of **Verdant / Instagib**, mouse click on Start, then authoritative pose and ACK >10. `evidence/menu.png` is the real native menu screenshot before Start. `evidence/results.json`, individual smoke logs, and `evidence/menu.log` record the observed results. No shared desktop/services were used.

Regression checks passed:

| Script under `godot/tests/protocol/` | Checks |
| --- | ---: |
| `control_safety.gd` | 2497 |
| `session_recovery.gd` | 52 |
| `guest_session.gd` | 10 |
| `native_trace.gd` | 28 |
| `round_boundaries.gd` | 12 |
| `stall_controls.gd` | 12 |
| `window_focus.gd` | 7 |

The first exploratory Instagib smoke exposed the Deathmatch-only nonempty-pickup assertion. It was corrected to assert zero pickups in Instagib; the final six-combination matrix and menu lane passed afterward. Evidence is small and scoped; generated semantic assets remain ignored build output.
