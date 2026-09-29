# Native Career / Arsenal

Home's **CAREER / ARSENAL** opens the source-derived catalog without room
authority. Join/create a source-server room and use **F12 → Career / Arsenal**
to inspect the seated connection's profile. Gear (primary, armour, utility),
mod slots and weapon finishes that are unlocked by level or source grant can
be equipped here. There is no unlock purchase endpoint. Reticles are view-only:
the source `GEAR` packet does not forward `crosshair` to `setGearOwned`.
An equipped gear/mod slot can be cleared; an equipped finish sends explicit
`null` to clear it. Other slots stay intact.
Action buttons have stable node names `Equip_<unlockId>` and catalog ID/kind
metadata for native journey selection, including level-one starter mods.

Each selection sends complete gear and attachment maps (preserving the other
slots) on the seated connection. `server/room.mjs:setGear` replies with a
`progression` frame containing `gear` and `attachments`; ordinary award frames
do not settle a pending selection. The returned profile is compared against
the exact requested maps and optional finish. Malformed/partial equipment or
inconsistent reply maps remain unconfirmed; outgoing loadouts require both
complete source equipment maps. Source-normalized/refused writes
are shown as adjustments, never as successful equips. Only one write can be
outstanding. A timeout means **unknown**, not a refusal: without a wire request
ID a second write cannot be safely attributed until the first receives its
reply or the connection is renewed. Disconnect clears pending state.

The source permits `GEAR` during a match, but it updates the progression
profile, not the existing match actor. The saved selection is for the **next
match**; the current actor does not change on respawn. Mod descriptions show
which source weapon types they fit, and their effects are applied only to
compatible weapons when the source resolves that loadout. Esc closes the panel
and returns to Settings when opened there.

`tools/godot-export/career_catalog.mjs` projects source descriptions, slots,
modifiers, weapon fit and unlock IDs from `game/progression.mjs`,
`game/attachments.mjs`, `game/cosmetics.mjs` and `game/data.mjs` into
`godot/career/catalog.json`, with source SHA-256 hashes. Regenerate using
`node tools/godot-export/career_catalog.mjs`; check with `--check`.

`godot/career/profile.gd` strips ownership credentials from the runtime view;
no token, profile ID or loadout is saved into Home preferences or diagnostics.
The panel displays aggregate profile/mode totals, not an individual match
timeline. Home without a room offers browsing only.

The **RESULTS** and **HISTORY** tabs add the latest accepted source result plus
its same-round award and the server's recent-match list. Neither is a local
authority: no win/loss is computed, no unknown stat becomes a zero and no
history row is attributed to the local career. History is read-only and
requested from the seated source; the owned server persists it beside the
career root under the parent's supervisor lease. See
`port/native-career/RESULTS-HISTORY.md` for the exact frame contract, status
model and round/reconnect rules.

Verification (in the parent's serial test slot):
`node tools/godot-export/career_catalog.mjs --check`,
`node --test port/native-career/catalog.test.mjs`,
`node --test port/native-career/wire.test.mjs`,
`node --test port/native-career/equip-lifecycle.test.mjs`,
`node --test port/native-career/results-history.test.mjs`,
`godot --headless --path godot --script res://tests/career/projection.gd`,
`godot --headless --path godot --script res://tests/career/modal.gd`,
`godot --headless --path godot --script res://tests/career/actions.gd`,
`godot --headless --path godot --script res://tests/career/results.gd`,
`godot --headless --path godot --script res://tests/career/history.gd`,
`godot --headless --path godot --script res://tests/career/results_history_ui.gd`.
The native journey is prepared as
`node port/native-career/results-history-journey.mjs` with a pinned `GODOT_BIN`.
