extends SceneTree

# Real normal-rate server snapshots, actual session scene, scripted ordinary input.
# No synthetic actor state. This is a short visual capture, not a gameplay acceptance run.
const SessionScene = preload("res://world/session.tscn")
var session: Node
var elapsed := 0.0
var playing := 0.0
var clicked := false
var saving := false
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-capture="): output = arg.trim_prefix("--hud-capture=")
	call_deferred("start")

func start() -> void:
	assert(not output.is_empty())
	session = SessionScene.instantiate()
	root.add_child(session)
	root.grab_focus()

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 15:
		push_error("HUD capture timed out")
		quit(1)
	if not is_instance_valid(session) or saving: return false
	if not session.can_capture_pointer(): return false
	if not clicked:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		Input.parse_input_event(event)
		clicked = true
	playing += delta
	if playing > 0.8:
		saving = true
		call_deferred("capture")
	return false

func capture() -> void:
	var hud: CanvasLayer = session.get_node("GameHUD")
	hud.refresh_status()
	assert(hud.vitals.is_visible_in_tree() and hud.health_label.is_visible_in_tree())
	assert(hud.health_label.text == "HEALTH  %s" % int(session.presentation.local_actor.health))
	assert(hud.ammo_label.text == "AMMO  ∞")
	assert(not session.label.visible and not session.selector.visible and not session.combat_label.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not hud.status_panel.visible)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for panel: Control in [hud.top, hud.vitals, hud.weapon_panel, hud.controls]:
		assert(root.get_visible_rect().encloses(panel.get_global_rect()), "HUD contained at capture resolution")
	assert(hud.score_label.size.x >= 220 and hud.score_label.is_visible_in_tree())
	assert(hud.score_label.text.contains("FRAGS") and hud.top.get_global_rect().encloses(hud.score_label.get_global_rect()))
	assert(root.get_texture().get_image().save_png(output) == OK)
	print("PORT_GAME_HUD_LIVE_CAPTURE_OK ", JSON.stringify({"viewport":[root.size.x, root.size.y], "ack":session.client.last_ack, "health":hud.health_label.text, "armor":hud.armor_label.text, "weapon":hud.weapon_label.text, "ammo":hud.ammo_label.text, "map":session.current_id, "captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "shots":session.presentation.local_actor.shots}))
	session.queue_free()
	await process_frame
	quit(0)
