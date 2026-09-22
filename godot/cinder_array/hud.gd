extends CanvasLayer
## Restrained screen-space field notebook. All controls pass pointer input through.

var location_label: Label
var elevation_label: Label
var engage_label: Label
var route_widget: Control

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := PanelContainer.new()
	header.position = Vector2(24, 22)
	header.size = Vector2(300, 94)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", _panel())
	root.add_child(header)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	header.add_child(stack)
	var title := _label("C I N D E R   /   A R R A Y", 20, Color("f2e4d1"))
	stack.add_child(title)
	location_label = _label("01   /   TRANSFER DECK", 13, Color("e7ad76"))
	stack.add_child(location_label)
	elevation_label = _label("CALDERA FIELD STATION    •    +07 M", 11, Color("b4bcc8"))
	stack.add_child(elevation_label)
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(24, -71)
	footer.add_theme_constant_override("separation", 6)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)
	engage_label = _label("CLICK TO EXPLORE", 12, Color("f0be86"))
	footer.add_child(engage_label)
	footer.add_child(_label("WASD  MOVE     MOUSE  LOOK     SHIFT  SPRINT     SPACE  JUMP     ESC  RELEASE     R  RESET", 11, Color("d0d4dc")))
	var stamp := _label("NATIVE EXPLORATION\n06 STATIONS / ONE CIRCUIT", 11, Color("c2b7b4"))
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stamp.position = Vector2(-235, 29)
	stamp.size = Vector2(210, 42)
	root.add_child(stamp)
	var crosshair := _label("·", 22, Color(0.92, 0.92, 0.88, 0.75))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-4, -16)
	root.add_child(crosshair)

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.071, 0.095, 0.78)
	style.border_color = Color("cb7a46")
	style.border_width_left = 2
	style.content_margin_left = 16
	style.content_margin_right = 18
	style.content_margin_top = 11
	style.content_margin_bottom = 12
	return style

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.035, 0.05, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func update_location(zone: Dictionary, elevation: float) -> void:
	if location_label == null: return
	location_label.text = "%s   /   %s" % [zone.code, zone.name]
	elevation_label.text = "CALDERA FIELD STATION    •    +%02d M" % roundi(elevation)

func _process(_delta: float) -> void:
	if engage_label != null:
		engage_label.text = "EXPLORING  /  ESC TO RELEASE" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "CLICK TO EXPLORE"
