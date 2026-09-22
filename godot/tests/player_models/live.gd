extends SceneTree
const SessionScene = preload("res://world/session.tscn")
var session: Node
var elapsed := 0.0
var output := ""
var records: Array = []
var samples := 0
var changes := 0
var yaw_changes := 0
var previous: Dictionary = {}
var failed := false
var finishing := false
var restarted := false
var image_saved := false
var live_nodes: Dictionary = {}
var transitions: Array = []
var clean_restarts := 0
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("start")
func start() -> void:
	session = SessionScene.instantiate()
	root.add_child(session)
	session.client.snapshot.connect(observe)
	session.client.results.connect(func(frame: Dictionary) -> void: transitions.append(frame))
	session.client.started.connect(func(frame: Dictionary) -> void:
		transitions.append(frame)
		if not live_nodes.is_empty():
			for node: Variant in live_nodes.values(): check(not is_instance_valid(node),"old round instances freed")
			check(session.presentation.actors.is_empty(),"round clears actor registry")
			clean_restarts += 1
		live_nodes.clear()
		previous.clear())
	# Ordinary host config through the protocol, not a simulation/state mutation.
	session.client.lobby.disconnect(session.on_lobby)
	session.client.lobby.connect(func(frame: Dictionary) -> void:
		if session.phase == 1:
			check(session.client.send_frame({"type":"host","mapId":session.current_id,"config":{"mode":"teamdeathmatch","botCount":2,"timeLimit":60,"fragLimit":100}})==OK,"host config")
			session.phase = 2
		else: session.on_lobby(frame))
func check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error("PLAYER_MODEL_LIVE: "+message)
func observe(frame: Dictionary) -> void:
	var rendered := []
	for actor: Dictionary in frame.state.actors:
		var id := int(actor.id)
		var node: Node3D = session.presentation.actors[id]
		if live_nodes.has(id): check(live_nodes[id] == node,"stable live actor instance")
		live_nodes[id] = node
		check(node.get_script().resource_path == "res://player_models/candidate.gd","candidate active")
		var track: Array = session.presentation.motion.tracks[id]
		var latest: Dictionary = track.back()
		var pose: Dictionary = session.presentation.motion.sample(id,latest.time)
		var source_position := Vector3(actor.x,actor.y+.9,actor.z)
		check(latest.position.distance_to(source_position)<.0001,"source anchor correlation")
		check(absf(angle_difference(latest.yaw,float(actor.get("bodyYaw",actor.get("yaw",0)))))<.0001,"source yaw correlation")
		if id != session.client.actor_id:
			check(node.position.distance_to(pose.position)<.001,"rendered interpolation")
			check(absf(angle_difference(node.rotation.y,pose.yaw))<.001,"rendered yaw")
			if previous.has(id):
				if source_position.distance_to(previous[id].position)>.01: changes += 1
				if absf(angle_difference(latest.yaw,previous[id].yaw))>.01: yaw_changes += 1
			previous[id] = {"position":source_position,"yaw":latest.yaw}
		check(node.get_meta("character") == str(actor.get("character","unknown")),"character correlated")
		rendered.append({"id":id,"position":[node.position.x,node.position.y,node.position.z],"yaw":node.rotation.y,"visible":node.visible,"variant":node.variant})
	records.append({"snapshot":frame,"rendered":rendered})
	samples += 1
func _process(delta: float) -> bool:
	elapsed += delta
	if not is_instance_valid(session) or finishing: return false
	if elapsed > 85:
		check(false,"normal-rate deadline")
		call_deferred("finish")
		finishing = true
	if elapsed > 8 and not image_saved and samples>30:
		image_saved = true
		call_deferred("capture")
	if session.phase == 4 and not restarted:
		restarted = true
		session.request_restart()
	if restarted and session.round_starts>=2 and session.phase == 3 and samples>100:
		finishing = true
		call_deferred("finish")
	return false
func capture() -> void:
	# Observer camera only; does not alter authority positions or player input.
	var remote: Node3D
	for id: int in session.presentation.actors:
		if id != session.client.actor_id and session.presentation.actors[id].visible:
			remote = session.presentation.actors[id]
			break
	if remote == null: check(false,"remote for screenshot"); return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_position = remote.global_position+Vector3(1.8,.7,-3)
	camera.look_at(remote.global_position)
	camera.current = true
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/live-observer.png")==OK,"live capture")
func finish() -> void:
	check(samples>100 and changes>10 and yaw_changes>10,"real moving/turning actors")
	check(restarted and session.round_starts>=2 and clean_restarts==1,"natural results and clean restart")
	var summary := {"passed":not failed,"snapshots":samples,"moving_transitions":changes,"turning_transitions":yaw_changes,"round_starts":session.round_starts,"elapsed_seconds":elapsed,"synthetic":false}
	var file := FileAccess.open(output+"/live.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary":summary,"records":records,"transitions":transitions,"clean_restarts":clean_restarts}))
	print("PLAYER_MODEL_LIVE_RESULT ",JSON.stringify(summary))
	session.queue_free()
	await process_frame
	quit(1 if failed else 0)
