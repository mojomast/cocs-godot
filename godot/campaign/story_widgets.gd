extends Control
## Low-center, non-interactive story overlay below the mission HUD's comms.
const Settings = preload("res://ui/settings_access.gd")
var caption := Label.new()
var prompt := Label.new()
var story: Dictionary = {}
var interludes: Dictionary = {}
var allowed := false
var session: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	for item: Label in [caption, prompt]:
		add_child(item)
		item.mouse_filter = MOUSE_FILTER_IGNORE
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_theme_color_override("font_color", Color("fff1d4"))
		item.add_theme_color_override("font_shadow_color", Color.BLACK)
		item.add_theme_constant_override("shadow_offset_x", 2)
		item.add_theme_constant_override("shadow_offset_y", 2)
	get_viewport().size_changed.connect(layout)
	layout()

func observe(value: Dictionary, can_show: bool, activities: Dictionary = {}) -> void:
	story = value
	interludes = activities
	allowed = can_show
	refresh()

func refresh() -> void:
	var show_: bool = allowed and not Settings.overlay_open()
	if is_instance_valid(session):
		show_ = show_ and session.get("application_focused") and session.get("phase") == 3 and not session.get("action_pending") and str(session.get("startup_error")).is_empty() and session.get("campaign").playing()
	var line: Variant = story.get("caption")
	if interludes.get("feedback") is Dictionary: line = interludes.feedback
	caption.text = "%s: %s" % [line.get("speaker", ""), line.get("text", "")] if line is Dictionary else ""
	caption.visible = show_ and not caption.text.is_empty()
	var pet: Variant = story.get("prompt")
	# The authority chooses eligibility. The player's actual Interact binding is
	# owned by shared controls (currently E), not by this decorative overlay.
	prompt.text = "[E] Pet Patch" if pet is Dictionary and pet.get("action") == "pet" else ""
	if prompt.text.is_empty() and interludes.get("prompt") is Dictionary: prompt.text = str(interludes.prompt.text)
	prompt.visible = show_ and not prompt.text.is_empty() and (not is_instance_valid(session) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	layout()

func _process(_dt: float) -> void:
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		caption.hide()
		prompt.hide()

func layout() -> void:
	var view := get_viewport_rect().size
	var width := minf(500, view.x - 32)
	var compact := view.y < 540 or view.x < 800
	caption.add_theme_font_size_override("font_size", 13 if compact else 17)
	prompt.add_theme_font_size_override("font_size", 14 if compact else 19)
	caption.position = Vector2((view.x - width) * 0.5, minf(view.y * (0.60 if compact else 0.69), view.y - 155))
	caption.size = Vector2(width, 38 if compact else 52)
	prompt.position = caption.position - Vector2(0, 32)
	prompt.size = Vector2(width, 26)
