# Native mode expansion

## Implemented capability

Team Deathmatch is available in the native setup and `--mode=teamdeathmatch`
on **Meridian Exchange, Verdant Reliquary, and Ember Crucible**. Deathmatch and
Instagib remain available on those maps. Other locked map/mode identities remain
visible with their pending status and a disabled Start button.

The scoreboard displays **Red / Blue team totals directly from the latest
snapshot or results**, and names numeric actor teams Red / Blue. Individual
actor sorting, plain-text names, and the local `YOU` marker remain intact.
Team-only score updates invalidate the display; missing totals display an em dash.
Personal frags are never summed to manufacture team scores.

**Rocket Arena remains pending** with a specific setup explanation. Its protocol
and source gameplay work, but this native baseline has no in-flight rocket,
launch, or explosion presentation. An invisible projectile-only match is not
advertised as supported gameplay. The standalone observer exercises it only as
a diagnosis, bypassing the setup capability gate without changing authority.

## Source authority findings

Base: `edc222fe0c8e7338a17c4324e581c055fe38b4ea`.
Locked gameplay source: `51289b79c627a26a381ba556b92bab71f93f3732`.
`git diff --quiet <locked-source> -- game server` passed before live verification;
the local source files used by the private server match that revision.

- Generated locked catalog lists `teamdeathmatch` and `rockets` for all three
  infantry arenas. Native capability remains a subset of that catalog.
- `game/config.mjs:118`: TDM uses teams, shared team-frag score, default frag limit
  30, friendly fire off. `game/core.mjs:543–568` assigns ordinary team seats
  `id % 2`. Native actor visuals already map 0 to red/one stripe and 1 to
  blue/two stripes (`godot/world/actor_visual.gd:40–60`).
- `game/core.mjs:873`: a non-self credited kill increments the killer's team's
  total. Suicide penalties on personal frags do not imply team-score subtraction.
- `game/core.mjs:1313`: `state.teamScores` is an object serialized with **string
  keys `"0"`, `"1"`**, even in FFA. Accordingly the new totals are gated on
  `state.config.mode == "teamdeathmatch"`, not mere presence of that object.
- `game/config.mjs:120`: Rocket Arena is **FFA**, weapon index **1**, unlimited
  ammo. `game/core.mjs:498–506` retains only health/armor supplies for pinned
  weapon modes. `game/data.mjs:23` identifies weapon 1 as Rocket Launcher.
- `game/core.mjs:1058`: an actual projectile shot emits **`launch`**, with
  `{actor, weapon:1, pos}`, and adds the projectile to `state.rockets`. Ordinary
  `shot` is the hitscan path; a blocked muzzle can also emit it (line 1056).
  Explosion events carry weapon 1 (line 1155). No synthetic `shot` is invented
  to make rocket verification pass.
- `game/core.mjs:1303–1308`: normal built-in sudden death can end a tied TDM
  match in its final 15 seconds, or Rocket Arena in its final 12 seconds, as
  soon as the tie breaks. A standard 60-second config can therefore legitimately
  produce results before time 60. The observer checks the actual source window.

## Verification and reproduction

Use the already-installed **Godot 4.5.2.stable.official.6ce3de25a** and existing
dependencies. Generate/copy the locked semantic assets into this worktree first.
No package installation or shared-service changes are required.

```sh
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/match_selection.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/scoreboard.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/team_scores.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/scoreboard_session.gd
node --test game/modes.test.mjs game/weapon-simulation.test.mjs
GODOT_BIN="$GODOT_BIN" node port/native-mode-expansion/live.mjs
```

UI checks: 94 match-selection assertions; 25 scoreboard assertions plus six
recorded frames; 15 focused synthetic team-score assertions; actual scoreboard
scene binding with explicitly synthetic signal delivery. Source unit tests:
22 passed. Those fixtures are distinct from live evidence.

The setup viewport connection now happens in `_ready()`, and detached centering
is a safe no-op. Selection tests cover both configure-before-attachment and
configure-after-attachment, deferred centering, the viewport signal, and all
unavailable locked pairs. The selection fixture also owns/frees its environment
and sun nodes. Its committed log has no script errors, engine errors, or leaks.

The live runner owns a `127.0.0.1:0` server, uses its normal timer, disables history
and progression persistence, and bounds/kills only its own children. It hosts
each mode on each arena with accepted `{botCount:2,timeLimit:60,fragLimit:100}`.
The native observer loads the actual map and uses the actual network, actor,
pickup, combat, and scoreboard scripts. It sends ordinary movement/aim/fire
inputs at 60 Hz, follows authority camera position, checks each snapshot's
mode/map/roster/loadout/team totals, and waits for authoritative results.
No source match state, positions, damage, clock, or physics are edited.

Live logs are compact summaries, without room credentials or raw wire dumps.
They are **headless native program-state evidence**, not graphical acceptance.

### Observed full-round results

All six rounds reached real results, acknowledged native movement/fire, and
passed snapshot-to-UI correspondence checks. Normal source timer scheduling
produced roughly 58 wall seconds for 60 simulation seconds; no tick interval or
step multiplier was overridden.

| Mode | Arena | Simulation seconds | ACK | Local fire events | Final Red / Blue | Live team-score changes |
| --- | --- | ---: | ---: | ---: | --- | ---: |
| Team Deathmatch | Meridian | 60.02 | 3473 | 513 | 1 / 0 | 1 |
| Team Deathmatch | Verdant | 60.02 | 3474 | 513 | 2 / 0 | 2 |
| Team Deathmatch | Ember | 60.02 | 3477 | 299 | 0 / 0 | 0 |
| Rockets diagnostic | Meridian | 53.08 | 3074 | 59 | FFA, hidden | 0 |
| Rockets diagnostic | Verdant | 60.02 | 3476 | 67 | FFA, hidden | 0 |
| Rockets diagnostic | Ember | 60.02 | 3475 | 67 | FFA, hidden | 0 |

Each Rockets round observed actual **`launch.weapon == 1`**, actors pinned to
weapon 1 with `ammo[1] == "∞"`, no actor team field, and only health/armor
pickups. Native observer sampled local in-flight weapon-1 projectiles 2915 times
on Meridian, 2749 on Verdant, and 3806 on Ember (samples are not unique shots).
Meridian ended through the source's normal sudden-death rule.

Existing combat presentation counted just 1 ordinary `shot` across the Meridian
Rockets round and **0** on Verdant and Ember, despite 59/67/67 real local fire
events. A blocked muzzle can account for the occasional ordinary `shot`; it does
not demonstrate supported launch or projectile presentation. This is the
concrete reason Rockets remains gated.

The unchanged real session scene's `--session-smoke` also passed for TDM on all
three maps: ACK 16/15/15, three actors, authoritative camera movement/fire,
74/76/74 remote poses, and 20/20/22 native pickup markers respectively. The runner
supports `--session-only` to repeat that final integration segment independently.

## Integration hooks for the lead

1. Team Deathmatch requires no changes to session/client/HUD wiring. The existing
   `configure_match` sends the selected mode; the actual scoreboard scene is
   already connected to snapshots/results.
2. To enable Rockets later, add bounded snapshot-derived rendering of
   `state.rockets` (`id`, `owner`, `weapon`, `pos`) and authoritative `launch` /
   `explosion` feedback in the owning presentation/combat lane. No source rule
   changes are needed. Then add `rockets` to `MatchSetup.MODES` and remove its
   targeted pending explanation after native verification.
3. `session.gd:331` currently requires `combat.shots > 0`. That counter handles
   `shot` only, so it is not reliable rocket-launch evidence; use a real launch
   counter/event when extending session smoke. **Keep health/armor pickup
   expectations** for Rockets: source filters to those supplies, not to empty.
4. New focused checks to add to the shared verifier when integrating:
   `res://tests/protocol/team_scores.gd`; the owned `live.mjs` provides the
   separately bounded full-round mode exercise. The shared verifier was outside
   this lane's ownership.
