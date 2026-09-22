extends "res://native_arenas/demo.gd"
## Actual native geometry, explicit synthetic public actor frames. This capture
## proves composition only; it is never smoke or source-gameplay acceptance.
const FixtureClient = preload("res://tests/native_arenas/session/fixture_client.gd")

func _init() -> void:
	super()
	client.free()
	client = FixtureClient.new()

func _ready() -> void:
	build_composition()
	set_process(false)
	var output := ""
	var setup_capture := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = arg.trim_prefix("--capture=")
		if arg == "--capture-setup": setup_capture = true
	if output.is_empty() or not catalog.open() or not load_map("prism-foundry"):
		push_error("Visual fixture requires an output path and real native geometry: " + catalog.error)
		get_tree().quit(1)
		return
	ids = NativeCatalog.MAP_IDS.duplicate()
	native_hud.configure(self)
	if not setup_capture:
		client.allowlist = catalog.entries
		client.requested_map = current_id
		client.actor_id = 0
		client.peer_id = 0
		client.decode_text(JSON.stringify({"type":"start","mapId":current_id,"inputEpoch":1,"geometryHash":catalog.entries[current_id].geometryHash}))
		var local := {"id":0,"name":"Fixture Operator","x":-7,"y":0,"z":8,"yaw":-0.52,"pitch":-0.03,
			"eyeHeight":1.45,"health":100,"maxHealth":100,"dead":0,"weapon":0,"ammo":[30],"armor":50,"frags":0,"deaths":0}
		var rival := local.duplicate(true)
		rival.id = 1
		rival.name = "Fixture Rival"
		rival.x = -4
		rival.z = 1
		rival.yaw = 2.8
		client.decode_text(JSON.stringify({"type":"snapshot","seq":1,"acks":{"0":0},"inputEpoch":1,
			"state":{"mapId":current_id,"mapName":"Prism Foundry","modeName":"Deathmatch",
			"config":{"mode":"deathmatch","timeLimit":180},"time":0,"over":false,"actors":[local,rival],"pickups":[],"leaders":[]}}))
		# Shared session normally applies these received/reseeded angles in its
		# process loop; the fixture disables network sending and projects them here.
		camera.rotation = Vector3(pitch, yaw, 0)
	var evidence := CanvasLayer.new()
	evidence.layer = 20
	add_child(evidence)
	var stamp := Label.new()
	stamp.text = "SYNTHETIC FRAME FIXTURE  ·  Actual native geometry  ·  Not gameplay acceptance"
	stamp.position = Vector2(24, 150 if not setup_capture else 2)
	stamp.add_theme_font_size_override("font_size", 14)
	stamp.add_theme_color_override("font_color", Color("ffd18a"))
	stamp.add_theme_color_override("font_shadow_color", Color.BLACK)
	stamp.add_theme_constant_override("shadow_offset_x", 2)
	stamp.add_theme_constant_override("shadow_offset_y", 2)
	evidence.add_child(stamp)
	for frame in range(5): await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(output)
	print("NATIVE_DM_VISUAL_FIXTURE ", JSON.stringify({"map":current_id,"evidence":"synthetic-public-frame",
		"realNativeGeometry":true,"actors":presentation.actors.size(),"capture":output,"saved":result == OK}))
	get_tree().quit(0 if result == OK else 1)
