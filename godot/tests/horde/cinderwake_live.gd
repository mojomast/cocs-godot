extends "res://tests/horde/identity_live.gd"
## Ordinary-input external observer of the actual Cinderwake Horde product.
## The inherited runner owns captures, bounded lifecycle and input events.
var observed_stage := false
var transit_id := -1
var travel_route: Array = []
var travel_index := 0
var pursuing_spine := false
var spine_index := 0
var last_revision := -1
var saw_transit := false

func _ready() -> void:
	super._ready()
	if scenario in ["waves", "stages"]: bounded = 355.0

func observe_horde() -> void:
	super.observe_horde()
	if session.horde.state.is_empty(): return
	var stage: Dictionary = session.horde.state.get("stage", {})
	if stage.is_empty() or not is_instance_valid(session.drydock): return
	if int(stage.get("geometryRevision", -1)) != last_revision:
		last_revision = int(stage.get("geometryRevision", -1))
		print("CINDERWAKE_GATE ", JSON.stringify({"revision":last_revision,
			"gateMask":stage.get("gateMask"),"stageId":stage.get("stageId"),
			"sourceTime":session.latest.get("time"),"nativeGateVisible":session.drydock.gate_bodies.map(func(body: StaticBody3D) -> bool: return body.visible)}))
	if stage.get("transit") is Dictionary and not saw_transit:
		saw_transit = true
		print("CINDERWAKE_TRANSIT ", JSON.stringify({"wave":session.horde.state.get("wave"),
			"transit":stage.transit,"sourceTime":session.latest.get("time")}))
	if scenario == "stages" and str(stage.get("stageId")) == "D" and int(stage.get("geometryRevision",0)) >= 2:
		finish(true, "ordinary-input source wave clears and both received bulkhead arrivals reached D")
	if observed_stage: return
	observed_stage = true
	print("CINDERWAKE_STAGE ", JSON.stringify({"map":session.current_id,
		"stage":stage.get("stageId"),"gateMask":stage.get("gateMask"),
		"revision":stage.get("geometryRevision"),"nativeGateCount":session.drydock.gate_bodies.size(),
		"authorityTime":session.latest.get("time"),"waveTarget":session.horde.state.get("waveTarget")}))

func special_wave_steering(_actor: Dictionary) -> bool:
	if not is_instance_valid(session.drydock): return false
	var stage: Dictionary = session.horde.state.get("stage", {})
	var transit: Variant = stage.get("transit")
	if not session.presentation.lifecycle.can_control(): return false
	if not transit is Dictionary:
		# The source bot may use the always-open lifeboat spine. Follow the
		# authored human route through its doorway if a living NPC is there;
		# a direct held-W toward its received position hits the hull wall.
		if scenario in ["waves", "stages"] and str(stage.get("stageId")) == "B":
			var target := nearest_enemy(_actor)
			if not target.is_empty() and float(target.x) < -31.0 and float(_actor.x) >= -31.0:
				pursue_spine()
				return true
		pursuing_spine = false
		spine_index = 0
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return true
	if int(transit.id) != transit_id:
		transit_id = int(transit.id)
		travel_index = 0
		var route_id := "%s-%s" % [str(transit.from), str(transit.to)]
		travel_route.clear()
		for route: Dictionary in session.drydock.recipe.routes:
			if route.get("id") == route_id:
				travel_route = route.points
				break
		var local_actor: Dictionary = session.presentation.local_actor
		if route_id == "B-C" and float(local_actor.get("x", 0)) < -24.0:
			# The open E spine is a real second route into C. A player who ended
			# wave 2 in E must not steer through B's flank cargo and rib walls.
			for route: Dictionary in session.drydock.recipe.routes:
				if route.get("id") == "E-C":
					travel_route = [{"x":-37.0,"z":46.0}] + route.points
					break
		elif route_id == "B-C" and float(local_actor.get("x", 0)) < -5.0 \
				and float(local_actor.get("z", 0)) > 38.0:
			# The centre line from the western cargo bay intersects pod B-2.
			# Rejoin the authored E-A return lane before using the B-C trench.
			travel_route = [{"x":-22.0,"z":50.0},{"x":-23.0,"z":56.0},
				{"x":-23.0,"z":57.5},{"x":0.0,"z":57.5}] + travel_route
		print("CINDERWAKE_TRAVEL ", JSON.stringify({"transitId":transit_id,"from":transit.from,
			"to":transit.to,"route":route_id,"waypoints":travel_route.size(),
			"entryX":local_actor.get("x"),"entryZ":local_actor.get("z"),
			"causeEventId":transit.causeEventId,"sourceTick":stage.tick}))
	if travel_route.is_empty():
		finish(false, "no authored path for source Cinderwake transit")
		return true
	var actor: Dictionary = session.presentation.local_actor
	var here := Vector2(float(actor.x), float(actor.z))
	while travel_index < travel_route.size():
		var point: Dictionary = travel_route[travel_index]
		if here.distance_to(Vector2(float(point.x), float(point.z))) >= 1.25: break
		travel_index += 1
	if travel_index >= travel_route.size():
		key(KEY_W, false)
		return true
	var waypoint: Dictionary = travel_route[travel_index]
	steer_waypoint(waypoint, actor, false)
	return true

func steer_waypoint(point: Dictionary, actor: Dictionary, sprint: bool) -> void:
	# One bounded ordinary mouse motion per rendered frame. Sending a one-frame
	# 180° delta through X11 capture can be clamped/coalesced by the display and
	# leaves held W driving into a hull slab; pause forward until actually facing
	# the next authored point. This reads received actor position only.
	var dx := float(point.x) - float(actor.x)
	var dz := float(point.z) - float(actor.z)
	var wanted := atan2(-dx, -dz)
	var error := wrapf(wanted - session.yaw, -PI, PI)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-clampf(error, -0.12, 0.12) / LOOK_GAIN, 0)
	Input.parse_input_event(motion)
	var aligned := absf(error) < 0.26
	key(KEY_W, aligned)
	key(KEY_SHIFT, aligned and sprint)

func pursue_spine() -> void:
	var actor: Dictionary = session.presentation.local_actor
	var target: Dictionary = nearest_enemy(actor)
	if target.is_empty() or float(target.x) > -31.0 or float(actor.x) < -31.0:
		pursuing_spine = false
		spine_index = 0
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return
	var route: Array = []
	for row: Dictionary in session.drydock.recipe.routes:
		if row.get("id") == "E-A":
			route = row.points.duplicate()
			break
	if route.is_empty(): return
	route.reverse()
	if not pursuing_spine:
		pursuing_spine = true
		spine_index = 0
		print("CINDERWAKE_PURSUIT ", JSON.stringify({"kind":"ordinary-input route to E", "route":"E-A reversed"}))
	var here := Vector2(float(actor.x), float(actor.z))
	while spine_index < route.size():
		var point: Dictionary = route[spine_index]
		if here.distance_to(Vector2(float(point.x), float(point.z))) >= 1.5: break
		spine_index += 1
	if spine_index >= route.size():
		aim_at(target, actor)
		key(KEY_W, false)
		return
	steer_waypoint(route[spine_index], actor, true)
