# Enemy windup audio: source audit and delta

Base: `27cfaa14`, branch `expansion-three/audio`. Source authority, frozen pins,
generated gameplay core and all server rules remain unchanged.

## Actual baseline audit

* `game/feedback.mjs:388–397, 2047–2062, 2436–2440`: eight distinct
  `TELEGRAPH_CUES`, including generic; one voice token per motif, current mode
  root, triangle notes, 1.42 frequency sweep, optional filtered noise shimmer,
  30-unit linear XZ falloff and >.03 audibility threshold.
* `game/singleplayer.mjs:659–865`: actual role updates emit `enemy-telegraph`.
  Overseer/mender/flanker/phalanx/sapper/artillery/boss have separate authored
  windup and cooldown logic. Artillery and boss point at the **target mark**;
  using the robot's position would misrepresent the incoming threat.
* `godot/campaign/telegraphs.gd` already consumes these marks visually;
  `godot/experience/caption_model.gd:6,36–38` already captions source kinds.
* `godot/campaign/robot_voices.gd:5–6,86–110,143–177` already supplies synthetic
  creature speech, including four snapshot windup edges, with two voices and
  actor/class/global cooldowns. These are **not missing robot vocalizations**.
  Their model-position grunts do not implement source target-mark motifs,
  overseer/mender/sapper event warnings, or the generic campaign `attack` cue.
* `godot/audio/event_router.gd` did not accept `enemy-telegraph`, and neither
  `godot/world/audio_feedback.gd` nor objective motifs supplied these motifs.
* Existing weapon/alt-fire/melee/mobility feedback, objective motifs, procedural
  vehicle loops, sample music, orchestral transitions, opt-in announcer and
  weather/ambience are implemented. In particular `av_service.gd:182–199` and
  `music_service.gd` already adapt music to recent combat; no music re-port.
* Vehicle reports still use a single native generic report and ignore remote
  report position. Ordinary `PortAudioFeedback` is explicitly non-positional.
  These are separate remaining parity gaps, not changes in this batch.

## Delivered delta

`threat_service.gd` renders the existing authoritative **event** through eight
source-derived earcons at its actual source mark. Unknown kinds (including
campaign `kind=attack`) use the source generic cue. Router keeps identity,
kind, actor, position, time and duration in one descriptor. Caption/model code
is untouched: no inferred attacks, replacement text or speculative timers.

`telegraph_pack.mjs` extracts and executes the actual exported source tables,
then generates PCM16 at 22,050 Hz for every distinct source mode root. Notes,
onsets, duration, gain, attack, exponential envelope and pitch sweep retain
source parameters. Overseer/boss retain their highpass shimmer. There is no
peak normalization, loudness boost, external recording or fetched soundtrack.

Deliberate native realization differences (not waveform-exact WebAudio claims):

* Deterministic triangle oscillator and sample-rate biquad rather than browser
  oscillator/filter implementation; fixed-seed noise rather than random buffer.
* Godot spatial panner at the source mark instead of WebAudio StereoPanner.
  Source linear XZ gain is explicit; native distance attenuation and Doppler
  are disabled. No occlusion or second distance filter is added.
* Dry local Effects bus; source optional room convolution send is not reproduced.
* Four reserved threat voices instead of competing with the browser's 30-token
  mixed pool. Boss priority, 80 ms attack protection (boss may preempt an ordinary
  tell even inside that guard) and .15 replacement margin
  are explicit **port presentation enhancements**, not source rules.
* Expired windups are discarded against the received snapshot time. There is
  no invented per-kind cooldown: source cooldowns remain authoritative.

## Bounded cost / ownership

160 generated files, 3,191,080 WAV bytes total; 20 roots × eight motifs.
Only eight selected-root streams retained by the service, loaded on mode change,
never on event dispatch. Four fixed players; no event queue or per-frame PCM.
Maximum new single-motif peak: 0.09732718897213075 before PCM quantization.
Four unity-gain motifs have a conservative sum bound <.390; this is **not** a
claim about the whole existing Effects mix. Pool priorities use actual gain;
equal/near-equal threats cannot repeatedly steal each other.

Effects volume is applied once by existing buses; mute/zero Effects/focus,
round/seek/stale/results/exit release voices. Wire IDs are consumed while
inaudible; nothing queues for unmute. Existing two robot-grunt voices remain
separate (combined threat + robot maximum six). Listen for masking after grant.
No added settings, ambience changes, announcer rewrite or physics/authority edits.

## Provenance / robot-lane coordination

Original deterministic procedural realization of repository source math under
the existing project/source reuse permissions. No new third-party license is
asserted or required by an external sample. `godot/audio/telegraphs/manifest.json`
contains extracted vectors, all roots, frame counts, peaks and SHA-256 inventory.
Regenerate with `node tools/godot-audiovisual/expansion/telegraph_pack.mjs`.

Robot lane should retain wire `kind` and target `x/z`: a mortar model uses
`artillery`, a Warden uses `boss`; these are not interchangeable model IDs.
Existing robot grunts are character sounds; this lane owns only windup motifs.
Shared `av_service.gd` attachment is isolated in a follow-up hook commit and must
be merged with world lane's confirmed `12f0aa1b` weather ownership context.
