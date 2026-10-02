extends SceneTree
## External final PCK probe. Loads real product scenes; never substitutes a core.
var failed := false

func reject(message: String) -> void:
	failed = true
	push_error("PACKAGE_FINAL_FAILED " + message)
	quit(2)

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var inventory_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-list="): inventory_path = arg.trim_prefix("--final-list=")
	var inventory: Variant = JSON.parse_string(FileAccess.get_file_as_string(inventory_path))
	if not inventory is Dictionary:
		reject("missing inventory"); return
	for path: String in inventory.resources:
		var uri := "res://" + path.trim_prefix("godot/")
		if path.ends_with(".json") or inventory.raw.has(path):
			if not FileAccess.file_exists(uri) or FileAccess.get_sha256(uri) != inventory.resources[path]:
				reject("raw/json hash " + uri); return
		if not path.ends_with(".json") and not path.ends_with(".wav"):
			if not ResourceLoader.exists(uri) or load(uri) == null:
				reject("imported resource " + uri); return
	var roster: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	if not roster is Dictionary or roster.get("operators", []).size() != 9:
		reject("nine operator roster"); return
	for entry: Dictionary in roster.operators:
		var visual = load("res://fighting/visuals/fighter_visual.gd").new()
		root.add_child(visual)
		if not visual.configure(str(entry.id)) or not visual.finish_report.get("installed", false):
			reject("fighter/finish " + str(entry.id)); visual.queue_free(); return
		visual.queue_free()
		await process_frame
	var home = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	var button = home.find_child("Fighting", true, false)
	if not button is Button:
		reject("Home Fighting button"); return
	button.pressed.emit()
	await process_frame
	await process_frame
	var product = current_scene
	if product == null or product.scene_file_path != "res://fighting/main.tscn":
		reject("Home route did not enter production Fighting"); return
	product.mode = "training"
	product.operators = ["meta", "mistral"]
	product.start_match()
	if not product.active or not product.error_text.is_empty():
		reject("production start " + str(product.error_text)); return
	var start_tick := int(product.state.get("tick", -1))
	for index: int in 65: await physics_frame
	if not product.active or int(product.state.get("tick", -1)) <= start_tick:
		reject("production snapshot did not advance"); return
	product.show_pause()
	product.resume_match()
	product.go_home()
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://ui/main_menu.tscn":
		reject("Fighting Home teardown"); return
	print("PACKAGE_FINAL_OK operators=9 home_fighting=true training=true raw_resources=", inventory.raw.size())
	quit(0)
