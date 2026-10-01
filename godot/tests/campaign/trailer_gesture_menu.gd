extends "res://tests/main_menu/live_attract.gd"
## Focused graphical spot check of the shared gesture in the actual live menu.
## The full menu lifecycle suite is owned/run by the menu integration lane.

func run() -> void:
	output = OS.get_environment("COCS_ATTRACT_EVIDENCE")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("COCS_ATTRACT_EVIDENCE required")
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	var settings := root.get_node("LocalSettings")
	settings.set_value("attract_demo_enabled", true, false)
	settings.set_value("reduced_motion", false, false)
	menu = Menu.instantiate()
	menu.preferences_path = "user://gesture_menu_%d.json" % OS.get_process_id()
	root.add_child(menu)
	current_scene = menu
	await wait_chapter(0)
	menu.attract_stage.advance_chapter()
	await wait_chapter(1)
	var stage = menu.attract_stage
	require(stage.clips[stage.chapter_index].id == "mara", "Actual Mara replay is in the menu viewport")
	require(stage.story_director.gestures.has("mara"), "Production shared gesture controller is active")
	await capture("gesture-menu-entry")
	var controller: RefCounted = stage.story_director.gestures.mara
	for frame: int in range(54): await process_frame
	require(stage.chapter_index == 1, "Spot check remains inside the Mara clip")
	require(stage.story_director.gestures.mara == controller and controller.age >= 2.35,
		"Menu snapshots retain one finite greeting through its settling time")
	var sample: Dictionary = controller.sample()
	var relaxed: Dictionary = preload("res://campaign/story_gesture.gd").rest()
	require((sample.armUpperR as Vector3).distance_to(relaxed.armUpperR) < 0.0001,
		"Menu greeting returns to the relaxed arm pose")
	await capture("gesture-menu-settled")
	require(menu.start.visible and menu.settings_button.visible and stage.active,
		"Functional menu remains foreground over live engine scene")
	menu.stop_attract()
	print("GESTURE_MENU_SPOT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
