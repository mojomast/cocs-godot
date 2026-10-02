extends RefCounted
## Source action IDs and ordered duplicate repair from game/keybinds.mjs.
## fire/ads are native mouse-path preferences, not new authority actions.
const DEFAULTS := {
	"forward":"KeyW", "back":"KeyS", "left":"KeyA", "right":"KeyD",
	"jump":"Space", "sprint":"ShiftLeft", "crouch":"ControlLeft",
	"reload":"KeyR", "melee":"KeyF", "grenade":"KeyG", "power":"KeyQ", "mobility":"KeyX", "interact":"KeyE", "voice":"KeyV",
	"altFire":"KeyZ", "cursor":"AltLeft", "commandScan":"KeyN", "commandGo":"KeyM", "commandAttack":"KeyP", "commandRoute":"KeyO",
	"command":"KeyB", "ping":"KeyU", "radial":"KeyK", "tacticalMap":"KeyJ", "squads":"KeyL", "fire":"MouseLeft", "ads":"MouseRight"}
const LABELS := {"forward":"Move forward", "back":"Move back", "left":"Move left", "right":"Move right", "jump":"Jump", "sprint":"Sprint", "crouch":"Crouch / Grok charge", "reload":"Reload / sports reset", "melee":"Melee", "grenade":"Frag", "power":"Harness ability", "mobility":"Mobility verb (hold for grapple)", "interact":"Interact / use", "altFire":"Alt fire", "fire":"Fire", "ads":"Aim down sights"}
const EXTRA := ["KeyB","KeyH","KeyI","KeyJ","KeyK","KeyL","KeyM","KeyN","KeyO","KeyP","KeyU","KeyY","KeyZ","ArrowUp","ArrowDown","ArrowLeft","ArrowRight","ShiftRight","ControlRight","AltLeft","AltRight","Semicolon","Quote","Comma","Period","Slash","Backquote","Minus","Equal","MouseX1","MouseX2"]
const SPECIAL := {"Space":KEY_SPACE,"ShiftLeft":KEY_SHIFT,"ShiftRight":KEY_SHIFT,"ControlLeft":KEY_CTRL,"ControlRight":KEY_CTRL,"AltLeft":KEY_ALT,"AltRight":KEY_ALT,"ArrowUp":KEY_UP,"ArrowDown":KEY_DOWN,"ArrowLeft":KEY_LEFT,"ArrowRight":KEY_RIGHT,"Semicolon":KEY_SEMICOLON,"Quote":KEY_APOSTROPHE,"Comma":KEY_COMMA,"Period":KEY_PERIOD,"Slash":KEY_SLASH,"Backslash":KEY_BACKSLASH,"Backquote":KEY_QUOTELEFT,"Minus":KEY_MINUS,"Equal":KEY_EQUAL}
const MOUSE := {"MouseLeft":MOUSE_BUTTON_LEFT,"MouseRight":MOUSE_BUTTON_RIGHT,"MouseMiddle":MOUSE_BUTTON_MIDDLE,"MouseX1":MOUSE_BUTTON_XBUTTON1,"MouseX2":MOUSE_BUTTON_XBUTTON2}

static func options() -> Array:
	var result: Array = []
	for code: String in DEFAULTS.values() + EXTRA:
		if not result.has(code): result.append(code)
	return result

static func valid(code: Variant) -> bool:
	if not code is String: return false
	if options().has(code) or code == "Backslash": return true
	return false

static func normalize(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	# Preserve extension fields across future schema versions, but never resolve
	# them as gameplay actions.
	var result := source.duplicate(true)
	var used: Array = []
	for action: String in DEFAULTS:
		var candidate: String = source.get(action) if valid(source.get(action)) else DEFAULTS[action]
		if used.has(candidate):
			for fallback: String in DEFAULTS.values() + options():
				if not used.has(fallback):
					candidate = fallback
					break
		result[action] = candidate
		used.append(candidate)
	return result

static func rebind(raw: Dictionary, action: String, code: String) -> Dictionary:
	var result := normalize(raw)
	if not DEFAULTS.has(action) or not valid(code): return result
	for other: String in DEFAULTS:
		if result[other] == code:
			result[other] = result[action]
			break
	result[action] = code
	return result

static func editable_options() -> Array:
	var result := options()
	result.append("Backslash") # Accepted by source validation, absent from its dropdown.
	# Native command/voice/cursor surfaces are separate contexts, owned by their
	# route adapters. Do not advertise dead bindings or steal their fixed keys.
	for action: String in DEFAULTS:
		if not LABELS.has(action): result.erase(DEFAULTS[action])
	return result

static func label(code: String) -> String:
	return code.trim_prefix("Key").replace("Arrow", "").replace("ShiftLeft", "Left Shift").replace("ShiftRight", "Right Shift").replace("ControlLeft", "Left Ctrl").replace("ControlRight", "Right Ctrl").replace("AltLeft", "Left Alt").replace("AltRight", "Right Alt").replace("Mouse", "Mouse ")

static func key_code(code: String) -> int:
	if code.begins_with("Key") and code.length() == 4: return code.unicode_at(3)
	return int(SPECIAL.get(code, 0))

static func physical(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		for code: String in MOUSE:
			if MOUSE[code] == event.button_index: return code
	if event is InputEventKey:
		var key: int = event.physical_keycode
		if key >= KEY_A and key <= KEY_Z: return "Key" + String.chr(key)
		for code: String in SPECIAL:
			if SPECIAL[code] == key:
				if code.ends_with("Left") and event.location == KEY_LOCATION_RIGHT: return code.trim_suffix("Left") + "Right"
				return code
	return ""

static func virtual_event(code: String, pressed: bool) -> InputEvent:
	if MOUSE.has(code):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE[code]
		mouse_event.pressed = pressed
		return mouse_event
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key_code(code)
	key_event.keycode = key_event.physical_keycode
	key_event.pressed = pressed
	return key_event
