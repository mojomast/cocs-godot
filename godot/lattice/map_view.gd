extends Control
## Recipient-node diagram with the recipient-visible authored link layer. No
## inferred links, actor layer or static objectives.
signal node_selected(id: String)
const RADIUS := 12.0
var markers: Array[Dictionary] = []
var links: Array[Dictionary] = []
var counts := {"owned": 0, "linked": 0, "cut": 0}
var selected := ""
var map_id := ""
var missing := 0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Public objective coordinates and recipient-visible authored links; X/Z fitted independently. Click to select; arrows browse. HOLD is a separate action. Overlapping markers cycle on repeated clicks."
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
	# A link is only drawn while both of its endpoints are current markers.
	var keep: Array[Dictionary] = []
	for link: Dictionary in links:
		if seen.has(link.a) and seen.has(link.b): keep.append(link)
	links = keep
	queue_redraw()

## Advisory link layer pushed by the board. `model` is the recipient-filtered
## authored model (`godot/lattice/topology.gd`): links whose endpoints are not
## both drawn markers are dropped here, so nothing outside the recipient's own
## markers can ever be drawn. Presentation only; the server decides orders.
func set_links(model: Dictionary) -> void:
	var source: Dictionary = model if model is Dictionary else {}
	var lookup := {}
	for node: Dictionary in markers: lookup[node.id] = true
	var next: Array[Dictionary] = []
	for link: Variant in source.get("edges", []):
		if not link is Dictionary: continue
		if not link.get("a") is String or not link.get("b") is String: continue
		if not lookup.has(link.a) or not lookup.has(link.b): continue
		next.append({"a": link.a, "b": link.b, "state": str(link.get("state", "unknown"))})
	var next_counts := {"owned": int(source.get("owned", 0)), "linked": int(source.get("linked", 0)),
		"cut": int(source.get("cut", 0))}
	if links == next and counts == next_counts: return
	links = next
	counts = next_counts
	queue_redraw()

func link_style(state: String) -> Dictionary:
	match state:
		"linked": return {"color": Color("7fd0ff"), "width": 2.0, "dash": 0.0}
		"severed": return {"color": Color("ff9b86"), "width": 2.0, "dash": 7.0}
		"front": return {"color": Color("f7d578"), "width": 1.5, "dash": 5.0}
		"other": return {"color": Color("5b6c7e"), "width": 1.0, "dash": 0.0}
	return {"color": Color("46545f"), "width": 1.0, "dash": 3.0}

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
	# Authored links draw behind every marker, so the objective symbols stay
	# readable on top of their own supply lines.
	var index_of := {}
	for i: int in range(markers.size()): index_of[markers[i].id] = i
	for link: Dictionary in links:
		if not index_of.has(link.a) or not index_of.has(link.b): continue
		var from := marker_position(index_of[link.a])
		var to := marker_position(index_of[link.b])
		var style := link_style(link.state)
		if float(style.dash) > 0.0:
			draw_dashed_line(from, to, style.color, float(style.width), float(style.dash))
		else:
			draw_line(from, to, style.color, float(style.width))
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
	if not links.is_empty():
		help = "Links: solid = own supplied line, dashed coral = cut, dashed gold = front, faint = other authored   •   %d owned / %d linked / %d cut off   •   click / arrows: select only" % [counts.owned, counts.linked, counts.cut]
	if markers.is_empty(): help = "No positioned public objectives received."
	if missing: help += " • %d without coordinates: use List" % missing
	draw_string(font, Vector2(10, size.y - 6), help, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 12, ink)
	if has_focus(): draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("f7d578"), false, 2)
