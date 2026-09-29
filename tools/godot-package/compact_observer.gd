extends SceneTree
## External read-only observer; no gameplay driving or synthetic snapshots.
var product: Node
var snapshots := 0
var latest: Dictionary = {}
var first_time := -1.0
var capturing := false
var elapsed := 0.0

func _initialize() -> void:
	call_deferred("observe")

func observe() -> void:
	product = load(OS.get_environment("COMPACT_SCENE")).instantiate()
	root.add_child(product)
	current_scene = product
	product.client.snapshot.connect(func(frame: Dictionary) -> void:
		if product.phase == 3 and product.received_pose:
			snapshots += 1
			latest = frame.duplicate(true)
			if first_time < 0: first_time = float(frame.state.time))
	product.client.connection_error.connect(func(message: String) -> void:
		push_error(message)
		quit(1))

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 110:
		print("COMPACT_DIAGNOSTIC ", JSON.stringify({"phase":product.phase,"pose":product.received_pose,"snapshots":snapshots,"size":str(root.get_visible_rect().size),"label":product.label.text}))
		push_error("COMPACT_TIMEOUT")
		quit(1)
	if not is_instance_valid(product) or capturing or snapshots < 3: return false
	if product.phase != 3 or not product.received_pose or product.snapshot_watch.stale(): return false
	if float(latest.state.time) <= first_time: return false
	var wanted := Vector2i(int(OS.get_environment("COMPACT_WIDTH")), int(OS.get_environment("COMPACT_HEIGHT")))
	if root.size != wanted: return false
	capturing = true
	call_deferred("capture")
	return false

func label_proof(label: Label) -> Dictionary:
	var rect := label.get_global_rect()
	var scale := Vector2(root.size) / root.get_visible_rect().size
	return {"text":label.text,"visible":label.is_visible_in_tree(),"rect":[rect.position.x * scale.x,rect.position.y * scale.y,rect.size.x * scale.x,rect.size.y * scale.y],"font_size":label.get_theme_font_size("font_size"),"render_scale":[scale.x,scale.y]}

func control_proof(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var scale := Vector2(root.size) / root.get_visible_rect().size
	return {"visible":control.is_visible_in_tree(),"rect":[rect.position.x * scale.x,rect.position.y * scale.y,rect.size.x * scale.x,rect.size.y * scale.y]}

func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var hud: Dictionary = {}
	if product.selected_mode == "assault":
		hud.objective = label_proof(product.objective_label)
	else:
		hud.title = label_proof(product.zone_hud.zone_title)
		hud.detail = label_proof(product.zone_hud.zone_detail)
		hud.hint = label_proof(product.zone_hud.zone_hint)
	var image := root.get_texture().get_image()
	var path := OS.get_environment("COMPACT_PNG")
	if image.save_png(path) != OK:
		push_error("COMPACT_SCREENSHOT_FAILED")
		quit(1)
		return
	var settings: Node = load("res://ui/settings_access.gd").service()
	var layout: Dictionary = {}
	var presenter: Node = product.get("game_hud") if product.selected_mode == "assault" else product.zone_hud
	if presenter != null:
		for key: String in ["top", "objective_panel", "vitals", "weapon_panel", "status_panel", "controls"]:
			if presenter.get(key) != null: layout[key] = control_proof(presenter.get(key))
		for key: String in ["map_label", "score_label", "health_label", "armor_label", "weapon_label", "ammo_label", "controls"]:
			hud[key] = label_proof(presenter.get(key))
	if settings.hint != null: layout.settings_hint = control_proof(settings.hint)
	if is_instance_valid(product.combat.quality_controls): layout.quality_hint = control_proof(product.combat.quality_controls.text)
	print("COMPACT_PRODUCT_CAPTURE ", JSON.stringify({"scene":product.scene_file_path,"map":product.current_id,"mode":product.selected_mode,"phase":product.phase,"received_pose":product.received_pose,"stale":product.snapshot_watch.stale(),"snapshots":snapshots,"first_time":first_time,"state":latest.state,"actor_id":product.client.actor_id,"local_actor":product.presentation.local_actor,"hud":hud,"layout":layout,"session_label":product.label.text,"ui_scale":settings.values.ui_scale,"size":[image.get_width(),image.get_height()],"path":path}))
	quit(0)
