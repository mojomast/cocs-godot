extends "res://tests/main_menu/live_attract.gd"
## Injects an external candidate into the real presentation stage, never production data.
var capture_trace: Array = []

func capture(label: String) -> PackedByteArray:
	var bytes: PackedByteArray = await super.capture(label)
	capture_trace.append({"label":label,"wallUsec":Time.get_ticks_usec(),
		"chapter":menu.attract_stage.chapter_index,"sourceReplayTime":menu.attract_stage.chapter_time})
	return bytes

func run() -> void:
	output = OS.get_environment("COCS_ATTRACT_EVIDENCE")
	var candidate := OS.get_environment("COCS_ATTRACT_CANDIDATE")
	if output.is_empty() or candidate.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Provide external COCS_ATTRACT_EVIDENCE and COCS_ATTRACT_CANDIDATE")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(candidate))
	root.size = Vector2i(1280, 800)
	var settings := root.get_node("LocalSettings")
	settings.set_value("attract_demo_enabled", true, false)
	settings.set_value("reduced_motion", false, false)
	menu = Menu.instantiate()
	menu.preferences_path = "user://cinematic_v3_%d.json" % OS.get_process_id()
	root.add_child(menu)
	current_scene = menu
	var stage: Node = menu.attract_stage
	var installed := OS.get_environment("COCS_ATTRACT_INSTALLED") == "1"
	require(data.version == 1 and data.fps == 12, "existing public replay format")
	if installed:
		require(stage.clips == data.clips and stage.active, "real Home loads installed source clips without injection")
	else:
		stage.stop()
		stage.clear_chapter()
		stage.clips.clear()
		for clip: Dictionary in data.clips:
			require(stage._valid_clip(clip), "candidate validates: " + str(clip.id))
			stage.clips.append(clip)
		stage.replay_checked = true
		stage.chapter_index = -1
		stage.start()
	var maps := {}
	for index: int in stage.clips.size():
		if index > 0: stage.advance_chapter()
		await wait_chapter(index)
		var clip: Dictionary = stage.clips[index]
		maps[clip.map] = true
		require(stage.viewport.get_child_count() == 1 and stage.viewport.own_world_3d and root.get_camera_3d() == null, "one isolated presentation world")
		require(stage.terrain_triangles > 0 and stage.terrain_triangles <= stage.MAX_TRIANGLES, "bounded production terrain")
		var first: PackedByteArray = await capture("%02d-%s-a" % [index, clip.id])
		await create_timer(0.5).timeout
		var second: PackedByteArray = await capture("%02d-%s-b" % [index, clip.id])
		require(first != second, "live viewport motion: " + str(clip.id))
		if clip.kind == "pet":
			stage.chapter_time = 1.2
			await process_frame
			require(int(stage.story_director.last_serial.get("patch", 0)) > 0, "recorded Patch input reaches native pose")
		if clip.kind == "combat":
			require(stage.actors.size() >= 2, "recorded robots present")
			var found := false
			for i: int in clip.frames.size():
				for event: Dictionary in clip.frames[i].events:
					if not found and event.get("type") == "shot" and event.get("from") is Dictionary:
						stage.chapter_time = float(clip.frames[i].t) + 0.01
						await process_frame
						var from: Dictionary = event.from
						require(stage.flash.visible and stage.flash_origin.distance_to(Vector3(from.x,from.y,from.z)) < 0.02, "flash uses recorded public event origin")
						found = true
			require(found, "combat contains actual source shot")
	require(maps.size() == 4, "all four chapter identities represented")
	stage.advance_chapter()
	await wait_chapter(0)
	require(stage.viewport.get_child_count() == 1, "full loop frees prior world")
	menu.category_buttons["modes"].emit_signal("pressed")
	menu.settings_button.grab_focus()
	await process_frame
	require(root.gui_get_focus_owner() == menu.settings_button and menu.current_category == "modes", "foreground routes/focus remain usable")
	settings.open_panel(true, menu.settings_button)
	await process_frame
	require(not stage.active and stage.world.process_mode == Node.PROCESS_MODE_DISABLED, "Settings pauses all animators")
	settings.close_panel()
	await process_frame
	require(stage.active, "Settings resumes")
	settings.set_value("reduced_motion", true, false)
	require(not stage.active, "reduced motion stops rendering")
	settings.set_value("reduced_motion", false, false)
	settings.set_value("attract_demo_enabled", false, false)
	require(not stage.active, "animation preference stops rendering")
	settings.set_value("attract_demo_enabled", true, false)
	menu._notification(menu.NOTIFICATION_APPLICATION_FOCUS_OUT)
	require(not stage.active, "focus loss pauses")
	menu._notification(menu.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frame
	root.size = Vector2i(760, 520)
	settings.set_value("ui_scale", 150, false)
	await capture("compact-ui150")
	menu.stop_attract()
	require(not stage.active and stage.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Home route departure stops viewport")
	var weak_stage: WeakRef = weakref(stage)
	menu.queue_free()
	await process_frame
	await process_frame
	require(weak_stage.get_ref() == null, "scene exit frees stage and resources")
	var report := FileAccess.open(output.path_join("native-result.json"), FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify({"status":"passed" if failures == 0 else "failed", "executed":true,
		"checks":checks, "failures":failures, "installed":installed,
		"captureToken":OS.get_environment("COCS_CAPTURE_TOKEN"),
		"candidateSHA256":FileAccess.get_sha256(candidate),"captures":capture_trace,
		"installedSHA256":FileAccess.get_sha256("res://ui/attract/demo.json")}))
	report.close()
	print("CINEMATIC_V3_ATTRACT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
