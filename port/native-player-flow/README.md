# Native player-flow clarity

Player-facing polish for the shipped `CAREER / ARSENAL` reader
(`godot/career/service.gd`, `godot/career/equipped_model.gd`). It changes only
presentation: the source stays the sole authority for profile, equipment,
results and history. No wire, server, render or session code is touched.

## What was unclear, and what changed

* **False empty-loadout claim (real bug).** The LOADOUT tab printed
  `No slot equipped · saved for the next match.` whenever it listed no *equipped*
  slot -- including a disconnected profile and a profile whose gear field the
  source never reported. That is a claim the source never made. The reader now
  distinguishes three honest cases:
  * disconnected -> `Not connected · no confirmed saved loadout to show.`
  * any slot the source never reported -> `Saved loadout unknown · the source did
    not report every equipped slot.`
  * a known, entirely unselected map -> `Stock saved loadout · no slot equipped
    for the next match.`
* **Result/XP on the first screen.** The pinned header's second line now follows
  the active tab: the accepted round and its same-round award XP on **RESULTS**,
  the bounded source-list status on **HISTORY**, and the aggregate totals
  elsewhere. The important result/XP therefore sits above the (irrelevant on
  those tabs) saved-loadout summary instead of below it, and the source identity
  line (`CONNECTED SOURCE CAREER` / `NO CONNECTED CAREER`) is unchanged.
* **Bounded summary.** The one-line saved-loadout summary caps at four named
  parts (`+N more`) and truncates a long unresolved ID, so a fully equipped
  loadout cannot push the compact first screen off the fold. Slot detail keeps
  the larger `MAX_ID` bound.
* **Player-facing status copy.** A pending write reads `awaiting source
  confirmation. It applies to the next match, not this respawn.`; an applied
  write still reads `Source confirmed selection · saved for next match.`; an
  adjusted/refused write stays explicit; a timeout stays `outcome unknown`. The
  LOADOUT body notes that the current match and its respawns keep the round-start
  loadout.

Unchanged authority contracts: profile known-empty gear means stock, a
missing map or finish is unknown, a null finish is stock, a null/non-string slot
is unknown, and an unresolved catalog ID stays a bounded literal. The Home
catalog keeps the `NOT LOADED` default and the `Equip_<unlockId>` /
`CatalogRows` / category-ID / `CareerBack` names.

## Tests

Focused checks (run in the parent's serial slot):

```sh
node --test port/native-player-flow/clarity-states.test.mjs
godot --headless --path godot --script res://tests/player_flow/clarity_model.gd
godot --headless --path godot --script res://tests/player_flow/clarity_ui.gd
GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
  node port/native-player-flow/clarity-journey.mjs
```

* `clarity-states.test.mjs` pins the real source behavior behind each reader
  state: a GEAR reply is explicit and award-free, unknown IDs normalize to known
  stock, and an unknown/gated finish is refused to explicit null.
* `clarity_model.gd` pins disconnected vs unknown vs known-stock vs named vs
  unresolved-ID, the bounded summary, and the shipped LOADOUT text.
* `clarity_ui.gd` asserts the actual important text and its visible bounds at
  760x520 @150%, 960x640 @100% and 1280x800 @100% (not just the viewport root or
  Back).
* `clarity-journey.mjs` + `godot/tests/player_flow/clarity_observer.gd` host one
  real owned match and capture the pending, no-reply-unknown, source-confirmed
  and accepted-results states at 760x520 @150% (evidence under
  `port/native-player-flow/evidence/clarity/`).

The journey holds only the shipped client's own `_process` so a pending write
cannot leave the client before its capture; it is a genuine wire state, not a
fabricated frame. It grants no unlock and claims no human visual acceptance.

## Verification status (this lane)

Verified green on this branch (serial, pinned `Godot 4.5.2`, explicit
`COCS_SOURCE_DERIVATIVE`, credentials env cleared):

* `port/native-player-flow/clarity-states.test.mjs`
* `res://tests/player_flow/clarity_model.gd`
* `res://tests/player_flow/clarity_ui.gd`
* the existing Career suite: `projection`, `actions`, `modal`,
  `newloadout_model`, `newloadout_ui`, `newloadout_lobby`, `results`, `history`,
  `results_history_ui`, `package_catalog`
* `node --test port/native-career/results-history.test.mjs` (server + `ws`
  connectivity)

`clarity_ui.gd` settles two frames after each resize before measuring, so the
bounds checks read the real layout rather than the previous frame's (the gap the
earlier Back-only checks left open).

The live `clarity-journey.mjs` could not be captured in this session: the native
Godot session timed out at its WebSocket handshake (`phase -1`) before the Career
panel opened, identically to a re-run of the existing `equipped-journey.mjs`. The
owned authority and a `ws` client round-trip passed in the same session, so this
is an environment-level Godot-client handshake failure, not a reader regression.
The first attempt is retained under `evidence/clarity-attempt-1/` and the default
`evidence/clarity/` directory is left free for a passing run in an integrated
environment.
