# Further Astra assets, features and cinematic work

The owner's repeated request launched **six more `openai/gpt-6-astra` agents**
from `e9d784a7`, each in an isolated worktree. Follow [BRIEF.md](BRIEF.md).
Existing map revisions and all earlier feature/asset lanes continue.

## Ownership

| Lane | Agent | Branch | Bounded deliverable |
|---|---|---|---|
| Vehicle fleet | `ses_f03440966ffeBzmLZZ3UkR4Oi7` | `expansion-four/vehicles` | Blender-authored Puma and source-existing fleet visuals, compatible wheel/turret/seat/muzzle assemblies and LODs |
| Campaign scenery | `ses_f03437da1ffeli91L87Q6CVyRP` | `expansion-four/scenery` | Four biome-specific hero assemblies plus supporting architectural/natural modules, preserving reviewed collision and routes |
| Stormglass Causeway | `ses_f0342d1ffffeyUHJkcUj3vqP7p` | `expansion-four/stormglass` | New Blender Puma-racing circuit through seawall gates, a freight tunnel and quay districts, with source-proven laps/checkpoints |
| Recording/replay | `ses_f034243c8ffeTxaxmJkhNlHdJG` | `expansion-four/replay` | Source-format local recording, clip library and read-only playback/seek controls for an explicitly supported initial route family |
| Remappable controls | `ses_f0341cb47ffeZ96g7LQUm2eJU4` | `expansion-four/controls` | Source-backed keyboard/mouse action mapping, settings and hints, preserving held-input and transport/modal boundaries |
| Cinematic refresh | `ses_f03411df4ffeEk7157dyOo57NZ` | `expansion-four/trailer` | Executable refreshed trailer capture/edit pipeline and evidence-linked shot manifest; audit existing live menu demo freshness |

Worktrees: `/home/mojo/.tmp-on-disk/cocs-expansion-four-<lane>-20261002`.
Evidence: `/home/mojo/.tmp-on-disk/cocs-expansion-four-<lane>-evidence-20261002`.
New racing-map ID: `stormglass-causeway`; source racing support is a target until
actual ordinary-input lap and hosted native acceptance pass.

## Source/code checkpoints

- **Vehicles — `91fb48e4` + isolated hooks `ce739609`, ready for Blender.**
  Source-audited Puma, Titan and Scout receive nine authored LOD recipes and an
  optional attachment adapter preserving procedural fallback and existing wheel
  motion. All five fleet identities were audited; no new gameplay vehicle type
  was invented. No master or GLB has been generated yet.
- **66/66 Node checks passed** (ten new asset contracts plus 56 existing fleet
  regressions), with ten asset checks repeated after the shared hooks. Python
  syntax and frozen core identity passed. Recipe counts precede Blender modifiers;
  material/draw/import/frame budgets remain unmeasured.
- Native review must verify barrel mouths against source muzzle functions: source
  turrets orbit the vehicle origin independently of cosmetic hull pitch/roll, so
  the adapter compensates offset mounts. Scout's existing tire width exceeds its
  source OBB by 1 cm per side, explicitly retained for review. The source bullet
  collider remains a solid yaw-only OBB, including visually open cage spaces.
- Required next gates: missing-asset fallback before generation, real Blender
  build/reopen, native assembly/pose and weather isolation, source-wire driving/
  crew/fire/repair/wreck journeys, silhouette/LOD review and wide/compact captures.
  The four shared fleet-file hooks remain isolated pending parent integration.

- **Stormglass — `e723b2fd`, ready for Blender.** A 1,191 m circuit with 21
  corners and 28 m clear road width links terminal, curved freight-vault and
  quay/surgeworks districts, with three seawall gates and 31 building modules.
  Nine focused source tests passed, plus 31 existing race tests (one existing
  slow test skipped). Ordinary-input mounted driving finished in 105.306 seconds
  with zero impacts/resets. Four stock AI racers produced a legitimate winner
  at 64.387 seconds; the other racers were on the closing sector, not all finished.
- Two input-driven competitors exercised countdown, finish and standings; 42
  barriers passed sustained infantry/Puma/ray contact, six overhead checks passed,
  and all 215 navigation nodes connect. These are source fixtures, not hosted
  native or human acceptance. `modeBindings` remains empty.
- **Parent scope decision:** accept a flat drivable circuit under the frozen
  source race rules, which use flat vehicle support, Y=0 respawns and a Y≤3 gate
  limit. The earlier suggested 15–25 m driving relief was a design target, not a
  user requirement; architecture may reach 24 m without claiming elevated roads.
  No authority change is authorized or needed for this map's current scope.
- Blender/master/GLB generation, eye-level architecture review, source/native
  collision comparison, hosted two-native-player race, restart/Home, standard
  wide/compact UI and measured continuous driving footage remain pending. Parent
  must extend the sports scene generator/catalog and package closure only after
  those gates. No heavy-tool grant is implied by the scope decision.

## Resource and integration contract

**No new lane has a heavy-tool grant. Parallax retains the exclusive slot.**
Source audits, implementation, authoring scripts and Node checks begin now.
Blender exports, Godot imports/tests, audio capture and video encoding require
explicit grants after previously queued work. No nested agents.

The parent reviews actual assets and rendered journeys before accepting quality,
merges shared hooks, verifies source/runtime closure and publishes checked builds.
Replay and trailer ownership are separate: the former is a player-facing feature;
the latter consumes recorded/native scenes for a versioned cinematic artifact.
Input changes must be reconciled with queued spectator and operator work. Vehicle
and scenery agents preserve existing authority shapes instead of changing physics
to fit art. All source pins and prior releases/evidence remain preserved.

No new exports, native feature acceptance, finished trailer or package inclusion
is claimed at this launch checkpoint. Published runtime remains `e731fd53`.
