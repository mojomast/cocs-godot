extends SceneTree
## External --script with the unchanged package --main-pack. No replaced methods,
## injected input, extra peer.poll calls, altered queues or modified smoke gates.
var session: Node
var last_frame_us := 0
var frames := 0
var snapshots := 0
var events := 0
var lines := 0

func emit_mark(kind: String, extra: Dictionary = {}) -> void:
	if lines >= 1200: return
	lines += 1
	var row := {"kind":kind,"us":Time.get_ticks_usec(),"frames":frames,"snapshots":snapshots,"eventBatches":events}
	if is_instance_valid(session):
		row.merge({"phase":session.phase,"receivedPose":session.received_pose,"robots":session.robot_instances})
		var peer: WebSocketPeer = session.client.peer
		row.merge({"peerState":peer.get_ready_state(),"queuedPackets":peer.get_available_packet_count(),"outboundBytes":peer.get_current_outbound_buffered_amount(),"closeCode":peer.get_close_code(),"closeReason":peer.get_close_reason(),"lastSeq":session.client.last_snapshot_seq,"epoch":session.client.input_epoch})
	row.merge(extra)
	print("STARTUP_NATIVE ", JSON.stringify(row))

func _initialize() -> void:
	emit_mark("script-initialize")
	call_deferred("run")

func run() -> void:
	emit_mark("scene-load-enter")
	var scene: PackedScene = load("res://campaign/demo.tscn")
	emit_mark("scene-load-exit")
	session = scene.instantiate()
	# Connect before _ready attaches production signal handlers: timestamps mark
	# entry to synchronous scene callbacks, not just completion after expensive work.
	session.client.started.connect(func(_f: Dictionary) -> void: emit_mark("started-enter"))
	session.client.snapshot.connect(func(f: Dictionary) -> void:
		snapshots += 1
		if snapshots <= 3: emit_mark("snapshot-enter", {"seq":f.get("seq"),"actors":f.state.get("actors", []).size()}))
	session.client.events.connect(func(_items: Array) -> void:
		events += 1
		if events <= 3: emit_mark("events-enter"))
	session.client.connection_error.connect(func(message: String) -> void: emit_mark("connection-error", {"message":message}))
	emit_mark("add-scene-enter")
	root.add_child(session)
	emit_mark("add-scene-exit")
	# These synchronous handlers run after the production handlers.
	session.client.started.connect(func(_f: Dictionary) -> void: emit_mark("started-exit"))
	session.client.snapshot.connect(func(_f: Dictionary) -> void:
		if snapshots <= 3: emit_mark("snapshot-exit"))

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	frames += 1
	if frames <= 5 or now - last_frame_us > 100000:
		emit_mark("frame", {"wallGapMs":float(now-last_frame_us)/1000.0})
	last_frame_us = now
	return false

func _finalize() -> void:
	emit_mark("tree-finalize")
