extends SceneTree
## Execute only after the combined engine grant. No authority is constructed.
const Menu = preload("res://ui/main_menu.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var menu := Menu.new()
	menu.attract_test_scene = true
	menu.preferences_path = "user://finish-home-preferences.json"
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var old_menu: WeakRef = weakref(menu)
	var old_attract: WeakRef = weakref(menu.attract_stage)
	check(menu.replays_button.is_inside_tree(), "Home exposes Replay entry")
	menu.replays_button.pressed.emit()
	await process_frame
	await process_frame
	var library := current_scene
	check(is_instance_valid(library) and library.scene_file_path == "res://replay/library.tscn", "production Home route opens library")
	check(old_menu.get_ref() == null and old_attract.get_ref() == null, "Home and attract freed")
	check(library.get("read_only_context") == true and not "client" in library and not "net" in library, "library has no authority peer")
	var helper_pid: int = library.bridge.process_id
	library.leave()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://ui/main_menu.tscn", "library Home restores production menu")
	# Godot's PID tracker reports ECHILD when queried again after kill reaped it.
	check(helper_pid <= 0 or not DirAccess.dir_exists_absolute("/proc/%d" % helper_pid), "replay helper released on Home (Linux /proc)")
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("FINISH_HOME_REPLAYS ", checks, " checks / ", failures, " failures")
	quit(1 if failures else 0)
