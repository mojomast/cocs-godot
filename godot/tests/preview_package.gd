extends SceneTree
## External extracted-package launch probe, not an ordinary-input/full-match gate.
var output := ""
var case_name := "fighting"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-output="): output = arg.trim_prefix("--preview-output=")
		if arg.begins_with("--preview-case="): case_name = arg.trim_prefix("--preview-case=")
	call_deferred("inspect")

func fail(message: String) -> void:
	push_error("PREVIEW_PACKAGE_FAILED " + message)
	quit(2)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(name + ".png")) != OK:
		fail("capture " + name)

func inspect() -> void:
	if output.is_empty(): fail("output required"); return
	if case_name == "vehicle":
		await vehicle()
		return
	var home = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	for i in 5: await process_frame
	await capture("home")
	var button = home.find_child("Fighting", true, false)
	if not button is Button: fail("Home Fighting button"); return
	button.pressed.emit()
	for i in 3: await process_frame
	var product = current_scene
	if product == null or product.scene_file_path != "res://fighting/main.tscn": fail("route"); return
	for mode in ["ai", "local", "training"]:
		product.mode = mode
		product.operators = ["meta", "mistral"]
		product.start_match()
		if not product.active or not product.error_text.is_empty(): fail("start " + mode); return
		var tick := int(product.state.get("tick", -1))
		for i in 65: await physics_frame
		if int(product.state.get("tick", -1)) <= tick: fail("tick " + mode); return
		await capture("fighting-" + mode)
		print("PREVIEW_FIGHTING_OK mode=", mode, " tick=", product.state.tick)
	product.go_home()
	for i in 3: await process_frame
	if current_scene.scene_file_path != "res://ui/main_menu.tscn": fail("return"); return
	print("PREVIEW_PACKAGE_GUI_OK home ai local training return")
	quit(0)

func vehicle() -> void:
	var product = load("res://combined_arms/demo.tscn").instantiate()
	root.add_child(product)
	current_scene = product
	for i in 1800:
		await process_frame
		if product.phase == "error": fail("vehicle " + product.error); return
		if product.phase == "active" and product.fleet.get_child_count() > 0:
			for j in 30: await process_frame
			await capture("vehicle-startup")
			print("PREVIEW_PACKAGE_VEHICLE_OK phase=", product.phase, " fleet=", product.fleet.get_child_count())
			product.net.disconnect_server()
			product.clear_round()
			quit(0)
			return
	fail("vehicle startup timeout")
