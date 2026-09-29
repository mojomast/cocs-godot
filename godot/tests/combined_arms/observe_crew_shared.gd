extends SceneTree
## Two independent native processes run this SceneTree against one authority room.
## All actions enter through physical input events; snapshots are read-only evidence.
const Demo = preload("res://combined_arms/demo.gd")
const PUMA := "sunscar-0-puma"
const DEADLINE := 190.0
var role := "host"
var demo
var elapsed := 0.0
var stage := "boot"
var stage_since := 0.0
var last_seq := -1
var room_reported := false
var path: Array[Vector2] = []
var waypoint := 0
var approach_origin := Vector2.ZERO
var mounted_origin := Vector2.ZERO
var fired := false
var shot_event := false

func log_line(kind: String, data: Dictionary = {}) -> void:
	var row := {"role":role, "seconds":elapsed, "stage":stage, "room":demo.net.room_id if is_instance_valid(demo) else "", "peer":demo.net.peer_id if is_instance_valid(demo) else -1, "actor_id":demo.net.actor_id if is_instance_valid(demo) else -1}
	row.merge(data, true)
	print("CREW_" + kind + " " + JSON.stringify(row))

func fail(reason: String) -> void:
	log_line("FAIL", {"reason":reason})
	quit(1)

func _initialize() -> void:
	var endpoint := false
	var map := false
	var join := false
	var wait := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = true
		if arg == "--map=sunscar-convoy": map = true
		if arg.begins_with("--join-room="): join = not arg.trim_prefix("--join-room=").strip_edges().is_empty()
		if arg == "--wait-for-players=2": wait = true
	if not endpoint or not map or not wait or (role == "guest") != join:
		print("CREW_USAGE " + JSON.stringify({"role":role,"required":"--map=sunscar-convoy --endpoint=ws://HOST:PORT --wait-for-players=2" + (" --join-room=ROOM" if role == "guest" else " (host creates room; omit --join-room)")}))
		quit(2)
		return
	demo = Demo.new()
	root.add_child.call_deferred(demo)
	demo.input_queued.connect(func(seq: int, packet: Dictionary, result: int) -> void:
		# Every input receipt carries the native client's packet and its wire sequence.
		log_line("QUEUE", {"input_seq":seq,"packet":packet,"result":result}))
	demo.net.started.connect(func(frame: Dictionary) -> void:
		log_line("START", {"frame":frame}))
	demo.net.events.connect(func(items: Array) -> void:
		for item: Variant in items:
			if item is Dictionary and item.get("type") == "vehicle-shot" and item.get("actor") == demo.net.actor_id:
				shot_event = true
		if not items.is_empty(): log_line("EVENTS", {"events":items}))
	log_line("BOOT", {"pid":OS.get_process_id()})

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	log_line("INPUT", {"physical_keycode":code,"pressed":pressed})

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	log_line("INPUT", {"mouse_button":"left","pressed":pressed})

func change(next: String) -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_SPACE]: key(code, false)
	mouse_button(false)
	stage = next
	stage_since = elapsed
	log_line("STAGE", {"next":stage,"snapshot_seq":demo.net.last_snapshot_seq})

func turn_to(target: Vector2) -> void:
	var a: Dictionary = demo.actor
	var delta := target - Vector2(float(a.x), float(a.z))
	var wanted := atan2(-delta.x, -delta.y)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(wanted-demo.yaw, -PI, PI)/0.003, demo.pitch/0.003)
	Input.parse_input_event(motion)
	log_line("INPUT", {"mouse_relative":[motion.relative.x,motion.relative.y],"target":[target.x,target.y]})

func source_puma() -> Dictionary:
	for v: Dictionary in demo.state.get("vehicles", []):
		if v.get("id") == PUMA: return v
	return {}

func sample() -> void:
	if demo.net.last_snapshot_seq == last_seq: return
	last_seq = demo.net.last_snapshot_seq
	var v := source_puma()
	var render := []
	var node = demo.fleet.vehicle_node(PUMA)
	if is_instance_valid(node): render = [node.position.x,node.position.y,node.position.z]
	var c: Vector3 = demo.world.camera.position
	log_line("SAMPLE", {"snapshot_seq":last_seq,"ack":demo.net.last_ack,"round":demo.state.get("roundRevision"),"phase":demo.phase,"actor":demo.actor,"vehicle":demo.vehicle,"source_puma":v,"render_puma":render,"camera":[c.x,c.y,c.z],"engaged":demo.controls.engaged,"focused":demo.controls.focused,"window_focus":root.has_focus(),"eligible":demo.eligible()})

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > DEADLINE:
		fail("deadline at " + stage)
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == "error":
		fail("demo error: " + demo.error)
		return false
	if not room_reported and not demo.net.room_id.is_empty():
		room_reported = true
		log_line("ROOM", {"join_room":demo.net.room_id})
	if demo.actor.is_empty(): return false
	sample()
	if not demo.eligible(): return false
	var a: Dictionary = demo.actor
	if float(a.get("health",0)) <= 0 or float(a.get("dead",0)) > 0:
		fail("actor died before crew observation")
		return false
	if stage in ["mounted","drive","brake","gunner-fire","observe"] and (a.get("vehicleId") != PUMA or a.get("vehicleSeat") != ("driver" if role == "host" else "gunner")):
		fail("crew seat lease lost")
		return false
	var pos := Vector2(float(a.x), float(a.z))
	var v := source_puma()
	if v.is_empty():
		fail("source Puma absent")
		return false
	match stage:
		"boot":
			approach_origin = pos
			# West spawn / east spawn respectively; these are authored freight-road waypoints.
			path = [Vector2(-80,-10),Vector2(-62,-10),Vector2(-62,-6)] if role == "host" else [Vector2(78,-18),Vector2(54,-18),Vector2(14,-18),Vector2(0,18),Vector2(-44,18),Vector2(-54,-10),Vector2(-62,-10),Vector2(-62,-6)]
			log_line("SPAWN", {"position":[pos.x,pos.y],"team":a.get("team"),"target":PUMA,"path":path.map(func(p: Vector2) -> Array: return [p.x,p.y])})
			change("walk")
			tap(KEY_ENTER)
		"walk":
			if a.get("vehicleId") != null:
				fail("unexpected mount before entry request")
				return false
			if pos.distance_to(path[waypoint]) < 0.9:
				waypoint += 1
				key(KEY_W, false)
				if waypoint == path.size():
					if pos.distance_to(Vector2(float(v.x),float(v.z))) >= 2.4:
						fail("route finished outside source enter radius")
						return false
					change("entry")
					tap(KEY_E)
					return false
			turn_to(path[waypoint])
			if not demo.controls.keys.has(KEY_W): key(KEY_W, true)
		"entry":
			if not demo.vehicle.is_empty():
				if a.get("vehicleId") != PUMA or a.get("vehicleSeat") != ("driver" if role == "host" else "gunner"):
					fail("wrong source vehicle or seat: " + str(a.get("vehicleId")) + "/" + str(a.get("vehicleSeat")))
					return false
				mounted_origin = Vector2(float(v.x),float(v.z))
				change("mounted")
				tap(KEY_ENTER) # identity transition released capture; recapture via physical Enter.
			elif elapsed-stage_since > 4.0: fail("entry receipt failed")
		"mounted":
			if role == "host":
				if v.get("gunner") != null and v.get("gunner") != a.get("id"):
					change("drive")
					key(KEY_W, true)
			else:
				# Motion proves independent gunner turret ownership while host drives.
				if v.get("driver") != null and v.get("driver") != a.get("id"):
					change("gunner-fire")
					turn_to(Vector2(float(v.x)+12.0,float(v.z)))
					mouse_button(true)
		"drive":
			if Vector2(float(v.x),float(v.z)).distance_to(mounted_origin) > 9.0:
				change("brake")
				key(KEY_SPACE, true)
			if elapsed-stage_since > 18.0: fail("driver did not move source Puma nine metres")
		"brake":
			if elapsed-stage_since > 0.3: key(KEY_SPACE, false)
			if elapsed-stage_since > 1.2:
				change("observe")
		"gunner-fire":
			if not fired and elapsed-stage_since > 2.0:
				fired = true
				mouse_button(false)
				change("observe")
		"observe":
			if role == "guest" and elapsed-stage_since > 8.0 and not shot_event:
				fail("no authoritative vehicle-shot event for guest actor")
			elif elapsed-stage_since > 2.0 and (role == "host" or (shot_event and Vector2(float(v.x),float(v.z)).distance_to(mounted_origin) > 9.0)):
				log_line("COMPLETE", {"source_vehicle":PUMA,"seat":a.get("vehicleSeat"),"mounted_from_spawn":approach_origin.distance_to(pos) > 2.0,"driver_distance":Vector2(float(v.x),float(v.z)).distance_to(mounted_origin),"gunner_fired":shot_event if role == "guest" else null,"passenger_fire":"requires third independently controlled actor; two-client source seat order driver then gunner"})
				quit()
	return false
