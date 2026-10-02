extends Control
## Home route prepared for parent binding; no authority launch is involved.
signal back_requested
const Bridge = preload("res://replay/bridge.gd")
const Stage = preload("res://replay/stage.gd")
const Access = preload("res://ui/settings_access.gd")
var read_only_context := true
var bridge: Node
var stage: Node3D
var viewport := SubViewport.new()
var clips := ItemList.new()
var message := Label.new()
var clock_label := Label.new()
var play := Button.new()
var speed := OptionButton.new()
var seek := HSlider.new()
var file_dialog := FileDialog.new()
var controls := VBoxContainer.new()
var rows: Array = []
var opened := false
var paused := true
var waiting := false
var changing := false
var tick_age := 0.0
var suspended := false
var playback_generation := 0
var refresh_button: Button
var import_button: Button
var open_button: Button
var library_button: Button
var view_container: SubViewportContainer

func _ready() -> void:
	name = "ReplayLibrary"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	margin.add_child(controls)
	var header := HFlowContainer.new()
	controls.add_child(header)
	button(header, "Home", leave)
	library_button = button(header, "Library", close_clip)
	library_button.hide()
	refresh_button = button(header, "Refresh library", refresh)
	import_button = button(header, "Import source demo", func() -> void: pause_for_modal(); file_dialog.popup_centered_ratio(0.8))
	button(header, "Settings", func() -> void: pause_for_modal(); Access.open_panel(true))
	message.text = "LOCAL REPLAYS · Meridian combat · 10 min / 32 MiB per clip"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(message)
	clips.custom_minimum_size.y = 100
	clips.item_activated.connect(open_clip)
	controls.add_child(clips)
	open_button = button(controls, "Open selected replay", func() -> void:
		var selected := clips.get_selected_items()
		if not selected.is_empty(): open_clip(selected[0]))
	var container := SubViewportContainer.new()
	view_container = container
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size.y = 60
	controls.add_child(container)
	viewport.own_world_3d = true
	viewport.physics_object_picking = false
	container.add_child(viewport)
	var transport := HFlowContainer.new()
	controls.add_child(transport)
	play = button(transport, "Play", toggle_play)
	button(transport, "−5s", func() -> void: seek_to(seek.value - 5.0))
	button(transport, "+5s", func() -> void: seek_to(seek.value + 5.0))
	button(transport, "Subject", func() -> void:
		if is_instance_valid(stage): stage.cycle_subject())
	transport.add_child(speed)
	for rate: String in ["0.25×", "0.5×", "1×", "2×", "4×"]: speed.add_item(rate)
	speed.select(2)
	speed.tooltip_text = "Playback speed · cues play at 1× only"
	speed.item_selected.connect(func(index: int) -> void:
		if opened: invalidate_cues(); bridge.send({"op":"speed", "speed":[0.25, 0.5, 1.0, 2.0, 4.0][index], "_epoch":playback_generation}))
	seek.step = 0.01
	seek.tooltip_text = "Seek in seconds · seeking clears past cues"
	seek.value_changed.connect(func(value: float) -> void:
		if not changing: seek_to(value))
	controls.add_child(seek)
	controls.add_child(clock_label)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; Source demo JSON"])
	file_dialog.file_selected.connect(import_file)
	add_child(file_dialog)
	bridge = Bridge.new()
	bridge.reply.connect(received)
	bridge.failed.connect(error)
	add_child(bridge)
	refresh()

func button(parent: Node, title: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = title
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func refresh() -> void:
	bridge.send({"op":"list"})

func open_clip(index: int) -> void:
	if index < 0 or index >= rows.size(): return
	if rows[index].has("error"): error(rows[index].error); return
	opened = false
	paused = true
	invalidate_cues()
	clear_stage()
	bridge.send({"op":"open", "id":rows[index].id, "_epoch":playback_generation})
	message.text = "Opening validated source replay…"

func received(op: String, value: Dictionary) -> void:
	if op == "list":
		rows = value.clips
		clips.clear()
		for row: Dictionary in rows:
			clips.add_item("Invalid clip · " + str(row.error) if row.has("error") else "%s · %s · %.1fs · %d frames · %s · %s" % [row.map, row.mode, row.duration, row.frames, row.role, row.createdAt])
		if rows.is_empty(): message.text = "No clips yet. In Meridian combat: release mouse → Record replay → Save clip."
	elif op == "import":
		message.text = "Imported as a new clip · original file preserved"
		refresh()
	elif value.has("state"):
		waiting = false
		if int(value.get("_epoch", 0)) != playback_generation: return
		if op == "open":
			stage = Stage.new()
			viewport.add_child(stage)
			opened = true
			browser_visible(false)
		if not opened or not is_instance_valid(stage): return
		# Modal/focus transitions can race an already-in-flight tick. Never play its cues.
		if suspended:
			value.events = []
			value.clear = true
		if not stage.apply_sample(value): error(stage.map_error); opened = false; clear_stage(); browser_visible(true); return
		paused = bool(value.paused)
		play.text = "Play" if paused else "Pause"
		changing = true
		seek.max_value = maxf(0.01, float(value.duration))
		seek.value = float(value.time)
		changing = false
		clock_label.text = "%.2f / %.2f s · %s · %.2f× · READ ONLY" % [value.time, value.duration, str(value.phase).to_upper(), value.speed]
		message.text = "Source replay · %s · %s · no live seat" % [value.state.mapId, value.state.config.mode]

func toggle_play() -> void:
	if not opened: return
	invalidate_cues()
	bridge.send({"op":"play" if paused else "pause", "_epoch":playback_generation})

func seek_to(value: float) -> void:
	if not opened: return
	invalidate_cues()
	bridge.send({"op":"seek", "time":value, "_epoch":playback_generation})

func pause_for_modal() -> void:
	invalidate_cues()
	if opened: bridge.send({"op":"pause", "_epoch":playback_generation})
	paused = true

func _process(delta: float) -> void:
	var blocked := Access.overlay_open() or file_dialog.visible or not get_window().has_focus()
	if blocked and not suspended: pause_for_modal()
	suspended = blocked
	play.disabled = not opened or blocked
	seek.editable = opened and not blocked
	speed.disabled = not opened or blocked
	if blocked or paused or not opened:
		tick_age = 0.0
		return
	tick_age += delta
	if waiting or tick_age < 1.0 / 30.0: return
	# A stalled UI consumes no large event window. Long stalls pause instead.
	if tick_age > 0.25: pause_for_modal(); tick_age = 0.0; return
	waiting = bridge.send({"op":"tick", "dt":tick_age, "_epoch":playback_generation})
	tick_age = 0.0

func import_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: error("Could not read selected replay"); return
	if file.get_length() > 32 * 1024 * 1024: error("Replay exceeds 32 MiB"); return
	# FileDialog grants only data reading. Paths from the clip are never loaded.
	var text := file.get_as_text()
	file.close()
	if text.to_utf8_buffer().size() > 4 * 1024 * 1024:
		error("Native import currently supports JSON up to 4 MiB; recording supports larger clips.")
		return
	bridge.send({"op":"import", "text":text})

func error(text: String) -> void:
	waiting = false
	paused = true
	message.text = "Replay error: " + text
	clear_cues()

func clear_cues() -> void:
	if is_instance_valid(stage): stage.clear_cues()

func invalidate_cues() -> void:
	playback_generation += 1
	clear_cues()

func clear_stage() -> void:
	clear_cues()
	if is_instance_valid(stage): stage.free()
	stage = null

func browser_visible(value: bool) -> void:
	clips.visible = value
	open_button.visible = value
	refresh_button.visible = value
	import_button.visible = value
	library_button.visible = not value

func close_clip() -> void:
	opened = false
	paused = true
	invalidate_cues()
	clear_stage()
	bridge.send({"op":"close"})
	browser_visible(true)
	refresh()

func leave() -> void:
	opened = false
	clear_stage()
	if back_requested.get_connections().is_empty(): get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	else: back_requested.emit()

func _exit_tree() -> void:
	clear_stage()
