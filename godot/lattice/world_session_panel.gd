extends Control
## Overlay only. The lead composes it with L1 transport/flow; no second socket.
signal close_requested
signal start_requested
signal restart_requested
const Outcomes = preload("res://lattice/world_outcomes.gd")
const Roles = preload("res://lattice/world_roles.gd")
const SessionFlow = preload("res://lattice/session_flow.gd")
var body := Label.new()
var role_text := Label.new()
var action := Button.new()
var dismiss := Button.new()
var box := PanelContainer.new()
var scroll := ScrollContainer.new()
var stage := "setup"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	add_child(box)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	box.add_child(outer)
	outer.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	for item: Label in [body, role_text]:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(item)
	outer.add_child(action)
	outer.add_child(dismiss)
	action.pressed.connect(func() -> void:
		if not action.disabled:
			if stage == "results": restart_requested.emit()
			else: start_requested.emit())
	dismiss.text = "Close / return to world"
	dismiss.pressed.connect(func() -> void: close_requested.emit())
	resized.connect(_layout)
	_layout()
	hide()

func _layout() -> void:
	box.size = Vector2(minf(720, maxf(280, size.x - 32)), minf(420, maxf(240, size.y - 32)))
	box.position = (size - box.size) * 0.5

func show_setup(requested: Dictionary, config: Dictionary, flow: Dictionary, is_host: bool) -> void:
	stage = "setup"
	var roster: Variant = config.get("roster")
	var roster_view: Dictionary = roster if roster is Dictionary else {}
	body.text = "LATTICE / SESSION SETUP\nRequested (not confirmed): %s / %s · rung %s · bots %s · limit %s\nSource echo: %s / %s · rung %s · humans %s · bots %s · limit %s\nSource roster: connected %s · floor %s · host peer %s\n%s" % [
		str(requested.get("map", "unknown")), str(requested.get("mode", "unknown")), Outcomes.value(requested.get("rung")), Outcomes.value(requested.get("bots")), Outcomes.value(requested.get("time_limit")),
		Outcomes.value(config.get("map")), Outcomes.value(config.get("mode")), Outcomes.value(config.get("rung")), Outcomes.value(config.get("human_count")), Outcomes.value(config.get("bot_count")), Outcomes.value(config.get("time_limit")),
		Outcomes.value(roster_view.get("connected_peers")), Outcomes.value(flow.get("minimum_humans")), Outcomes.value(roster_view.get("host_peer")), str(flow.get("reason", ""))]
	var role: Dictionary = Roles.from_session(config)
	role_text.text = role.text if role.ready else "Assigned kit unknown. " + role.text
	action.text = "Host: request Start" if is_host else "Awaiting host identity / host controls Start" if flow.get("host_peer", -1) < 0 else "Guest: host controls Start"
	# Never offer start before the authoritative echo. L1 start() rechecks floor and host.
	action.disabled = not is_host or config.is_empty() or flow.get("state") != SessionFlow.State.HOST_WAITING
	show()

func show_result(result: Dictionary, config: Dictionary, is_host: bool) -> void:
	stage = "results"
	body.text = Outcomes.final_result(result, is_host)
	var role: Dictionary = Roles.from_session(config)
	role_text.text = role.text if role.ready else "Assigned kit unknown. " + role.text
	action.text = "Host: request next round" if is_host else "Guest: wait for host"
	action.disabled = not is_host or result.is_empty()
	show()
