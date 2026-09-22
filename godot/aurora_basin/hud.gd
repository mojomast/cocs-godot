extends Control
## Small native overlay. All geometry/resources are built outside frame updates.
var map: Node3D
var walker: Node3D
var _refresh := 0.0
var _font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	_refresh += delta
	if _refresh >= 0.15:
		_refresh = 0
		queue_redraw()

func _draw() -> void:
	if _font == null or not is_instance_valid(walker): return
	var ink := Color("d9eaf0")
	var dim := Color("96b9c9")
	var gold := Color("e8bd80")
	var panel := Color(0.018, 0.040, 0.065, 0.78)
	draw_style_box(_panel(panel), Rect2(20, 20, 322, 99))
	draw_line(Vector2(20, 20), Vector2(342, 20), Color("689eaa"), 1.0)
	draw_string(_font, Vector2(35, 42), "FIELD STATION  /  NATIVE EXPLORATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
	draw_string(_font, Vector2(34, 77), "Aurora Basin", HORIZONTAL_ALIGNMENT_LEFT, -1, 29, ink)
	draw_string(_font, Vector2(35, 101), "74° N     ·     POLAR NIGHT     ·     −28°C", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gold)
	var region: String = map.area_at(walker.position)
	draw_string(_font, Vector2(size.x - 354, 40), region, HORIZONTAL_ALIGNMENT_RIGHT, 327, 12, ink)
	draw_line(Vector2(size.x - 166, 52), Vector2(size.x - 27, 52), Color("6a9da8"), 1.0)
	draw_style_box(_panel(panel), Rect2(20, size.y - 83, minf(size.x - 220, 715), 63))
	draw_string(_font, Vector2(34, size.y - 57), "FOLLOW THE AMBER MARKERS    /    LAKE CIRCUIT → CROWN VISTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gold)
	var controls := "WASD  Move   ·   Mouse  Look   ·   Shift  Sprint   ·   Space  Jump   ·   R  Reset   ·   Esc  Cursor"
	draw_string(_font, Vector2(34, size.y - 35), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
	# A compact, geographically faithful route diagram (north at top).
	var center := Vector2(size.x - 102, size.y - 104)
	draw_circle(center, 77, panel)
	draw_arc(center, 75, 0, TAU, 72, Color("41606f"), 1.0, true)
	draw_circle(center, 33, Color(0.13, 0.27, 0.34, 0.65))
	var circuit := PackedVector2Array()
	for p in map.route_points: circuit.append(center + Vector2(p.x, p.z) * 1.24)
	draw_polyline(circuit, Color("a8ced2"), 1.7, true)
	var high := PackedVector2Array()
	for p in map.skywalk_points: high.append(center + Vector2(p.x, p.z) * 1.24)
	draw_polyline(high, gold, 2.0, true)
	draw_circle(center + Vector2(-23, 29) * 1.24, 8.0, Color("7599a8"))
	draw_string(_font, center + Vector2(-4, -57), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dim)
	var player := center + Vector2(walker.position.x, walker.position.z) * 1.24
	var forward := Vector2(-sin(walker.rotation.y), -cos(walker.rotation.y))
	var side := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([player + forward * 5, player - forward * 3 + side * 3, player - forward * 3 - side * 3]), Color("ecf9f7"))
	draw_circle(size * 0.5, 1.5, Color(0.82, 0.94, 0.98, 0.5))

var _panel_style: StyleBoxFlat
func _panel(color: Color) -> StyleBoxFlat:
	if _panel_style == null:
		_panel_style = StyleBoxFlat.new()
		_panel_style.bg_color = color
		_panel_style.corner_radius_top_left = 3
		_panel_style.corner_radius_top_right = 3
		_panel_style.corner_radius_bottom_left = 3
		_panel_style.corner_radius_bottom_right = 3
	return _panel_style
