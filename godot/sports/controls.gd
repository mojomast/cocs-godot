extends RefCounted
## Small sports-specific input gate. Release/focus/staleness never auto-resumes.
var engaged := false
var focused := true
var keys: Dictionary = {}

func release() -> void:
	engaged = false
	keys.clear()

func focus(value: bool) -> void:
	focused = value
	release()

func accept(event: InputEvent, eligible: bool) -> void:
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_ESCAPE and event.pressed:
			release()
		elif event.physical_keycode == KEY_ENTER and event.pressed:
			if eligible and focused:
				keys.clear()
				engaged = true
		elif event.pressed and engaged and focused and eligible:
			keys[event.physical_keycode] = true
		else:
			keys.erase(event.physical_keycode)

func held(key: int) -> float:
	return 1.0 if keys.has(key) else 0.0

func packet(yaw: float, eligible: bool) -> Dictionary:
	if not eligible or not focused: release()
	var throttle := held(KEY_W) - held(KEY_S) if engaged else 0.0
	var steer := held(KEY_D) - held(KEY_A) if engaged else 0.0
	# Invert source stepRace/stepSoccer world-input projections exactly.
	return {"x":-sin(yaw)*throttle-cos(yaw)*steer,
		"z":-cos(yaw)*throttle+sin(yaw)*steer,"yaw":yaw,"pitch":0.0,
		"jump":engaged and keys.has(KEY_SPACE),"sprint":engaged and keys.has(KEY_SHIFT),
		"interact":engaged and keys.has(KEY_R),"fire":false,"power":false}
