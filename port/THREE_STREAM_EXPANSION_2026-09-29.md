# Three-stream expansion and consolidated build

The user authorized all three recommended additions and a final consolidated
build on 2026-09-29. This supersedes the earlier **build hold**. Windows and Linux
packages will be generated serially from one reviewed integration revision after
the ongoing player-flow polish and these feature streams are integrated.

## Workstreams

1. **Objective modes:** complete source-backed Uplink, Assault and Holdout loops,
   including setup, supported maps, objective presentation, results and rematch.
2. **Vehicles/combined arms:** inventory every source-supported vehicle and close
   actual native gaps in interactions, cameras, HUDs, damage/weapon feedback and
   multiplayer presentation. Existing coverage is retained rather than duplicated.
3. **Audiovisual presentation:** source-derived music, announcer cues, weather and
   map ambience, including source-event correlation, volume/mute controls and
   bounded presentation resource use.

Read-only discovery runs in parallel, followed by bounded implementation lanes.
Every engine import, rendered test, benchmark, full suite and build uses the
single local heavy-work slot. The active player-flow clarity lane holds that
slot until its focused verification completes.

## Integration contracts

- Gameplay, vehicles, mode scoring, progression and admission remain owned by the
  recorded source authority. Existing purchases/recon privacy and unknown-state
  rules remain intact. New native presentation does not invent source features.
- Shared launch/route/catalog registration and package resource inventories are
  integrated centrally. The original source lock remains strict, with the
  reviewed combined derivative explicitly selected where required.
- Device settings, endpoint-scoped credentials and owned progression/history
  remain separate. Fixture state is isolated and secrets stay out of evidence.
- Failed verification attempts are retained with their exact tested composition.
  New screenshots shared with the user use stable public GitHub release hosting.
- Builds record the reviewed commit, source identity, input/resource hashes and
  archive hashes. Artifact validation resolves recorded Git objects rather than
  ambient checkout files or environment-selected authority.

## Build and acceptance

The existing pinned Godot 4.5.2 editor/export templates and bundled Windows Node
archive are available from the reviewed local toolchain cache. Build state will
use the disk-backed owned package root, avoiding tmpfs capacity pressure.

Acceptance includes extracted Linux startup/resource/ownership checks and static
Windows package validation. Native Windows execution, physical hardware feel,
eight-human play and natural full-wave campaigns remain owner-run evidence;
scripted fixtures will not be labelled as those outcomes.

The package verifier's old default-combat assumption has been updated for the
current Home supervisor: default boot must display the exported Home without
creating an authority, while explicit combat setup retains its independent
readiness/cleanup case. This change will be exercised against the final package.

Discovery findings, implementation commits, serial verification results and final
package paths/hashes will be appended as work completes.

## Objective discovery and implementation assignment

All three IDs are implemented in the source. No map-catalog expansion or source
authority edit is required:

| Mode | Existing supported maps | Source semantics that native presentation must preserve |
| --- | --- | --- |
| `uplink` | Meridian Exchange, Verdant Reliquary, Ember Crucible | Three shared sequential stage captures; most banked captures wins. Objective kind is `koth`, not the mode ID. |
| `holdout` | Meridian Exchange, Verdant Reliquary, Ember Crucible | Own a quorum of two zones continuously for 30 seconds; losing ownership quorum resets progress. Objective kind is `domination`. |
| `assault` | Tidal Citadel, Sunscar Convoy | Attackers breach ordered sectors; defenders win an unbreached timeout. Sector count uses source `fragLimit` (1–9). Source vehicles stay enabled. |

The objective-mode orchestrator owns one zone-family worker (Uplink/Holdout), one
Assault worker, and shared mode launch/route/scoreboard integration. Assault must
consume its source sectors from the snapshot's `zones` field and must not require
a `contested` flag that the source does not publish. Source `over`, `overReason`
and `winner` determine all endings, including timeout and tiebreak cases.

The independent vehicle stream supplies reusable vehicle coverage for Assault;
an infantry-only composition is not complete Assault parity. Shared package and
aggregate registration remain with the parent integration owner.
