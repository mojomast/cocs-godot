# Native Career saved-loadout overview

`godot/career/equipped_model.gd` is a pure projection: a **confirmed** source
profile plus the shipped `godot/career/catalog.json` become a user-facing
"Saved for next match" overview. It never reads live actor state, never
reverse-resolves the actor's resolved modifiers into item names, never balances
stats and never stores a credential.

## Slots and states

* Gear: `primary`, `armor`, `utility`. Attachments: `optic`, `barrel`,
  `magazine`, `underbarrel`. Finish: the source cosmetic ID.
* Per slot:
  * `equipped` — the field is known and the slot names a catalog item; the
    readable catalog name is shown.
  * `stock` — the field is known and the slot is absent or explicitly unset. A
    known empty map (`{}`) makes every slot in that field `stock`.
  * `unknown` — the field itself is missing or malformed (the source never said).
    A missing `finish` is `unknown`; an explicit `null` finish is `stock`.
  * `unknown-id` — the slot names an ID the catalog cannot resolve. It is shown
    literally and bounded, never as stock and never as a fabricated name.
* An unsupported/invalid field is omitted whole by `profile.gd`, so its slots
  stay `unknown`, never an invented empty or stock value.

## Current vs saved

The saved loadout applies to the **next** match. The source constructs a match
actor once from the profile at round start; a mid-match `GEAR` write replies with
a `progression` frame that updates the profile only. The live actor carries
resolved modifiers, not item IDs, so the reader can never claim a "current item"
name.

The one honest current-vs-saved split is the finish: a cosmetic is an ID on both
sides. The service calls an optional parent hook, `client.current_actor_snapshot()`
returning e.g. `{"finish": <id|null>}`, and shows a separate "Current match
finish" line only when that hook exists. Until the parent exposes it, the finish
is reported saved-for-next-match only. (The native first-person viewmodel already
binds `actor.finish` directly through `godot/first_person/finish.gd`; the Career
reader does not depend on that file and claims no third-person finish rendering.)

## Compact layout

At 760x520 @150% the viewport is ~506x347 logical px. The header (title + Back)
and the concise source header are pinned outside the scroll body, so Back is
always reachable; only the 7-tab strip, the one-line summary and the item list
scroll. The LOADOUT list is ordered equipped/unknown-id slots first, then the
finish, then the stock/unknown line, then the authority facts (matches/wins/
kills and mode totals) and status. The compact first screen therefore shows the
confirmed saved summary, at least one named equipped slot and the finish. The
checks assert those rects start inside the viewport, not only Back and the tabs.

## Owner gating and refresh

`Career.equipment_summary()` is only meaningful for the connection that `welcome`
bound (`service.owned(client)`). The lobby checks that ownership plus
`career_seated`/`career_wire_open()` before reading, so another client, endpoint
or a disconnected seat cannot leak a profile; a disconnect clears the owner and
the summary falls back to the explicit `Connect to load source loadout.` prompt.

The projection is memoized on a monotonic profile revision (bumped only when the
confirmed profile changes). No credential and no digest of the raw profile is
computed or retained. This keeps the existing per-frame lobby refresh cheap
without a new signal.

## Source fixture

`port/native-career/equipped.test.mjs` exercises the real authoritative `Room`
and `ProgressionStore` (no local balance authority): a complete write is
normalized and echoed with explicit maps, unknown IDs/slots are dropped, the
current actor is not rewritten, a respawn does not re-read the profile, and only
the next match constructs the saved attachment. Finish writes are validated
(level gate), explicit `null` clears, and unknown finishes are refused.

## Live journey

`port/native-career/equipped-journey.mjs` runs one owned authority and one real
Godot session (`godot/tests/career/newloadout_observer.gd`). The observer opens
the shipped Career panel, equips a level-one starter attachment through the
displayed MODS tab, waits for the source-marked GEAR reply (never optimistic),
reads the LOADOUT summary, proves the current actor's resolved attachments are
unchanged, lets the round resolve, and restarts; after the authoritative start
the new actor carries the saved attachment. It also checks the compact
760x520 @150% geometry and sweeps for credential leakage. No unlock is granted
and no human visual acceptance is claimed.
