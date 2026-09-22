extends Control
## Recipient-node diagram only. No inferred links, actor layer or static objectives.
signal node_selected(id: String)
const RADIUS := 12.0
var markers: Array[Dictionary] = []
var selected := ""
var map_id := ""
var missing := 0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Public objective coordinates; X/Z fitted independently. No topology links. Click to select; arrows browse. HOLD is a separate action. Overlapping markers cycle on repeated clicks."
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func set_nodes(public_nodes: Array, chosen: String, public_map: String) -> void:
	var next: Array[Dictionary] = []
	var seen := {}
	var absent := 0
	for value: Variant in public_nodes:
		if not value is Dictionary or not value.get("id") is String or value.id.is_empty() or seen.has(value.id): continue
		seen[value.id] = true
		if not finite_number(value.get("x")) or not finite_number(value.get("z")):
			absent += 1
			continue
		var item := {}
		for field: String in ["id", "label", "x", "z", "owner", "live", "contested"]:
			if value.has(field): item[field] = value[field]
		next.append(item)
	if markers == next and selected == chosen and map_id == public_map and missing == absent: return
	markers = next
	selected = chosen
	map_id = public_map
	missing = absent
	queue_redraw()

func marker_position(index: int) -> Vector2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for node: Dictionary in markers:
		var point := Vector2(node.x, node.z)
		low = low.min(point)
		high = high.max(point)
	var extent := high - low
	var normalized := Vector2(0.5, 0.5)
	if extent.x > 0: normalized.x = (float(markers[index].x) - low.x) / extent.x
	if extent.y > 0: normalized.y = (float(markers[index].z) - low.y) / extent.y
	return Vector2(88, 43) + normalized * Vector2(maxf(0, size.x - 176), maxf(0, size.y - 90))

func hit_test(point: Vector2, after_id: String = "") -> String:
	var hits: Array[String] = []
	for i: int in range(markers.size()):
		if point.distance_to(marker_position(i)) <= RADIUS + 5: hits.append(markers[i].id)
	if hits.is_empty(): return ""
	return hits[(hits.find(after_id) + 1) % hits.size()]

func choose(id: String) -> void:
	if id.is_empty(): return
	selected = id
	queue_redraw()
	node_selected.emit(id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		choose(hit_test(event.position, selected))
		accept_event()
	elif event is InputEventKey and event.pressed and not markers.is_empty():
		var ids: Array[String] = []
		for node: Dictionary in markers: ids.append(node.id)
		var index := ids.find(selected)
		match event.keycode:
			KEY_LEFT, KEY_UP: index = posmod(index - 1, ids.size()) if index >= 0 else ids.size() - 1
			KEY_RIGHT, KEY_DOWN: index = (index + 1) % ids.size()
			KEY_HOME: index = 0
			KEY_END: index = ids.size() - 1
			_: return
		choose(ids[index])
		accept_event()

func owner_symbol(node: Dictionary) -> String:
	if not node.has("owner"): return "?"
	if node.owner == null: return "N"
	if finite_number(node.owner) and (float(node.owner) == 0.0 or float(node.owner) == 1.0): return str(int(node.owner))
	return "?"

func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel", "Tree"), Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var ink := Color("dce8f2")
	var title := "MONSOON FOUNDRY" if map_id == "monsoon-foundry" else "ASTERION RELAY" if map_id == "asterion-relay" else "PUBLIC OBJECTIVES"
	draw_string(font, Vector2(10, 19), title + "   /   -Z ↑    +X →", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	draw_string(font, Vector2(maxf(350, size.x - 445), 19), "0 blue / 1 coral / N neutral / ? unknown   •   ! contested", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	for i: int in range(markers.size()):
		var node: Dictionary = markers[i]
		var point := marker_position(i)
		var symbol := owner_symbol(node)
		var color := Color("68bdff") if symbol == "0" else Color("ff9b86") if symbol == "1" else Color("b4bfcc")
		if node.get("live") != true: color = color.darkened(0.4)
		if node.id == selected: draw_arc(point, RADIUS + 5, 0, TAU, 32, Color("ffffff"), 2, true)
		draw_circle(point, RADIUS, color)
		draw_string(font, point + Vector2(-4, 5), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("101b29"))
		if node.get("contested") == true: draw_string(font, point + Vector2(15, 4), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd375"))
		var label_text: String = str(node.get("label", node.id))
		# Coincident positions remain true positions; the selected label wins.
		var overlaps := 0
		var show_label := true
		for j: int in range(markers.size()):
			if j == i or point.distance_to(marker_position(j)) > RADIUS * 2: continue
			overlaps += 1
			if markers[j].id == selected or (node.id != selected and j < i): show_label = false
		if overlaps: label_text += " (+%d)" % overlaps
		if show_label:
			var width := minf(220, font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
			draw_string(font, Vector2(clampf(point.x - width / 2, 8, maxf(8, size.x - width - 8)), point.y + 28), label_text, HORIZONTAL_ALIGNMENT_LEFT, 220, 12, ink)
	var help := "Click / arrows: select only • bright = live, dim = inactive/unknown • HOLD below"
	if markers.is_empty(): help = "No positioned public objectives received."
	if missing: help += " • %d without coordinates: use List" % missing
	draw_string(font, Vector2(10, size.y - 6), help, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 12, ink)
	if has_focus(): draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("f7d578"), false, 2)
