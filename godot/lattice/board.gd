extends Control
const Transport = preload("res://lattice/transport.gd")
const MapView = preload("res://lattice/map_view.gd")
const Topology = preload("res://lattice/topology.gd")
const Catalog = preload("res://world/catalog.gd")
const SessionOptions = preload("res://lattice/session_options.gd")
const SessionFlow = preload("res://lattice/session_flow.gd")
var client := Transport.new()
var session_flow := SessionFlow.new()
var requested: Dictionary = {}
var last_lobby: Dictionary = {}
## Authored link topology for the current map, resolved from the locked
## generated catalog. Advisory only: it never gates or replaces an order.
var topology := Topology.new()
var catalog: Variant = null
var catalog_ready := false
var topology_map := ""
var endpoint := LineEdit.new()
var room := LineEdit.new()
var maps := OptionButton.new()
var modes := OptionButton.new()
var connect_button := Button.new()
var start_button := Button.new()
var hold_button := Button.new()
var spend_button := Button.new()
var confirm_spend := CheckBox.new()
var nodes := ItemList.new()
var view_choice := OptionButton.new()
var map_view := MapView.new()
var selection_context := ""
var status := Label.new()
var resources := Label.new()
var selection := Label.new()
var history := Label.new()
var notice := Label.new()
var economy_help: Label
var authorization_context := ""
var phase := "idle"
var phase_at := 0
var selected := ""
var node_ids: Array[String] = []
var joining := false
var smoke := false
var smoke_step := 0
var smoke_at := 0
var smoke_start := 0
var capture := ""
var evidence: Array = []
var spend_baseline: Variant = null
var fighter_baseline := -1

func label(text_value: String, parent: Node, size: int = 18) -> Label:
	var result := Label.new()
	result.text = text_value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Locked generated catalog for the authored link layer. Absent content just
	# means no link layer is drawn; it never invents a link.
	catalog = Catalog.new()
	catalog_ready = catalog.open()
	var bg := ColorRect.new()
	bg.color = Color("101b29")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("scrollbar_h_separation", 12)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 18)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	label("LATTICE / COMMAND", column, 28)
	label("Recipient-authorized state • Node orders • Team recruitment", column, 16)
	var setup := HBoxContainer.new()
	column.add_child(setup)
	maps.add_item("Asterion Relay")
	maps.add_item("Monsoon Foundry")
	modes.add_item("cocs")
	modes.add_item("cocs-coop")
	setup.add_child(maps)
	setup.add_child(modes)
	endpoint.text = "ws://127.0.0.1:8080"
	endpoint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup.add_child(endpoint)
	room.placeholder_text = "Room ID (optional join)"
	room.custom_minimum_size.x = 190
	setup.add_child(room)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	connect_button.text = "Connect / configure"
	connect_button.pressed.connect(begin)
	controls.add_child(connect_button)
	start_button.text = "Start / restart (host)"
	start_button.pressed.connect(start_round)
	controls.add_child(start_button)
	var disconnect_button := Button.new()
	disconnect_button.text = "Disconnect"
	disconnect_button.pressed.connect(disconnect_session)
	controls.add_child(disconnect_button)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(resources)
	var objectives_header := HBoxContainer.new()
	column.add_child(objectives_header)
	label("OBJECTIVES — select a node; the server decides final order legality", objectives_header, 17).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_choice.add_item("List")
	view_choice.add_item("Map")
	view_choice.tooltip_text = "Objective view (selection only)"
	view_choice.item_selected.connect(func(index: int) -> void:
		nodes.visible = index == 0
		map_view.visible = index == 1)
	objectives_header.add_child(view_choice)
	nodes.custom_minimum_size.y = 132
	nodes.item_selected.connect(func(index: int) -> void: selected = node_ids[index]; refresh())
	column.add_child(nodes)
	map_view.custom_minimum_size.y = 184
	map_view.visible = false
	map_view.node_selected.connect(func(id: String) -> void: selected = id; refresh())
	column.add_child(map_view)
	selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(selection)
	var actions_row := HBoxContainer.new()
	column.add_child(actions_row)
	hold_button.text = "Issue HOLD / GO"
	hold_button.pressed.connect(func() -> void: notice.text = client.activate("hold", selected); refresh())
	actions_row.add_child(hold_button)
	confirm_spend.text = "Authorize one 12 FLUX purchase"
	actions_row.add_child(confirm_spend)
	spend_button.text = "Recruit Fighter"
	spend_button.pressed.connect(buy_fighter)
	actions_row.add_child(spend_button)
	confirm_spend.toggled.connect(func(_pressed: bool) -> void: refresh())
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	label("ACTION RECEIPTS — queued ≠ accepted ≠ completed", column, 17)
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(history)
	economy_help = label("", column, 14)
	add_child(client)
	client.changed.connect(refresh)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.connection_error.connect(func(message: String) -> void: phase = "error"; notice.text = message; refresh())
	client.results.connect(func(_frame: Dictionary) -> void: phase = "results"; session_flow.observe_result(client.result_projection); refresh())
	client.below_minimum.connect(func(message: String) -> void: notice.text = message; phase = "waiting for host" if joining else "host waiting"; refresh())
	requested = SessionOptions.parse(OS.get_cmdline_user_args())
	if requested.error.is_empty():
		endpoint.text = requested.endpoint
		maps.select(1 if requested.map == "monsoon-foundry" else 0)
		modes.select(1 if requested.mode == "cocs-coop" else 0)
		room.text = requested.room
	elif requested.error != "Explicit --endpoint is required": notice.text = requested.error
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--smoke": smoke = true
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	refresh()
	if smoke:
		smoke_start = Time.get_ticks_msec()
		begin()

func begin() -> void:
	if phase not in ["idle", "error"]: return
	if not requested.get("error", "").is_empty() and requested.error != "Explicit --endpoint is required": notice.text = requested.error; refresh(); return
	requested.map = ["asterion-relay", "monsoon-foundry"][maps.selected]
	requested.mode = modes.get_item_text(modes.selected)
	requested.endpoint = endpoint.text.strip_edges()
	requested.room = room.text.strip_edges()
	requested.join = not requested.room.is_empty()
	var problem: String = SessionOptions.validate(requested)
	if not problem.is_empty(): notice.text = problem; refresh(); return
	session_flow.disconnect(client)
	last_lobby.clear()
	selected = ""
	confirm_spend.button_pressed = false
	joining = requested.join
	client.mode = requested.mode
	var map_id: String = requested.map
	var allowed := {"asterion-relay":{"modes":["cocs", "cocs-coop"]}, "monsoon-foundry":{"modes":["cocs", "cocs-coop"]}}
	phase = "connecting"
	phase_at = Time.get_ticks_msec()
	notice.text = ""
	if client.connect_server(endpoint.text, allowed, map_id) != OK: phase = "error"; notice.text = "Connection could not be opened"
	refresh()

func on_lobby(frame: Dictionary) -> void:
	last_lobby = frame.duplicate(true)
	session_flow.observe_roster(frame, client)
	if joining and frame.get("config") is Dictionary and (frame.get("mapId") != requested.map or frame.config.get("mode") != client.mode):
		client.fail("Joined room differs from requested map/mode"); return
	if phase == "creating":
		var answer: Dictionary = session_flow.request_configuration(requested, client)
		if not answer.queued: client.fail(answer.reason); return
		phase = "configuring"
	elif phase == "configuring" and frame.get("config") is Dictionary:
		var cfg: Dictionary = frame.config
		if frame.get("mapId") != requested.map or cfg.get("mode") != requested.mode or cfg.get("timeLimit") != requested.time_limit or cfg.get("rung") != requested.rung or (requested.rung == null and cfg.get("botCount") != requested.bots):
			client.fail("Configuration echo differs from host request"); return
		session_flow.echoed = cfg.duplicate(true)
		session_flow.publish(SessionFlow.State.HOST_WAITING, "Configuration echoed; host may start")
		phase = "host waiting"
		if smoke: start_round()
	elif phase == "joining": phase = "waiting for host"
	phase_at = Time.get_ticks_msec()
	refresh()

func disconnect_session() -> void:
	session_flow.disconnect(client)
	last_lobby.clear()
	phase = "idle"
	selected = ""
	confirm_spend.button_pressed = false
	refresh()

func start_round() -> void:
	if phase not in ["host waiting", "results"] or joining: return
	var answer: Dictionary = session_flow.restart(client, last_lobby) if phase == "results" else session_flow.start(client, last_lobby)
	if answer.queued: phase = "starting"; phase_at = Time.get_ticks_msec(); notice.text = "Start queued; awaiting source start"
	else: notice.text = answer.reason
	refresh()

func on_started(frame: Dictionary) -> void:
	# A guest validates identity against the joined room but must not demand that
	# the host chose the guest's local default limit or bot count.
	if joining: session_flow.requested.clear()
	if not session_flow.observe_start(frame, requested.map, requested.mode):
		client.fail(session_flow.reason); return
	phase = "active"
	confirm_spend.set_pressed_no_signal(false)
	notice.text = "Source start echoed"
	refresh()

func buy_fighter() -> void:
	if not confirm_spend.button_pressed: return
	confirm_spend.button_pressed = false
	notice.text = client.activate(client.purchase_kind())
	refresh()

func known(value: Variant) -> String:
	if value == null: return "unknown / hidden"
	if value is float: return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	return str(value)

func team_name(value: Variant) -> String:
	if value == null: return "unknown / hidden"
	return "Team %d" % int(value)

func refresh() -> void:
	if not is_instance_valid(status): return
	var p: Dictionary = client.projection
	var context := "%s/%s" % [p.get("map", ""), client.revision]
	if context != selection_context:
		selected = ""
		selection_context = context
	if p.is_empty(): confirm_spend.set_pressed_no_signal(false)
	var connected := phase not in ["idle", "error"]
	maps.disabled = connected
	modes.disabled = connected
	endpoint.editable = not connected
	room.editable = not connected
	connect_button.disabled = connected
	start_button.disabled = joining or phase not in ["host waiting", "results"] or client.peer_id != session_flow.host_peer
	var cfg: Dictionary = client.session_config if not client.session_config.is_empty() else session_flow.echoed
	status.text = "%s  |  %s / %s  |  round %s  |  %s\nRequested: rung %s, bots %s, limit %ss, %s/%s | Source echo: rung %s, bots %s, limit %s, floor %s, connected %s" % [phase.to_upper(), client.requested_map, client.mode, known(client.revision if client.revision >= 0 else null), client.gate(), known(requested.get("rung")), known(requested.get("bots")), known(requested.get("time_limit")), requested.get("operator", "?"), requested.get("harness", "?"), known(cfg.get("rung")), known(cfg.get("bot_count", cfg.get("botCount"))), known(cfg.get("time_limit", cfg.get("timeLimit"))), known(session_flow.minimum_humans), known(client.roster_metadata.get("connected_peers"))]
	if phase == "results":
		var final: Dictionary = client.result_projection
		var outcome: Dictionary = final.get("outcome", {})
		status.text += "\nSOURCE RESULT: winner %s · reason %s · scores %s · source time %s · revision %s. Host may request restart; guest waits." % [known(outcome.get("winner")), known(outcome.get("reason")), known(final.get("scores")), known(final.get("source_time")), known(final.get("revision"))]
	resources.text = "%s  •  FLUX %s  •  spent %s  •  income/s %s  •  upkeep %s  •  REQ %s" % [team_name(p.get("team")), known(p.get("flux")), known(p.get("spent")), known(p.get("income")), known(p.get("upkeep")), known(p.get("req"))]
	var ids: Array[String] = []
	for node: Dictionary in p.get("nodes", []): ids.append(node.id)
	if ids != node_ids:
		node_ids = ids
		nodes.clear()
		for id: String in ids: nodes.add_item(id)
	if selected not in node_ids: selected = ""
	if selected.is_empty(): nodes.deselect_all()
	elif not nodes.is_selected(node_ids.find(selected)): nodes.select(node_ids.find(selected))
	var map_id := str(p.get("map", ""))
	if map_id != topology_map:
		# Only the authored topology for this recipient's own map id is loaded,
		# and only for as long as that map is the live projection.
		topology_map = map_id
		topology.clear()
		if catalog_ready and not map_id.is_empty():
			topology.set_authored(catalog.resolve_map(map_id))
	var cuts: Array = p.get("cuts") if p.get("cuts") is Array else []
	var link_model: Dictionary = topology.model(p.get("nodes", []), p.get("team"), cuts)
	map_view.set_nodes(p.get("nodes", []), selected, map_id)
	map_view.set_links(link_model)
	for i: int in range(node_ids.size()):
		var node: Dictionary = p.nodes[i]
		nodes.set_item_text(i, "%s  |  %s  |  owner %s  |  %s" % [node.get("label", node.id), node.get("archetype", "unknown"), "neutral" if node.has("owner") and node.owner == null else team_name(node.get("owner")), "CONTESTED" if node.get("contested") == true else "live" if node.get("live") == true else "inactive"])
		nodes.set_item_tooltip(i, "Node %s • x %s / z %s" % [node.id, known(node.get("x")), known(node.get("z"))])
	var cue: Dictionary = topology.guidance(link_model, selected)
	selection.text = "Selected: " + (selected if not selected.is_empty() else "none")
	if not p.is_empty() and not str(cue.get("text", "")).is_empty():
		selection.text += "  •  " + str(cue.text)
	var hold_gate: String = client.action_gate("hold", selected)
	var spend_gate: String = client.action_gate(client.purchase_kind())
	var command: Dictionary = client.dictionary(p.get("command"))
	var recruitment: Dictionary = client.dictionary(p.get("recruitment"))
	var authorization := "%s/%s/%s/%s/%s/%s/%s/%s" % [client.mode, client.revision, client.peer_id,
		client.actor_id, p.get("team"), recruitment.get("wave"), command.get("executor"), command.get("leaseUntil")]
	if authorization != authorization_context or not spend_gate.is_empty(): confirm_spend.set_pressed_no_signal(false)
	authorization_context = authorization
	var coop: bool = client.mode == "cocs-coop"
	confirm_spend.text = "Authorize one %s FLUX purchase" % ("50" if coop else "12")
	spend_button.text = "Co-op REINFORCE" if coop else "PvP Fighter"
	economy_help.text = ("Co-op: Fighter + 1 THREAD • 50 team FLUX, no REQ. " if coop else "PvP: Fighter • 12 team FLUX. ") + (spend_gate if not spend_gate.is_empty() else "Authorize, then purchase once; the server decides.")
	hold_button.disabled = not hold_gate.is_empty()
	hold_button.tooltip_text = hold_gate
	spend_button.disabled = not spend_gate.is_empty() or not confirm_spend.button_pressed
	spend_button.tooltip_text = spend_gate
	confirm_spend.disabled = not spend_gate.is_empty()
	notice.visible = not notice.text.is_empty()
	history.text = "No actions submitted."
	if not client.actions.is_empty():
		var lines: PackedStringArray = []
		for action: Dictionary in client.actions.slice(maxi(0, client.actions.size() - 6)):
			lines.append("%s • %s • %s%s" % [action.cardId, action.kind, action.status, " — " + client.rejection_text(action.reason) if action.reason != null else ""])
		history.text = "\n".join(lines)

func _process(_delta: float) -> void:
	if phase == "connecting" and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		phase = "joining" if joining else "creating"
		var result: Error = client.join_room(requested.room, "LATTICE guest", requested.operator, requested.harness) if joining else client.create_room("LATTICE host", requested.operator, requested.harness)
		if result != OK: client.fail("Room request queue failed")
	if phase in ["connecting", "creating", "configuring", "starting", "joining"] and Time.get_ticks_msec() - phase_at > 15000:
		client.fail("Handshake timed out; reconnect explicitly")
	refresh()
	if smoke: run_smoke()

func save_evidence(event: String) -> void:
	var p: Dictionary = client.projection
	var record := {"event":event, "map":client.requested_map, "mode":client.mode,
		"round":client.revision, "actor":client.actor_id, "flux":p.get("flux"), "spent":p.get("spent"),
		"roles":p.get("roles"), "actions":client.actions.duplicate(true)}
	evidence.append(record)
	print("LATTICE_EVIDENCE " + JSON.stringify(record))

func run_smoke() -> void:
	if Time.get_ticks_msec() - smoke_start > 115000:
		push_error("LATTICE smoke timed out at step %d" % smoke_step)
		get_tree().quit(1)
		return
	if phase != "active" or client.projection.is_empty(): return
	if smoke_step == 0 and client.gate().is_empty():
		if evidence.is_empty(): save_evidence("connected")
		for i: int in range(client.projection.nodes.size()):
			var node: Dictionary = client.projection.nodes[i]
			# Both locked authored maps link hq-N directly to front-N
			# (destination-lattice-maps.mjs:14). Neutral front is a legal HOLD.
			if node.id == "front-%d" % client.projection.team and node.get("live") == true:
				nodes.select(i)
				nodes.item_selected.emit(i)
				break
		if selected.is_empty(): return
		if hold_button.disabled: return
		hold_button.pressed.emit()
		var count: int = client.actions.size()
		hold_button.pressed.emit()
		if client.actions.size() != count: get_tree().quit(1); return
		smoke_step = 1
	elif smoke_step == 1 and not client.actions.is_empty() and client.actions[0].status != "queued":
		if client.actions[0].status == "rejected": push_error("Live HOLD rejected"); get_tree().quit(1); return
		save_evidence("order-authoritative")
		smoke_step = 2
	elif smoke_step == 2 and client.gate().is_empty():
		if client.mode == "cocs-coop":
			save_evidence("coop-state-and-hold-only")
			smoke_step = 5
		elif client.action_gate("fighter").is_empty():
			spend_baseline = client.projection.spent
			fighter_baseline = int(client.projection.roles.get("spawned", -1))
			save_evidence("before-economy")
			confirm_spend.button_pressed = true
			spend_button.pressed.emit()
			spend_button.pressed.emit()
			smoke_step = 3
	elif smoke_step == 3:
		for action: Dictionary in client.actions:
			if action.kind == "fighter" and action.status == "confirmed":
				if spend_baseline == null or client.projection.spent == null or not is_equal_approx(float(client.projection.spent) - float(spend_baseline), 12.0) or int(client.projection.roles.get("spawned", -1)) != fighter_baseline + 1:
					push_error("Economy cost/spawn reconciliation failed")
					get_tree().quit(1)
					return
				save_evidence("economy-confirmed")
				smoke_step = 4
				break
	elif smoke_step == 4 and client.gate().is_empty():
		# Explicit verification-only legal wire request for an unimplemented PvP sink.
		# This is a real refusal, not an injected snapshot or privileged role.
		client.activate("unsupported-fortify", selected)
		smoke_step = 5
	elif smoke_step == 5:
		if client.mode == "cocs":
			var refused := false
			for action: Dictionary in client.actions:
				if action.kind == "unsupported-fortify" and action.status == "rejected" and action.reason == "no-sink": refused = true
			if not refused: return
		save_evidence("final-state")
		smoke_step = 6
		smoke_at = Time.get_ticks_msec()
	elif smoke_step == 6 and Time.get_ticks_msec() - smoke_at > 800:
		if not capture.is_empty() and DisplayServer.get_name() != "headless":
			var image := get_viewport().get_texture().get_image()
			if image.save_png(capture) != OK: get_tree().quit(1); return
		disconnect_session()
		if not client.actions.is_empty() or not client.projection.is_empty() or not selected.is_empty(): get_tree().quit(1); return
		print("LATTICE_SMOKE_PASS disconnect clears actions/targets/state")
		get_tree().quit(0)
