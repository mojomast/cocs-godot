# Experience source parity inventory

Base: `29e242a0`, branch `improvement/port-experience`. Read-only source audit; no
locked source or derivative protocol changes. This is a bounded lane inventory,
not an exhaustive claim that every product element is complete.

## Selected journeys

1. **Enable sound captions in Home/in-match F12 Settings, then play with a muted
   or audible mix.** New persisted preferences retain source defaults (off,
   100%, dim, bottom); text scale is 80–160%, with top/bottom and three background
   choices. The passive player-information child consumes accepted client events.
   Important calls protect their 2.2-second window from equal/lower callouts;
   identical gunfire does not restart the clock. No speech synthesis or new sound
   is produced. Settings/cheats/Career/focus loss suppress captions; round/error,
   stale snapshot and route change clear them. No caption is replayed on recovery.
2. **Take damage, review the last three incoming hits on elimination, respawn
   with a cleared ledger; receive a worded OVERKILL local-kill badge.** Current
   accepted snapshot attribution only; unknown/hidden attackers stay unknown.
   No position is retained or shown. Ability wording takes precedence over the
   observed weapon, as in the source page. This extends combat information; the
   already-ported Career results/history reader is a separate existing journey.

Implementation: `godot/experience/{caption_model,combat_info,player_info}.gd`,
`godot/ui/local_settings.gd`. LocalSettings instantiates the passive child and
forwards normalized preferences; the child binds the current scene's client
after ready. The parent can instead explicitly call `bind_session(session)`.
The node has no input handler, input packets, camera changes, or authority writes.

## Family inventory and code anchors

| Family | Already ported, confirmed in code | Selected / remaining |
|---|---|---|
| Home, settings, persistence | `godot/ui/main_menu.gd`, `local_settings.gd:45 normalize / load_at / save / release_controls`, `menu_preferences.gd`; source `game/config.mjs:270 DEFAULT_DISPLAY`, `normalizeDisplay` | Selected additive caption preferences; existing saved mute, volumes, UI scale, display mode and announcer choice preserved. Native settings validation pending slot. |
| Sound captions and assistive policy | Source `game/hud.mjs:357 CAPTION_EVENTS`, `:405 audioCaption`, `:547 CAPTION_TTL`, `:625 captionPriority`, `:633 acceptCaption`; ranks `game/assistive-announce.mjs:21` | Missing shared native caption channel selected. 115 static event rows plus pickup, actual spawn, alt mode/fire, seven enemy telegraphs, charging, weather/time names. Independent source-generated replacement oracle: 432 cases. Full dynamic LATTICE logistics captions remain; no automatic accessibility speech added. |
| Combat recap and elimination badges | Existing hit/edge/weapon feedback: `godot/world/combat_feedback.gd`, `combat_overlay.gd`; existing results recap: `godot/career/results_model.gd`, `service.gd:12–16` | Source `app/page.tsx:572–595 noteDamage/noteKill`, `game/hud.mjs:192 killFeedBadges`, `:499 DAMAGE_LOG_LIMIT`, `:501 damageLogEntry`, `:515 damageRecap`. Selected last-three incoming hits and local elimination word badges. Full enriched public feed, inferred pending streak accounting, ASSIST timing and harness/wing chips remain. Only event-supplied badges are presented. |
| Weapon ranges and class/kit discoverability | Existing `godot/ui/loadout.gd`, `weapon_names.gd`, `game_hud.gd`, operator content; source `game/class-ui.mjs:140 operatorCard`, `:179 specSheet`, `:237 kitView` | `game/hud.mjs:1168 weaponRangeInfo/:1177 weaponRangeLabel` extracted for ten weapons, not yet wired to a new native surface. Full class movement budget/spec sheet remains; gameplay agent owns verbs/bindings. |
| Spectator views | Real read-only spectator seat, lifecycle and fixed camera: `godot/net/client.gd`, `godot/world/session.gd:154 spectator_status`, `:162 seat gate` | Source `game/hud.mjs spectateActor/nextSpectateTarget/spectatorBoard/spectatorTeams`; `app/page.tsx:606 applySpectateCamera`. Follow/cycle/camera-mode UX remains missing; not selected because it needs shared camera/session ownership plus visibility-policy review. |
| Career, arsenal, profiles, saved loadout, results/history | `godot/career/service.gd`, `profile.gd`, `identity.gd`, `actions_model.gd`, `equipped_model.gd`, `results_model.gd`, `history_model.gd`; source `server/progression.mjs`, `app/page.tsx` | Existing substantive implementations, not counted as new gaps. Progression/challenge expansion belongs to MODES. |
| Chat, rooms and reconnect | `godot/social/{social_model,room_browser,chat_panel}.gd`; `godot/net/{client,reconnect_ticket,snapshot_watch}.gd`; source `game/protocol.mjs`, `server/room.mjs` | Already implemented. New passive information drops attribution on error/new start/seat changes and never keeps credentials. Native reconnect journey remains to be exercised. |
| Music, voices, mixing, vehicles, ambience/weather | `godot/audio/av_service.gd`, `event_router.gd`, `buses.gd`, `music_service.gd`, `vehicle_service.gd`, `objective_motifs.gd`; `godot/world/audio_feedback.gd`; source `game/feedback.mjs`, `sfx-design.mjs` | Already real implementations (8-voice weapon pool, effects bus, objective router, music ducking, weather service). This change adds text only. Ability/movement spatial-audio completeness and listener/occlusion parity remain unaudited beyond these anchors; no new PCM or listening claim. |
| HUD mode state and sudden death | Existing `godot/ui/objective_hud.gd`, `scoreboard.gd`, route-specific HUDs; source `game/hud.mjs:353 suddenDeathBanner` | Caption table includes authoritative sudden-death events. New mode HUD/state routes remain MODES-owned; no duplicated sudden-death rule or speculative state introduced. |
| Campaign controls, F3 pause, world visuals | Existing `godot/campaign/demo.gd`, `hud.gd`, `godot/debug/solo_cheats.gd` | F3 pause, physics aim, edge effects and workshops preserved. Overlay suppression reads existing cheat overlay visibility. Native compact compositing must still be inspected with the new optional caption channel enabled. |

## Extraction / source provenance

`tools/experience/extract.mjs` imports real source helpers; it never edits source.
It freezes expected caption outputs, all six rank-band pairings at six age
boundaries with duplicate/nonduplicate text, badge boundaries, and range labels.
The native implementation does not evaluate JavaScript at runtime.

`game/hud.mjs` SHA256:
`e3f93556b9c71e0aa81da51a0e0266ebe61e70c84d0bac9d927f6bf26db171b2`.
Check with `node tools/experience/extract.mjs --check`.

## Deliberate native limits

- Personal-event captions require the seated actor ID; received global events
  get generic words without a direction, distance, or claim of visibility.
- Damage uses a plain fallback; no derived bearing from hidden actors.
- No ASSIST or inferred streak is claimed without the relevant metadata.
- Caption defaults are off, matching source. Combat readouts can be disabled.
- Source dynamic LATTICE-specific captions, full kill feed, spectator follow,
  range/UI kit details, automatic screen-reader announcements and full family
  parity remain outstanding. This pass does not claim them as completed.
