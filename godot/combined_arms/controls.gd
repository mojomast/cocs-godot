extends "res://sports/controls.gd"
const Motion = preload("res://world/control_math.gd")
var down: Dictionary = {}
var blocked: Dictionary = {}
var interact_pending := false
var fire := false
var ads := false

func cancel_aim() -> void:
	ads = false

func release() -> void:
	super.release()
	blocked = down.duplicate()
	interact_pending = false
	fire = false
	cancel_aim()

func accept(event: InputEvent, eligible: bool, infantry: bool = true) -> void:
	if not infantry: cancel_aim()
	if event is InputEventKey:
		if event.echo: return
		var code: int = event.physical_keycode
		if not event.pressed:
			down.erase(code)
			blocked.erase(code)
		else:
			if down.has(code): return
			down[code] = true
		if blocked.has(code): return
		if code == KEY_R and event.pressed: cancel_aim()
		if code == KEY_E:
			if event.pressed and engaged and focused and eligible: interact_pending = true
			return
		super.accept(event, eligible)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.pressed:
			down.erase(MOUSE_BUTTON_RIGHT)
			blocked.erase(MOUSE_BUTTON_RIGHT)
			cancel_aim()
		elif not down.has(MOUSE_BUTTON_RIGHT):
			down[MOUSE_BUTTON_RIGHT] = true
			ads = engaged and focused and eligible and infantry and not blocked.has(MOUSE_BUTTON_RIGHT)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			down.erase(MOUSE_BUTTON_LEFT)
			blocked.erase(MOUSE_BUTTON_LEFT)
			fire = false
		else:
			down[MOUSE_BUTTON_LEFT] = true
			fire = engaged and focused and eligible and not blocked.has(MOUSE_BUTTON_LEFT)

func command(yaw: float, pitch: float, eligible: bool, driving: bool) -> Dictionary:
	if driving: cancel_aim()
	var p := super.packet(yaw, eligible)
	# Protocol clamps each world axis independently. Fit their common scale
	# before sending so diagonal driving retains throttle/steer proportions.
	var axis_scale := maxf(1.0, maxf(absf(p.x), absf(p.z)))
	p.x /= axis_scale
	p.z /= axis_scale
	if not driving:
		var direction := Motion.movement(yaw, held(KEY_W)-held(KEY_S), held(KEY_D)-held(KEY_A)) if engaged else Vector2.ZERO
		p.x = direction.x
		p.z = direction.y
	p.pitch = pitch
	p.interact = engaged and interact_pending
	interact_pending = false
	p.fire = engaged and fire
	p.crouch = engaged and keys.has(KEY_CTRL)
	p.reload = engaged and keys.has(KEY_R)
	p.ads = engaged and focused and eligible and not driving and ads
	return p
