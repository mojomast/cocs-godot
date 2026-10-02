extends Node
const Model = preload("res://input_bindings/model.gd")
signal changed
var values: Dictionary = Model.DEFAULTS.duplicate()
var extras: Dictionary = {}
var path := "user://input_bindings.json"
var revision := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	var configured := OS.get_environment("COCS_BINDINGS_PATH")
	if configured.is_absolute_path(): path = configured
	load_at(path)

func load_at(file_path: String) -> void:
	path = file_path
	var next := Model.DEFAULTS.duplicate()
	extras = {}
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() <= 16384:
			var raw: Variant = JSON.parse_string(file.get_as_text())
			if raw is Dictionary and raw.get("version", 1) == 1:
				extras = raw.duplicate(true)
				next = Model.normalize(raw.get("bindings", {}))
	apply_bindings(next)

func apply_bindings(next: Dictionary) -> void:
	# Neutralize before changing resolution. Existing release methods own their
	# network boundary and spectator checks; this service never sends packets.
	var settings := get_tree().root.get_node_or_null("LocalSettings") if is_inside_tree() else null
	if settings != null: settings.release_controls()
	values = Model.normalize(next)
	revision += 1
	changed.emit()

func set_binding(action: String, code: String) -> bool:
	if not Model.LABELS.has(action): return false
	if not Model.editable_options().has(code) and values[action] != code: return false
	apply_bindings(Model.rebind(values, action, code))
	return save()

func reset_defaults() -> bool:
	var next := values.duplicate(true)
	for action: String in Model.DEFAULTS: next[action] = Model.DEFAULTS[action]
	apply_bindings(next)
	return save()

func save() -> bool:
	var document := extras.duplicate(true)
	document.version = 1
	document.bindings = values
	var text := JSON.stringify(document)
	if text.to_utf8_buffer().size() > 16384: return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK: return false
	var temp := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if ok: ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) == OK
	if not ok: DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	return ok
