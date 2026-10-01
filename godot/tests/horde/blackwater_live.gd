extends "res://tests/horde/identity_live.gd"
## Native, ordinary-input bounded observer of the shipping Blackwater scene.
## No writes to Match, actors, objective, clock, lives or source stage.
var station_index := 0
var stations := ["north-feeder", "south-feeder", "switch-pump", "relief-valve"]
var route: Array[Vector2] = []
var waypoint := 0
var armed := false
var last_gate := -1
var last_notice := ""
var last_completed := 0
var blocked_samples := 0
var resume_at := 0.0
var next_position_log := 8.0

func _ready() -> void:
	super._ready()
	bounded = 480.0

func alternate_picture(tag: String) -> void:
	# Do not resize an actively captured pointer during Blackwater combat.
	# Window focus loss cancels real source inputs under software X11.
	await picture(tag)

func finish(ok: bool, message: String) -> void:
	if ok and (last_completed < 4 or last_gate < 2 or cleared < 7):
		ok = false
		message += " (Blackwater objective/gate/wave contract incomplete)"
	super.finish(ok, message)

func observe_horde() -> void:
	super.observe_horde()
	if session.phase != 3 or session.latest.is_empty(): return
	var stage: Dictionary = session.horde.state.get("stage", {})
	if not stage.is_empty() and int(stage.get("geometryRevision", -1)) != last_gate:
		last_gate = int(stage.geometryRevision)
		var bodies: Array = session.builder.gate_bodies
		var gate_data := []
		for body: StaticBody3D in bodies:
			gate_data.append({"visible":body.visible,"collision_layer":body.collision_layer,
				"collision_mask":body.collision_mask})
		var stage_data := {"stage":stage.get("stageId"),"wave":session.horde.state.get("wave"),
			"revision":last_gate,"gateMask":stage.get("gateMask"),"gate_bodies":gate_data,"source_time":session.latest.get("time")}
		print("BLACKWATER_NATIVE_GATE ", JSON.stringify(stage_data))
		want_picture("gate%d" % last_gate)
	var mission: Dictionary = session.latest.get("blackwater", {})
	if mission.is_empty(): return
	var completed_now: Array = mission.get("completed", [])
	if completed_now.size() != last_completed:
		last_completed = completed_now.size()
		print("BLACKWATER_NATIVE_OBJECTIVE ", JSON.stringify({"completed":completed_now,"serial":mission.get("serial"),
			"wave":mission.get("wave"),"source_time":session.latest.get("time"),"score":session.horde.state.get("score")}))
		want_picture("objective%d" % last_completed)
	if completed_now.size() == 4 and last_gate >= 2 and cleared >= 7:
		finish(true,"all four source-held objectives, two native gate transitions, seven real wave clears")

func build_route(index: int, actor: Dictionary) -> void:
	route.clear()
	waypoint = 0
	var pos := Vector2(float(actor.x), float(actor.z))
	match index:
		0:
			route.append(Vector2(-170,0))
			route.append(Vector2(-170,-40))
			route.append(Vector2(-170,78))
		1:
			route.append_array([Vector2(-170,-40),Vector2(-82,-40),Vector2(-82,-78)])
		2:
			route.append_array([Vector2(-82,-40),Vector2(0,-40),Vector2(0,78)])
		3:
			route.append_array([Vector2(0,-40),Vector2(170,-40),Vector2(170,-82)])
	armed = false
	print("BLACKWATER_NATIVE_ROUTE ", JSON.stringify({"index":index,"from":[pos.x,pos.y],"waypoints":route.map(func(p: Vector2) -> Array: return [p.x,p.y])}))

func special_wave_steering(a: Dictionary) -> bool:
	if elapsed >= next_position_log:
		next_position_log += 8.0
		print("BLACKWATER_NATIVE_POSITION ", JSON.stringify({"position":[a.get("x"),a.get("y"),a.get("z")],
			"capture":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"wave":session.horde.state.get("wave"),
			"health":a.get("health"),"waypoint":waypoint,"station":station_index,"last_ack":session.client.last_ack,
			"controls":session.controls.sample(session.yaw,session.pitch),"input_status":session.horde_client.input_status}))
	if OS.has_environment("BLACKWATER_DIAGNOSTIC") and elapsed > float(OS.get_environment("BLACKWATER_DIAGNOSTIC")):
		finish(false,"bounded control diagnostic")
		return true
	var mission: Dictionary = session.latest.get("blackwater", {})
	if mission.is_empty(): return false
	while station_index < stations.size() and stations[station_index] in mission.get("completed", []):
		station_index += 1
		route.clear()
		armed = false
	if station_index >= stations.size(): return false
	if station_index > 0 and int(session.horde.state.get("enemiesAlive",0)) > 0: return false
	var station: Dictionary = {}
	for row: Dictionary in mission.get("stations", []):
		if row.get("id") == stations[station_index]: station = row
	if not station.get("available", false): return false
	if route.is_empty(): build_route(station_index,a)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return true
	var pos := Vector2(float(a.x),float(a.z))
	var goal: Vector2 = route[mini(waypoint,route.size()-1)]
	var distance := pos.distance_to(goal)
	if distance < 3 and waypoint+1 < route.size():
		waypoint += 1
		goal = route[waypoint]
		distance = pos.distance_to(goal)
	var final_distance := pos.distance_to(Vector2(float(station.x),float(station.z)))
	if final_distance < 4.25:
		key(KEY_W,false)
		key(KEY_SHIFT,false)
		if not armed:
			key(KEY_E,true)
			armed = true
			print("BLACKWATER_NATIVE_ARM ", JSON.stringify({"station":station.id,"position":[a.x,a.z],
				"wave":session.horde.state.get("wave"),"source_time":session.latest.get("time")}))
		else: key(KEY_E,false)
		# Combat remains genuine while holding the station. Source decides whether
		# the player survives, the repair completes, and the wave clears.
		var nearby: Dictionary = nearest_enemy(a)
		if not nearby.is_empty():
			aim_at(nearby,a)
			if not firing: mouse(true)
		else: mouse(false)
		return true
	var target := {"x":goal.x,"y":float(a.y),"z":goal.y}
	aim_at(target,a)
	key(KEY_E,false)
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	if firing: mouse(false)
	if int(session.horde.state.get("wave",0)) <= 1 and int(session.horde.state.get("enemiesAlive",0)) > 0 and station_index == 0:
		# First district holds the opening pressure; move while the native
		# operator fires on robots that approach the planned foot route.
		var enemy: Dictionary = nearest_enemy(a)
		if not enemy.is_empty() and pos.distance_to(Vector2(float(enemy.x),float(enemy.z))) < 16:
			aim_at(enemy,a)
			if not firing: mouse(true)
	return true
