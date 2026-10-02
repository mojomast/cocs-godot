extends SceneTree
## External additive probe: shipped PCK resources only, no scene substitutes.
func _initialize() -> void:
	var list_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--feature-list="): list_path = arg.trim_prefix("--feature-list=")
	var files: Variant = JSON.parse_string(FileAccess.get_file_as_string(list_path))
	if not files is Dictionary:
		push_error("PACKAGE_FEATURE_LIST_INVALID"); quit(2); return
	for path: String in files:
		var resource := "res://" + path.trim_prefix("godot/")
		if path.ends_with(".json"):
			if not FileAccess.file_exists(resource) or FileAccess.get_sha256(resource) != files[path]:
				push_error("PACKAGE_FEATURE_JSON_MISSING_OR_CHANGED " + resource); quit(2); return
			if JSON.parse_string(FileAccess.get_file_as_string(resource)) == null:
				push_error("PACKAGE_FEATURE_JSON_INVALID " + resource); quit(2); return
		elif not ResourceLoader.exists(resource) or load(resource) == null:
			push_error("PACKAGE_FEATURE_RESOURCE_MISSING " + resource); quit(2); return
	if files.has("godot/input_bindings/contexts.json"):
		if str(ProjectSettings.get_setting("autoload/InputBindings", "")) != "*res://input_bindings/service.gd":
			push_error("PACKAGE_INPUT_BINDINGS_AUTOLOAD_MISSING"); quit(2); return
	print("PACKAGE_FEATURE_RESOURCES_OK ", files.size())
	quit(0)
