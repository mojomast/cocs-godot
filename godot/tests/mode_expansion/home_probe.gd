extends RefCounted
## Direct-scene acceptance probe survives the departing scene; no gameplay writes.
static func observe(tree: SceneTree, path: String, map_id: String, mode: String) -> void:
	await tree.process_frame
	await tree.process_frame
	var menu := tree.current_scene
	assert(menu != null and menu.scene_file_path == "res://ui/main_menu.tscn")
	menu.select_category("modes")
	menu.select_route("mode-expansion")
	for key: String in ["map", "mode"]:
		var picker: Variant = menu.choice_rows[key]
		var target := map_id if key == "map" else mode
		for index: int in picker.item_count:
			if str(picker.get_item_metadata(index)) == target:
				picker.select(index)
				picker.item_selected.emit(index)
				break
	assert(menu.current_route.id == "mode-expansion")
	assert(menu.registry.validate_route(menu.current_route, menu.selections).is_empty())
	var args: PackedStringArray = menu.registry.assemble_args(menu.current_route, menu.selections)
	assert("--experience=mode-expansion" in args)
	assert("--map=" + map_id in args and "--mode=" + mode in args)
	menu.start.grab_focus()
	await tree.process_frame
	menu.content_scroll.ensure_control_visible(menu.start)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	assert(tree.root.get_texture().get_image().save_png(path) == OK)
	print("MODE_NATIVE_HOME ", JSON.stringify({"scene":menu.scene_file_path,"route":menu.current_route.id,"args":args,"pointerReleased":Input.mouse_mode == Input.MOUSE_MODE_VISIBLE}))
