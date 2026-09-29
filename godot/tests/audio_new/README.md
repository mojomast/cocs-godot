# Audio and weather fixtures

Run each fixture from the repository root with Godot 4:

```sh
godot --path godot --script res://tests/audio_new/event_router.gd
godot --path godot --script res://tests/audio_new/outcome.gd
godot --path godot --script res://tests/audio_new/settings.gd
godot --path godot --script res://tests/audio_new/lifecycle.gd
godot --path godot --script res://tests/audio_new/weather_ownership.gd
godot --path godot --script res://tests/audio_new/weather_oracle.gd
godot --path godot --script res://tests/audio_new/score_form.gd
godot --path godot --script res://tests/audio_new/soak.gd
godot --path godot --script res://tests/audio_new/standalone_lifecycle.gd
godot --path godot --script res://tests/audio_new/independent_event_binding.gd
godot --path godot --script res://tests/audio_new/horde_recipe_binding.gd
godot --path godot --script res://tests/audio_new/menu_rapid_lifetime.gd
COCS_AUDIO_CAPTURE_PATH=/absolute/isolated/audio.wav godot --path godot --display-driver headless --audio-driver ALSA --script res://tests/audio_new/waveform_capture.gd
COCS_WEATHER_CAPTURE_DIR=/absolute/isolated/weather godot --path godot --script res://tests/audio_new/weather_render.gd
```

- `event_router.gd` checks event filtering, duplicate/reconnect latching, escalation, and throttling.
- `outcome.gd` checks victory, defeat, neutral outcomes, and tie handling across game modes.
- `settings.gd` checks legacy settings migration, normalization, and settings UI construction.
- `lifecycle.gd` checks audio service event consumption, round lifecycle, and final-result music.
- `weather_ownership.gd` checks weather timing, precipitation handoff, and native weather suppression.
- `weather_oracle.gd` compares native float/uint weather functions against checked-in source-game vectors.
- `score_form.gd` checks 32-bar form, all mode palettes, imported samples, outcome-safe mute and seeded changes.
- `soak.gd` checks thousands of long-round events, bounded dedupe/state and pooled voices.
- `standalone_lifecycle.gd` exercises Sports/Combined Arms adapter semantics including countdown and reconnect.
- `independent_event_binding.gd` instantiates production Assault and Zone `_ready` compositions with only network connect stubbed; emits their actual `Client.events` signal and asserts exactly one audiovisual owner (a separate vehicle-visual callback may coexist), one AV route and one dedupe per repeated wire ID.
- `horde_recipe_binding.gd` instantiates source, Cinderwake and Nacre Horde compositions with only network connect stubbed; starts their actual AV lifecycle from the loaded map and rejects an unpublished arena instead of fabricating weather metadata.
- `menu_rapid_lifetime.gd` starts the real Home score and immediately frees eight actual menu trees, catching leaked audio players or callbacks across quick route visits.
- `waveform_capture.gd` requires a real audio driver, captures actual Ogg/WAV/earcon Master mix and two seeded bar-11 Ogg variation windows, fails on silence/Dummy or indistinct seeded PCM, and writes isolated WAV evidence. On hosts without usable hardware, place `pcm.!default { type null }` and `ctl.!default { type null }` in a **private isolated** `$HOME/.asoundrc`; this is a userspace ALSA sink, not evidence of speakers or listening. The tight DSP drain handles its unpaced output. The optional `pcm_*probe.gd` scripts diagnose driver, child-bus, Ogg, and mix capture independently.
- `weather_render.gd` requires a renderer and compares weather on/off from the same authoritative frame; optional PNG evidence is isolated.

The renderer and audible-mix probes must not be reported as passing from a Dummy
headless lifecycle run. Native PCM here establishes DSP output only; no hardware,
human listening, or Windows playback is claimed.
