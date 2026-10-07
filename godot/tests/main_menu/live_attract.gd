extends SceneTree
## Visible production replay acceptance; run with xvfb and COCS_ATTRACT_EVIDENCE.
const Menu = preload("res://ui/main_menu.tscn")
var checks := 0
var failures := 0
var output := ""
var menu: Control

func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print(("PASS " if ok else "FAIL ") + message)

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> PackedByteArray:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var stage_image: Image = menu.attract_stage.viewport.get_texture().get_image()
	require(stage_image.save_png(output.path_join(label + "-stage.png")) == OK, "saved 3D stage " + label)
	require(image.get_width() >= 760 and image.get_height() >= 520, "visible image " + label)
	require(image.save_png(output.path_join(label + ".png")) == OK, "saved screenshot " + label)
	return image.get_data()

func wait_chapter(index: int) -> void:
	for _attempt: int in range(420):
		await process_frame
		if menu.attract_stage.scene_ready and menu.attract_stage.chapter_index == index: return
	require(false, "chapter %d loaded within bounded frames" % index)

func run() -> void:
	output = OS.get_environment("COCS_ATTRACT_EVIDENCE")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("COCS_ATTRACT_EVIDENCE must point to a writable absolute directory")
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	var settings := root.get_node_or_null("LocalSettings")
	if settings != null:
		settings.set_value("attract_demo_enabled", true, false)
		settings.set_value("reduced_motion", false, false)
	menu = Menu.instantiate()
	menu.preferences_path = "user://live_attract_%d.json" % OS.get_process_id()
	root.add_child(menu)
	current_scene = menu
	var stage = menu.attract_stage
	# Data-driven: every clip the authored replay ships must load, whatever the set.
	var replay: Dictionary = {}
	var replay_file := FileAccess.open("res://ui/attract/demo.json", FileAccess.READ)
	if replay_file != null:
		var parsed: Variant = JSON.parse_string(replay_file.get_as_text())
		replay_file.close()
		if parsed is Dictionary: replay = parsed
	var authored_clips: Array = replay.get("clips", [])
	require(authored_clips.size() > 0 and stage.clips.size() == authored_clips.size() and stage.active,
		"loaded every authored replay clip; menu starts immediately")
	require(menu.get_child(menu.attract_background.get_index() + 1).name == "Shell" and menu.start.visible and menu.settings_button.visible,
		"3D viewport stays behind foreground actions")
	for index: int in range(stage.clips.size()):
		if index > 0: stage.advance_chapter()
		await wait_chapter(index)
		require(stage.terrain_triangles > 0 and stage.terrain_triangles <= stage.MAX_TRIANGLES,
			"chapter %d loads bounded real campaign triangles" % index)
		var environments := 0
		for child: Node in stage.world.get_children():
			if child is WorldEnvironment: environments += 1
			if child.name == "CampaignEnvironment":
				for grandchild: Node in child.get_children():
					if grandchild is WorldEnvironment: environments += 1
		require(environments == 1 and stage.viewport.own_world_3d and root.get_camera_3d() == null,
			"chapter %d has one private daylight environment and no root camera" % index)
		require(stage.story_director != null and stage.story_director.actors.size() >= 1,
			"chapter %d instantiates production story cast" % index)
		var first: PackedByteArray = await capture("%02d-%s-a" % [index, stage.clips[index].id])
		await create_timer(0.65).timeout
		var second: PackedByteArray = await capture("%02d-%s-b" % [index, stage.clips[index].id])
		require(first != second, "chapter %d has live in-engine camera/model animation" % index)
		if stage.clips[index].kind == "pet":
			var before: int = stage.story_director.last_serial.get("patch", 0)
			stage.chapter_time = 4.8
			await process_frame
			require(int(stage.story_director.last_serial.get("patch", 0)) > before,
				"recorded Patch pet reaction serial reaches production story director")
		if stage.clips[index].kind == "combat":
			require(stage.actors.size() >= 2 and stage.flash != null,
				"combat replay creates production actor and robot visuals plus bounded event effect")
			var shot_index := -1
			var shot: Dictionary = {}
			for frame_i: int in stage.clips[index].frames.size():
				for event: Dictionary in stage.clips[index].frames[frame_i].events:
					if event.get("type") == "shot" and event.get("from") is Dictionary:
						shot_index = frame_i
						shot = event
						break
				if shot_index >= 0: break
			require(shot_index >= 0, "production replay contains a recorded projectile origin")
			if shot_index >= 0:
				stage.chapter_time = float(stage.clips[index].frames[shot_index].t) + 0.01
				await process_frame
				var from: Dictionary = shot.from
				require(stage.flash.visible and stage.flash_origin.distance_to(Vector3(from.x, from.y, from.z)) < 0.02,
					"combat flash follows exact authority shot origin rather than a guessed player muzzle")
	stage.advance_chapter()
	await wait_chapter(0)
	require(stage.viewport.get_child_count() == 1 and stage.chapter_index == 0,
		"loop frees old chapter and retains one world")
	var categories_before: int = menu.category_buttons.size()
	menu.category_buttons["modes"].emit_signal("pressed")
	menu.settings_button.grab_focus()
	await process_frame
	require(menu.current_category == "modes" and menu.category_buttons.size() == categories_before
		and root.gui_get_focus_owner() == menu.settings_button,
		"route click and keyboard focus work over the moving replay")
	if settings != null:
		settings.open_panel(true, menu.settings_button)
		await process_frame
		require(not stage.active and stage.world.process_mode == Node.PROCESS_MODE_DISABLED,
			"Settings overlay pauses viewport and every descendant animator")
		settings.close_panel()
		await process_frame
		require(stage.active and stage.world.process_mode == Node.PROCESS_MODE_INHERIT,
			"Settings close resumes same private world")
		settings.set_value("reduced_motion", true, false)
		require(not stage.active, "reduced motion disables live replay")
		settings.set_value("reduced_motion", false, false)
		settings.set_value("attract_demo_enabled", false, false)
		require(not stage.active and menu.get_node("AttractBase").visible,
			"animation switch leaves opaque dark background")
		settings.set_value("attract_demo_enabled", true, false)
		require(stage.active, "animation switch resumes without a second world")
	menu._notification(menu.NOTIFICATION_APPLICATION_FOCUS_OUT)
	require(not stage.active, "focus loss pauses replay")
	menu._notification(menu.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frame
	await process_frame
	require(stage.active, "focus regain resumes replay")
	menu.stop_attract()
	require(not stage.active and stage.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"menu exit disables viewport rendering")
	print("LIVE_ATTRACT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
