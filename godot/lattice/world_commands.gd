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
var tabs := TabContainer.new()
var req_list_shell := PanelContainer.new()
var req_name := Label.new()
var req_price := Label.new()
var req_category := Label.new()
var req_balance := Label.new()
var req_state := Label.new()
var header_margin := MarginContainer.new()
var header_eyebrow: Label
var deck_title: Label

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

func card_style(background: String, border: String, padding: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(padding)
	return style

func section_card(parent: Node, background: String = "111e2b") -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style(background, "344b5d"))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	return content

func eyebrow(text_value: String, parent: Node) -> Label:
	var label := world_label(text_value, parent)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("78d9d0"))
	return label

func primary_action(button: Button) -> void:
	button.add_theme_stylebox_override("normal", card_style("167a76", "68d8c8", 8))
	button.add_theme_stylebox_override("hover", card_style("20968e", "a5f1dd", 8))
	button.add_theme_stylebox_override("pressed", card_style("0c5a59", "68d8c8", 8))
	button.add_theme_stylebox_override("disabled", card_style("142431", "263d4a", 8))
	button.add_theme_color_override("font_color", Color("f2fffa"))
	button.add_theme_color_override("font_disabled_color", Color("869ca9"))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.025, 0.04, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	add_child(panel)
	panel.add_theme_stylebox_override("panel", card_style("0b1724", "4c7586", 0))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)
	for side: String in ["left", "right"]: header_margin.add_theme_constant_override("margin_" + side, 28)
	for side: String in ["top", "bottom"]: header_margin.add_theme_constant_override("margin_" + side, 18)
	outer.add_child(header_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	header_margin.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)
	header_eyebrow = eyebrow("LATTICE  /  FIELD SYSTEMS", title_stack)
	deck_title = world_label("Command deck", title_stack)
	deck_title.add_theme_font_size_override("font_size", 27)
	deck_title.add_theme_color_override("font_color", Color("e8f2f3"))
	resources.add_theme_font_size_override("font_size", 14)
	resources.add_theme_color_override("font_color", Color("b9ceda"))
	resources.custom_minimum_size.x = 365
	resources.autowrap_mode = TextServer.AUTOWRAP_OFF
	resources.clip_text = true
	resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(resources)
	var close_button := Button.new()
	close_button.text = "CLOSE  ×"
	close_button.custom_minimum_size = Vector2(102, 44)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)
	var divider := ColorRect.new()
	divider.color = Color("30485a")
	divider.custom_minimum_size.y = 1
	outer.add_child(divider)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 16)
	outer.add_child(tabs)
	var objectives := HBoxContainer.new()
	objectives.name = "01  OBJECTIVES"
	objectives.add_theme_constant_override("separation", 16)
	tabs.add_child(objectives)
	var objective_list := section_card(objectives)
	eyebrow("01 / MAP CONTROL", objective_list)
	world_label("Choose an objective", objective_list).add_theme_font_size_override("font_size", 21)
	world_label("The server decides legality and applies HOLD.", objective_list)
	nodes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nodes.custom_minimum_size = Vector2(345, 180)
	nodes.item_selected.connect(world_select)
	objective_list.add_child(nodes)
	var objective_detail := section_card(objectives, "152636")
	eyebrow("SELECTED TARGET", objective_detail)
	objective_detail.add_child(selection)
	selection.add_theme_font_size_override("font_size", 18)
	hold_button.text = "Issue HOLD →"
	hold_button.custom_minimum_size.y = 48
	primary_action(hold_button)
	hold_button.pressed.connect(world_hold)
	objective_detail.add_child(hold_button)
	world_label("A HOLD receipt records the request. It does not prove capture or supply change.", objective_detail)
	var req_page := HBoxContainer.new()
	req_page.name = "02  PERSONAL REQ"
	req_page.add_theme_constant_override("separation", 16)
	tabs.add_child(req_page)
	req_list_shell.add_theme_stylebox_override("panel", card_style("111e2b", "344b5d"))
	req_list_shell.custom_minimum_size.x = 390
	req_list_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	req_page.add_child(req_list_shell)
	var req_list_column := VBoxContainer.new()
	req_list_column.add_theme_constant_override("separation", 10)
	req_list_shell.add_child(req_list_column)
	eyebrow("02 / PERSONAL REQUISITION", req_list_column)
	world_label("Choose one field option", req_list_column).add_theme_font_size_override("font_size", 20)
	world_label("Source catalog · server validates every purchase", req_list_column)
	req_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	req_items.custom_minimum_size.y = 240
	req_items.add_theme_font_size_override("font_size", 16)
	req_items.add_theme_constant_override("v_separation", 10)
	req_items.add_theme_stylebox_override("selected", card_style("20515a", "62cfc5", 4))
	req_items.add_theme_stylebox_override("selected_focus", card_style("20515a", "62cfc5", 4))
	req_items.item_selected.connect(world_req_select)
	req_list_column.add_child(req_items)
	req_balance.add_theme_color_override("font_color", Color("a7c0ce"))
	req_list_column.add_child(req_balance)
	var req_detail_scroll := ScrollContainer.new()
	req_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	req_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	req_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	req_page.add_child(req_detail_scroll)
	var req_detail := section_card(req_detail_scroll, "152636")
	eyebrow("SELECTED LOADOUT", req_detail)
	req_name.add_theme_font_size_override("font_size", 27)
	req_name.add_theme_color_override("font_color", Color("f0f6f2"))
	req_detail.add_child(req_name)
	req_price.add_theme_font_size_override("font_size", 23)
	req_price.add_theme_color_override("font_color", Color("79e2d2"))
	req_detail.add_child(req_price)
	req_category.add_theme_color_override("font_color", Color("adc3ce"))
	req_detail.add_child(req_category)
	var rule := HSeparator.new()
	req_detail.add_child(rule)
	req_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req_effect.add_theme_font_size_override("font_size", 17)
	req_detail.add_child(req_effect)
	req_state.add_theme_font_size_override("font_size", 14)
	req_detail.add_child(req_state)
	req_depot_caption.text = "FRIENDLY DEPOT"
	req_depot_row.add_theme_constant_override("separation", 10)
	req_depot_row.add_child(req_depot_caption)
	req_depot_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	req_depot_pick.item_selected.connect(func(_index: int) -> void: world_refresh())
	req_depot_row.add_child(req_depot_pick)
	req_detail.add_child(req_depot_row)
	req_confirm.toggled.connect(func(_pressed: bool) -> void: world_refresh())
	req_detail.add_child(req_confirm)
	req_button.custom_minimum_size.y = 50
	primary_action(req_button)
	req_button.pressed.connect(world_req_purchase)
	req_detail.add_child(req_button)
	req_detail.add_child(req_help)
	req_detail.add_child(req_notice)
	var team_page := VBoxContainer.new()
	team_page.name = "03  TEAM ECONOMY"
	tabs.add_child(team_page)
	var team_content := section_card(team_page, "152636")
	eyebrow("03 / SHARED TEAM FLUX", team_content)
	world_label("Reinforce the line", team_content).add_theme_font_size_override("font_size", 25)
	world_label("This spends team FLUX, never personal REQ. Your team's command seat and source rules decide availability.", team_content)
	confirm_spend.toggled.connect(func(_pressed: bool) -> void: world_refresh())
	team_content.add_child(confirm_spend)
	spend_button.custom_minimum_size.y = 48
	primary_action(spend_button)
	spend_button.pressed.connect(world_purchase)
	team_content.add_child(spend_button)
	team_content.add_child(economy_help)
	var activity_page := VBoxContainer.new()
	activity_page.name = "04  ACTIVITY"
	tabs.add_child(activity_page)
	var activity := section_card(activity_page)
	eyebrow("04 / SOURCE RECEIPTS", activity)
	world_label("Recent decisions", activity).add_theme_font_size_override("font_size", 23)
	world_label("QUEUED means a local request. ACCEPTED and SETTLED are separate source observations.", activity)
	activity.add_child(history)
	var footer := MarginContainer.new()
	for side: String in ["left", "right"]: footer.add_theme_constant_override("margin_" + side, 26)
	for side: String in ["top", "bottom"]: footer.add_theme_constant_override("margin_" + side, 12)
	outer.add_child(footer)
	var footer_row := HBoxContainer.new()
	footer.add_child(footer_row)
	footer_row.add_child(notice)
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var exit_help := world_label("C / ESC TO CLOSE  ·  CLICK WORLD TO RESUME", footer_row)
	exit_help.add_theme_font_size_override("font_size", 12)
	exit_help.add_theme_color_override("font_color", Color("829eab"))
	exit_help.custom_minimum_size.x = 320
	exit_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	exit_help.clip_text = true
	for label: Label in [selection, economy_help, notice, history, req_effect, req_help, req_notice]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(world_layout)
	world_layout()
	# Container minimums settle after insertion; repeat once before the first
	# rendered frame so tab content cannot expand the panel off-screen.
	get_tree().process_frame.connect(world_layout, CONNECT_ONE_SHOT)
	hide()

func world_layout() -> void:
	var compact := size.y < 640 or size.x < 900
	header_eyebrow.visible = not compact
	deck_title.add_theme_font_size_override("font_size", 20 if compact else 27)
	for side: String in ["top", "bottom"]: header_margin.add_theme_constant_override("margin_" + side, 8 if compact else 18)
	for side: String in ["left", "right"]: header_margin.add_theme_constant_override("margin_" + side, 14 if compact else 28)
	resources.custom_minimum_size.x = 225 if compact else 365
	req_items.custom_minimum_size.y = 110 if compact else 240
	panel.size = Vector2(minf(1080, size.x - 28), minf(700, size.y - 28))
	panel.position = (size - panel.size) * 0.5
	req_list_shell.custom_minimum_size.x = minf(390, maxf(205, panel.size.x * 0.39))

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
	req_name.text = "Choose a field option"
	req_price.text = ""
	req_category.text = ""
	req_balance.text = ""
	req_state.text = ""
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
	resources.text = "FLUX %s  ·  REQ %s" % [world_known(p.get("flux")), world_known(p.get("req"))] if size.x < 900 else "TEAM FLUX  %s   ·   PERSONAL REQ  %s" % [world_known(p.get("flux")), world_known(p.get("req"))]
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
	selection.text = "%s\n\n%s\n\n%s" % [selected if not selected.is_empty() else "No objective selected", hold_gate if not hold_gate.is_empty() else "Ready to issue HOLD · server decides", selected_cue.get("text", "")]
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
		req_items.set_item_text(i, "%s  ·  %s REQ" % [option.get("name", option.get("id")), cost])
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
	req_balance.text = "AVAILABLE  %s REQ     ·     %s OPTIONS" % [world_known(p.get("req")), options.size()]
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
		req_name.text = "Choose a field option"
		req_price.text = ""
		req_category.text = "SELECT FROM THE SOURCE CATALOG"
		req_effect.text = "Select an item to see its effect, target and current eligibility before you authorize a single purchase."
	elif not blocked.is_empty():
		req_name.text = str(chosen.get("name"))
		req_price.text = "%s REQ" % chosen.get("cost")
		req_category.text = "%s  /  %s" % [str(chosen.get("category", "field")).to_upper(), str(chosen.get("target", "self")).to_upper()]
		req_effect.text = str(chosen.get("effectCopy"))
		req_gate = blocked
	else:
		req_name.text = str(chosen.get("name"))
		req_price.text = "%s REQ" % chosen.get("cost")
		req_category.text = "%s  /  %s" % [str(chosen.get("category", "field")).to_upper(), str(chosen.get("target", "self")).to_upper()]
		req_effect.text = str(chosen.get("effectCopy"))
		req_gate = client.req_gate(req_selected, depot)
	req_state.text = "SELECT AN ITEM" if chosen.is_empty() else "UNAVAILABLE  ·  %s" % req_gate if not req_gate.is_empty() else "AVAILABLE TO REQUEST  ·  SERVER SETTLES"
	req_state.add_theme_color_override("font_color", Color("f2b57a") if not req_gate.is_empty() else Color("79e2d2"))
	# Consent belongs to one item, price and depot inside a live identity epoch.
	# Any change to those (or to the server gate below) revokes it before another
	# request can reuse it.
	var req_fresh := "%s/%s/%s/%s/%s" % [p.get("map"), client.mode, client.revision, req_selected, chosen.get("cost")]
	if depot != "": req_fresh += "/" + depot
	if req_fresh != req_authorization or not req_gate.is_empty(): req_confirm.set_pressed_no_signal(false)
	req_authorization = req_fresh
	req_confirm.text = "Authorize one purchase" if chosen.is_empty() else "Authorize %s  ·  %s REQ" % [chosen.get("name"), chosen.get("cost")]
	req_confirm.disabled = not visible or chosen.is_empty() or not req_gate.is_empty()
	req_button.disabled = req_confirm.disabled or not req_confirm.button_pressed
	req_button.text = "REQUEST PURCHASE →" if chosen.is_empty() else "REQUEST %s →" % str(chosen.get("name")).to_upper()
	req_help.text = "Server checks the legal target at application; no valid effect means no debit." if req_gate.is_empty() else "Why unavailable: %s" % req_gate
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
