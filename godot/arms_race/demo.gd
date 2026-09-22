extends "res://world/session.gd"
## Standalone composition. Source Match/Room own all combat and progression.
const FreshInput = preload("res://arms_race/fresh_input.gd")
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible"]
var fresh := FreshInput.new()
var round_seconds := 180

func _ready() -> void:
	add_child(camera)
	add_child(sun)
	add_child(environment)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	for widget: Control in [label, selector, combat_label]:
		panel.add_child(widget)
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selector.hide()
	for node: Node in [pickups, presentation, combat, client]: add_child(node)
	presentation.interpolate_remote = true
	trace_enabled = "--native-trace" in OS.get_cmdline_user_args()
	selected_mode = "armsrace"
	var selected := MAPS[0]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): selected = arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--round-seconds="):
			var value := arg.trim_prefix("--round-seconds=")
			if not value.is_valid_int() or int(value) < 60 or int(value) > 900:
				on_error("Round seconds must be an integer from 60 to 900")
				return
			round_seconds = int(value)
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	if selected not in MAPS or not catalog.entries.has(selected) or selected_mode not in catalog.entries[selected].modes:
		on_error("Arms Race requires Meridian Exchange, Verdant Reliquary or Ember Crucible")
		return
	if not load_map(selected):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	client.results.connect(on_results)
	connect_selected_match()

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		var result := client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":"armsrace", "botCount":2, "difficulty":"normal", "timeLimit":round_seconds}})
		if result != OK: on_error("Arms Race configuration could not be queued")
		else: phase = 2
		return
	if phase == 2:
		var config: Dictionary = frame.get("config", {})
		if config.get("mode") != "armsrace" or config.get("difficulty") != "normal" or config.get("botCount") != 2 or config.get("timeLimit") != round_seconds or config.get("fragLimit") != 10:
			on_error("Authority returned a different Arms Race configuration")
			return
	super.on_lobby(frame)

func on_results(frame: Dictionary) -> void:
	round_results += 1
	phase = 4
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	combat.clear_round()
	release_pointer()
	label.text = "Results received. Enter: request restart"

func weapon_controls_active() -> bool:
	return false

func release_pointer() -> void:
	fresh.boundary()
	super.release_pointer()

func _input(event: InputEvent) -> void:
	fresh.observe(event)
	# Source pins the weapon. Never queue a native selection request.
	weapon_selection.clear()
	if (event is InputEventKey and WeaponSelection.key_index(event.physical_keycode) >= 0) or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not fresh.capture_allowed(): return
	super._unhandled_input(event)
