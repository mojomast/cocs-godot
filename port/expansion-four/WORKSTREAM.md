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
