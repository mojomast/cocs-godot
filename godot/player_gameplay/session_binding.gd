extends Node
## Optional child adapter. Experience can consume status_changed/model and set
## show_compact_status=false; this fallback ensures the journey is usable alone.
signal status_changed(model: Dictionary)
const Status = preload("res://player_gameplay/status.gd")
const Cues = preload("res://player_gameplay/world_cues.gd")
const Settings = preload("res://ui/settings_access.gd")
var status := Status.new()
var cues := Cues.new()
var session: Node
var model: Dictionary = {}
var snapshot: Dictionary = {}
var show_compact_status := true
var panel := Label.new()

func bind_session(target: Node) -> void:
	if session != null: return
	session = target
	add_child(cues)
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	layer.add_child(panel)
	panel.position = Vector2(850, 180)
	panel.size = Vector2(406, 140)
	panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_theme_font_size_override("font_size", 16)
	panel.add_theme_color_override("font_color", Color("b7e8e1"))
	panel.add_theme_color_override("font_shadow_color", Color.BLACK)
	panel.add_theme_constant_override("shadow_offset_x", 2)
	panel.add_theme_constant_override("shadow_offset_y", 2)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.055, 0.075, 0.88)
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 10
	background.content_margin_bottom = 10
	background.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("normal", background)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.client.snapshot.connect(observe)
	session.client.events.connect(events)
	session.client.started.connect(func(_frame: Dictionary) -> void: clear_round())
	session.client.results.connect(func(_frame: Dictionary) -> void: clear_round())
	session.client.connection_error.connect(func(_message: String) -> void: clear_round())
	session.client.transport_dropped.connect(func(_message: String) -> void: clear_round())

func allowed() -> bool:
	if not is_instance_valid(session) or session.phase != 3 or session.client.spectating or not session.application_focused or session.snapshot_watch.stale() or Settings.overlay_open(): return false
	if session.has_method("social_capturing") and session.social_capturing(): return false
	if "solo_cheats" in session and is_instance_valid(session.solo_cheats) and session.solo_cheats.state.get("paused", false): return false
	return session.presentation.lifecycle.can_control()

func observe(frame: Dictionary) -> void:
	snapshot = frame.get("state", {})
	refresh()

func refresh() -> void:
	var active := allowed() and not snapshot.is_empty()
	var actor: Dictionary = session.presentation.local_actor if is_instance_valid(session) else {}
	var next := status.project(actor, snapshot.get("config", {}), active)
	if not next.is_empty():
		var hint := Status.rope_hint(actor, snapshot)
		if not hint.is_empty(): next.statuses.append(hint)
	if next != model:
		model = next
		status_changed.emit(model)
	panel.text = preload("res://input_bindings/hints.gd").resolve(Status.text(model))
	panel.visible = not model.is_empty() and show_compact_status
	if not model.is_empty(): cues.apply_state(snapshot)
	else: cues.clear_visuals()

func events(items: Array) -> void:
	cues.apply_events(items, allowed() and not model.is_empty())

func _process(delta: float) -> void:
	if session == null: return
	var settings := Settings.service()
	if settings != null: cues.reduced_motion = settings.values.get("reduced_motion", false)
	if "combat" in session and is_instance_valid(session.combat) and is_instance_valid(session.combat.quality_controls):
		cues.set_quality(session.combat.quality_controls.quality)
	refresh()
	cues.advance(delta)

func clear_round() -> void:
	snapshot = {}
	model = {}
	panel.text = ""
	panel.hide()
	status_changed.emit(model)
	cues.clear_round()
