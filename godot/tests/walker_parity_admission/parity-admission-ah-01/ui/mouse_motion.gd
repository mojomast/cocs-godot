extends RefCounted
## Godot scales relative with the root content scale; screen_relative remains
## hardware pixels. Synthetic events used by route probes may only set relative.
static func raw_delta(event: InputEventMouseMotion) -> Vector2:
	return event.screen_relative if event.screen_relative != Vector2.ZERO else event.relative
