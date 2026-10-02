extends CanvasLayer
## Passive shared presentation. Explicit bind_session is also available to the
## parent integrator. No input handler, network write, camera or simulation edit.
const Captions = preload("res://experience/caption_model.gd")
const Combat = preload("res://experience/combat_info.gd")
const Access = preload("res://ui/settings_access.gd")
var captions := Captions.new()
var combat := Combat.new()
var session: Node
var client: Node
var caption := Label.new()
var recap := Label.new()
var kill := Label.new()
var settings: Dictionary = {}
var clock := 0.0
var received_usec := 0
var ready_for_events := false
var bound_scene: Node

func _ready() -> void:
	layer = 6
	for label: Label in [caption, recap, kill]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color("edf5ff"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(label)
	caption.name = "SoundCaption"
	recap.name = "IncomingHitRecap"
	kill.name = "EliminationReadout"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_viewport().size_changed.connect(layout)
	layout()
	clear()

func apply_settings(value: Dictionary) -> void:
	settings = value.duplicate()
	if settings.get("captions", false) != true: captions.clear()
	if is_inside_tree(): layout()

func bind_session(target: Node) -> void:
	if session == target and is_instance_valid(client): return
	unbind()
	if not is_instance_valid(target) or not "client" in target: return
	var peer: Variant = target.get("client")
	if not peer is Node or not peer.has_signal("snapshot") or not peer.has_signal("events"): return
	session = target
	client = peer
	client.snapshot.connect(on_snapshot)
	client.events.connect(on_events)
	if client.has_signal("started"): client.started.connect(on_started)
	if client.has_signal("results"): client.results.connect(on_results)
	if client.has_signal("connection_error"): client.connection_error.connect(on_error)

func unbind() -> void:
	if is_instance_valid(client):
		for pair: Array in [["snapshot", on_snapshot], ["events", on_events], ["started", on_started], ["results", on_results], ["connection_error", on_error]]:
			if client.has_signal(pair[0]) and client.is_connected(pair[0], pair[1]): client.disconnect(pair[0], pair[1])
	session = null
	client = null
	clear()

func clear() -> void:
	captions.clear()
	combat.clear()
	clock = 0
	received_usec = 0
	ready_for_events = false
	for label: Label in [caption, recap, kill]:
		label.text = ""
		label.hide()

func on_started(_frame: Dictionary) -> void: clear()
func on_results(_frame: Dictionary) -> void: clear()
func on_error(_message: String) -> void: clear()

func on_snapshot(frame: Dictionary) -> void:
	if not is_instance_valid(client) or not frame.get("state") is Dictionary: return
	if "phase" in session and int(session.get("phase")) != 3:
		clear()
		return
	var state: Dictionary = frame.state
	var next_clock := Combat.number(state.get("time"))
	if next_clock < clock: clear()
	clock = next_clock
	received_usec = Time.get_ticks_usec()
	ready_for_events = true
	combat.snapshot(state, int(client.get("actor_id")))
	refresh()

func blocked() -> bool:
	if Access.overlay_open(): return true
	if is_instance_valid(session) and "solo_cheats" in session:
		var cheats: Variant = session.get("solo_cheats")
		if is_instance_valid(cheats) and cheats.overlay.visible: return true
	return not get_window().has_focus()

func on_events(items: Array) -> void:
	if not ready_for_events or not is_instance_valid(client): return
	# A muted mix still captions; focus/modal loss drops captions without replay.
	combat.events(items)
	if blocked():
		captions.clear()
		return
	captions.consume(items, clock, int(client.get("actor_id")), settings.get("captions", false) == true)
	refresh()

func _process(_delta: float) -> void:
	# LocalSettings lives across route changes. Bind after the route's own ready.
	var scene := get_tree().current_scene
	if scene != bound_scene:
		bound_scene = scene
		bind_session(scene)
	if not is_instance_valid(session): return
	if "phase" in session and int(session.get("phase")) != 3:
		clear()
		return
	if received_usec > 0 and Time.get_ticks_usec() - received_usec > 1500000:
		clear()
	if blocked(): captions.clear()
	refresh()

func refresh() -> void:
	var active := ready_for_events and not blocked()
	caption.text = captions.line(clock)
	caption.visible = active and not caption.text.is_empty() and settings.get("captions", false) == true
	recap.text = combat.recap()
	recap.visible = active and not recap.text.is_empty() and settings.get("combat_readouts", true) == true
	kill.text = combat.latest_kill
	kill.visible = active and not combat.dead and clock - combat.kill_at >= 0 and clock - combat.kill_at < 2.2 and not kill.text.is_empty() and settings.get("combat_readouts", true) == true

func layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var compact := view.x < 700 or view.y < 450
	var font := 14 if compact else 18
	caption.add_theme_font_size_override("font_size", roundi(font * float(settings.get("caption_scale", 100)) / 100.0))
	for label: Label in [recap, kill]: label.add_theme_font_size_override("font_size", font)
	var width := minf(view.x - 32, 680)
	caption.size = Vector2(width, 0)
	caption.position = Vector2((view.x - width) / 2, 60 if settings.get("caption_position", "bottom") == "top" else view.y - (108 if compact else 160))
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.035, 0.05, 0.96 if settings.get("caption_background") == "solid" else 0.72)
	if settings.get("caption_background") == "transparent": background.bg_color.a = 0
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: background.set_content_margin(edge, 6)
	caption.add_theme_stylebox_override("normal", background)
	recap.add_theme_stylebox_override("normal", background)
	recap.size = Vector2(minf(view.x - 32, 520), 0)
	recap.position = Vector2((view.x - recap.size.x) / 2, 92 if compact else 130)
	kill.size = Vector2(width, 0)
	kill.position = Vector2((view.x - width) / 2, 92 if compact else 130)
