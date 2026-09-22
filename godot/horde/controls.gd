extends RefCounted
## Desktop default bindings and press/hold split from game/input.mjs and
## app/page.tsx:878-905,637. Rendering/input only; no authoritative state writes.
const EDGE_KEYS := {KEY_SPACE:"jump", KEY_R:"reload", KEY_E:"interact", KEY_Q:"power", KEY_F:"melee", KEY_G:"grenade"}
const Weapons = preload("res://world/weapon_selection.gd")
var keys := {}
var mouse := {}
var pulses := {}
var weapon := -1

func clear() -> void:
	keys.clear()
	mouse.clear()
	pulses.clear()
	weapon = -1

func record(event: InputEvent, active: bool, actor: Dictionary = {}) -> void:
	if event is InputEventKey:
		var code: int = event.physical_keycode
		if not event.pressed:
			keys.erase(code)
			return
		if not active: return
		keys[code] = true
		if event.echo: return
		if EDGE_KEYS.has(code): pulses[EDGE_KEYS[code]] = true
		var index := Weapons.key_index(code)
		if index >= 0 and Weapons.available(actor, index): weapon = index
	elif event is InputEventMouseButton:
		if not event.pressed:
			mouse.erase(event.button_index)
			return
		if not active: return
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			mouse[event.button_index] = true
			if event.button_index == MOUSE_BUTTON_LEFT: pulses.fire = true
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var start: int = weapon if weapon >= 0 else int(actor.get("weapon", 0))
			var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			for step in range(1, 11):
				var index := posmod(start + direction * step, 10)
				if Weapons.available(actor, index):
					weapon = index
					break

func sample(yaw: float, pitch: float) -> Dictionary:
	var forward := float(keys.has(KEY_W)) - float(keys.has(KEY_S))
	var right := float(keys.has(KEY_D)) - float(keys.has(KEY_A))
	# Match normalizes movement, while the wire parser clamps each world axis.
	# Normalize before rotation so diagonal direction survives that parser intact.
	var axes := Vector2(right, forward).limit_length(1.0)
	var value := {"x":-sin(yaw)*axes.y+cos(yaw)*axes.x, "z":-cos(yaw)*axes.y-sin(yaw)*axes.x,
		"yaw":yaw, "pitch":pitch, "fire":mouse.has(MOUSE_BUTTON_LEFT) or pulses.has("fire"),
		"jump":keys.has(KEY_SPACE) or pulses.has("jump"), "mobility":keys.has(KEY_X),
		"sprint":keys.has(KEY_SHIFT), "crouch":keys.has(KEY_CTRL) or keys.has(KEY_C),
		"ads":mouse.has(MOUSE_BUTTON_RIGHT), "altFire":keys.has(KEY_Z) or mouse.has(MOUSE_BUTTON_MIDDLE)}
	for action: String in ["reload", "interact", "power", "melee", "grenade"]:
		value[action] = pulses.has(action)
	if weapon >= 0: value.weapon = weapon
	return value

func queued() -> void:
	# Consume only after successful wire queueing. The authority FIFO then retains
	# each sample until a real step, cancellation, expiry, or bounded disconnect.
	pulses.clear()
	weapon = -1
