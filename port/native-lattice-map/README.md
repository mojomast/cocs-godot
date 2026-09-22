# Native LATTICE objective map

Isolated branch `native-lattice-map`, worktree `/tmp/opencode/native-lattice-map`, based on `d498479`. Pinned engine: Godot `4.5.2.stable.official.6ce3de25a`. Source commit is checked against `port/contracts/source-lock.json` before each server run.

## UI and authority

The actual `godot/lattice/board.tscn` starts in **List** mode. The objective heading now has a native **List / Map** choice. Both views share the selected public node ID. Changing the view performs no action. In Map mode:

- Public `projection.nodes` X/Z positions determine the diagram. Axes fit independently to a compact 184px-high area, keeping resources, explicit HOLD and receipts on screen. This is a coordinate diagram, not a distance/terrain or reachability map.
- Team ownership uses blue `0`, coral `1`, neutral `N`, unknown `?`; labels come from public nodes. Bright markers are live, dim markers inactive/unknown, `!` denotes contested, a white ring denotes selection. Keyboard focus adds a gold border.
- Click a marker to select it. Arrows browse projected nodes; Home/End select the first/last positioned objective. Tab uses ordinary native focus traversal. Overlapping hit areas cycle deterministically on repeated clicks; coincident positions stay coincident. Their displayed label follows selection and shows the overlap count.
- Missing/non-numeric/nonfinite coordinates produce no map hit target; the footer directs the user to List. Duplicate IDs have one deterministic marker. Empty/disconnected projections remove markers. Removed targets, new maps and new rounds clear selection in both views.
- Only ID, label, X/Z, owner, live and contested are retained by the marker model. No actor positions, links, wallets, authored fallback objectives, or inferred topology are added. Asterion/Monsoon remain distinguishable through their actual public coordinate arrangements and authored labels. No static catalog geometry is needed.

HOLD uses the existing explicit board button and ordinary transport adapter. Purchases still require the existing fresh authorization checkbox. The map never issues orders or purchases automatically.

### Integration API

`map_view.gd` extends `Control`: `set_nodes(public_nodes: Array, chosen: String, public_map: String)` updates its allow-listed presentation model; `node_selected(id: String)` is the sole outbound signal. `marker_position(index)` and `hit_test(local_point, after_id = "")` expose deterministic diagram/hit geometry for the scoped observer and tests. They carry no legality information. `board.gd` adds `view_choice`, `map_view`, and a map/round selection-context key. Existing `nodes`, `selected`, controls and action adapter remain the board integration points.

## Verification helpers

- `godot/tests/lattice/map_view.gd`: deterministic synthetic projection/hit-testing and real board selection lifecycle checks. Synthetic checks are not gameplay evidence.
- `godot/tests/lattice/map_view_physical.gd`: external SceneTree observer of the actual command-line board scene. It inherits only input/read/capture helpers from the existing physical observer; it selects view and nodes using `Input.parse_input_event` mouse and physical-key press/release events, then explicitly clicks HOLD. No signal emission, handler invocation, focus assignment, state injection or built-in smoke mode.
- `run.mjs`: scoped adaptation of the prior witness. Owns an ephemeral loopback normal-rate server, observes allow-listed outgoing recipient frames and incoming ordinary orders, and requires the same target/card/peer/actor/round in the server's running accepted card. No raw frames or credentials are retained.
- `verify.py`: semantic/source verification, import, original adapter/UI checks, new deterministic checks, three map observer cases, and all three original list observer cases through the unchanged `port/native-lattice-physical/run.mjs`. All evidence is written here, including outputs from the original helper.

From this worktree root:

```sh
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode
python3 port/native-lattice-map/verify.py
python3 port/native-lattice-map/cleanup_check.py
```

The symlink uses existing dependencies. Each live case has private `xvfb-run -a -s '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix'`, fresh XDG directories and an owned ephemeral `127.0.0.1` server. Each manifest records exact commands, source/implementation SHA-256 hashes, engine version, display and endpoint. `finally` closes the native child/server and removes temporary XDG directories; `cleanup.json` records closure.

## Retained development attempts

- [`1790041590461860545`](evidence/1790041590461860545/results.json): semantic/import/unit checks passed; first graphical case failed the view toggle. A mouse-opened native PopupMenu initially has no keyboard-highlighted item, so one Down + Enter selected List again. The observer now uses Down to the first row and another Down for Map. The failed attempt's native log, recipient witness, hashes and cleanup remain recorded; no command was submitted.
- [`1790041640121940883`](evidence/1790041640121940883/results.json): all eleven steps passed, including six real graphical cases. Direct PNG inspection then found that JSON float owner IDs were shown as `?` because the initial symbol lookup used integer-array membership. This run is superseded visually. The renderer now accepts finite numeric 0/1 identities, deterministic tests cover float IDs and reject string coercion, and the physical observer checks the actual wire-derived marker symbols. Full Monsoon relay-label width was also increased after PNG inspection.

## Accepted verification

Final evidence: [`1790041767328324921/results.json`](evidence/1790041767328324921/results.json). Semantic export verifies all nine locked maps and source `51289b79c627a26a381ba556b92bab71f93f3732`; pinned import passes. Original adapter **38/38**, original UI **10/10**, new map deterministic checks **23/23**.

| Actual scene observer | Case | Checks / failures | Source result |
|---|---|---:|---|
| Map | Asterion / cocs / 960×640 | 26 / 0 | One HOLD for clicked `front-0`; same target accepted/running |
| Map | Monsoon / cocs / 1280×800 | 26 / 0 | One HOLD for clicked `front-0`; same target accepted/running |
| Map | Asterion / cocs-coop / 960×640 | 26 / 0 | One HOLD for clicked `front-0`; same target accepted/running |
| Original list | Asterion / cocs / 960×640 | 28 / 0 | HOLD running; one Fighter done, spent +12, spawned +1 |
| Original list | Monsoon / cocs / 1280×800 | 28 / 0 | HOLD running; one Fighter done, spent +12, spawned +1 |
| Original list | Asterion / cocs-coop / 960×640 | 20 / 0 | HOLD running; economy disabled |

Each map witness independently verifies one incoming HOLD, recipient-visible positioned target, running card target/card/actor/peer/round correlation, recipient-only wallet keys, and zero economy requests. Each observer verifies view toggles, native marker click and arrow-key selection, list synchronization, explicit HOLD deduplication, visible receipts/resources/actions, and physical disconnect removing all hit targets. Synthetic board checks additionally cover selection removal and map/round reset.

The final PNGs were directly read with the image-capable tool:

- [Asterion 960×640 map](evidence/1790041767328324921/map-asterion-relay-cocs-960x640/map-receipts.png): blue `0` and coral `1`, neutral selected frontier, distinct public arrangement, all labels and accepted receipt visible.
- [Monsoon 1280×800 map](evidence/1790041767328324921/map-monsoon-foundry-cocs-1280x800/map-receipts.png): reversed frontier slope and full authored labels including `MONSOON / TURBINE CONTROL`.
- [Co-op 960×640 map](evidence/1790041767328324921/map-asterion-relay-cocs-coop-960x640/map-receipts.png): accepted HOLD and disabled economy controls visible.
- [Disconnected map](evidence/1790041767328324921/map-asterion-relay-cocs-960x640/map-disconnected.png): no residual nodes or selection; disabled actions and empty receipt visible. Wrapped unknown resources make the footer use the existing outer scroll.
- [Original list 960×640](evidence/1790041767328324921/original-asterion-relay-cocs-960x640/receipts.png): original selection/purchase flow and both receipts still fit without scrolling.

No script errors in the final run. Xvfb's software driver emits its existing V-Sync capability warning. [`evidence/cleanup.json`](evidence/cleanup.json) confirms all 13 ports across all retained attempts are closed and no owned native/server/Xvfb runtime children remain. Individual cases also record exited native processes and removed temporary runtimes. The final manifest hashes identify tested working-tree contents; its Git revision is the pre-commit base because evidence was gathered before the scoped implementation commit.

## Limits

Engine-input-path checks are not OS device injection or a human playtest. Short single-client acceptance proves ordinary HOLD accepted/running for the clicked public frontier; it does not prove capture/completion. No pan/zoom, terrain collision, authoritative links or enemy-actor layer is represented. The diagram fits X/Z independently; consumers must not infer world distances from it. Missing-coordinate objectives remain selectable in List. The full receipt history retains the board's existing scrolling behavior.
