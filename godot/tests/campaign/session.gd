extends SceneTree
const Demo = preload("res://campaign/demo.gd")
const HUD = preload("res://campaign/hud.gd")

class RecordingClient extends "res://campaign/client.gd":
	var sent: Array = []
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var valid := Demo.parse_options(["--map=crown-array", "--mode=campaign", "--endpoint=ws://127.0.0.1:12345/native-campaign", "--difficulty=hard"])
	assert(valid.error.is_empty() and valid.difficulty == "hard")
	for endpoint: String in ["ws://example.com:123/native-campaign", "ws://127.0.0.1:70000/native-campaign", "ws://127.0.0.1:123/native-arenas"]:
		assert(not Demo.parse_options(["--endpoint=" + endpoint]).error.is_empty())
	var demo := Demo.new()
	demo.client.free()
	demo.client = RecordingClient.new()
	demo.client.input_epoch = 4
	var hud := HUD.new()
	root.add_child(hud)
	hud.set_process(false)
	hud.bind_session(demo)
	demo.campaign_hud = hud
	demo.catalog.entries = {"rootfall-verge":{"geometryHash":"one"}, "siltwake-crossing":{"geometryHash":"two"}}
	demo.current_id = "rootfall-verge"
	hud.show_brief("rootfall-verge")
	assert(hud.card.visible and hud.primary.text == "Begin chapter")
	hud.hide_brief()
	hud.observe_boss({"singleplayer":{"boss":{"alive":true,"hp":750,"maxHp":1000,"phase":2}}})
	assert(hud.boss.visible and hud.boss.text.contains("75%") and hud.boss.text.contains("Phase 2"))
	hud.observe_boss({"singleplayer":{"boss":null}})
	assert(not hud.boss.visible, "Absent authoritative boss cannot retain stale health")
	demo.phase = 3
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	fire.pressed = true
	var mobility := InputEventKey.new()
	mobility.physical_keycode = KEY_X
	mobility.pressed = true
	demo.combat_actions.record(fire, true)
	demo.combat_actions.record(mobility, true)
	assert(demo.combat_actions.sample(0, 0, true).fire and demo.combat_actions.sample(0, 0, true).mobility)
	demo.campaign.state = {"phase":"dead", "checkpoint":2}
	demo.client.campaign_phase = "dead"
	hud.refresh()
	assert(hud.primary.visible and hud.primary.text.contains("Retry") and not demo.can_capture_pointer())
	demo.request_restart()
	assert(demo.phase == 20 and demo.action_pending and demo.client.sent.back().action == "retry")
	assert(not demo.combat_actions.sample(0, 0, true).fire and not demo.combat_actions.sample(0, 0, true).mobility)
	var count: int = demo.client.sent.size()
	demo.request_restart()
	assert(demo.client.sent.size() == count, "double activation cannot queue duplicate retry")
	var old_visual := Node3D.new()
	demo.presentation.add_child(old_visual)
	demo.presentation.actors[1] = old_visual
	var old_ref: WeakRef = weakref(old_visual)
	demo.on_started({"mapId":"rootfall-verge", "geometryHash":"one"})
	assert(demo.phase == 3 and not demo.action_pending and old_ref.get_ref() == null and demo.presentation.actors.is_empty())
	demo.combat_actions.record(fire, true)
	demo.combat_actions.record(mobility, true)
	assert(not demo.combat_actions.sample(0, 0, true).fire and not demo.combat_actions.sample(0, 0, true).mobility, "held physical inputs need release before reactivation")
	demo.phase = 4
	demo.campaign.state = {"phase":"level-complete"}
	demo.client.campaign_phase = "level-complete"
	demo.client.action_pending = false # detached start bypasses decode_text
	demo.request_restart()
	assert(demo.client.sent.back().action == "continue" and demo.phase == 20)
	# A chapter map rebuild is covered by the real smoke/terrain integration;
	# this detached probe tests the shared start lifecycle without loading geometry.
	demo.current_id = "siltwake-crossing"
	demo.on_started({"mapId":"siltwake-crossing", "geometryHash":"two"})
	assert(not demo.received_pose and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	assert(not demo.combat_actions.sample(0, 0, true).fire and not demo.combat_actions.sample(0, 0, true).mobility)
	count = demo.client.sent.size()
	demo.action_pending = false
	demo.phase = 4
	demo.campaign.state = {"phase":"campaign-complete", "totalElapsed":1200}
	hud.refresh()
	assert(hud.card.visible and not hud.primary.visible and hud.body.text.contains("way home"))
	demo.request_restart()
	assert(demo.client.sent.size() == count, "ending cannot restart through Enter")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not demo.application_focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "focus regain never captures")
	hud.free()
	# Detached session owns these eager children until composition attaches them.
	for node: Node in [demo.camera, demo.label, demo.selector, demo.combat_label, demo.pickups, demo.presentation, demo.combat, demo.client, demo.ground_tells]: node.free()
	demo.free()
	print("CAMPAIGN_SESSION_OK")
	quit()
