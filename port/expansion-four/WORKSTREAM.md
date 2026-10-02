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

- **Replay — `9120d991` + optional session hook `9794575a`, ready for engine.**
  Recipient-delivered recording, unique local clip storage, metadata library,
  source JSON import and read-only play/pause/seek/speed/subject controls are
  implemented through unchanged source demo logic in a bounded local Node helper.
  First admission is Meridian Exchange DM/TDM/Instagib/Rockets; other families
  explicitly fail admission. Playback has no authority client or award path.
- **78/78 Node checks passed**, including source-exact seek/interpolation, actual
  seated/spectator recipient-stream recording, malformed-file handling and an
  authenticated helper lifecycle. Six GDScript files passed grammar parsing only.
  The four-file standalone runtime package was generated and exercised. Meridian
  tests do not establish private-intel COCS recording parity; COCS is unsupported.
- Parent integration must add Home **Replays** without starting authority and
  include `replay/admission.json`, native renderer dependencies and the separate
  `replay-runtime` closure. The optional four-line live-session capture hook must
  be reconciled with other queued session changes. Native record/save/reopen,
  exact seek poses, zero post-leave authority input, UI/audio/lifecycle inspection
  and both extracted-package checks remain pending. No engine grant is implied.

- **Trailer — `1c65712b`, `05f2a216`, `44dafb18`, ready for capture.** Executable
  v3 pipeline plans sixteen shots / 75 source seconds / 1,800 individually
  rendered frames at 1280×720, with four chapter identities, six camera splines,
  source traversal/combat/melee, Patch, Mara/Ivo captions and artillery. Staged
  setup and ordinary scripted inputs are labeled separately. No footage exists.
- **6/6 Node tests passed** and source preparation/edit planning completed.
  Source receipts include 70.38 m Rootfall traversal, 51.19 m Emberline detour,
  ten airborne output frames, sixteen positive active-AI combat damage events,
  an accepted melee hit and Patch pet. The eight-clip menu candidate has 504
  frames and 210 events, independently checked once-only/in-order after reduction.
- Actual weather/event stepping is explicitly prepared for the render-only
  session. Native parsing/rendering, decorative-art camera clearance, HUD/gesture
  review, full trailer viewing/listening and menu lifecycle acceptance remain
  pending. Capture is deterministic offline rendering; encoded frame rate will
  not be presented as real-time performance. All captures/edits are hash-bound
  to immutable attempts and retain failures. Parent installs accepted menu data
  and publishes a new v3 without replacing v2; no engine/encoding grant yet.

- **Scenery — `36358d96` + isolated composition hook `fe3f3b5a`, ready for
  Blender.** Twelve biome-bound assemblies provide one hero and two supporting
  modules per campaign chapter: root/canopy, layered waterworks, basalt/copper
  shielding and faceted antenna/ceramic archive forms. Deterministic placement
  metadata and build/reopen scripts are prepared; no master or GLB exists yet.
- Six focused source checks and thirty existing regressions passed, including
  8,337 swept route-clearance comparisons, 2,827 supported/clear source route
  points and preservation of 10,117 previously clear approach rays. Original
  chapter recipes, hashes, facade triangles and asset bytes remain unchanged.
  These sampled prospective-geometry checks do not establish arbitrary-ray
  equivalence or acceptance of the eventual imported art.
- The prepared inspector uses real campaign authority and production scenes for
  all four chapters, with matched old/new/reduced full-viewport captures, collider
  identity, source-camera return and teardown checks. Native execution, actual
  art review and ordinary connected walk/shot/workshop journeys remain pending.
  Parent must review runtime catalog/GLB closure and the reduced-detail setting
  hook; staged camera inspection alone will not satisfy gameplay acceptance.

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
