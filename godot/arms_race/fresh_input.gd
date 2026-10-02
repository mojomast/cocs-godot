extends RefCounted
## Releases are observed even while controls are disabled. A boundary cannot
## turn an already-held key/button into a new capture/action.
const KEYS := [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_E,KEY_R,KEY_F,KEY_SHIFT,KEY_CTRL]
var held: Dictionary = {}
var blocked: Dictionary = {}

func observe(event: InputEvent) -> void:
	var physical := preload("res://input_bindings/model.gd").physical(event)
	var codes := preload("res://input_bindings/access.gd").gameplay_codes()
	if physical.is_empty(): return
	if event.pressed and not codes.has(physical) and physical not in ["KeyC", "MouseLeft", "MouseMiddle"]: return
	if event.pressed: held[physical] = true
	else:
		held.erase(physical)
		blocked.erase(physical)

func boundary() -> void:
	blocked.merge(held)

func capture_allowed() -> bool:
	if not blocked.is_empty(): return false
	for code: String in held:
		if code != "MouseLeft": return false
	return true
