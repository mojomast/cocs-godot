# Native Career / Arsenal (first slice)

Home's **CAREER / ARSENAL** button opens the catalog in-process; during a live
source-server session use **F12 → Career / Arsenal**. At Home it says **NO
CONNECTED CAREER** and every lock status says **NOT LOADED**. Join/create a
room through the existing match/lobby workflow; `server/room.mjs:966-974`
returns `welcome.profile` to the seated connection. `godot/net/client.gd`
passes that frame and subsequent `progression.profile` frames into the runtime
projection. `server/room.mjs:1122-1123,1372` is the authoritative origin of
those updates; this panel sends no gear or unlock messages. Esc closes the
panel and returns to Settings when entered from Settings. During the match
the panel is read-only and the match continues.

`game/progression.mjs` and `game/attachments.mjs` define the 23 gear and 22
attachment items, levels, grants and equipment slots; cosmetics come from
`game/cosmetics.mjs`; weapon fit names come from `game/data.mjs`.
`tools/godot-export/career_catalog.mjs` projects source
descriptions, modifiers, attachment fit and unlock IDs into
`godot/career/catalog.json` and records source SHA-256 hashes. A missing
source unlock or incomplete definition fails generation. Regenerate with
`node tools/godot-export/career_catalog.mjs`; verify with `--check`.

The source profile contains `ownerToken`; `godot/career/profile.gd` projects
only display fields. No owner token, progression token, or profile ID is
printed or saved in Home preferences or local settings. The server's global
`history` frame contains player names but no career IDs; the panel therefore
shows **byMode totals** from the owned profile and does not call this an
individual match timeline. On disconnect the in-memory projection clears.
Cross-process identity persistence and reconnect credentials belong to the
next slice; Home makes no claim to the prior process's career.

Verification (when the serial test slot is free):
`node tools/godot-export/career_catalog.mjs --check`,
`node --test port/native-career/catalog.test.mjs`,
`node --test port/native-career/wire.test.mjs`,
`godot --headless --path godot --script res://tests/career/projection.gd`,
`godot --headless --path godot --script res://tests/career/modal.gd`.
The last two require an engine/import slot; the wire fixture runs a genuine
ephemeral source authority and must wait for the shared server-test slot.
