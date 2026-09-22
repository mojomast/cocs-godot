extends SceneTree
const Demo = preload("res://objectives/demo.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var demo := Demo.new()
	root.add_child(demo)
	demo.set_process(false)
	await process_frame
	var hud: Node = demo.objective_hud
	demo.phase = 3
	var state: Dictionary = JSON.parse_string('{"config":{"mode":"ctf"},"actors":[{"id":0,"team":0,"health":75,"armor":20,"weapon":0,"ammo":[10],"frags":1,"deaths":2}],"teamScores":{"0":2,"1":7},"flags":[{"team":0,"state":"dropped","carrier":null,"x":1,"y":0,"z":0},{"team":1,"state":"carried","carrier":0,"x":3,"y":0,"z":0}]}')
	demo.objectives.apply_state(state, 0)
	hud.apply_state(state, 0)
	check(hud.objective_title.text.contains("2 : 7"), "CTF source team scores, not frags")
	check(hud.objective_title.text.contains("RED [1]"), "JSON float team zero identifies local team")
	check(hud.objective_detail.text.contains("actor 0") and hud.objective_detail.text.contains("dropped"), "both flags and zero carrier")
	check(hud.health_label.text == "HEALTH  75" and hud.ammo_label.text == "AMMO  10", "shared combat composition")
	check(not hud.objective_progress.visible, "CTF has no fabricated gauge")
	var old_flag: Node = demo.objectives.markers.flag_0
	demo.on_started({})
	hud.on_started({})
	check(not is_instance_valid(old_flag), "new round frees old flag")
	check(demo.objective_label.text == "Objectives unavailable" and hud.objective_detail.text.is_empty(), "new round clears observer and visual HUD")
	check(not demo.received_pose and not demo.can_capture_pointer(), "new round waits for pose and fresh capture")
	state.config.mode = "payload"
	state.objectives = {"kind":"payload", "attacker":0.0,"defender":1.0,"payload":{"position":{"x":5,"y":0,"z":0},"distance":30,"total":80,"progress":37.5,"pushing":null,"contested":true,"checkpointsReached":1,"checkpointCount":3},"zones":[]}
	demo.objectives.apply_state(state, 0)
	hud.apply_state(state, 0)
	check(hud.objective_title.text.contains("ESCORT") and hud.objective_title.text.contains("CONTESTED"), "attacker contest status")
	check(hud.objective_detail.text.contains("37.5%") and hud.objective_progress.value == 37.5, "bounded source progress gauge")
	check(not demo.objectives.markers.has("flag_0"), "mode switch removes stale flags")
	demo.camera.current = true
	demo.camera.position = Vector3(5, 1.5, 0)
	demo.objectives._process(0)
	var cart: Node3D = demo.objectives.markers.cart
	check(not cart.get_child(0).visible and cart.position == Vector3(5,0,0), "near-eye cart mesh yields without moving source root")
	demo.camera.position = Vector3(10, 1.5, 0)
	demo.objectives._process(0)
	check(cart.get_child(0).visible, "cart mesh returns outside near-eye volume")
	state.actors[0].team = 1
	state.objectives.payload.contested = false
	state.objectives.payload.pushing = 1
	demo.objectives.apply_state(state, 0)
	hud.apply_state(state, 0)
	check(hud.objective_title.text.contains("DEFEND") and hud.objective_title.text.contains("ROLLING BACK"), "defender rollback distinct from escort")
	for size: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		await process_frame
		hud.resize()
		await process_frame
		for panel: Control in [hud.top,hud.objective_panel,hud.vitals,hud.weapon_panel,hud.status_panel]:
			check(panel.position.x >= 0 and panel.position.x + panel.size.x <= size.x and panel.position.y + panel.size.y <= size.y, "HUD bounds at %s" % size)
		check(hud.objective_panel.position.y + hud.objective_panel.size.y <= hud.status_panel.position.y, "objective/status separation at %s" % size)
		check(hud.objective_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "objective HUD passes pointer at %s" % size)
		check(hud.objective_hint.size.y >= 20 and hud.objective_hint.size.x <= size.x - 40, "hint has a visible bounded row at %s" % size)
	state.over = true
	state.winner = 1
	demo.objectives.apply_state(state, 0)
	hud.apply_state(state, 0)
	check(hud.objective_hint.text.contains("Winner: BLUE"), "authoritative results team")
	var old_cart: Node = demo.objectives.markers.cart
	demo.on_error("Synthetic progression disconnect")
	hud.on_error("Synthetic")
	check(not is_instance_valid(old_cart) and demo.objectives.hud_model.is_empty(), "disconnect clears cart and scalar model")
	check(hud.objective_detail.text.is_empty() and hud.objective_progress.value == 0, "disconnect clears visible progress")
	demo.free()
	print("PROGRESSION_HUD_TESTS checks=",checks," failures=",failures," synthetic=true")
	quit(1 if failures else 0)
