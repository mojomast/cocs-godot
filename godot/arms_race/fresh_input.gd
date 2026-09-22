extends RefCounted
## Releases are observed even while controls are disabled. A boundary cannot
## turn an already-held key/button into a new capture/action.
const KEYS := [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_E,KEY_R,KEY_F,KEY_SHIFT,KEY_CTRL]
var held: Dictionary = {}
var blocked: Dictionary = {}

func observe(event: InputEvent) -> void:
	var code := 0
	if event is InputEventKey and event.physical_keycode in KEYS: code = event.physical_keycode
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: code = -event.button_index
	if code == 0: return
	if event.pressed: held[code] = true
	else:
		held.erase(code)
		blocked.erase(code)

func boundary() -> void:
	blocked.merge(held)

func capture_allowed() -> bool:
	if not blocked.is_empty(): return false
	for code: int in held:
		if code != -MOUSE_BUTTON_LEFT: return false
	return true
