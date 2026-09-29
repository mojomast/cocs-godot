# Audio and weather fixtures

Run each fixture from the repository root with Godot 4:

```sh
godot --path godot --script res://tests/audio_new/event_router.gd
godot --path godot --script res://tests/audio_new/outcome.gd
godot --path godot --script res://tests/audio_new/settings.gd
godot --path godot --script res://tests/audio_new/lifecycle.gd
godot --path godot --script res://tests/audio_new/weather_ownership.gd
```

- `event_router.gd` checks event filtering, duplicate/reconnect latching, escalation, and throttling.
- `outcome.gd` checks victory, defeat, neutral outcomes, and tie handling across game modes.
- `settings.gd` checks legacy settings migration, normalization, and settings UI construction.
- `lifecycle.gd` checks audio service event consumption, round lifecycle, and final-result music.
- `weather_ownership.gd` checks weather timing, precipitation handoff, and native weather suppression.
