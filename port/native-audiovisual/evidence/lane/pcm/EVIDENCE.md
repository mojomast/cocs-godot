# Audio PCM capture evidence — bounded Master DSP + seeded variation

Date: 2026-09-29
Repo: `/home/mojo/.tmp-on-disk/cocs-audiovisual-expansion` (branch `port/audiovisual-expansion-20260929`)
Godot: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64` (`4.5.2.stable.official.6ce3de25a`)
Evidence root: `/tmp/opencode/audio-slot-20260929/pcm/`

## Ownership / scope

- Edited: `godot/tests/audio_new/waveform_capture.gd` (only existing file touched).
- Added: `godot/tests/audio_new/pcm_driver_probe.gd`, `pcm_bus_capture_probe.gd`, `pcm_ogg_probe.gd`, `pcm_mix_diagnostic.gd`.
- No production audio service was edited. No commit made.
- No hardware-output or human-listening claim is made anywhere below.

## What was verified

1. A real (non-Dummy) Godot audio driver is active: `AudioServer.get_driver_name()` returns `"ALSA"`.
   The verbose log shows `ALSA 1.2.14 detected.` / `Audio buffer frames: 512 calculated latency: 11ms`
   and **no** `All audio drivers failed, falling back to the dummy driver.`
2. `AudioEffectCapture` on the **Master** bus observes genuinely mixed, nonzero PCM produced by the
   production score (`music_service.gd`, Ogg samples), the announcer speech WAV (`cue("objective")`),
   and the objective earcon WAV (`objective_motifs.gd`), routed through the Score/Announcer/Effects
   buses that `buses.gd` sends to Master.
3. Two seeded variation takes differ deterministically in the score's pitch plan and in the captured
   Master PCM zero-crossing rate, reproduced across three runs.
4. Negative control: with `--audio-driver Dummy` the probe fails and writes **no** WAV.

## Environment

- Isolated `HOME=/tmp/opencode/audio-slot-20260929/home` containing a private `.asoundrc`:

```conf
# Private ALSA default for isolated Godot audio capture. Userspace null device:
# no hardware, no human listening, no kernel module required.
pcm.!default {
    type null
}
ctl.!default {
    type null
}
```

- `XDG_RUNTIME_DIR` / `XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_CACHE_HOME` all under
  `/tmp/opencode/audio-slot-20260929/`.
- `COCS_SOURCE_DERIVATIVE=/home/mojo/.tmp-on-disk/cocs-audiovisual-expansion/port/contracts/lattice-catalog-derivative.json`.
- Existing generated-content symlink:
  `godot/content/generated -> /home/mojo/.tmp-on-disk/cocs-arsenal-verify-20260928/godot/content/generated`.

### Why a private ALSA null device

- `/dev/snd/*` is `root:audio` and the user is not in group `audio`, so the default hardware PCM
  fails with `cannot find card '0'` / `Unknown PCM default`.
- `pulseaudio`/`pactl`/`pipewire` daemons are not installed, so the PulseAudio driver fails
  (`PulseAudio: context failed`).
- Both real drivers therefore fall back to Dummy unless the null default is supplied.
- The null PCM is a userspace alsa-lib plugin; it consumes writes but does **not** pace in real time.
  Measured throughput is roughly 26 M frames/s (~600x realtime), which is why the capture loop is a
  tight drain (see note below).

## Driver probe (new script)

`godot/tests/audio_new/pcm_driver_probe.gd` pushes a known 440 Hz generator into Master and reports the
active driver plus captured peak.

```
cd /home/mojo/.tmp-on-disk/cocs-audiovisual-expansion
HOME=/tmp/opencode/audio-slot-20260929/home XDG_RUNTIME_DIR=/tmp/opencode/audio-slot-20260929/xdg \
XDG_CONFIG_HOME=/tmp/opencode/audio-slot-20260929/config XDG_DATA_HOME=/tmp/opencode/audio-slot-20260929/data \
XDG_CACHE_HOME=/tmp/opencode/audio-slot-20260929/cache \
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --display-driver headless --audio-driver ALSA \
  --script res://tests/audio_new/pcm_driver_probe.gd
```

Observed:

```
driver_name=ALSA  frames=491520  peak=0.49999988079071  captured=true
```

With `--audio-driver Dummy` the same probe reports `driver_name=Dummy` (so the driver check in the
capture probe is meaningful).

## Canonical capture command

```
cd /home/mojo/.tmp-on-disk/cocs-audiovisual-expansion
HOME=/tmp/opencode/audio-slot-20260929/home \
XDG_RUNTIME_DIR=/tmp/opencode/audio-slot-20260929/xdg \
XDG_CONFIG_HOME=/tmp/opencode/audio-slot-20260929/config \
XDG_DATA_HOME=/tmp/opencode/audio-slot-20260929/data \
XDG_CACHE_HOME=/tmp/opencode/audio-slot-20260929/cache \
COCS_SOURCE_DERIVATIVE="$PWD/port/contracts/lattice-catalog-derivative.json" \
COCS_AUDIO_CAPTURE_PATH=/tmp/opencode/audio-slot-20260929/pcm/master-mix.wav \
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --verbose --display-driver headless --audio-driver ALSA \
  --script res://tests/audio_new/waveform_capture.gd
```

Exit status `0`. Verbatim result line (`pcm/logs/pcm_final_verbose.log`):

```
AUDIO_WAVEFORM_OK driver=ALSA frames=44100 peak=0.25514674186707 energy=50.6707905416745 streams=73 variation_frames=44100,44100 variation_peaks=0.06726046651602,0.06726046651602 variation_zcr=0.13172335600907,0.09272108843537 pitch_plans=[1.0, 2.0, 1.1225],[1.0, 1.2599, 1.0] variation_pcm_equal=false file=/tmp/opencode/audio-slot-20260929/pcm/master-mix.wav sha256=0177ec7994600a2f6e723b2a19a55f19971b41ca3a46cc5ddee48093369c64ed
```

## WAV evidence

All files are stereo, 16-bit, 44100 Hz, 44100 frames (1.0 s). `peak`/`rms`/`zcr` below are measured
independently with Python `wave`; `zcr` is over the interleaved stream.

| file | peak | rms | zcr | sha256 |
| --- | --- | --- | --- | --- |
| `pcm/master-mix.wav` | 0.255127 | 0.023968 | 0.01040 | `0177ec7994600a2f6e723b2a19a55f19971b41ca3a46cc5ddee48093369c64ed` |
| `pcm/master-mix-seed42.wav` | 0.067261 | 0.012253 | 0.06589 | `f265e5f351912b5da1a95b1ac1c92bf69ad5f9d67a99973f3fbe9defb630b5f1` |
| `pcm/master-mix-seed137.wav` | 0.067261 | 0.011906 | 0.04632 | `ac2469f7b72940ed6903f412f7bbfb6b3fc6749c8a94e7c8b7cb6078f747d8e5` |

Reproducibility runs are in `pcm/run2/` and `pcm/run3/`; the main-mix peak was 0.247/0.248 and the
seed42/seed137 zcr stayed ~0.066/~0.046 in every run.

## Seeded variation

For `variation_take(V)` the probe stops all voices, sets `music.variation = V`, `form_bar = 11`,
`step = 12`, calls `music._step_music()`, records each playing player's `pitch_scale`, and captures the
Master mix from the note onset.

- Deterministic pitch plans (stable across runs):
  - variation 42: `[1.0, 2.0, 1.1225]`
  - variation 137: `[1.0, 1.2599, 1.0]`
  - These come from `music_service._hash()`, which mixes `variation` into the bar-11 arp/motif
    ornament choices. The probe fails if the two plans are equal.
- Captured-PCM difference: the probe computes a left-channel zero-crossing rate over the stored window
  and fails if the two takes are within 0.001. Observed 0.1317 vs 0.0927 (canonical); the independent
  interleaved-stream zcr above shows 0.0659 vs 0.0463, also stable across runs.

## Negative control (Dummy must not count)

```
cd /home/mojo/.tmp-on-disk/cocs-audiovisual-expansion
# same env; capture path dummy-should-not-write.wav
... Godot_v4.5.2 ... --path godot --display-driver headless --audio-driver Dummy \
  --script res://tests/audio_new/waveform_capture.gd
```

Exit status `1`, log `pcm/logs/pcm_negative_dummy.log`:

```
ERROR: Dummy driver is not DSP evidence; pass a real --audio-driver
```

No WAV is written.

## Preserved failure logs

- `pcm/logs/pcm_first_attempt_missing_path.log` — operator error (unset `COCS_AUDIO_CAPTURE_PATH`).
- `pcm/logs/pcm_attempt2_silent_race.log` — **first genuine failure**: `frames=368640 peak=0.000000`.
  Root cause: the original per-`process_frame` read loop let the ~600x ALSA-null mixer wrap the 3 s
  `AudioEffectCapture` ring past the note before the first read. Fixed by draining in a tight loop
  (no `await`) and triggering inside the drain so the onset is always mixed while draining.

## Blockers / coordination notes

- The `boosting` parser failure in `lifecycle`/`soak` was fixed by the concurrent worker during this
  task; both now parse and pass (`AUDIO_LIFECYCLE_OK`, `AUDIO_SOAK_OK`, see `pcm/logs/peer_*.log`).
  `waveform_capture.gd` never depended on `av_service`, so it was runnable throughout.
- `waveform_capture.gd` reads `music_service` internals (`form_bar`, `step`, `_step_music()`,
  `players`, `announcer_player`). If that service's shape changes, this probe must be updated; no
  production edit was made here.
- The ALSA `null` PCM is not a hardware device; the evidence demonstrates native DSP mixing and
  capture only, not playback on any speaker.
