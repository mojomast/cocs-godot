extends SceneTree
## Controlled source-fixture visual, not a live-wire journey.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(8, 8, 9)
	camera.look_at(Vector3(0, 1, -3))
	var cues := preload("res://player_gameplay/world_cues.gd").new()
	scene.add_child(cues)
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://player_gameplay/fixtures.json"))
	cues.apply_state(fixtures.rope)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40, 40)
	cues.mesh_node(mesh, Color("172b37"))
	var label := Label.new()
	label.position = Vector2(30, 30)
	label.text = "CONTROLLED SOURCE FIXTURE · Qwen shared rope\nGold: boarding point · Mint: source anchor route\nNative presentation only; live input proof is in live-final/"
	label.add_theme_font_size_override("font_size", 22)
	root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/home/mojo/.tmp-on-disk/cocs-port-gameplay-evidence-20261001/controlled-rope.png")
	cues.clear_visuals()
	var events: Array = []
	var harnesses := ["openclaw", "hermes", "opencode", "codex", "roo"]
	for i in harnesses.size(): events.append({"id":i,"type":"power","harness":harnesses[i],"pos":{"x":(i - 2) * 2.6,"y":2,"z":-3}})
	cues.apply_events(events, true)
	label.text = "CONTROLLED EVENT FIXTURE · Five harness activation cues\nBurst / Speed / Fire rate / Heal / Jam\nGuardrail and Phase Step retain existing native effects"
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/home/mojo/.tmp-on-disk/cocs-port-gameplay-evidence-20261001/controlled-powers.png")
	quit()
