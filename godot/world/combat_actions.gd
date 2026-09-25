extends RefCounted
## Source desktop defaults. Press actions survive a tap between network samples;
## held actions require a recorded fresh press, never global synthetic key state.
const Motion = preload("res://world/control_math.gd")
const EDGE_KEYS := {KEY_R:"reload", KEY_E:"interact", KEY_Q:"power", KEY_F:"melee", KEY_G:"grenade"}
var down := {}
var held := {}
var pulses := {}
var capture_press := false
var actor_weapon := -1

func clear() -> void:
	held.clear()
	pulses.clear()
	capture_press = false
	# Physical down survives boundaries: release then press is mandatory.

func cancel_aim() -> void:
	held.erase("m2")

func observe_actor(actor: Dictionary) -> void:
	var weapon := int(actor.get("weapon", -1))
	if weapon != actor_weapon or actor.get("reloading", false): cancel_aim()
	actor_weapon = weapon

func record(event: InputEvent, active: bool, actor: Dictionary = {}) -> void:
	observe_actor(actor)
	var token := ""
	var pressed := false
	var code := 0
	if event is InputEventKey:
		if event.echo: return
		code = event.physical_keycode
		token = "k%d" % code
		pressed = event.pressed
	elif event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]: return
		token = "m%d" % event.button_index
		pressed = event.pressed
	else: return
	if not pressed:
		down.erase(token)
		held.erase(token)
		if token == "m1": capture_press = false
		return
	if down.has(token): return
	down[token] = true
	if token == "m1": capture_press = not active
	if not active: return
	held[token] = true
	if token == "m1": pulses.fire = true
	if code == KEY_SPACE: pulses.jump = true
	if EDGE_KEYS.has(code): pulses[EDGE_KEYS[code]] = true
	if code == KEY_R or actor.get("reloading", false): cancel_aim()

func captured() -> void:
	# The eligible click that actually captured may also fire, exactly once.
	if capture_press:
		held.m1 = true
		pulses.fire = true
	capture_press = false

func key(code: int) -> bool:
	return held.has("k%d" % code)

func aiming() -> bool:
	return held.has("m2")

func sample(yaw: float, pitch: float, active: bool) -> Dictionary:
	if not active: clear()
	var direction := Motion.movement(yaw, float(key(KEY_W))-float(key(KEY_S)), float(key(KEY_D))-float(key(KEY_A)))
	var value := {"x":direction.x, "z":direction.y, "yaw":yaw, "pitch":pitch,
		"fire":held.has("m1") or pulses.has("fire"), "ads":aiming(),
		"jump":key(KEY_SPACE) or pulses.has("jump"), "mobility":key(KEY_X),
		"sprint":key(KEY_SHIFT), "crouch":key(KEY_CTRL) or key(KEY_C),
		"altFire":key(KEY_Z) or held.has("m3")}
	for action: String in EDGE_KEYS.values(): value[action] = pulses.has(action)
	value.melee = key(KEY_F) or pulses.has("melee")
	return value

func queued() -> void:
	pulses.clear()
