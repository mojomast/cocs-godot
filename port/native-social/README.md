# Native social: room browser + room-scoped text chat

User-usable browser and chat for the native multiplayer route, riding the one
existing connection. No new autoload, no `project.godot` hook and no
`local_settings.gd` change was required (see "Parent integration" below).

## What shipped

**Room browser** (`godot/social/room_browser.gd`) inside the lobby form.
`Browse / Refresh` either sends the source `list` verb on the live connection or
connects the *entered* endpoint as an unseated browse seat (phase `-4`). It shows
the authority's advertised rooms with name / map / mode / player count / lifecycle
status, is searchable, scopes only to the selected endpoint (no scanning or
discovery of any other address) and never invents a field the authority omitted.
Selecting a row only fills the explicit guest join fields; the connect step stays
user-driven so the source's active-room spectator rule is preserved.

**Room chat** (`godot/social/chat_panel.gd`) available in the lobby and the live
round on the same connection. `Chat` opens a modal panel; the local player's line
is only displayed when the authority broadcasts it back — there is no optimistic
echo. The log is cleared whenever the seated room changes or the connection drops,
so no line can leak across rooms or sessions.

**Pure model** (`godot/social/social_model.gd`): the source `sanitizeText` mirror,
room-record normalization, sort/filter, and truthful labels.

## Exact protocol API consumed (source facts)

| Direction | Frame | Source |
| --- | --- | --- |
| C→S | `{type:'list'}` | `server/game-server.mjs` `case MESSAGE.LIST` |
| S→C | `{type:'rooms', rooms:[summary,...]}` | `RoomRegistry.list()` → `Room.summary()` |
| C→S | `{type:'chat', text}` | `case MESSAGE.CHAT` → `Room.chat(peerId, msg.text)` |
| S→C | `{type:'chat', peerId, name, text, time}` | `Room.chat` room-scoped broadcast |

`summary()` fields: `roomId`, `name`, `players` (connected count), `started`,
`mapId` (default `exchange`), `config` (`null` until the host configures it).

Honesty rules implemented from those facts:

- `config === null` ⇒ mode **unknown** (never inferred available).
- missing `players`/`started` ⇒ `player count unknown` / `STATUS UNKNOWN`.
- `Room.chat` sanitizes to 200 chars and drops sends inside a 300 ms per-peer
  floor; the client mirrors the 200 cap and the 300 ms floor, but *says so*
  instead of silently dropping. A send is shown as `Sending…` until the
  authority echoes it, then `No server confirmation (rate-limited or dropped by
  the authority)` after 2.5 s with no echo.
- A `chat` refused with `{type:'error', message:'not in a room'}` and a malformed
  `rooms`/`chat` frame are non-fatal `social_error` notices, not session teardown.

Untrusted names/text render through plain `Label`s (no RichText/BBCode parsing).

## Typing guard

While a chat panel is open, `Session.social_capturing()` is true and the
gameplay input adapters gate on it exactly like `SettingsAccess.overlay_open()`:

- `session.gd` `_input`, `_unhandled_input` and `can_capture_pointer()` return
  early, so WASD/weapon/fire input cannot leak; key releases still reach the
  adapters.
- The panel is modal (full-rect mouse STOP) and `Escape` closes it with
  `set_input_as_handled()`, so it never reaches the Home route's Escape handler.

## Files

- `godot/net/client.gd` — additive only: `rooms`/`chat`/`social_error` signals,
  `request_rooms()` / `send_chat()` (never touches create/join/welcome/career).
- `godot/social/social_model.gd`, `godot/social/room_browser.gd`,
  `godot/social/chat_panel.gd` — new.
- `godot/ui/lobby_menu.gd` — builds and wires both surfaces.
- `godot/world/session.gd` — additive `browse_rooms()` (phase `-4`),
  `social_capturing()` and the three guard checks.
- `godot/tests/protocol/lobby_social.gd` — synthetic offline test.
- `port/native-social/social_authority.test.mjs` — real-authority wire test.

## Tests and commands

```bash
# Both groups (authority always; native when GODOT_BIN is set):
GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 port/native-social/run.sh
#   -> authority  PASS (4 subtests)
#   -> native     PORT_SOCIAL_OK checks=<n> failures=0
#   -> PORT_NATIVE_SOCIAL_OK

# Authority wire contract alone (real server + two rooms + spectator scope):
node --test port/native-social/social_authority.test.mjs

# Native synthetic group alone:
GODOT_BIN=... godot --headless --path godot --script res://tests/protocol/lobby_social.gd
```

Covered by the authority test: two real rooms listed with exact summary fields,
`config: null` for an unconfigured room, chat sanitization (control strip + newline
strip + 200 cap), room-scope isolation between two rooms, a seated spectator
sharing and sending room chat, the 300 ms burst floor, `not in a room` and
unknown-verb correlated errors.

Covered by the native test: model sanitization/unknowns/sort/filter; browser
render of valid rows and skipping of malformed/non-dict records; unknown
map/mode/status wording; select-fills-fields-without-join; non-fatal malformed
`rooms` and `not in a room` handling; send-is-pending until the source echo;
local rate refusal is worded; room-change clears the log; a late frame with no
seat never renders; toggle and panel fit 960x640 and 1280x800 at 150% scale;
real-Session `browse_rooms` URL validation and `social_capturing` wiring.

## Provenance

Baseline `d36dc67d`; the bounded return hashes for every touched file and the
exact protocol API/status strings live in `port/native-social/provenance.json`.

## Parent integration

- **Required parent hooks: none.** No autoload, no `project.godot`, no
  `local_settings.gd` edit. `godot/social/*.gd.uid` files are generated by the
  normal Godot import step.
- **Identity-project autoload conflict (flagged):** if the identity project adds
  a global `Social` autoload shared across routes, that decision collides with
  this lane's attached-lobby-scene approach and would need an owner call; this
  batch deliberately avoids a global autoload and a shared F12 entry.
- Scope is intentionally the lobby route only (`--lobby-menu`, phase `-4` plus the
  live round on the same connection); no other route grows a chat surface.
- No reconnect UI was added; room tokens are never serialized.
