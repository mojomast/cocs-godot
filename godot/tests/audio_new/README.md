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
COCS_AUDIO_CAPTURE_PATH=/absolute/isolated/audio.wav godot --path godot --script res://tests/audio_new/waveform_capture.gd
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
- `waveform_capture.gd` requires a real audio driver, captures actual Ogg/WAV/earcon Master mix and two seeded bar-11 Ogg variation windows, fails on silence/Dummy or identical pitch plans, and writes isolated WAV evidence.
- `weather_render.gd` requires a renderer and compares weather on/off from the same authoritative frame; optional PNG evidence is isolated.

These are prepared scripts, not results. Run only after the serial heavy-slot grant. The
renderer and audible-mix probes must not be reported as passing from a Dummy
headless lifecycle run.
