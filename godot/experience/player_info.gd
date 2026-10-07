extends CanvasLayer
## Shared information projection. The dedicated spectator child owns read-only
## camera input; neither component writes actor controls or simulation state.
const Captions = preload("res://experience/caption_model.gd")
const Combat = preload("res://experience/combat_info.gd")
const Access = preload("res://ui/settings_access.gd")
const Regions = preload("res://experience/hud_regions.gd")
const AbilityText = preload("res://experience/ability_text.gd")
const SpectatorEvents = preload("res://experience/spectator_events.gd")
var captions := Captions.new()
var combat := Combat.new()
var public_feed := preload("res://experience/kill_feed.gd").new()
var feed := Label.new()
var session: Node
var client: Node
var caption := Label.new()
var recap := Label.new()
var kill := Label.new()
var ability := Label.new()
var ability_scroll := ScrollContainer.new()
var recap_scroll := ScrollContainer.new()
var gameplay: Node
var gameplay_model: Dictionary = {}
var campaign_hud: Control
var role_key := ""
var caption_team: Variant = null
var layout_age := 0.0
var layout_dirty := true
var desired_visibility: Dictionary = {}
var settings: Dictionary = {}
var clock := 0.0
var received_usec := 0
var ready_for_events := false
var bound_scene: Node
var spectator_camera := preload("res://experience/spectator_camera.gd").new()

func _ready() -> void:
	layer = 6
	spectator_camera.information = self
	add_child(spectator_camera)
	for label: Label in [caption, recap, kill, ability, feed]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color("edf5ff"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(label)
	add_child(ability_scroll)
	preload("res://experience/scroll_keys.gd").bind(ability_scroll)
	add_child(recap_scroll)
	preload("res://experience/scroll_keys.gd").bind(recap_scroll)
	recap.reparent(recap_scroll)
	recap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recap_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recap_scroll.follow_focus = true
	recap_scroll.name = "IncomingHitHistory"
	ability.reparent(ability_scroll)
	ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ability_scroll.follow_focus = true
	ability_scroll.name = "PlayerAbilityReadout"
	ability.tooltip_text = "Esc releases the cursor. Scroll this panel to read the complete operator kit."
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
	layout_dirty = true
	if is_inside_tree():
		_dock_campaign()
		layout()

static func phase_live(value: Variant) -> bool:
	# Audited families: world/session descendants use integer 3. Independent
	# sports and combined-arms roots use the string active, with a `net` client.
	return value == "active" if value is String else ((value is int or value is float) and value == 3)

func live() -> bool:
	return is_instance_valid(session) and "phase" in session and phase_live(session.get("phase"))

func bind_session(target: Node) -> void:
	if session == target and is_instance_valid(client): return
	unbind()
	if not is_instance_valid(target): return
	var peer: Variant = target.get("client") if "client" in target else (target.get("net") if "net" in target else null)
	if not peer is Node or not peer.has_signal("snapshot") or not peer.has_signal("events"): return
	session = target
	client = peer
	session.tree_exiting.connect(unbind)
	client.snapshot.connect(on_snapshot)
	client.events.connect(on_events)
	if client.has_signal("started"): client.started.connect(on_started)
	if client.has_signal("results"): client.results.connect(on_results)
	if client.has_signal("connection_error"): client.connection_error.connect(on_error)
	if client.has_signal("lobby"): client.lobby.connect(on_lobby)
	_dock_campaign()
	_bind_gameplay()
	var bindings := preload("res://input_bindings/access.gd").service()
	if bindings != null and not bindings.changed.is_connected(refresh_ability_bindings): bindings.changed.connect(refresh_ability_bindings)

func refresh_ability_bindings() -> void:
	ability.text = preload("res://input_bindings/hints.gd").resolve(AbilityText.text(gameplay_model))
	layout_dirty = true

func _bind_gameplay() -> void:
	if not is_instance_valid(session): return
	var candidate := session.get_node_or_null("PlayerGameplay")
	if candidate == gameplay: return
	_release_gameplay()
	if candidate == null or not candidate.has_signal("status_changed"): return
	gameplay = candidate
	gameplay.show_compact_status = false
	gameplay.panel.hide()
	gameplay.status_changed.connect(on_gameplay_status)
	on_gameplay_status(gameplay.model)

func _release_gameplay() -> void:
	if is_instance_valid(gameplay):
		if gameplay.is_connected("status_changed", on_gameplay_status): gameplay.disconnect("status_changed", on_gameplay_status)
		gameplay.show_compact_status = true
	gameplay = null
	gameplay_model = {}

func on_gameplay_status(model: Dictionary) -> void:
	# The owner enforces alive/mode/vehicle/source-clock policy. Retain all fields
	# without changing active/cooldown or inventing values when it clears itself.
	var next := model.duplicate(true) if ready_for_events and live() and not blocked() and not spectator() else {}
	if next == gameplay_model: return
	gameplay_model = next
	ability.text = preload("res://input_bindings/hints.gd").resolve(AbilityText.text(gameplay_model))
	layout_dirty = true

func _dock_campaign() -> void:
	if not is_instance_valid(session): return
	var hud: Variant = session.get("campaign_hud") if "campaign_hud" in session else null
	if hud is Control and hud.has_method("attach_experience"):
		campaign_hud = hud
		hud.attach_experience(ability, caption, settings.get("caption_position", "bottom") == "top")
		ability_scroll.hide()

func _undock_campaign() -> void:
	if is_instance_valid(campaign_hud): campaign_hud.detach_experience()
	# Restore ownership before a route can be freed, so persistent UI is not lost.
	if is_instance_valid(ability) and ability.get_parent() != ability_scroll: ability.reparent(ability_scroll)
	if is_instance_valid(caption) and caption.get_parent() != self: caption.reparent(self)
	ability.custom_minimum_size.x = 0
	caption.custom_minimum_size.x = 0
	campaign_hud = null

func unbind() -> void:
	_release_gameplay()
	_undock_campaign()
	if is_instance_valid(client):
		for pair: Array in [["snapshot", on_snapshot], ["events", on_events], ["started", on_started], ["results", on_results], ["connection_error", on_error], ["lobby", on_lobby]]:
			if client.has_signal(pair[0]) and client.is_connected(pair[0], pair[1]): client.disconnect(pair[0], pair[1])
	if is_instance_valid(session) and session.tree_exiting.is_connected(unbind): session.tree_exiting.disconnect(unbind)
	session = null
	client = null
	clear()

func clear() -> void:
	# A new spectator seat must not inherit the previous actor's mouse capture.
	if is_instance_valid(client) and spectator(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spectator_camera.clear()
	public_feed.clear()
	captions.clear()
	combat.clear()
	clock = 0
	received_usec = 0
	ready_for_events = false
	gameplay_model = {}
	role_key = ""
	caption_team = null
	layout_dirty = true
	desired_visibility.clear()
	ability_scroll.hide()
	recap_scroll.hide()
	for label: Label in [caption, recap, kill, ability, feed]:
		label.text = ""
		label.hide()

func on_started(_frame: Dictionary) -> void: clear()
func on_results(_frame: Dictionary) -> void: clear()
func on_error(_message: String) -> void: clear()

func spectator() -> bool:
	return not is_instance_valid(client) or ("spectating" in client and client.get("spectating") == true)

func current_role() -> String:
	return "%s:%s" % [client.get("actor_id"), spectator()] if is_instance_valid(client) else ""

func on_lobby(_frame: Dictionary) -> void:
	if not live() or (not role_key.is_empty() and current_role() != role_key): clear()

func on_snapshot(frame: Dictionary) -> void:
	if not is_instance_valid(client) or not frame.get("state") is Dictionary: return
	if not live():
		clear()
		return
	var state: Dictionary = frame.state
	var next_clock := Combat.number(state.get("time"))
	var next_team: Variant = null
	if not spectator() and state.get("actors") is Array:
		for value: Variant in state.actors:
			if value is Dictionary and value.get("id") == client.get("actor_id"):
				next_team = value.get("team")
				break
	if next_clock < clock or (not role_key.is_empty() and current_role() != role_key) or (ready_for_events and next_team != caption_team): clear()
	role_key = current_role()
	clock = next_clock
	received_usec = Time.get_ticks_usec()
	ready_for_events = true
	caption_team = next_team
	combat.snapshot(state, -1 if spectator() else int(client.get("actor_id")))
	public_feed.snapshot(state, null if spectator() else client.get("actor_id"))
	spectator_camera.snapshot(state)
	_bind_gameplay()
	layout_dirty = true
	refresh()

func blocked() -> bool:
	if Access.overlay_open(): return true
	if not is_instance_valid(session): return true
	if "application_focused" in session and session.get("application_focused") == false: return true
	if session.has_method("social_capturing") and session.social_capturing(): return true
	for key: String in ["world_commands", "session_panel"]:
		var panel: Variant = session.get(key) if key in session else null
		if panel is Control and panel.is_visible_in_tree(): return true
	if is_instance_valid(campaign_hud) and campaign_hud.card.visible: return true
	if is_instance_valid(session) and "solo_cheats" in session:
		var cheats: Variant = session.get("solo_cheats")
		if is_instance_valid(cheats) and cheats.overlay.visible: return true
	return not get_window().has_focus()

func stale() -> bool:
	if not is_instance_valid(session): return true
	if "snapshot_watch" in session and session.get("snapshot_watch") != null:
		return session.get("snapshot_watch").stale()
	if "age" in session: return Combat.number(session.get("age"), 999) >= 0.5
	return received_usec == 0 or Time.get_ticks_usec() - received_usec > 1500000

func on_events(items: Array) -> void:
	# Lobby/role signals can precede the next snapshot in the same poll batch.
	# Never let that batch reuse the previous seat's attribution/private context.
	if current_role() != role_key:
		clear()
		return
	if not ready_for_events or not is_instance_valid(client) or not live() or stale(): return
	# A muted mix still captions; focus/modal loss drops captions without replay.
	combat.events(items)
	public_feed.events(items)
	if blocked():
		captions.clear()
		return
	var caption_items := items
	if spectator(): caption_items = items.filter(func(item: Variant) -> bool: return item is Dictionary and SpectatorEvents.public_event(item))
	captions.consume(caption_items, clock, -1 if spectator() else int(client.get("actor_id")), settings.get("captions", false) == true, caption_team)
	layout_dirty = true
	refresh()

func _process(delta: float) -> void:
	# LocalSettings lives across route changes. Bind after the route's own ready.
	var scene := get_tree().current_scene
	if scene != bound_scene or not is_instance_valid(client):
		bound_scene = scene
		bind_session(scene)
	if not is_instance_valid(session): return
	_bind_gameplay()
	if not live() or (not role_key.is_empty() and current_role() != role_key):
		clear()
		return
	if ready_for_events and stale():
		clear()
	if blocked():
		captions.clear()
		gameplay_model = {}
		ability.text = ""
	layout_age += delta
	if layout_age >= 0.1:
		layout_age = 0
		layout_dirty = true # Existing HUD bounds can change without a snapshot.
	refresh()

func refresh() -> void:
	var active := ready_for_events and live() and not stale() and not blocked()
	caption.text = captions.line(clock)
	recap.text = combat.recap()
	kill.text = combat.latest_kill
	feed.text = public_feed.text()
	var show_ability := active and not spectator() and not gameplay_model.is_empty()
	var show_recap: bool = active and not spectator() and not recap.text.is_empty() and settings.get("combat_readouts", true) == true and not is_instance_valid(campaign_hud)
	var wanted := {
		feed:active and not feed.text.is_empty() and settings.get("combat_readouts", true) == true and not is_instance_valid(campaign_hud),
		caption:active and not caption.text.is_empty() and settings.get("captions", false) == true,
		recap:show_recap, recap_scroll:show_recap,
		kill:active and not spectator() and not combat.dead and clock - combat.kill_at >= 0 and clock - combat.kill_at < 2.2 and not kill.text.is_empty() and settings.get("combat_readouts", true) == true,
		ability:show_ability, ability_scroll:show_ability and not is_instance_valid(campaign_hud)}
	if wanted != desired_visibility:
		desired_visibility = wanted
		layout_dirty = true
	var released := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	ability_scroll.mouse_filter = Control.MOUSE_FILTER_STOP if released else Control.MOUSE_FILTER_IGNORE
	ability_scroll.focus_mode = Control.FOCUS_ALL if released else Control.FOCUS_NONE
	recap_scroll.mouse_filter = Control.MOUSE_FILTER_STOP if released else Control.MOUSE_FILTER_IGNORE
	recap_scroll.focus_mode = Control.FOCUS_ALL if released else Control.FOCUS_NONE
	ability.mouse_filter = Control.MOUSE_FILTER_STOP if released else Control.MOUSE_FILTER_IGNORE
	if layout_dirty: layout()

func layout() -> void:
	if not is_inside_tree(): return
	layout_dirty = false
	for control: Control in desired_visibility: control.visible = desired_visibility[control]
	var view := get_viewport().get_visible_rect().size
	var compact := view.x < 700 or view.y < 450
	var font := 14 if compact else 18
	caption.add_theme_font_size_override("font_size", roundi(font * float(settings.get("caption_scale", 100)) / 100.0))
	for label: Label in [recap, kill, ability, feed]: label.add_theme_font_size_override("font_size", font)
	var width := minf(view.x - 32, 680)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.035, 0.05, 0.96 if settings.get("caption_background") == "solid" else 0.72)
	if settings.get("caption_background") == "transparent": background.bg_color.a = 0
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: background.set_content_margin(edge, 4 if compact and edge in [SIDE_TOP, SIDE_BOTTOM] else 6)
	caption.add_theme_stylebox_override("normal", background)
	recap.add_theme_stylebox_override("normal", background)
	ability.add_theme_stylebox_override("normal", background)
	if is_instance_valid(campaign_hud):
		ability.custom_minimum_size.x = 0 # Campaign owns its narrower column width.
		caption.custom_minimum_size.x = 0
		campaign_hud.layout_live()
		# Campaign has its own death/result card. It owns that area exclusively.
		recap.hide()
		kill.hide()
		return
	var occupied: Array[Rect2] = []
	if is_instance_valid(session): occupied = Regions.occupied(session, [gameplay])
	var preferences := Access.service()
	if preferences != null and preferences.hint != null and preferences.hint.is_visible_in_tree(): occupied.append(preferences.hint.get_global_rect())
	# Keep the actual aiming point free even if the route hides its reticle.
	occupied.append(Rect2(view * 0.5 - Vector2(28, 28), Vector2(56, 56)))
	if spectator_camera.active: occupied.append(spectator_camera.panel.get_global_rect())
	for label: Label in [caption, kill, feed]:
		if not label.visible: continue
		label.size = Vector2(minf(width, 520), 0)
		var desired := Vector2(minf(width, 520), label.get_combined_minimum_size().y)
		var rect := Regions.choose(view, occupied, desired, settings.get("caption_position", "bottom") == "bottom" if label == caption else false, 120)
		# Caption/recap must fit fully: never clip a protected call mid-sentence.
		label.size = Vector2(rect.size.x, 0)
		var needed := label.get_combined_minimum_size().y
		if not rect.has_area() or needed > rect.size.y:
			label.hide()
			continue
		label.position = rect.position
		label.size.y = needed
		occupied.append(Rect2(rect.position, Vector2(rect.size.x, needed)))
	if recap_scroll.visible:
		recap.custom_minimum_size.x = 0
		recap.size.x = minf(width, 520)
		var desired := Vector2(minf(width, 520), recap.get_combined_minimum_size().y)
		var rect := Regions.choose(view, occupied, desired)
		if rect.has_area():
			recap_scroll.position = rect.position
			recap_scroll.size = rect.size
			recap.custom_minimum_size.x = maxf(80, rect.size.x - 16)
			occupied.append(rect)
		else: recap_scroll.hide()
	if ability_scroll.visible:
		var desired := Vector2(minf(view.x - 24, 390), 120 if compact else 220)
		var rect := Regions.choose(view, occupied, desired)
		if rect.has_area():
			ability.custom_minimum_size.x = 0
			ability_scroll.position = rect.position
			ability_scroll.size = rect.size
			ability.custom_minimum_size.x = maxf(80, rect.size.x - 16)
		else: ability_scroll.hide()
