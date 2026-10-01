# Four-level biome campaign workstream

## User requirements

- Four connected single-player campaign levels in the visual family of Canopy
  Divide and Basalt Reach, substantially larger than those 96 × 80 m arenas.
- Target 5–10 minutes of first-playthrough gameplay per level.
- A continuous story, authored pacing and varied gameplay objectives.
- Multiple recognizably different robot-style enemy models and combat roles.
- Flash subagents research best practice first; Astra subagents implement.

## Delivery constraints

- Keep established multiplayer and other native modes working. New campaign
  content is explicitly port-owned; original locked authoritative source bytes
  stay unchanged.
- Integration branch `feature/relay-campaign` starts at `5db21753`.
- Isolated Astra worktrees: `campaign/worlds`, `campaign/runtime`,
  `campaign/robots`, `campaign/client`, `campaign/packaging`.
  Commit scoped changes for integration.
- Serialize engine imports, rendering, heavyweight verification and exports.
- Preserve unrelated untracked files and the existing published biome preview.
- Validate real campaign transitions, player death/retry, checkpoint state,
  objectives, encounters and final ending. Scripted timing or route budgets are
  not evidence of observed human 5–10 minute playthroughs.
- Build both platform artifacts from the same pinned revision; publish actual
  export screenshots and record package acceptance honestly.

Flash research completed before the five Astra implementation lanes launched.
See [research](RESEARCH.md) and the [shared implementation contract](CONTRACT.md).
Packaging/route integration ownership is delegated to `campaign/packaging`;
the orchestrator owns integration verification, evidence and final exports.

## Integration preparation

The source semantic export completed on the integration checkout. The first
pinned-editor import completed its asset scan/import work but crashed on editor
shutdown (signal 11). An incremental retry with `LP_NUM_THREADS=1` exited zero.
Both logs are retained under
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/`; this baseline failure
preceded integration of any campaign runtime code.

An independent Astra interface review identified and clarified feet-vs-centre
coordinates, visual-vs-hitbox scaling, base Match respawn/timeout behavior,
NativeClient chapter validation/input-reset behavior, actor-ID model reuse and
mandatory-route versus drawn-polyline distance. These clarifications were sent
to the relevant implementation lanes before integration.

## Integration progress

All five first implementation commits have been integrated. Initial results:

- 58 launcher/package identity tests passed.
- All four chapters passed real owned-authority native smoke: movement, firing,
  input ACKs, first-person/effects, robot instances and matching geometry hash.
- Authority/mission tests and route closure passed.
- Robot, death-presentation, ground-warning, campaign model/client and terrain
  Godot contracts passed. The session fixture initially needed an explicit
  WeakRef type and cleanup of the newly added ground-warning node; corrected.
- The first world pass passed 13 source movement/route tests, Godot support
  queries and twelve renders. Visual review requested a second pass because
  the chapters shared an overly similar terrace-corridor layout.

The second world pass is integrated: four distinct footprints, original biome
surface/foliage assets, a stitched landscape collar, exact chapter handoff
heights, and 14/14 source route tests. The live graphical acceptance fixtures
are integrated too. The orchestrator now owns the heavy verification slot for
final collision/ending/cache checks, native smokes, compact UI review, full
regression verification and exports.

Initial integration logs are retained under the campaign evidence root in
`integration-first/` and `integration-live-first/`; failures are preserved.

## Final integration repair checkpoint

Revised-world native smokes pass on all four chapters. The first final focused
pass caught a blocked Crown guardian placement, fixture assertion issues, and
compact-screen HUD/capture failures. Runtime repair `c03cd249` passes **23/23
Node tests**, including all-four scripted progression, final Continue, actual
hitscan/projectile volumes, cache behavior and guardian placement across five
seeds. See `integration-final-focused/node-authority-repair-2.log`.

Client repair `a64979d5` fixes the actual briefing camera, compact layout,
scrollable comms, modal actions, waypoint placement and boss readout. All four
maps passed both wide/compact profiles: **82 captures, zero failures**. Every
gameplay capture has three robots, one danger ring, visible first person, ACKs
and active control eligibility. Both Crown profiles verify real Continue →
fresh start → ending results. Evidence: `live-captures/run-wBDkBR/` (compact)
and `live-captures/run-kZEpPZ/` (wide). Initial failed graphical evidence remains
in `live-captures/run-tjyEKy/`. The orchestrator now owns the heavy slot.

Parent change `adea4b65` enables camera-driven robot LOD in actual play and adds
three live-camera checks. All **267 robot checks** and the updated session
contracts pass. A compact campaign UI gate is registered in `verify.py`.

After the client releases its slot: generate the axis/meridian GLB probes,
run the full canonical keep-going verifier with explicit source derivative,
repair relevant failures, commit one runtime identity, export both platforms,
verify extracted packages and recorded Git identity, render release-PCK evidence,
and publish a separate Quiet Relay testing prerelease. Existing published tags
and archives retain their prior identities.

## User art feedback and pending integration

The owner reviewed the public
[development screenshot gallery](https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-gallery-2026-09-30)
and requested an Astra revision of the monotonous, repeated jagged terrain.
The worlds lane (`ses_f0bf6227cffewV7OwI2Pg2zL4h`) is revising actual ridge
geometry and skyline composition in its isolated `campaign/worlds` worktree:
broader landforms, varied crests and wall profiles, per-biome geology, selective
outcrops and less uniformly repeated scenery. Routes, encounters, collision
agreement and chapter continuity remain acceptance requirements. New same-camera
comparison renders will be shared publicly when verified.

The canonical run at `51136196` completed **288/291 gates**. Its three failures
were the expanded route-count/menu expectations and the menu's implicit default
changing with display order. Exact expectations are updated; invalid preferences
now explicitly retain Combat as their safe default. All affected focused checks
pass. Full logs and verification-generated files are preserved under
`canonical-51136196/` outside the checkout. Integrated follow-ups:

- `57488031` → `7e643693`: persistent per-map daylight, since AV owns
  audio/particles and does not install the missing live world sky/sun. Includes
  lifecycle/capture regression checks; environment and session headless checks
  now pass. Graphical confirmation will use the forthcoming revised terrain.
- `925e15ea` → `610aaa99`: exact expanded route/menu test expectations;
  all eight focused parser tests pass.

The terrain-variety revision `c6c3a0e1` is integrated as `5c14ab41`: twenty
source terrain tests and Godot physics/render checks pass. Same-camera comparison
images and twenty revised views are retained in `terrain-variety/`; comparisons
and contact sheets are uploaded to the public development gallery.

The integrated `5c14ab41` authority, terrain, environment, session and all four
native smoke runs pass, including revised geometry hashes. Evidence lives in
`integrated-5c14ab41/`. Its graphical run `captures/run-0uYhBT/` failed: the
lighting assertion counts two environments/three suns after first-person setup,
and some software-rendered gameplay frames lose pointer capture/weapon display.
The capture-repair Astra lane (`ses_f0bf53d86ffeAtBriqa8u8lJtq`) now owns the
exclusive heavy slot to diagnose these failures and verify a scoped repair.
Production input/focus safeguards and effective world lighting remain required.

Export waits for final integrated graphical acceptance. The existing screenshot
gallery is explicitly work in progress, with earlier images retained and labelled.

## Additional user request: melee kick response

The owner confirmed the existing kick and requested swoosh/smack impact audio,
fresh-press-only input with a short rapid-tap cooldown, authoritative enemy
knockback and a confirmed-hit shockwave. See [MELEE.md](MELEE.md). Two isolated
Astra lanes own mechanics/input and shared native audio/VFX. Capture repair
continues to own the heavy slot; these lanes are initially edit-only. Export
also waits for this requested upgrade's integrated acceptance.

## Additional user request: operator detail textures

The owner requested armor-panel and circuit-board texture detail on the playable
operator models. Isolated Astra lane `campaign/operator-textures`
(`ses_f0b620f69ffesvd6lTn1bhtHmt`) owns an explicit native material/detail layer
across the nine identities, keeping source GLB provenance and rigging intact.
The intended finish includes panel seams, fasteners, vents and selective recessed
circuit details, with team colors and silhouettes readable at gameplay distance.
Matched before/after captures, identity/team/pose checks and material resource
costs are required before integration. The lane initially edits only while the
capture-repair lane holds the heavy slot. Kick work continues independently.

## Additional user request: distinct robot voice quips

The owner requested a distinctive voice-like sound for each enemy. Isolated
Astra lane `campaign/robot-voices` (`ses_f0b609999ffe9BcN6uRYikiXfY`) owns six
synthetic vocal identities, contextual authoritative-state/event admission,
spatial playback, repetition limits and session cleanup. Short formant/syllabic
quips should distinguish personalities rather than repitching a common beep.
The lane will supply individual audio previews and a labelled audition reel.
It owns new campaign voice modules and minimal campaign session hooks; shared
weapon/kick feedback remains with the melee lane. Heavy tests await slot release.

## Additional user request: splashy animated damage numbers

The owner requested creative animated numeric damage indicators. Isolated Astra
lane `campaign/damage-numbers` (`ses_f0b5b1ff2ffeh76nLiUS96d0SI`) owns shared
native presentation: authoritative outgoing-hit numbers at targets and distinct
incoming player-damage numbers near the HUD. Direction is a brief splash,
squash/stretch pop, slight arc/tumble and fade, with bounded burst aggregation
and heavier treatment for larger real hits. Requirements include no invented
critical hits, duplicate replay or enemy-vs-enemy clutter, readable compact UI,
reduced-motion behavior, lifecycle cleanup and a rendered animation preview.
This lane starts from integrated melee mechanics/feedback; engine work awaits
the capture-repair lane's heavy-slot release.

Operator texture implementation `a04c5c16` is integrated as `bb79136f` and its
runtime gate is registered. It uses cached face-fitted overlay UVs and four shared
authored textures, preserving original GLBs and adding no overlay draw calls.
Import/runtime checks and before/after renders remain pending the heavy slot.

## Additional user request: epic orchestral score

The owner rejected the music they heard and requested an epic orchestral feel.
Isolated Astra lane `campaign/orchestral-score`
(`ses_f0b5a382cffemwXzsQGV35HbnL`) owns a substantive composition/orchestration
revision using the existing sampled strings, brass and orchestral percussion.
The direction is coherent themes, string ostinatos, brass phrases, low strings,
timpani/cymbal builds, quieter exploration and a stronger Warden finale. A
45–90 second audition showing the transitions is required for subjective review;
automated audio/timing tests do not establish musical quality. Heavy rendering
and audio baking remain serialized behind capture repair.

Robot voice implementation `25006b95` is integrated as `e543ab66`, with a
registered runtime gate. Forty-eight baked clips and the six-voice audition reel
pass deterministic generation, peak and uniqueness checks. Engine integration
and subjective listening are still pending.

## Additional user request: Sol scripted events and recurring puppy

The owner explicitly requested Sol subagents for more scripted events, operator
NPCs and a recurring pettable puppy. `STORY_EVENTS.md` defines the additive
authority/client contract. Sol authority lane `ses_f0b551e14ffecYoeyDSA3smVhk`
owns staged chapter content, authoritative interaction and continuity; Sol client
lane `ses_f0b551dceffey79hEa9L61i9Pp` owns friendly operator staging, Patch the
puppy's articulated model/reactions and contextual UI. Both use isolated branches
from `63251774`, initially edit-only while capture repair owns the heavy slot.

Damage-number implementation `8247678c` is integrated as `c474e687`, with its
runtime gate registered. It consumes authoritative damage totals (including
absorption), groups same-target hits in fixed 100 ms windows, and bounds animated
draw slots to sixteen. Parse checks passed; runtime and wide/compact/reduced-motion
visual checks remain pending. Reproduction commands are in `docs/damage-numbers.md`.

Sol story authority `838228cf` + `c50bb373` is integrated as `753b72e3` +
`0be8260e`: sixteen phase/proximity beats, Mara/Ivo continuity and Patch petting
with source visibility and a one-second reaction cooldown. Twelve isolated
lightweight tests passed. Review requested a follow-up to cache supported story
placements across retries and preserve existing navigation-cache tests. Client
`02427e22` remains isolated pending fixes for JSON numeric transport, operator
feet anchoring, actual rig joints, puppy mesh cost and modal/focus UI behavior.

Sol story client `02427e22` + `643d9ab1` is now integrated as `4f46799d` +
`0dc108e9`; its runtime gate is registered. The reviewed issues have code fixes
and probes, but engine checks have not run. No completed visual/petting evidence
is claimed yet.

## Serialized verification queue

The capture-repair lane remains the sole owner of heavy engine work. Once it
returns, integrate its scoped repair and run an editor import before the new
runtime tests: melee mechanics/controls/feedback, operator textures, robot voices,
damage numbers, story authority/client and campaign session contracts. Then
produce the promised audio exports and operator/damage/story graphical previews,
followed by actual-authority petting and all four integrated campaign captures.
The orchestral lane still owes its composition commit and audition artifact.

The new explicitly audited melee derivative is `0326b435`; source verification
has passed in the parent checkout. The broad canonical run at `51136196` predates
all these gameplay/presentation additions. A fresh canonical acceptance pass is
needed on final integrated inputs before committing one export identity and
building/verifying Linux and Windows serially. Earlier failed logs and existing
published releases remain retained.

Story placement-cache follow-up `fee59843` is integrated as `8bd4f0f9`. One
arena-keyed cache covers operator and puppy placement, with terrain-surface,
route and anchor identity invalidation. The terrain support grid now invalidates
with replaced surfaces. All fifteen isolated navigation/story/authority checks
passed, retaining zero repeated triangle reads and no navigation rebuild on retry.

Orchestral source revision `a91a5a8c` is integrated as `e6dabc10`. **This checkout
requires the pending generated stem assets before music playback or export.**
Render with `tools/godot-audiovisual/orchestral_score.py`, validate with
`orchestral_verify.py`, import, then run the score-form/lifetime tests and the
actual-engine audition described in `docs/orchestral-score-20260930.md`. The
parent has instructed the capture-repair lane to finish its current command,
return its scoped fix/results and release the slot; repeating all old-base
captures is superseded by the forthcoming full integrated acceptance pass.

## Music render and trailer / attract-demo request

The heavy slot returned with capture repair `eae68904`, integrated as `8b1bacbc`.
Its old-base eight profile runs/82 PNGs passed; later additions remain unverified.
The parent rendered all four orchestral PCM stems, passed the stem integrity,
headroom and phase verifier, and completed editor import without errors. The
first engine score test exposed a strict inferred-Variant warning in its WeakRef
fixture; an explicit type fixes it. A paced PulseAudio audition and score/lifetime
checks are running serially; the initial failure is retained.

The owner now also requests a cinematic campaign trailer and main-menu attract
demo. Astra `campaign/trailer` (`ses_f0b446962ffeoJrAVel3PjJYIz`) owns storyboard,
actual in-engine capture and music-synced editing/MP4/Theora production. Sol
`campaign/menu-attract` (`ses_f0b44196bffeLTLjawLXO4kDmZ`) owns background menu
playback, focus/settings lifecycle and silent-video integration. The owner
clarified that the demo must play beneath the usable menu, like original COCS:
no fullscreen takeover, idle delay or input consumption. Both lanes received this
correction; the menu cut omits promotional title overlays.
Both initially edit only while music audition holds the heavy slot. The trailer
must feature terrain, combat, operator NPCs, petting Patch, robots and the finale,
with authored text overlays and documented scripted in-engine footage.

Music preview completed: the four stems are committed in `5258591d` with explicit
uncompressed PCM import settings. Score-form and menu rapid-lifetime tests pass.
Actual Godot/PulseAudio 72-second audition passes at 44.1 kHz stereo with no
dropped capture frames. A linearly level-adjusted MP3 (roughly -16 LUFS, dynamics
retained) and raw WAV are published on the development gallery release. Evidence:
`orchestral-score/audition-results-4.json`, `quiet-relay-orchestral-preview.wav.json`
and `mp3-linear-encode.log`. Earlier parse/import/audio-server failures are retained.
Music quality remains subject to the owner's listening feedback.

Trailer tooling `7997aa0b` is integrated as `3622c734`. After focused integration
checks, the trailer lane received the **exclusive heavy slot** and parent head
`19884ca1` to render sample shots, repair actual capture issues and produce the
finished MP4 plus silent menu Theora. Parent engine/build work pauses until that
handoff. The lane owns the final media task, not only the prepared scripts.

Focused integration at `bfb91314` passed Node melee/story/campaign, melee feedback,
damage numbers and settings. Repairs in `19884ca1` fix strict GDScript typing,
floating-point test comparison and explicit robot voice PCM import settings.
Operator textures, story presentation and campaign session then passed; robot
voices passed **238 checks / zero failures** after PCM import. Menu background
contracts exposed six failures; the Sol menu lane is correcting them in isolation
without engine work while the trailer owns the slot. All failures are retained in
`feature-integration-bfb91314/` and `repair-1/`.

Menu follow-up `1e55bfaa` is integrated as `c4e33142`: only the headless mock
media seam bypasses the virtual minimized-window state. Real minimized/unfocused
windows remain paused. The menu runtime contracts must be rerun once the trailer
releases the slot; actual Theora-under-interface acceptance waits for its media.

## Corrected menu requirement: live engine rendering

The owner clarified that the menu demo must be a scripted scene rendered in
Godot, **not a video**; the trailer remains MP4. Both lanes received the override.
The trailer lane retains the exclusive heavy slot for video production and will
export compact verified authority replay data instead of Theora. The Sol menu
lane replaces VideoStream playback with isolated real 3D rendering behind the
usable interface. `ATTRACT_DEMO.md` defines their shared replay contract. Earlier
Theora plans are historical and superseded; no menu video will be installed.

The owner requested operator-detail screenshots immediately. The trailer lane,
which owns the heavy slot, is instructed to finish its current safe command and
prioritize the real operator texture gallery under
`operator-textures/rendered-20260930/`, then return images for parent review and
public upload. Trailer progress is preserved and will resume after that handoff.

Operator gallery completed: **164 original PNGs plus three comparison crops**.
Parent reviewed Claude/Grok before-after and the nine-identity roster; thirteen
selected images are published with the `operator-details-` prefix on the gallery
release. No operator render fixes were needed. Trailer checkpoint `0ba1bfed`
integrated as `f1dc8d91`; all thirteen authority receipts and Patch/fire/terrain
samples passed in that lane. The exclusive slot has returned to the trailer
lane for final MP4 and the live-menu JSON, with Theora explicitly canceled.
The old video-background menu contracts passed after the window-state fix; the
replacement engine-demo component will require its own runtime verification.

Live menu implementation `eb4e5b74` is integrated as `f60137bc`. Static review
identified asynchronous build readiness, descendant processing during pause,
story-operator visibility and camera/event fidelity issues. The Sol lane owns a
follow-up correction and meaningful runtime fixture, still edit-only while the
trailer has the exclusive slot. Live menu rendering is not yet accepted.
