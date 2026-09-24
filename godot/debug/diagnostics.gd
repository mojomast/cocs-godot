extends CanvasLayer
## Read-only, mode-independent diagnostics selected in the main menu. The
## existing F10 combat metrics and local-authority F3 cheats remain separate.
var panel: PanelContainer
var readout: Label
var elapsed := 0.0

func _ready() -> void:
	if not "--diagnostics" in OS.get_cmdline_user_args():
		set_process(false)
		set_process_input(false)
		return
	layer = 90
	panel = PanelContainer.new()
	panel.name = "DiagnosticsOverlay"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -330
	panel.offset_top = 16
	panel.offset_right = -16
	panel.offset_bottom = 165
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.035, 0.05, 0.84)
	background.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	readout = Label.new()
	readout.name = "DiagnosticsReadout"
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_font_size_override("font_size", 15)
	readout.add_theme_color_override("font_color", Color("d7e9ef"))
	panel.add_child(readout)
	refresh()

func _input(event: InputEvent) -> void:
	if panel == null: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if panel == null or not panel.visible: return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0.0
	refresh()

func refresh() -> void:
	if readout == null: return
	var scene: Node = get_tree().current_scene
	var mode := "scene pending"
	var phase := ""
	var actors := "—"
	var bots := "—"
	if is_instance_valid(scene):
		mode = scene.name
		if "selected_mode" in scene: mode = str(scene.selected_mode)
		elif "mode" in scene: mode = str(scene.mode)
		if "phase" in scene: phase = str(scene.phase)
		if "presentation" in scene and is_instance_valid(scene.presentation):
			actors = str(scene.presentation.actors.size())
		if "bot_count" in scene: bots = str(scene.bot_count)
		elif "selected_bot_count" in scene: bots = str(scene.selected_bot_count)
	var bounds := get_viewport().get_visible_rect().size
	var fps := Engine.get_frames_per_second()
	readout.text = "DIAGNOSTICS · F11 hide\n%s · phase %s\nFPS %d · frame %.1f ms\nViewport %d × %d · %s\nActors %s · Bots %s" % [mode, phase, fps, 1000.0 / maxf(1.0, fps), int(bounds.x), int(bounds.y), OS.get_name(), actors, bots]
