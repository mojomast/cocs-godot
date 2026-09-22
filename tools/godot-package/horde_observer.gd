extends SceneTree
## External read-only observer of the actual exported scene. Never in the PCK.
## No replacement script, source mutation, authority observer, or gameplay driver.
var product: Node
var snapshots := 0
var latest: Dictionary = {}
var events: Array = []
var ready := false
var captured := false
var released := false
var elapsed := 0.0

func _initialize() -> void:
	call_deferred("observe")

func observe() -> void:
	product = load("res://horde/demo.tscn").instantiate()
	root.add_child(product)
	current_scene = product
	product.client.snapshot.connect(func(frame: Dictionary) -> void:
		snapshots += 1
		latest = frame.duplicate(true)
		print("HORDE_PRODUCT_SNAPSHOT ", JSON.stringify(frame)))
	product.client.events.connect(func(items: Array) -> void:
		events.append_array(items.duplicate(true))
		print("HORDE_PRODUCT_EVENTS ", JSON.stringify(items)))
	product.client.connection_error.connect(func(message: String) -> void:
		push_error("HORDE_PRODUCT_ERROR " + message)
		quit(1))

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 110:
		push_error("HORDE_PRODUCT_TIMEOUT")
		quit(1)
	if not is_instance_valid(product) or latest.is_empty(): return false
	var state: Dictionary = latest.get("state", {})
	var single: Dictionary = state.get("singleplayer", {})
	if not ready and snapshots >= 3 and single.get("wave") == 1 and single.get("enemiesAlive") == 3:
		if product.phase != 3 or product.waves != 10 or single.get("waveTarget") != 10 or single.get("lives") != 3:
			push_error("HORDE_PRODUCT_DEFAULT_MISMATCH")
			quit(1)
			return false
		ready = true
		print("HORDE_PRODUCT_READY ", JSON.stringify({"scene":product.scene_file_path,"map":product.current_id,"waves":product.waves,"snapshots":snapshots,"state":state,"events":events,"hud":product.horde_label.text,"help":product.get_node("GameHUD").controls.text,"scoreboard_script":product.get_node("Scoreboard").get_script().resource_path}))
	var board: Node = product.get_node("Scoreboard")
	if ready and board.panel.visible and not captured:
		captured = true
		call_deferred("capture")
	if captured and not board.panel.visible and not released:
		released = true
		print("HORDE_PRODUCT_RELEASED ", JSON.stringify({"phase":product.phase,"snapshots":snapshots,"board_visible":false}))
	return false

func capture() -> void:
	await RenderingServer.frame_post_draw
	var board: Node = product.get_node("Scoreboard")
	var rect: Rect2 = board.panel.get_global_rect()
	var strip: Rect2 = product.horde_label.get_global_rect()
	var image := root.get_texture().get_image()
	var path := OS.get_environment("HORDE_PACKAGE_PNG")
	if image.save_png(path) != OK:
		push_error("HORDE_PRODUCT_SCREENSHOT_FAILED")
		quit(1)
		return
	print("HORDE_PRODUCT_CAPTURE ", JSON.stringify({"path":path,"size":[image.get_width(),image.get_height()],"board_visible":board.panel.visible,"board":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"horde":[strip.position.x,strip.position.y,strip.size.x,strip.size.y],"state":latest.state,"hud":product.horde_label.text,"help":product.get_node("GameHUD").controls.text}))
