# Cinematic v3 — source-driven refresh

Status: **READY FOR CAPTURE**, subject to the exclusive heavy-slot grant.
Baseline: expansion-four brief at `e9d784a7`; published runtime `e731fd53`.

## Audit and concrete changes

The prior `tools/godot-campaign/trailer*.{mjs,json,py}` pipeline records actual
CampaignMatch snapshots, then renders production Godot nodes. Its 48-second,
960×540 cut uses controlled placement and disables robot locomotion AI during
staged action. Its menu exporter hardcodes forest/Mara/Patch/fire: three Rootfall
clips and one Siltwake clip. Packaged replay provenance is `cec6663e…`, before
the latest accepted four-biome/animation/features pass.

`godot/ui/attract/demo.gd` already provides the right live-menu architecture:
silent private 3D viewport, public recorded snapshots, production cast, bounded
terrain/event presentation, no session or authority, immediate foreground input,
pause on overlays/focus loss, and explicit world disposal. No production changes
are needed before the refreshed data is rendered and reviewed. Existing main-menu
live acceptance assumes exactly four clips/index positions; a separate candidate
fixture validates the new eight-clip sequence without modifying the installed file.

## 75-second composition

`tools/release/cinematic-v3/manifest.mjs` is executable source data: 16 shots,
1,800 planned native output images, 1280×720, 24 timeline samples per second.
Source authority advances at 60 Hz. Edit boundaries follow the existing original
Relay / Warden score's three-second bars, with its 48-second phrase loop intact.

1. Rootfall canopy/nursery silhouette, Mara's actual arrival caption, Patch's
   accepted pet response, ordinary default-spawn sprint.
2. Siltwake waterwheel/riverworks, Ivo's actual arrival caption, input-fired pulse
   combat against active production AI, a ferry-route glimpse.
3. Emberline foundry/cooling district, walking/jumping the connected condenser
   detour, staged robots, source melee hit, real artillery event presentation.
4. Crown choir/receiver district, existing Warden role, garden/title resolution.

Six cubic camera splines resolve from authored optional-route coordinates rather
than guessed map centers. Each candidate is checked at 121 source terrain/block
samples. Low arc, lateral approach and a brief target glance provide composition;
small deterministic side/lift alternatives avoid collision. Resolved control
points and checks are recorded in the plan. This does **not** prove native art
occlusion, clear district silhouettes or good visual cuts; those require review.

Mara/Ivo/Patch are the implemented source cast and captions, not invented voiced
dialogue. Existing robots/art/weather render through the production campaign
session. No queued skins or maps are advertised. Optional map assets remain empty;
the baseline refuses additions until a separately reviewed map-specific capture
adapter has explicit parent approval and matched geometry/native-art provenance.

## Evidence levels and export

- Staged NPC/pet/melee/robot/artillery/Warden shots retain the existing explicit
  setup/AI fixture, clearly disclosed in every replay header and receipt.
- Rootfall traversal starts at the ordinary spawn. Emberline traversal uses a
  controlled authored-route start. Siltwake combat uses supported controlled
  encounter deployment, then leaves production enemy AI active.
- After setup, these three new shots mutate gameplay only through validated input,
  InputBuffer and `match.step`; no per-frame position/health/score/objective writes.
- This is offline scripted-source evidence rendered natively, **not** connected
  native input, human play, full campaign completion or real-GPU performance.
- FP footage retains mission/health/ammo/comms HUD. Only composed cameras hide HUD
  and receive presentation bars. Original full-viewport PNGs remain external.
- Per-frame source index/time, monotonic render/save timestamps, engine-frame
  increments, save errors, dimensions, camera and potential cast visibility are
  retained. Output holes fail; observed wall FPS is distinct from encoded FPS.
- Manifest, runtime tracked-blob inventory, exact recipe/script SHA256s, geometry
  hashes, replay digests and licensed music stem hashes bind each attempt.
- Evidence is append-only at attempt/shot level. No old gallery, replay or video is
  overwritten. Child processes run serially with LP_NUM_THREADS=1; timeout and
  interrupt kill only the owned process group and await its closure.

The edit exports an H264 CRF16/PCM24 master plus AAC delivery, keeps original PNGs,
performs two-pass -18 LUFS normalization, checks decoded delivery true peak ≤-1.5
dBTP, probes dimensions/duration, fully decodes, and creates a first/last-frame
contact sheet across all cuts. It uses the existing original game score and CC0
sample provenance. It claims **music-only edit audio**, not a captured live mix.
Listening and visual approval remain mandatory, even when automated checks pass.

## Live attract refresh

Preparation exports `attract-candidate.json` in unchanged version-1/12-Hz format:
Rootfall reveal/Mara/Patch, Siltwake reveal/Ivo/combat, Emberline reveal and Crown
reveal. Every pair of source records contributes all events exactly once. The
candidate uses a conservative 4 MiB limit and existing actor/event caps. It lives
outside production pending native acceptance; parent installs the accepted bytes
and runs production menu/package gates in a separate integration commit.
