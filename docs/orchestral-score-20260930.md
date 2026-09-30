# Relay / Warden — native orchestral revision

## Status and handoff

Branch `campaign/orchestral-score`, based on `06792d58`, isolated worktree
`/home/mojo/.tmp-on-disk/cocs-orchestral-score-20260930`.

**Source implementation and lightweight structural checks are complete. Audio
render, Godot import/tests, and actual audition are pending the parent's heavy
slot grant.** No engine or full offline audio render has been run in this lane.
The generated stems must be rendered, verified, imported, and committed before
shipping/cherry-picking this as a working audio change. Missing stems produce an
explicit diagnostic; there is no electronic or old-score fallback.

No listening or perceptual-quality claim is made. Parent must publish the actual
audition and solicit feedback before calling musical quality complete.

## Diagnosis of the rejected native arrangement

Inspected `godot/audio/music_service.gd`, native/source manifests,
`tools/godot-audiovisual/music_pack.mjs`, `scripts/music-bake.mjs`, source
`game/music.mjs` arrangements, and `assets/music/THIRD_PARTY_LICENSES.md`.

* The 37 native samples really are VSCO/VCSL orchestral recordings. There was
  **no electronic fallback in the native service**; the web source does have
  synthesized optional layers. Blaming a nonexistent native GM fallback would
  misdiagnose the audible problem.
* Native `_note` ignored loopStart/loopEnd. Its duration set a voice-reuse
  deadline instead of a sustain/release envelope, so a later note could abruptly
  replace a still-playing string/brass recording. Whole Ogg one-shots also kept
  sounding beyond requested lengths when no later note claimed the voice.
* Three or four widely spaced chord notes, constantly reattacked short leads,
  scale-degree arpeggios unrelated to actual major/minor chord tones, and motif
  transposition with *every chord root* obscured melody and voice-leading.
* The shared `low-brass` nearest-note family could change horn into tuba or
  trombone based on register, rather than preserve an authored orchestration.
* Presentation-frame sixteenth-note dispatch and scene-dependent BPM changes
  could bunch attacks and change phase midphrase. The fixed 19-voice pool could
  truncate/drop dense attacks. Native swells and rolls existed but were unused.

## Composition and sound production

New original material, **Relay / Warden**, 80 BPM, 4/4, sixteen bars / 48 seconds.
Harmony: Dm–Bb–F–C | Gm–Dm–A–A | Bb–Gm–Dm–A | Bb–C–A–Dm.
The opening D–A–F gesture is answered and developed in explicitly authored
phrases. Melody is fixed in concert pitch; C# functions as the dominant leading
tone. The G-minor phrase includes named passing tones rather than random notes.

Four simultaneous stems:

1. **Strings:** real sustained cello/viola/violin sections, independent inner
   voices, violin statement/cadence, restrained harp, four-bar dynamic arch.
2. **Motion:** low-cellos' D2-register bass attacks and grouped 3+3+2 eighth-note
   ostinati with phrase-end space, pitched timpani, bass drum, rolls.
3. **Brass:** explicitly selected French horn phrases with breathing gaps,
   trombone/tuba harmonic support, trumpet doubling in the developed half.
4. **Warden:** measured string tremolo, low brass, horn fifth accents, suspended
   cymbal crescendos, timpani rolls, bass drum/crash peaks and final bell.

658 authored events select 43 existing CC0 source recordings. Recorded round
robins alternate deterministically. Source selection is instrument-specific,
with pitch shifts bounded to one octave. No external music, theme copy, GM
soundfont, oscillator pad, drum kit or new download is involved.

The offline renderer uses the existing sustain loop metadata with a 60ms
overlap, attack/release and phrase envelopes, stereo orchestral placement, and
fixed early/late room reflections. Releases/reflections wrap through the end
of the form, producing phase-aligned cyclic stems. Normalization uses the
sample-wise sum of absolute stem amplitudes: *any* gain combination <=1 stays
below 0.701 sample peak, including quantization allowance. This is headroom
verification, not a quality score or an intersample true-peak measurement.

`orchestral/manifest.json` records each selected source's CC0 license, upstream
URL, source description, original baked-file SHA-256, and each generated WAV's
SHA-256. Existing full license text remains in
`assets/music/THIRD_PARTY_LICENSES.md`.

## Native integration

`orchestral_score.gd` uses one `AudioStreamSynchronized` with four PCM streams,
identical frame counts and loop boundaries. Adaptive changes modify gains only;
they never restart a stem or change tempo. Targets latch at the next bar (at
most three seconds), ramping in over one beat and out over two beats.

Exploration exposes the quieter strings/harp bed. Combat introduces motion and
brass. Existing intensity/tension control their weight. Warden phase 1–3 scales
the finale layer; escalation 3 also enables it in non-campaign modes. Menu uses
a moderate horn statement. Results release percussion and retain strings/brass.

`av_service.gd` reads existing `singleplayer.boss.alive/hp/phase` presentation
state, with no authority changes. `campaign/demo.gd` is untouched. Native music
settings, Score bus, mute/zero volume, focus reset, explicit tick/start, and scene
cleanup retain ownership. Existing announcer/cue sample players remain bounded.
Seed and variation setters remain compatible metadata; they no longer randomly
alter the composed harmony. Updated tests compare adaptive layers instead of
expecting random seeded semitone changes.

## Resource budgets

* Each stem: 1,536,000 frames, stereo signed PCM16, 32,000Hz, exactly 48s.
* Each WAV: 6,144,044 bytes; four files: **24,576,176 bytes / 23.44 MiB**,
  plus a small provenance manifest. No compressed decoder timing ambiguity.
* Runtime stem PCM: **24,576,000 bytes**; four constant synchronized streams,
  one player; no runtime composing, sample decoding or per-note allocations.
* Existing bank retained: 37 Ogg files / 938,092 compressed bytes; announcer:
  36 WAV files / 2,130,384 bytes. Existing 19 cue voices plus dedicated announcer
  remain the cue ceiling; the score itself consumes four streams.
* Offline render uses numpy plus ffmpeg and is designed for <256 MiB working
  memory. This is a planned budget, not an observed peak-RSS measurement.
* A 72s stereo PCM16 audition is 12.70MB at 44.1kHz (13.82MB at 48kHz).
  The capture is frame-bounded and rejects unpaced/null-device or dropped audio.

## Checks already performed (lightweight only)

`python3 tools/godot-audiovisual/orchestral_score.py --check` passes:
harmonic membership with explicit passing tones, phrase-end rests, phrase
development, sample-family existence/CC0, bounded pitch transposition,
event timing/gains, 16-bar frame budget and source-file existence.
Both Python scripts compile. `git diff --check` passes.

## Commands pending exclusive heavy slot

Use the parent's existing Godot 4.5 executable as `$GODOT` and its **paced real
audio output** as `$AUDIO_DRIVER` (e.g. PulseAudio). Do not use Dummy for audible
evidence or an unpaced ALSA null sink. Run commands sequentially in this worktree.

```bash
python3 tools/godot-audiovisual/orchestral_score.py
python3 tools/godot-audiovisual/orchestral_verify.py
"$GODOT" --headless --path godot --editor --import
"$GODOT" --headless --path godot --script res://tests/audio_new/score_form.gd
"$GODOT" --headless --path godot --script res://tests/audio_new/menu_rapid_lifetime.gd
```

The verifier checks exact PCM lengths/format and hashes, finite/non-silent
samples, conservative adaptive headroom, and loop-edge discontinuity. Engine
tests cover phase-preserving transitions, musical-bar target latching, invalid
deltas, mute/disable/zero-volume/focus restart, and release on node teardown.

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/orchestral-score/`.
Preserve the rejected service for an actual same-driver, same-settings A/B:

```bash
mkdir -p /home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/orchestral-score
git show 06792d58:godot/audio/music_service.gd > /home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/orchestral-score/before_service.gd
"$GODOT" --path godot --display-driver headless --audio-driver "$AUDIO_DRIVER" --script res://tests/audio_new/orchestral_audition.gd -- --output=/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/orchestral-score/after.wav
"$GODOT" --path godot --display-driver headless --audio-driver "$AUDIO_DRIVER" --script res://tests/audio_new/orchestral_audition.gd -- --legacy=/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/orchestral-score/before_service.gd --output=/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/orchestral-score/before.wav
```

Each take: 0–18s exploration, 18–36s combat, 36–54s Warden,
54–66s phase-3 finale, 66–72s victory release. Changes enter on bar boundaries.
Each take gets a JSON checkpoint/status sidecar. These are actual service output
auditions rather than a separately synthesized demonstration. Before lacks the
new Warden setter, so it receives the same scene/intensity/escalation settings.
For a fair loudness comparison, publish loudness-matched previews alongside raw
WAVs (same target for both, not peak-normalizing only the new arrangement).

Finally stage the four WAVs and generated manifest and commit them; import
metadata follows the repository's normal Godot policy. Then parent reviews the
audition, seeks user feedback, and verifies campaign/menu playback in its build.
