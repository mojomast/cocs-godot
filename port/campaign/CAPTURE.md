# Campaign graphical acceptance capture

These tools capture the **actual `res://campaign/demo.tscn`** with its terrain,
robot visuals, first-person rig, HUD, Settings and authority-driven ground warning
rings. They own a loopback campaign authority and use its existing trusted
`matchFactory` seam. No production route or cheat flag is added.

## Evidence qualification

Every PNG carries `SCRIPTED AUTHORITY FIXTURE | <scenario>`. The manifest and
per-image metadata also label the scenarios scripted. The fixture places real
source actors on supported authored/nav points near encounter one, supplies three
robot roles, and freezes their poses while the real authority publishes ordinary
normal-rate snapshots, events, ACKs and input epochs. A scripted 25-second mortar
windup gives the renderer a reproducible ground-warning view; it is not a claim
about production attack timing. The briefing uses the unmodified production
preview camera and checks its above-ground clearance; gameplay uses the normal
received player-eye camera. The production preview now provides temporary ambient
and sun lighting until `av_start` installs live atmosphere.

Death sets the authoritative player's health to zero and runs the actual campaign
step. Retry goes through the real HUD button, WebSocket action and fresh start.
Level completion stages the exit checkpoint/position then runs the actual mission
update. **Crown Array's ending is obtained only by pressing Continue through the
real client**: the production authority emits a new same-map start/epoch followed
by campaign-complete results. Both the client fixture and recorded wire sequence
check that boundary. No client model text or results frame is injected.

These captures are visual/UI acceptance evidence, **not** organic playthrough,
movement smoke, combat balance, hardware performance, or pacing evidence.

## Run after final worlds integration (serialized graphical slot)

Use the pinned Godot binary and a working graphical display. Do not add
`--headless`: the fixture reads rendered viewport images. On the existing review
display, run:

```bash
GODOT_BIN=/path/to/pinned/Godot node port/campaign/live-capture.mjs
```

Without an existing display, the repository's equivalent software-rendered Xvfb
path is suitable for layout/art review (not hardware performance):

```bash
xvfb-run -a -s '-screen 0 1280x800x24' env \
  LIBGL_ALWAYS_SOFTWARE=1 GODOT_BIN=/path/to/pinned/Godot \
  node port/campaign/live-capture.mjs
```

Default: all four maps, each at **1280×800 / UI100** and **760×520 / UI150**.
For a focused rerun:

```bash
GODOT_BIN=/path/to/pinned/Godot node port/campaign/live-capture.mjs \
  --map=crown-array --profile=compact
```

For the final exported PCK:

```bash
GODOT_BIN=/path/to/pinned/Godot node port/campaign/live-capture.mjs \
  --pack=/absolute/path/to/exported/game.pck
```

`--pack` uses `--main-pack` and the external absolute-path test script. It does
not copy test scripts into the pack or change its resources. The exported pack
must already contain the production campaign scene/resources and autoloads;
the working tree supplies the matching real Node authority/maps. The invocation
and pack path are recorded, and the normal geometry-hash handshake still applies.

## Outputs and checks

A fresh directory is created beneath:

```
/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/live-captures/run-*/
```

No evidence is overwritten or written into the repository. Optional
`--output=/absolute/external/directory` changes the parent evidence directory.
Each map/profile contains PNGs for briefing and its scroll-reachable action,
gameplay, long subtitle, Settings overlay, death/action, result/action, and (Crown
Array only) ending. It also contains:

- `capture-report.json`: physical/logical sizes, UI scale, per-widget rectangles
  and text line counts, visible robot/ring counts, starts/epochs/ACKs, renderer,
  adapter, and explicit failures.
- `authority-wire.json`: actual lifecycle/actions, results and telegraph events.
- `invocation.json` and `godot.log`.
- Run-root `index.json`: all map/profile outcomes.

Checks require actual robot and ground-ring positions in the gameplay camera
frustum, an active first-person rig, and real input ACKs. UI checks reject viewport
overflow, horizontal clipping of scrollable modal content, inaccessible primary
actions, subtitle/vitals overlap, subtitle/status/objective/waypoint versus
crosshair overlap, menu/objective collisions, and modal/subtitle bleed-through.
Settings must release capture and hide the crosshair; closing it cannot recapture.
Any newly exposed chat control is also checked against the crosshair.
Intentional vertical modal scrolling is allowed and independently captured at the
primary action. Primary buttons now remain fixed outside that scrolling content.
Long subtitle wrapping is required rather than silently elided; the bounded comms
viewport is also captured scrolled to its fully reachable final line. Intersection
checks use actually painted rectangles after ancestor clipping, and separately
check the scroll viewport against vitals/crosshair/waypoint. This distinguishes
intentional scroll content from genuine overlapping or off-screen UI.

**All captures are saved even when layout checks fail.** The tool then returns
nonzero and records failures for fixing, rather than treating screenshot creation
as acceptance. Camera-frustum presence is not proof of unoccluded visibility;
review the actual PNGs for occlusion, robot readability and terrain composition.

## Verified source acceptance — 2026-09-30

Pinned Godot 4.5.2, compatibility renderer, llvmpipe/Xvfb, `LP_NUM_THREADS=1`.
All four maps passed each profile, including actual rig/robot/ground-ring checks,
long comms and its scroll tail, Settings, death/retry, results and final ending:

| Profile | Evidence run | Outcomes |
| --- | --- | --- |
| 760×520 / UI150 | `live-captures/run-wBDkBR` | 4/4 pass, 41 PNGs, zero failures |
| 1280×800 / UI100 | `live-captures/run-kZEpPZ` | 4/4 pass, 41 PNGs, zero failures |

Paths are relative to `/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/`.
Every gameplay capture records three robots and one warning ring in the camera
frustum, real ACKs, active pointer/control eligibility and visible first person.
Both Crown Array runs verify the actual same-map fresh-start/ending wire flow.
Gameplay PNGs for all maps were visually reviewed, alongside compact briefing,
long comms/tail, death, results and ending views. Software rendering does not
establish hardware performance; these remain explicitly scripted scenes.

The initial failing evidence `live-captures/run-tjyEKy` remains intact. It exposed
real fixed-offset HUD overflow and modal bleed-through, plus two fixture bugs:
sparse nav candidates left staged enemies at unrelated spawn heights, and stale
input epochs during slow initialization released capture before the screenshot.
The fixture now requires distinct supported robot positions and makes bounded
explicit recapture clicks after initialization without bypassing focus/lifecycle
checks. Production pointer policy is unchanged.

Product fixes use content-measured bottom anchoring, bounded scrollable comms and
mission text, compact typography, a fixed modal action footer, exclusive modal
HUD visibility, and waypoint placement outside reserved UI rectangles. A compact
Warden health/phase line reads the authoritative `singleplayer.boss` projection.
The campaign suppresses the shared transient F9 tutorial over its mission text;
explicit F9/F10 controls remain available.

`tests/campaign/session.gd` passes, including authoritative boss readout/reset.
Parent-owned `tests/campaign/robots.gd` passed **267 checks, zero failures** with
the camera-driven LOD implementation. No parent-owned robot files were edited.

Node syntax checks can run without loading authority modules:

```bash
node --check port/campaign/capture-scenarios.mjs
node --check port/campaign/live-capture.mjs
```

The exported-PCK capture path is supported but was not exercised in this source
acceptance slot. Parent owns final package/export acceptance. The fixture never
resizes or restyles production HUD widgets to make its checks pass.
