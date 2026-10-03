extends RefCounted
## Private event mapper: never registers or edits global InputMap actions.
const ACTIONS := ["left", "right", "up", "down", "L", "M", "H", "Special", "Mobility", "Grab", "Guard", "Dash", "Super"]
const BITS := {"L":1, "M":2, "H":4, "Special":8, "Mobility":16, "Grab":32, "Guard":64, "Dash":128, "Super":256}
const PAD := {"L":JOY_BUTTON_X, "M":JOY_BUTTON_Y, "H":JOY_BUTTON_B, "Special":JOY_BUTTON_A, "Mobility":JOY_BUTTON_RIGHT_SHOULDER, "Grab":JOY_BUTTON_LEFT_SHOULDER, "Guard":JOY_BUTTON_LEFT_STICK, "Dash":JOY_BUTTON_RIGHT_STICK}
const DEFAULTS := [
	[KEY_A,KEY_D,KEY_W,KEY_S,KEY_F,KEY_G,KEY_H,KEY_R,KEY_T,KEY_Y,KEY_C,KEY_V,KEY_B],
	[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_J,KEY_K,KEY_L,KEY_U,KEY_I,KEY_O,KEY_N,KEY_M,KEY_P]]
var bindings: Array = []
var devices: Array = [-1,-1] # -1 keyboard; nonnegative exact joypad device ID.
var down: Array = [{},{}]
var blocked: Dictionary = {}
var queued: Array = [0,0]
var modal := false
var deadzone := 0.28
var document: Dictionary = {}
var path := "user://fighting/bindings.json"

func _init() -> void:
	for layout: Array in DEFAULTS:
		var row := {}
		for i: int in ACTIONS.size(): row[ACTIONS[i]] = layout[i]
		bindings.append(row)

func assign(player: int, device: int) -> bool:
	if player < 0 or player > 1 or device < -1: return false
	if device >= 0 and devices[1-player] == device: return false
	release_all()
	devices[player] = device
	return true

func rebind(player: int, action: String, key: int) -> bool:
	if not ACTIONS.has(action) or key in [KEY_ESCAPE,KEY_F12,KEY_QUOTELEFT] or key == 0: return false
	for p: int in 2:
		for a: String in bindings[p]:
			if bindings[p][a] == key and (p != player or a != action): return false
	release_all()
	bindings[player][action] = key
	return true

func label(player: int, action: String) -> String:
	if devices[player] >= 0:
		if action == "Super": return "L1 + R1"
		if action in ["left","right","up","down"]: return "D-pad / left stick"
		return {"L":"X / Square","M":"Y / Triangle","H":"B / Circle","Special":"A / Cross","Mobility":"R1","Grab":"L1","Guard":"L3","Dash":"R3"}.get(action, action)
	return OS.get_keycode_string(int(bindings[player].get(action,0)))

func ingest(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo: return
		var token := "k:%d" % event.physical_keycode
		_update_token(token,event.pressed)
		for p: int in 2:
			if devices[p] != -1: continue
			for action: String in bindings[p]:
				if bindings[p][action] == event.physical_keycode: _set_action(p,action,event.pressed,token)
	elif event is InputEventJoypadButton:
		var token := "b:%d:%d" % [event.device,event.button_index]
		_update_token(token,event.pressed)
		for p: int in 2:
			if devices[p] != event.device: continue
			for action: String in PAD:
				if PAD[action] == event.button_index: _set_action(p,action,event.pressed,token)
			var directions := {JOY_BUTTON_DPAD_LEFT:"left",JOY_BUTTON_DPAD_RIGHT:"right",JOY_BUTTON_DPAD_UP:"up",JOY_BUTTON_DPAD_DOWN:"down"}
			if directions.has(event.button_index): _set_action(p,directions[event.button_index],event.pressed,token)
	elif event is InputEventJoypadMotion:
		for p: int in 2:
			if devices[p] != event.device: continue
			var pair: Array = ["left","right"] if event.axis == JOY_AXIS_LEFT_X else ["up","down"] if event.axis == JOY_AXIS_LEFT_Y else []
			for i: int in pair.size():
				var token := "a:%d:%d:%d" % [event.device,event.axis,i]
				var active: bool = event.axis_value < -deadzone if i == 0 else event.axis_value > deadzone
				_update_token(token,active)
				_set_action(p,pair[i],active,token)

func _update_token(token: String, active: bool) -> void:
	if not active: blocked.erase(token)
	elif modal: blocked[token] = true

func _set_action(player: int, action: String, active: bool, token: String) -> void:
	var key := action + "|" + token
	var was: bool = down[player].get(key,false)
	active = active and not modal and not blocked.has(token)
	down[player][key] = active
	if active and not was: queued[player] |= int(BITS.get(action,0))

func _held(player: int, action: String) -> bool:
	for key: String in down[player]:
		if key.begins_with(action+"|") and down[player][key]: return true
	return false

func command(player: int) -> Dictionary:
	var held := 0
	for action: String in BITS:
		if _held(player,action): held |= int(BITS[action])
	var pressed: int = queued[player]
	# Core derives edges from held history. A complete press/release between
	# ticks must therefore occupy one command's held mask, then clear next tick.
	held |= pressed
	queued[player] = 0
	if devices[player] >= 0 and (held & 48) == 48:
		held |= 256
		if (pressed & 48) != 0: pressed |= 256
	return {"axis_x":int(_held(player,"right"))-int(_held(player,"left")),"axis_y":int(_held(player,"up"))-int(_held(player,"down")),"held":held,"pressed":pressed}

func release_all() -> void:
	for p: int in 2:
		for key: String in down[p]:
			if down[p][key]: blocked[key.substr(key.find("|")+1)] = true
		down[p].clear()
		queued[p] = 0

func set_modal(value: bool) -> void:
	release_all()
	modal = value

func unplug(device: int) -> void:
	if devices.has(device): release_all()

func load_settings() -> void:
	if not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return
	document = parsed
	var saved: Variant = document.get("keyboard",[])
	if saved is Array and saved.size() == 2:
		var candidate: Array = bindings.duplicate(true)
		var seen := {}
		for p: int in 2:
			if not saved[p] is Dictionary: return
			for action: String in ACTIONS:
				var key := int(saved[p].get(action,candidate[p][action]))
				if key == 0 or key in [KEY_ESCAPE,KEY_F12,KEY_QUOTELEFT] or seen.has(key): return
				seen[key] = true
				candidate[p][action] = key
		bindings = candidate
	deadzone = clampf(float(document.get("deadzone",0.28)),0.1,0.8)

func save_settings() -> Error:
	document["keyboard"] = bindings.duplicate(true)
	document["deadzone"] = deadzone
	DirAccess.make_dir_recursive_absolute("user://fighting")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document,"\t"))
	return OK
