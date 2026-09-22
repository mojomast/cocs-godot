extends SceneTree
## Private oracle transport. The controller receives public state/events only.
const Controller = preload("res://combat_shields/controller.gd")
var peer := WebSocketPeer.new()
var fx: Node3D
var endpoint := ""
var opened := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
	call_deferred("start")

func start() -> void:
	fx = Controller.new()
	root.add_child(fx)
	fx.configure(null)
	create_timer(20.0).timeout.connect(func() -> void: push_error("COMBAT_SHIELDS_LIVE watchdog"); quit(1))
	if peer.connect_to_url(endpoint) != OK: quit(1)

func _process(_delta: float) -> bool:
	peer.poll()
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		opened = true
		while peer.get_available_packet_count() > 0:
			var text := peer.get_packet().get_string_from_utf8()
			var frame: Variant = JSON.parse_string(text)
			if not frame is Dictionary: quit(1); return false
			match frame.get("type"):
				"events": fx.apply_events(frame.items,0)
				"snapshot":
					fx.apply_state(frame.state,0)
					var a: Dictionary = frame.state.actors[1]
					var row := {"type":"test-receipt","seq":frame.seq,"sha256":text.sha256_text(),"armor":a.armor,"health":a.health,"temporaryShield":a.temporaryShield,"protection":a.protection,"kind":fx.debug_state().kinds.get(1,""),"controller":fx.debug_state()}
					print("COMBAT_SHIELDS_LIVE " + JSON.stringify(row))
					peer.send_text(JSON.stringify(row))
				"test-end":
					fx.reset()
					var clean: bool = fx.factory.state().materials == 0
					print("COMBAT_SHIELDS_LIVE_DONE " + JSON.stringify({"clean":clean}))
					peer.close()
					fx.free()
					quit(0 if clean else 1)
	elif opened and peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		push_error("COMBAT_SHIELDS_LIVE early disconnect")
		quit(1)
	return false
