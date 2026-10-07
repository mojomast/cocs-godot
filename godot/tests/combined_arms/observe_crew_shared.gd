extends SceneTree
## Three independent native processes run this SceneTree against one authority room.
## All actions enter through physical input events; snapshots are read-only evidence.
const Demo = preload("res://combined_arms/demo.gd")
const PUMA := "sunscar-0-puma"
const DEADLINE := 200.0
class FrameWitness extends Node:
	var observe: Callable
	func _process(_delta: float) -> void:
		observe.call()

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
var gunner_seen := false
var personal_event := false
var passenger_seen := false
var host_create_sent := false
var last_progress := 0.0
var last_position := Vector2.INF
var crew_ready_since := -1.0
var passenger_shot_since := -1.0
var neutral_seq := -1
var entry_seq := -1
var approach_pulses := 0
var entry_retries := 0
var witnessed_mounted_samples := 0
var held_input_probe_sent := false
var held_input_probe_pending := false
var capture_released := false

func released_capture(who: String) -> bool:
	var directory := OS.get_environment("VEHICLE_HANDOFF_ROOT")
	return not directory.is_empty() and FileAccess.file_exists(directory.path_join(who + ".released"))

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
		if arg == "--wait-for-players=3": wait = true
	if not endpoint or not map or not wait or (role != "host") != join:
		print("CREW_USAGE " + JSON.stringify({"role":role,"required":"--map=sunscar-convoy --endpoint=ws://HOST:PORT --wait-for-players=3" + (" --join-room=ROOM" if role != "host" else " (host creates room; omit --join-room)")}))
		quit(2)
		return
	demo = Demo.new()
	# First child runs after Demo updates its camera, before the network child
	# polls the next snapshot. SceneTree._process observes the previous camera
	# paired with newly received actor state, which is not a coherent frame.
	var witness := FrameWitness.new()
	witness.observe = sample
	demo.add_child(witness)
	# The native host selects a non-autogunner loadout through the ordinary
	# create request. Default OpenClaw would shoot the opposing-team gunner
	# during the natural approach before that player can take the seat.
	if role == "host": demo.create_sent = true
	root.add_child.call_deferred(demo)
	demo.input_queued.connect(func(seq: int, packet: Dictionary, result: int) -> void:
		# Every input receipt carries the native client's packet and its wire sequence.
		if stage in ["settle", "waypoint-settle"] and neutral_seq < 0 and result == OK and is_zero_approx(float(packet.get("x", 1))) and is_zero_approx(float(packet.get("z", 1))) and not packet.get("interact", false): neutral_seq = seq
		if stage == "entry" and entry_seq < 0 and result == OK and packet.get("interact", false): entry_seq = seq
		log_line("QUEUE", {"input_seq":seq,"packet":packet,"result":result}))
	demo.net.started.connect(func(frame: Dictionary) -> void:
		log_line("START", {"frame":frame}))
	demo.net.events.connect(func(items: Array) -> void:
		for item: Variant in items:
			if item is Dictionary and item.get("type") == "shot":
				if role == "passenger" and int(item.get("actor", -1)) == 2: personal_event = true
				if int(item.get("actor", -1)) == 2:
					passenger_seen = true
					if passenger_shot_since < 0: passenger_shot_since = elapsed
			if item is Dictionary and item.get("type") == "vehicle-shot" and item.get("vehicle") == PUMA:
				if role == "guest" and int(item.get("actor", -1)) == 1: shot_event = true
				if int(item.get("actor", -1)) == 1: gunner_seen = true
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
	last_progress = elapsed
	neutral_seq = -1
	entry_seq = -1
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

func retry_western_walk(pos: Vector2, distance: float) -> void:
	entry_retries += 1
	if entry_retries > 2:
		fail("source entry recovery exhausted: " + JSON.stringify({"distance":distance,"ack":demo.net.last_ack,"position":[pos.x,pos.y]}))
		return
	# The only replay is another physical walk around the safe western
	# approach; neither the actor nor vehicle position is assigned.
	if pos.y > 0: path.assign([Vector2(-80,18),Vector2(-80,-10),Vector2(-62,-10),Vector2(-62,-4)])
	else: path.assign([Vector2(-80,-10),Vector2(-62,-10),Vector2(-62,-4)])
	waypoint = 0
	last_position = pos
	approach_pulses = 0
	log_line("REAPPROACH", {"attempt":entry_retries,"source_distance":distance,"path":path.map(func(p: Vector2) -> Array: return [p.x,p.y])})
	change("walk")

func sample() -> void:
	if demo.actor.is_empty(): return
	if demo.net.last_snapshot_seq == last_seq: return
	last_seq = demo.net.last_snapshot_seq
	# The passive wire witness retains seq <= 10 or seq % 5 == 0. At low
	# render cadence, completion must collect enough actual overlapping frames
	# rather than assuming a few elapsed seconds imply camera/seat evidence.
	if not demo.vehicle.is_empty() and (last_seq <= 10 or last_seq % 5 == 0):
		witnessed_mounted_samples += 1
	var v := source_puma()
	var render := []
	var node = demo.fleet.vehicle_node(PUMA)
	if is_instance_valid(node): render = [node.position.x,node.position.y,node.position.z]
	var c: Vector3 = demo.world.camera.position
	log_line("SAMPLE", {"snapshot_seq":last_seq,"ack":demo.net.last_ack,"round":demo.state.get("roundRevision"),"phase":demo.phase,"actor":demo.actor,"vehicle":demo.vehicle,"source_puma":v,"render_puma":render,"camera":[c.x,c.y,c.z],"hands_visible":demo.graphics.rig.showing,"muzzle_count":demo.graphics.rig.get_muzzle_count(),"engaged":demo.controls.engaged,"focused":demo.controls.focused,"window_focus":root.has_focus(),"eligible":demo.eligible()})

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > DEADLINE:
		fail("deadline at " + stage)
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if role == "host" and not host_create_sent and demo.net.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		host_create_sent = true
		var result: Error = demo.net.create_room("Vehicle crew", "chatgpt", "hermes")
		log_line("CREATE", {"result":result,"character":"chatgpt","harness":"hermes"})
		if result != OK: fail("host create request failed")
	if demo.phase == "error":
		fail("demo error: " + demo.error)
		return false
	if not room_reported and not demo.net.room_id.is_empty():
		room_reported = true
		log_line("ROOM", {"join_room":demo.net.room_id})
	if demo.actor.is_empty(): return false
	var a: Dictionary = demo.actor
	if float(a.get("health",0)) <= 0 or float(a.get("dead",0)) > 0:
		fail("actor died before crew observation: " + JSON.stringify({"stage":stage,"waypoint":waypoint,"position":[a.get("x"),a.get("z")],"snapshot_seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
		return false
	if role == "host" and a.get("harness") != "hermes":
		fail("host source actor did not receive requested non-autogunner harness")
		return false
	if not demo.eligible(): return false
	if stage in ["mounted","drive","brake","gunner-fire","passenger-fire","observe"] and (a.get("vehicleId") != PUMA or a.get("vehicleSeat") != ("driver" if role == "host" else ("gunner" if role == "guest" else "passenger"))):
		fail("crew seat lease lost")
		return false
	var pos := Vector2(float(a.x), float(a.z))
	if stage == "walk":
		if pos.distance_to(last_position) > 0.3:
			last_position = pos
			last_progress = elapsed
		if elapsed - last_progress > 8.0:
			fail("walk stalled: " + JSON.stringify({"waypoint":waypoint,"position":[pos.x,pos.y],"focus":root.has_focus(),"engaged":demo.controls.engaged,"snapshot_seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
			return false
	var v := source_puma()
	if v.is_empty():
		fail("source Puma absent")
		return false
	match stage:
		"boot":
			if role == "passenger" and (v.get("gunner") == null or not gunner_seen): return false
			if role == "passenger" and not released_capture("guest"): return false
			if role == "guest" and v.get("driver") == null: return false
			if role != "host":
				if crew_ready_since < 0: crew_ready_since = elapsed
				# Only one X11 client may own the pointer grab. Let the prior
				# rider release it with physical Esc before the next approaches.
				if elapsed-crew_ready_since < (3.0 if role == "passenger" else 1.0): return false
			approach_origin = pos
			# West spawn / east spawn respectively; these are authored freight-road waypoints.
			if role == "guest":
				if pos.y > 0:
					# North/east source spawns cannot travel straight through
					# the Sun Gate pillar at x=78, z≈-7. Go west above it.
					path.assign([Vector2(78,0),Vector2(54,0),Vector2(54,-18)])
				else:
					path.assign([Vector2(78,-18),Vector2(54,-18)])
				path.append_array([Vector2(14,-18),Vector2(0,18),Vector2(-44,18),Vector2(-54,-10),Vector2(-62,-10),Vector2(-62,-4)])
			else:
				path.assign([Vector2(-80,-10),Vector2(-62,-10),Vector2(-62,-4)])
			log_line("SPAWN", {"position":[pos.x,pos.y],"team":a.get("team"),"target":PUMA,"path":path.map(func(p: Vector2) -> Array: return [p.x,p.y])})
			change("walk")
			last_position = pos
			tap(KEY_ENTER)
		"walk":
			if held_input_probe_pending:
				held_input_probe_pending = false
				log_line("HELD_RELEASE", {"down_w":demo.controls.down.has(KEY_W),"active_w":demo.controls.keys.has(KEY_W),"engaged":demo.controls.engaged})
			# Optional regression probe of the same held-key release contract as
			# focus loss or stale snapshots, using ordinary physical Esc/Enter.
			if OS.get_environment("VEHICLE_RECOVER_HELD_INPUT") == "1" and not held_input_probe_sent and demo.controls.keys.has(KEY_W):
				held_input_probe_sent = true
				held_input_probe_pending = true
				tap(KEY_ESCAPE)
				return false
			if not root.has_focus(): root.grab_focus()
			if not root.has_focus() or not demo.controls.focused: return false
			if not demo.controls.engaged:
				tap(KEY_ENTER)
				if not demo.controls.engaged: return false
			if a.get("vehicleId") != null:
				fail("unexpected mount before entry request")
				return false
			# Never send E while the last acknowledged command is still W.
			# A client frame stall can leave that command driving the authority
			# for seconds before the interact edge reaches Room.
			# The source Puma is the destination. A slower rendered client may
			# pass close to it while still pursuing an intermediate waypoint;
			# do not run another full-speed circle around that waypoint.
			if pos.distance_to(Vector2(float(v.x),float(v.z))) < 4.5:
				change("settle")
				return false
			# A 0.9 m fly-through threshold could be missed between low-FPS
			# source snapshots. Stop, wait for the neutral wire ACK and source
			# velocity, then pick the next physical leg from a stationary actor.
			if pos.distance_to(path[waypoint]) < 3.0:
				change("waypoint-settle")
				return false
			turn_to(path[waypoint])
			if not demo.controls.keys.has(KEY_W):
				# Focus/stale-snapshot release deliberately blocks held keys until
				# a real key-up. Repeated downs alone remain neutral forever.
				key(KEY_W, false)
				key(KEY_W, true)
		"waypoint-settle":
			if elapsed-stage_since > 12.0:
				fail("waypoint neutral input was not acknowledged: " + JSON.stringify({"waypoint":waypoint,"neutral_seq":neutral_seq,"ack":demo.net.last_ack,"position":[pos.x,pos.y]}))
				return false
			if neutral_seq < 0 or demo.net.last_ack < neutral_seq: return false
			if Vector2(float(a.get("vx", 0)),float(a.get("vz", 0))).length() > 0.3: return false
			if pos.distance_to(Vector2(float(v.x),float(v.z))) < 6.0:
				change("settle")
			elif pos.distance_to(path[waypoint]) < 3.5:
				log_line("WAYPOINT", {"index":waypoint,"position":[pos.x,pos.y],"ack":demo.net.last_ack})
				waypoint += 1
				change("settle" if waypoint == path.size() else "walk")
			else:
				# A late acknowledgement may let the last W step cross the
				# threshold. Steer again from the acknowledged resting position.
				change("walk")
		"settle":
			# Check the exact source acknowledgement and source velocity before
			# submitting E. This cannot be faked by a local proximity prompt.
			if elapsed-stage_since > 12.0:
				fail("foot approach failed to settle: " + JSON.stringify({"neutral_seq":neutral_seq,"ack":demo.net.last_ack,"velocity":[a.get("vx"),a.get("vz")],"position":[pos.x,pos.y]}))
				return false
			if neutral_seq < 0 or demo.net.last_ack < neutral_seq: return false
			if Vector2(float(a.get("vx", 0)),float(a.get("vz", 0))).length() > 0.3: return false
			var distance := pos.distance_to(Vector2(float(v.x),float(v.z)))
			if distance < 1.6:
				change("entry")
				tap(KEY_E)
			elif distance > 8.0:
				retry_western_walk(pos, distance)
			else:
				if approach_pulses >= 25:
					fail("bounded foot approach exhausted: " + JSON.stringify({"distance":distance,"ack":demo.net.last_ack}))
					return false
				approach_pulses += 1
				turn_to(Vector2(float(v.x),float(v.z)))
				change("approach-pulse")
				key(KEY_W, true)
		"approach-pulse":
			if elapsed-stage_since > 4.0:
				fail("physical approach pulse stalled before key release")
				return false
			if elapsed-stage_since >= 0.14: change("settle")
		"entry":
			if not demo.vehicle.is_empty():
				if a.get("vehicleId") != PUMA or a.get("vehicleSeat") != ("driver" if role == "host" else ("gunner" if role == "guest" else "passenger")):
					fail("wrong source vehicle or seat: " + str(a.get("vehicleId")) + "/" + str(a.get("vehicleSeat")))
					return false
				mounted_origin = Vector2(float(v.x),float(v.z))
				change("mounted")
				# Seat-eye evidence is a first-person assertion; the persisted
				# default vehicle view is third-person chase in a fresh profile.
				if role != "host" and not demo.chase.first_person: tap(KEY_F4)
				# Seat identity releases capture. Reacquire only in the role's
				# active phase; idle host must not hold X11 pointer against crew.
			elif entry_seq >= 0 and demo.net.last_ack >= entry_seq and elapsed-stage_since > 0.5:
				var distance := pos.distance_to(Vector2(float(v.x),float(v.z)))
				if distance > 8.0: retry_western_walk(pos, distance)
				elif distance >= 2.4: change("settle")
				else: fail("source denied acknowledged nearby entry: " + JSON.stringify({"distance":distance,"entry_seq":entry_seq,"ack":demo.net.last_ack,"source_vehicle":v.get("id")}))
			elif elapsed-stage_since > 6.0: fail("entry input was not acknowledged: " + JSON.stringify({"entry_seq":entry_seq,"ack":demo.net.last_ack}))
		"mounted":
			if role == "host":
				var passenger_mounted := false
				for occupant: Variant in v.get("passengers", []):
					if occupant != null and int(occupant) == 2: passenger_mounted = true
				# X11 cannot focus two native windows at once. Let guest fire
				# independently first, then focus the host and drive with fresh input.
				if v.get("gunner") != null and gunner_seen and passenger_mounted and passenger_seen and elapsed-passenger_shot_since > 2.5 and released_capture("passenger"):
					if not root.has_focus(): root.grab_focus()
					if not root.has_focus() or not demo.controls.focused: return false
					tap(KEY_ENTER)
					if not demo.controls.engaged: return false
					change("drive")
					key(KEY_W, true)
				elif elapsed-stage_since > 60.0:
					fail("crew wait stalled: " + JSON.stringify({"gunner":v.get("gunner"),"gunner_seen":gunner_seen,"passenger_mounted":passenger_mounted,"passenger_seen":passenger_seen,"shot_age":elapsed-passenger_shot_since}))
			elif role == "guest":
				# This distinct client's fire input proves independent gun ownership;
				# the host drives after X11 focus is returned to its window.
				if v.get("driver") != null and v.get("driver") != a.get("id"):
					if not root.has_focus(): root.grab_focus()
					if not root.has_focus() or not demo.controls.focused: return false
					tap(KEY_ENTER)
					if not demo.controls.engaged: return false
					change("gunner-fire")
					turn_to(Vector2(float(v.x)+12.0,float(v.z)))
					mouse_button(true)
			else:
				if not root.has_focus(): root.grab_focus()
				if not root.has_focus() or not demo.controls.focused: return false
				tap(KEY_ENTER)
				if not demo.controls.engaged: return false
				change("passenger-fire")
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
				tap(KEY_ESCAPE)
		"passenger-fire":
			if elapsed-stage_since > 1.5:
				mouse_button(false)
				change("observe")
				tap(KEY_ESCAPE)
		"observe":
			# Process clocks diverge under load. Transfer the shared X11 pointer
			# only after Esc has actually been consumed by the previous rider.
			if role != "host" and not capture_released and not demo.controls.engaged and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				var directory := OS.get_environment("VEHICLE_HANDOFF_ROOT")
				var receipt := FileAccess.open(directory.path_join(role + ".released"), FileAccess.WRITE)
				if receipt == null:
					fail("cannot publish physical capture release")
					return false
				receipt.store_string("physical Esc consumed\n")
				receipt.close()
				capture_released = true
				log_line("CAPTURE_RELEASED")
			if elapsed-stage_since > 45.0:
				fail("source drive observation stalled: " + JSON.stringify({"shot_event":shot_event,"personal_event":personal_event,"driver_distance":Vector2(float(v.x),float(v.z)).distance_to(mounted_origin)}))
				return false
			if role == "guest" and elapsed-stage_since > 8.0 and not shot_event:
				fail("no authoritative vehicle-shot event for guest actor")
			elif role == "passenger" and elapsed-stage_since > 8.0 and not personal_event:
				fail("no authoritative passenger personal shot event")
			elif witnessed_mounted_samples >= 12 and elapsed-stage_since > 2.0 and (role == "host" or ((shot_event if role == "guest" else personal_event) and Vector2(float(v.x),float(v.z)).distance_to(mounted_origin) > 9.0)):
				log_line("COMPLETE", {"source_vehicle":PUMA,"seat":a.get("vehicleSeat"),"mounted_from_spawn":approach_origin.distance_to(pos) > 2.0,"driver_distance":Vector2(float(v.x),float(v.z)).distance_to(mounted_origin),"gunner_fired":shot_event if role == "guest" else null,"passenger_fired":personal_event if role == "passenger" else null})
				quit()
	return false
