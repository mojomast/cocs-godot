extends Control
## Presentation only: the world's existing recipient transport owns all actions.
signal close_requested
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
	for label: Label in [resources, selection, economy_help, notice, history]:
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
	if ids != node_ids:
		node_ids = ids
		nodes.clear()
		for id: String in ids: nodes.add_item(id)
	if selected not in node_ids: selected = ""
	if selected.is_empty(): nodes.deselect_all()
	else: nodes.select(node_ids.find(selected))
	for i: int in range(node_ids.size()):
		var node: Dictionary = p.nodes[i]
		nodes.set_item_text(i, "%s · %s · %s" % [node.get("label", node.id), "Neutral" if node.get("owner") == null else "Team %d" % int(node.owner), "CONTESTED" if node.get("contested") == true else "live" if node.get("live") == true else "inactive"])
		nodes.set_item_disabled(i, not blocked.is_empty())
	var hold_gate: String = blocked if not blocked.is_empty() else client.action_gate("hold", selected)
	var spend_gate: String = blocked if not blocked.is_empty() else client.action_gate(client.purchase_kind())
	selection.text = "Selected: %s · %s" % [selected if not selected.is_empty() else "none", hold_gate if not hold_gate.is_empty() else "Ready to issue HOLD (server decides)"]
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
	notice.visible = not notice.text.is_empty()
	history.text = "No actions submitted."
	var lines: PackedStringArray = []
	for action: Dictionary in client.actions.slice(maxi(0, client.actions.size() - 3)):
		lines.append("%s · %s · %s%s" % [action.cardId, action.kind, action.status, " — " + client.rejection_text(action.reason) if action.reason != null else ""])
	if not lines.is_empty(): history.text = "\n".join(lines)

func _process(_delta: float) -> void:
	world_refresh()
