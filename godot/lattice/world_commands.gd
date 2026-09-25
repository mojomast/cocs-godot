extends Control
## Presentation only: the world's existing recipient transport owns all actions.
signal close_requested
const Topology = preload("res://lattice/topology.gd")
const Telemetry = preload("res://lattice/world_telemetry.gd")
var session: Node
var client: Node
var selected := ""
var context := ""
var authorization := ""
var node_ids: Array[String] = []
var panel := PanelContainer.new()
var nodes := ItemList.new()
var resources := Label.new()
var selection := Label.new()
var hold_button := Button.new()
var confirm_spend := CheckBox.new()
var spend_button := Button.new()
var economy_help := Label.new()
var notice := Label.new()
var history := Label.new()
var topology := Topology.new()
var telemetry := Telemetry.new()
var authored_map_id := ""
var req_items := ItemList.new()
var req_depot_row := HBoxContainer.new()
var req_depot_caption := Label.new()
var req_depot_pick := OptionButton.new()
var req_depot_ids: Array[String] = []
var req_effect := Label.new()
var req_confirm := CheckBox.new()
var req_button := Button.new()
var req_help := Label.new()
var req_notice := Label.new()
var req_selected := ""
var req_signature := "<unset>"
var req_authorization := ""

func bind_authored_map(map_id: String, source_map: Variant) -> bool:
	if map_id != authored_map_id:
		topology.clear()
		authored_map_id = map_id
	return topology.set_authored(source_map)

func world_label(text_value: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_font_size_override("font_size", 16)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.07, 0.65)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152333")
	style.border_color = Color("56859a")
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	world_label("LATTICE / TACTICAL COMMAND", header).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := Button.new()
	close_button.text = "Close [C / Esc]"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)
	world_label("World controls paused. Select an objective, then explicitly issue HOLD.", column)
	for label: Label in [resources, selection, economy_help, notice, history, req_effect, req_help, req_notice]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(resources)
	nodes.custom_minimum_size.y = 128
	nodes.item_selected.connect(world_select)
	column.add_child(nodes)
	column.add_child(selection)
	hold_button.text = "Issue HOLD"
	hold_button.pressed.connect(world_hold)
	column.add_child(hold_button)
	column.add_child(confirm_spend)
	confirm_spend.toggled.connect(func(_pressed: bool) -> void: world_refresh())
	spend_button.pressed.connect(world_purchase)
	column.add_child(spend_button)
	column.add_child(economy_help)
	world_label("PERSONAL REQ · local picker, server-owned rules", column)
	req_items.custom_minimum_size.y = 96
	req_items.item_selected.connect(world_req_select)
	column.add_child(req_items)
	req_depot_caption.text = "Depot"
	req_depot_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req_depot_row.add_theme_constant_override("separation", 8)
	req_depot_row.add_child(req_depot_caption)
	req_depot_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	req_depot_pick.item_selected.connect(func(_index: int) -> void: world_refresh())
	req_depot_row.add_child(req_depot_pick)
	column.add_child(req_depot_row)
	column.add_child(req_effect)
	req_confirm.toggled.connect(func(_pressed: bool) -> void: world_refresh())
	column.add_child(req_confirm)
	req_button.pressed.connect(world_req_purchase)
	column.add_child(req_button)
	column.add_child(req_help)
	column.add_child(req_notice)
	column.add_child(notice)
	world_label("RECEIPTS · queued ≠ accepted ≠ completed", column)
	column.add_child(history)
	world_label("Movement ACK is a high-water receipt, not individual input application.\nClose, release controls, then click the world to resume.", column)
	resized.connect(world_layout)
	world_layout()
	hide()

func world_layout() -> void:
	panel.size = Vector2(minf(700, size.x - 32), minf(590, size.y - 32))
	panel.position = (size - panel.size) * 0.5

func world_bind(owner_session: Node) -> void:
	session = owner_session
	client = session.client
	client.changed.connect(world_refresh)

func world_clear() -> void:
	selected = ""
	context = ""
	authorization = ""
	confirm_spend.set_pressed_no_signal(false)
	nodes.deselect_all()
	notice.text = ""
	hold_button.disabled = true
	spend_button.disabled = true
	confirm_spend.disabled = true
	req_selected = ""
	req_signature = "<unset>"
	req_authorization = ""
	req_confirm.set_pressed_no_signal(false)
	req_items.deselect_all()
	req_depot_ids.clear()
	req_depot_pick.clear()
	req_depot_row.visible = false
	req_effect.text = ""
	req_help.text = ""
	req_notice.text = ""
	req_notice.visible = false
	req_confirm.disabled = true
	req_button.disabled = true

func world_select(index: int) -> void:
	if not visible or not session.world_command_gate().is_empty(): return
	if index < 0 or index >= node_ids.size(): return
	selected = node_ids[index]
	world_refresh()

func world_hold() -> void:
	world_refresh()
	if not visible or hold_button.disabled: return
	notice.text = client.activate("hold", selected)
	world_refresh()

func world_purchase() -> void:
	world_refresh()
	if not visible or spend_button.disabled or not confirm_spend.button_pressed: return
	# Consume consent before queueing; synchronous changed signals cannot reuse it.
	confirm_spend.set_pressed_no_signal(false)
	notice.text = client.activate(client.purchase_kind())
	world_refresh()

func world_req_select(index: int) -> void:
	if not visible or not session.world_command_gate().is_empty(): return
	var options: Array = client.req_options()
	if index < 0 or index >= options.size(): return
	req_selected = str(options[index].get("id", ""))
	world_refresh()

## Selected owned depot for the OPERATIONS Puma, or "" when unknown/none. Uses
## the explicit per-depot picker when its selection is still owned, else the
## first observed owned depot; never inferred.
func world_req_depot() -> String:
	var owned: Array[String] = []
	if is_instance_valid(client): owned = client.req_owned_depots()
	if owned.is_empty(): return ""
	if req_depot_pick.selected >= 0 and req_depot_pick.selected < req_depot_ids.size():
		var chosen := req_depot_ids[req_depot_pick.selected]
		if owned.has(chosen): return chosen
	return str(owned[0])

func world_req_purchase() -> void:
	world_refresh()
	if not visible or req_button.disabled or not req_confirm.button_pressed: return
	# Consume consent before queueing; synchronous changed signals cannot reuse it.
	req_confirm.set_pressed_no_signal(false)
	var depot := world_req_depot() if req_selected == "puma" else ""
	req_notice.text = client.activate("buy", req_selected, depot)
	world_refresh()

func observe_events(items: Array) -> void:
	if is_instance_valid(client): telemetry.observe_events(items, client.projection)

func world_known(value: Variant) -> String:
	return "unknown" if value == null else "%.1f" % float(value)

func world_refresh() -> void:
	if not is_instance_valid(client): return
	var p: Dictionary = client.projection
	var current := "%s/%s/%s/%s/%s/%s" % [p.get("map"), client.mode, client.revision, client.peer_id, client.actor_id, p.get("team")]
	var blocked: String = session.world_command_gate()
	if current != context or not blocked.is_empty(): world_clear()
	context = current
	resources.text = "Own team FLUX %s · spent %s · own REQ %s" % [world_known(p.get("flux")), world_known(p.get("spent")), world_known(p.get("req"))]
	var ids: Array[String] = []
	for node: Dictionary in p.get("nodes", []): ids.append(node.id)
	var model: Dictionary = topology.model(p.get("nodes", []), p.get("team"), p.get("cuts", []))
	var by_id: Dictionary = model.get("by_id", {})
	if ids != node_ids:
		node_ids = ids
		nodes.clear()
		for id: String in ids: nodes.add_item(id)
	if selected not in node_ids: selected = ""
	if selected.is_empty(): nodes.deselect_all()
	else: nodes.select(node_ids.find(selected))
	for i: int in range(node_ids.size()):
		var node: Dictionary = p.nodes[i]
		var fact: Dictionary = by_id.get(node.id, {})
		var owner := "unknown" if not node.has("owner") else "Neutral" if node.owner == null else "Team %s" % str(node.owner)
		var legality := "capture legal" if fact.get("capture_legal") == true else "own HOLD" if fact.get("mine") == true else "capture unknown" if fact.get("reach") == null or not fact.get("owner_known", false) else "capture unavailable"
		nodes.set_item_text(i, "%s · %s · %s · %s · supply %s" % [node.get("label", node.id), owner, "CONTESTED" if node.get("contested") == true else "live" if node.get("live") == true else "inactive", legality, fact.get("supply", "UNKNOWN")])
		nodes.set_item_disabled(i, not blocked.is_empty())
	var hold_gate: String = blocked if not blocked.is_empty() else client.action_gate("hold", selected)
	var spend_gate: String = blocked if not blocked.is_empty() else client.action_gate(client.purchase_kind())
	var selected_cue: Dictionary = topology.guidance(model, selected)
	selection.text = "Selected: %s · %s\n%s" % [selected if not selected.is_empty() else "none", hold_gate if not hold_gate.is_empty() else "Ready to issue HOLD (server decides)", selected_cue.get("text", "")]
	var command: Dictionary = p.get("command", {})
	var recruitment: Dictionary = p.get("recruitment", {})
	var fresh := "%s/%s/%s/%s" % [current, recruitment.get("wave"), command.get("executor"), command.get("leaseUntil")]
	if fresh != authorization or not spend_gate.is_empty(): confirm_spend.set_pressed_no_signal(false)
	authorization = fresh
	var coop: bool = client.purchase_kind() == "reinforce"
	var price: float = client.COOP_REINFORCE_FLUX if coop else client.PVP_FIGHTER_FLUX
	confirm_spend.text = "Authorize one %.0f team FLUX purchase" % price
	spend_button.text = "Purchase co-op REINFORCE" if coop else "Recruit PvP Fighter"
	economy_help.text = spend_gate if not spend_gate.is_empty() else "Recipient permission available. Authorize, then purchase once."
	hold_button.disabled = not visible or not hold_gate.is_empty()
	confirm_spend.disabled = not visible or not spend_gate.is_empty()
	spend_button.disabled = confirm_spend.disabled or not confirm_spend.button_pressed
	world_refresh_req(p, blocked)
	notice.visible = not notice.text.is_empty()
	history.text = "No actions submitted."
	var lines: PackedStringArray = []
	for action: Dictionary in client.actions.slice(maxi(0, client.actions.size() - 3)):
		var settlement := ""
		if action.get("kind") == "buy":
			settlement = "server settled purchase; REQ debit authoritative" if action.status == "confirmed" else "server accepted; settlement unconfirmed" if action.status.begins_with("pending") else "local queue only (not accepted)" if action.status == "queued" else "card refused/expired"
		else:
			var observed_effect := telemetry.effect_for_action(action, p, client.actor_id)
			settlement = "order effect observed" if observed_effect else "card settled (effect unconfirmed)" if action.status == "confirmed" else "server accepted; effect unconfirmed" if action.status.begins_with("pending") else "local queue only" if action.status == "queued" else "card refused/expired"
		if action.get("reason") == "replaced": settlement = "card replaced; no capture evidence"
		lines.append("%s · %s · %s%s" % [action.cardId, action.kind, settlement, " — " + client.rejection_text(action.reason) if action.reason != null else ""])
	if not lines.is_empty(): history.text = "\n".join(lines)

## Personal REQ picker. Everything shown is a mirror of the source catalogue plus
## recipient-observed state; the button only queues one ordinary BUY request.
## Gated rows stay readable (greyed, not disabled) so the truthful refusal reason
## is visible, but the purchase gate still refuses any frame for them.
func world_refresh_req(p: Dictionary, blocked: String) -> void:
	var options: Array = []
	if is_instance_valid(client): options = client.req_options()
	var rows := PackedStringArray()
	for option: Variant in options:
		if option is Dictionary: rows.append(str(option.get("id", "")))
	var signature := "%s|%s" % [blocked, "\n".join(rows)]
	if signature != req_signature:
		req_signature = signature
		req_items.clear()
		for option: Variant in options:
			if option is Dictionary: req_items.add_item(str(option.get("name", option.get("id"))))
	for i: int in range(options.size()):
		var option: Dictionary = options[i]
		var mark := ""
		if option.get("enabled") != true:
			mark = client.req_reason_text(str(option.get("disabledReason", "")))
		var cost: Variant = option.get("cost")
		req_items.set_item_text(i, "%s · %s REQ%s" % [option.get("name", option.get("id")), cost, "" if mark.is_empty() else " · " + mark])
		var tip := str(option.get("effectCopy", ""))
		if not mark.is_empty(): tip += "\n" + mark
		if str(option.get("target", "self")) in ["cut-link", "depot"]:
			tip += "\nServer validates a legal target; a refusal appears as no-target."
		req_items.set_item_tooltip(i, tip)
		# Readable when gated, but never purchase-enabling; the buy gate below and
		# the server re-check every frame.
		req_items.set_item_disabled(i, false)
		var usable: bool = option.get("enabled") == true and blocked.is_empty()
		req_items.set_item_custom_fg_color(i, Color("dbe7f0") if usable else Color("8aa0b4"))
	req_items.custom_minimum_size.y = maxf(64.0, minf(7.0, float(maxi(1, options.size()))) * 30.0)
	var chosen: Dictionary = {}
	var index := -1
	for i: int in range(options.size()):
		if options[i].get("id") == req_selected:
			chosen = options[i]
			index = i
	if chosen.is_empty() or index < 0:
		req_selected = ""
		req_items.deselect_all()
	else:
		req_items.select(index)
	world_refresh_depots(chosen)
	var depot := world_req_depot() if req_selected == "puma" else ""
	var req_gate := "Select a REQ item"
	if chosen.is_empty():
		req_effect.text = "Select a REQ item. Costs and effects mirror game/cocs-economy.mjs."
	elif not blocked.is_empty():
		req_effect.text = "%s · %s REQ\n%s" % [chosen.get("name"), chosen.get("cost"), chosen.get("effectCopy")]
		req_gate = blocked
	else:
		var detail := "%s · %s REQ\n%s" % [chosen.get("name"), chosen.get("cost"), chosen.get("effectCopy")]
		if str(chosen.get("target", "self")) in ["cut-link", "depot"]:
			detail += "\nServer validates a legal target; a refusal appears as no-target."
		req_effect.text = detail
		req_gate = client.req_gate(req_selected, depot)
	# Consent belongs to one item, price and depot inside a live identity epoch.
	# Any change to those (or to the server gate below) revokes it before another
	# request can reuse it.
	var req_fresh := "%s/%s/%s/%s/%s" % [p.get("map"), client.mode, client.revision, req_selected, chosen.get("cost")]
	if depot != "": req_fresh += "/" + depot
	if req_fresh != req_authorization or not req_gate.is_empty(): req_confirm.set_pressed_no_signal(false)
	req_authorization = req_fresh
	req_confirm.text = "Authorize one REQ purchase" if chosen.is_empty() else "Authorize %s (%s REQ)" % [chosen.get("name"), chosen.get("cost")]
	req_confirm.disabled = not visible or chosen.is_empty() or not req_gate.is_empty()
	req_button.disabled = req_confirm.disabled or not req_confirm.button_pressed
	req_button.text = "Purchase REQ item" if chosen.is_empty() else "Purchase %s" % chosen.get("name")
	req_help.text = req_gate if not req_gate.is_empty() else "Recipient permission available. Authorize, then purchase once."
	req_notice.text = ""
	var latest_buy: Dictionary = {}
	for action: Dictionary in client.actions:
		if action.get("kind") == "buy": latest_buy = action
	if not latest_buy.is_empty():
		var status := str(latest_buy.get("status", ""))
		if status == "queued": req_notice.text = "BUY queued locally — not accepted yet."
		elif status.begins_with("pending"): req_notice.text = "BUY accepted by server — effect not yet confirmed."
		elif status == "confirmed": req_notice.text = "BUY settled by server; own REQ above is authoritative."
		elif status == "rejected": req_notice.text = "BUY refused: %s" % client.rejection_text(latest_buy.get("reason"))
	req_notice.visible = not req_notice.text.is_empty()

## Owned-depot picker for the OPERATIONS Puma only. The list is exactly the
## recipient-observed owned depots; absence stays hidden and the row refuses.
func world_refresh_depots(chosen: Dictionary) -> void:
	var owned: Array[String] = []
	if is_instance_valid(client): owned = client.req_owned_depots()
	if owned != req_depot_ids:
		req_depot_ids = owned
		req_depot_pick.clear()
		for id: String in owned: req_depot_pick.add_item(id)
		if not owned.is_empty(): req_depot_pick.select(0)
	var needs_depot: bool = not chosen.is_empty() and str(chosen.get("target", "self")) == "depot"
	req_depot_row.visible = needs_depot and not owned.is_empty()
	req_depot_caption.text = "Depot" if req_depot_row.visible else ""

func _process(_delta: float) -> void:
	world_refresh()
