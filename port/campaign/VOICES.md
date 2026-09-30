# Campaign robot vocalizations

Original procedural, non-English voice-like gestures for the six authoritative
`npcModel` identities. These are glottal/noise excitation through three moving
vowel-formant resonators, with model-specific syllabic envelopes, consonant-like
gaps, rasp, tremolo and (Warden) subharmonic/detuned layers. They are not six pitch
shifts of one beep. No external audio, model, service, or recorded speech is used.

| Model | Intended character | Combined audition start |
|---|---|---:|
| Scrapper | Four short raspy/chittering imp syllables | 0.000 s |
| Skirmisher | Clipped three-part taunt with falling syllable energy | 6.063 s |
| Sentinel | Smooth two-syllable warbling status voice | 12.541 s |
| Mortar | Low hollow three-count mutter with long gaps | 20.019 s |
| Bulwark | Gravelly long/short mechanical grunt | 29.077 s |
| Warden | Deep layered three-part commanding phrase | 35.834 s |

## Human audition

`godot/campaign/robot_voice_assets/audition/all_robots.wav` is the 44.93-second
combined reel. Each model has its own `<model>.wav` in that directory. Within
each section: encounter variants 1/2, attack variants 1/2, hurt variants 1/2,
death variants 1/2, with 350 ms silence after each. `timeline.json` gives the
exact label, offset and duration of all 48 clips. Publish that reel and timestamp
list for human listening; waveform checks do **not** establish that it sounds
good. No human audition has been claimed by the implementation agent.

## Runtime behavior

`godot/campaign/robot_voices.gd` owns 48 pre-baked mono 22,050 Hz PCM WAV streams
(two variations × four contexts × six classes) and exactly two
`AudioStreamPlayer3D` children. No synthesis, stream construction, audio-buffer
allocation, or audio-node allocation occurs per frame or cue. Variation alternates
deterministically per class/context. Maximum PCM peak is 0.68; player gain is
−8 dB before distance attenuation. Unit distance is 8 m, maximum distance 42 m.

Snapshots supply all triggers:

* **Encounter activation**, explicitly not a claimed AI “spotted player” event:
  first received playing `campaign.stepIndex` with `enemiesRemaining > 0`.
  Exactly one representative live robot speaks, preferring Warden then nearest.
  The step is consumed even if muted, distant, or unfocused. New actors alone
  never cause chatter.
* **Attack preparation**: rising edge of received `artilleryWindup`,
  `flankWindup`, `phalanxWindup`, or `bossStompWindup`. Scrapper and Sentinel have
  no reliable anticipation field, so their attack assets are auditionable but
  do not fabricate a preparation event in play.
* **Hurt/death**: received health reduction / live-to-dead edge. Already-dead
  actors and unchanged snapshots never retrigger. Snapshot state is copied,
  preventing a caller's dictionary mutation from erasing an edge.

The service intentionally uses one snapshot source for each cue. It does not
also subscribe to damage/telegraph events, avoiding event-versus-snapshot double
playback. Equal/older authority times are discarded. There is no queued chatter.

Per-actor cooldown is 2.8 s (Warden 1.8 s), per-class 1.4 s, and global spacing
650 ms. Warden is processed first, can bypass global spacing, and can replace a
non-boss/non-death voice if both slots are occupied; it still obeys its actor and
class cooldowns. Hurt/death can be suppressed by these shared budgets. Distance,
dead-state and lifecycle checks happen before budget consumption.

The shared `audio/buses.gd` applies Effects gain once and Master remains parent.
Robot speech is diegetic SFX, so it follows Effects volume, Master mute, `--mute`
and `--mute-capture`. The existing **Announcer voice** switch is specifically
opt-in recorded narration (default off), not a general creature-voice setting;
this implementation does not repurpose it or add a new preference.

Campaign hooks stop on focus/staleness/settings overlay, death/results, pending
retry, transport loss, errors and leaving. Suspended snapshots still drain edges;
the first fresh snapshot after resumption also drains to prevent stale damage
being spoken. Explicit start/retry clears the epoch, actor history, encounter
history and all budgets. Exiting the node clears cache references and its two
child players are freed with it. Cache size and voice pool never grow in play.

## Generation and verification

```sh
python3 port/campaign/tools/robot_voice_synth.py
python3 port/campaign/tools/robot_voice_synth.py --check
```

The check verifies exact deterministic WAV bytes, all 48 distinct hashes,
bounded peaks, silent boundaries, and all 15 class pairs' distinct normalized
12-bin temporal envelopes and 20-band spectral fingerprints. These measurements
are committed in `fingerprints.json`. Committed `signatures.json` permits
independent asset accounting. All assets reside under `res://campaign/` for
normal Godot resource export; the audition directory is review material only.

After the coordinator grants the heavy slot and completes the normal import:

```sh
godot --headless --path godot --script res://tests/campaign/robot_voices.gd
```

Use the repository's Godot binary if it has a different executable name. Do not
pass `--mute` to this test: it exercises playback admission and does not need a
physical audio device. It checks resource closure, PCM shape/peak bounds, unique
waveforms and all 15 pairs of time-normalized energy envelopes (which rejects
mere pitch-shift clones), snapshot deduplication, windup edges, encounter limits,
damage/death, global/class/actor cooldowns, boss priority, distance/dead rejection,
mute/SFX-zero, suspension draining, retry epochs and spatial routing.

The parent owns registration in `verify.py`. This branch has only run modest
offline generation/reproducibility and envelope analysis; Godot import, runtime
tests, and in-game/human listening remain pending the shared heavy slot.
