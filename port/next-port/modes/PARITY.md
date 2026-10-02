# Competitive modes source → native parity

Status: **native follow-up accepted for all four mode journeys after explicit
exclusive engine grant; engine slot released at follow-up handoff**. Package and
combined cross-lane acceptance remain parent-owned. No Blender or package build
was used in this lane. See ACCEPTANCE.md for exact native outcomes and limits.

## Audited authority

- Frozen source pin `515daf07589150dd3241f4ae1425cc1b093912f5`; existing reviewed
  gameplay core/derivative approvals remain unchanged. No `game/` or `server/`
  files are modified.
- `game/config.mjs:121,140–142` registers the four modes, loadouts and targets.
- `game/core.mjs` owns spawn inventory, damage, crown transfer, stepping,
  snapshots and winners; `game/objectives.mjs:24–72` owns crown survival,
  shared tickets and extraction.
- `server/room.mjs` already supports all four through the generic config/start
  path, including spectator late joins, token resume and fresh round revisions.
- `app/page.tsx` uses the shared mode catalog and source match. Its local career
  settlement at line 641 calls `applyMatchAll` before `awardMatch`.
- `port/contracts/map-selection.json` is the existing source map capability
  authority. The new route is its eight supported pairs, not new world claims.
- `multiplayer-worlds` has its own port-owned map allowlist, not automatic
   authorization for arbitrary source modes. Its existing 43 pairs stay intact.

## Status matrix

| Element | Baseline audit | This batch | Acceptance |
|---|---|---|---|
| Assault, Uplink, Holdout | Already ported (`godot/assault`, `godot/zone_modes`) | Reused authority; no re-port claim | Existing baseline |
| Vehicles / Combined Arms | Already ported | No new claim | Existing baseline |
| Career identity, profiles, XP, equipment, results/history | Already ported (`godot/career/{identity,profile,equipped_model,results_model,history_model,service}.gd`) | Reuse ordinary source sessions | Existing baseline |
| Daily/weekly challenge bonus UI | Source local application path exists | Pending; no server award invented | Not claimed |
| Full Arsenal | Missing native route | All ten source weapon identities, unlimited ammo; existing selection/first person | Source fixtures pass; native normal-rate draw / restart / Home pass |
| Juggernaut | Missing native route | Source crown, shield, survival points, kill transfer/bounty, crown world marker and point-ranked scoreboard | Source fixtures, native survival win and native-observed bot combat transfer / 30-point win pass |
| Team Elimination | Missing native route | Source team tickets/deaths/attrition/time winner; ticket HUD and team lives results | Source fixtures pass; native time-result / restart / Home pass |
| VIP Escort | Missing native route | Source VIP deployment/proximity motion/extraction hold/decay/death/timeout; VIP + beacon labels and escort scoreboard | Source fixtures pass; native defender timeout / restart / Home pass; ordinary-input extraction not accepted |
| Home / host setup | Generated selectors already present | Competitive Modes route: map, mode, bots, round seconds, wait-for-players | Actual native selectors validate all four selected journeys; wide/compact Home inspected |
| Guest / spectator / reconnect / restart / leave | Existing source transport and native session lifecycle | Scoped scene hooks, explicit reconnect button, restart button/Enter, Leave/Home | Three native clients (two players + late spectator), actual reconnect, restart and Leave/Home pass for all four modes |

## Exact routing and integration contract

`--experience=mode-expansion` → **`res://mode_expansion/demo.tscn`** → existing
**`server/game-server.mjs`**, with neither `world:true` nor a new authority adapter.

| Map | Modes |
|---|---|
| `meridian-exchange` | `arsenal`, `juggernaut` |
| `verdant-reliquary` | `arsenal`, `juggernaut` |
| `ember-crucible` | `arsenal`, `juggernaut` |
| `tidal-citadel` | `team-elimination` |
| `sunscar-convoy` | `vip-escort` |

Both package/development parsers accept host `--bots=0..8`,
`--time-limit=60..900`, optional mode-bounded `--round-target`, and
`--wait-for-players=1..8`. Guests supply `--endpoint=ws[s]://…` and
`--join-room=…` without host settings. `--diagnostics` is allowed. Generated
capabilities advertise external authority reuse. Existing Combat setup shows the
exact separate route for these modes; the Home Competitive Modes selector is the
playable host setup.

Native scope: `godot/mode_expansion/{demo,state,markers,scoreboard,hud}.gd` and scene.
The scoreboard subclasses the common layout; no common HUD/settings/menu layout
rewrite. It uses crown points (then frags), VIP captures/time/frags, and ticket
totals instead of implying ordinary FFA ranking for objectives.

Parent integration dependencies:

1. Include this scene and its dependencies through the existing generic Godot
   resource closure. No new generated map, runtime adapter, source derivative,
   server progression or geometry hash is required.
2. Keep `tools/godot-package/endpoint.mjs` packaged beside the parser as before.
3. Update parent-owned canonical verification/provenance/package probe lists:
   eight new map/mode cases on **each Linux and Windows** package. Preserve the
   previous 67 probes; expected expanded count is 75 per platform if one probe
   is counted per map/mode. Registry changes 25 → 26 routes, 13 → 14 experiences.
4. Native lane checks passed after grant. Re-run the two new native gates below
   against the combined branch, including Experience HUD composition. Package
   build/release remains parent-owned; this is not release authorization.
   - `godot --headless --path godot --script res://tests/mode_expansion/contracts.gd`
   - `GODOT_BIN=... MODE_EVIDENCE=<isolated-dir> node port/next-port/modes/native-proof.mjs --mode=<id>` (each of the four IDs, sequentially, a display/Xvfb required)

## Source details that must not be “fixed” in native

- **Team Elimination is not one-life elimination.** Every death spends a shared
  ticket, source respawn delay is three seconds, and a team at zero loses. There
  is no post-results respawn. Source attrition starts after 45 seconds, burns at
  nine-second intervals, and time/sudden-death tie handling remains source-owned.
- **Juggernaut damage flag discrepancy:** the source assigns/serializes
  `juggernautDamage=1.4` but never consumes that field in combat damage. The
  shield works (125 initially, 175 on a credited transfer), and crown scoring
  works (.75/second, +3 bounty, +2 carrier kill). Native shows actual shield and
  points, not an unimplemented damage bonus. A bounded regression fixture records
  the source behavior; no hidden frozen patch is made.
- **VIP hold:** source extraction radius is seven, hold four seconds. Progress
  decreases by elapsed time outside the radius rather than instantly resetting.
  The source VIP uses its direct extraction motion and source floor support; the
  port does not substitute navigation or different rules. Native full-path
  successful ordinary-input extraction acceptance remains pending. A bounded
  source-input probe following the VIP stalls near x=-32.35 on Sunscar and loses
  at 180 seconds. This preserves frozen behavior rather than moving the beacon,
  teleporting the VIP, or changing source navigation.

Evidence directory: `/home/mojo/.tmp-on-disk/cocs-port-modes-evidence-20261001`.
See [ACCEPTANCE.md](ACCEPTANCE.md) for passed checks, failed attempts and the
explicit remaining native gate.
