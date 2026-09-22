extends Node3D
## Passive public-snapshot presentation. Goal.team is the DEFENDING team.
## game/soccer.mjs soccerSnapshot/crossSoccerGoals/scoreGoal own all geometry/scoring.
const RED := Color(1, 0.38, 0.32)
const BLUE := Color(0.35, 0.7, 1)
const BALL := Color(1, 0.88, 0.35)
var selection: Dictionary = {}
var markers: Array[Node3D] = []

func _ready() -> void:
	for i in range(3):
		var marker := Node3D.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		marker.add_child(mesh)
		var caption := Label3D.new()
		caption.font_size = 36
		caption.pixel_size = 0.018
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.position.y = 2.6 if i == 2 else 3.5
		marker.add_child(caption)
		add_child(marker)
		markers.append(marker)
	reset()

static func numbers(value: Variant, fields: Array) -> bool:
	if not value is Dictionary: return false
	for field in fields:
		var n: Variant = value.get(field)
		if not (n is int or n is float) or not is_finite(float(n)): return false
	return true

static func team_name(team: int) -> String:
	return "Red" if team == 0 else "Blue"

static func team_color(team: int) -> Color:
	return RED if team == 0 else BLUE

static func select(state: Dictionary, actor_id: int, vehicle: Dictionary, active: bool) -> Dictionary:
	if not active or actor_id < 0 or state.get("over", false): return {}
	var race: Variant = state.get("race")
	if not race is Dictionary or race.get("kind") != "soccer" or not race.get("phase") in ["kickoff", "playing"]: return {}
	var actors: Variant = state.get("actors")
	if not actors is Array: return {}
	var local: Dictionary = {}
	for a: Variant in actors:
		if a is Dictionary and a.get("id") == actor_id: local = a
	if not numbers(local, ["team", "health", "dead"]) or (local.team != 0 and local.team != 1) or local.health <= 0 or local.dead > 0: return {}
	if not numbers(vehicle, ["x", "z", "yaw", "health", "respawnTimer"]) or vehicle.health <= 0 or vehicle.respawnTimer > 0: return {}
	if vehicle.get("driver") != actor_id or local.get("vehicleSeat") != "driver" or not vehicle.has("id") or local.get("vehicleId") != vehicle.id: return {}
	var pitch: Variant = race.get("pitch")
	var ball: Variant = race.get("ball")
	if not numbers(pitch, ["minX", "maxX", "minZ", "maxZ"]) or pitch.minX >= pitch.maxX or pitch.minZ >= pitch.maxZ: return {}
	if not numbers(ball, ["x", "y", "z", "r"]) or ball.r <= 0: return {}
	# Permit the public ball to cross the line into the goal before reset.
	var goals: Variant = race.get("goals")
	if not goals is Array or goals.size() != 2: return {}
	var own: Dictionary = {}
	var opponent: Dictionary = {}
	for goal: Variant in goals:
		if not numbers(goal, ["team", "x", "z", "nx", "nz", "halfWidth", "height", "depth"]): return {}
		if (goal.team != 0 and goal.team != 1) or goal.halfWidth <= 0 or goal.height <= 0 or goal.depth <= 0: return {}
		var normal := Vector2(goal.nx, goal.nz)
		if absf(normal.length()-1) > 0.01: return {}
		var outward := Vector2(goal.x-(pitch.minX+pitch.maxX)/2, goal.z-(pitch.minZ+pitch.maxZ)/2)
		if outward.dot(normal) <= 0: return {}
		if goal.team == local.team: own = goal
		else: opponent = goal
	if own.is_empty() or opponent.is_empty(): return {}
	var margin := maxf(float(own.depth), float(opponent.depth)) + float(ball.r)
	if ball.x < pitch.minX-margin or ball.x > pitch.maxX+margin or ball.z < pitch.minZ-margin or ball.z > pitch.maxZ+margin: return {}
	return {"team":int(local.team), "own":own, "opponent":opponent, "ball":ball, "vehicle":vehicle}

static func bearing(target: Dictionary, vehicle: Dictionary) -> String:
	var offset := Vector2(float(target.x)-float(vehicle.x), float(target.z)-float(vehicle.z))
	var angle := wrapf(atan2(offset.x, offset.y)-float(vehicle.yaw), -PI, PI)
	var direction := "Ahead" if absf(angle) < 0.22 else ("Right" if angle > 0 else "Left")
	if absf(angle) > 2.4: direction = "Behind"
	return "%s · %.0f m" % [direction, offset.length()]

static func describe(target: Dictionary) -> String:
	if target.is_empty(): return ""
	return "You: %s · OWN %s goal · ATTACK %s goal\nBall %s   |   Opponent goal %s" % [team_name(target.team), team_name(target.team), team_name(1-target.team), bearing(target.ball, target.vehicle), bearing(target.opponent, target.vehicle)]

func reset() -> void:
	selection = {}
	hide()
	for marker: Node3D in markers:
		marker.position = Vector3.ZERO
		marker.rotation = Vector3.ZERO
		marker.get_child(1).text = ""

func apply(state: Dictionary, actor_id: int, vehicle: Dictionary, active: bool) -> Dictionary:
	selection = select(state, actor_id, vehicle, active)
	if selection.is_empty():
		reset()
		return {}
	if markers.size() != 3: return selection
	for i in range(3):
		var target: Dictionary = selection.ball if i == 2 else (selection.own if i == 0 else selection.opponent)
		var marker := markers[i]
		marker.position = Vector3(target.x, float(target.y)+float(target.r)+0.25 if i == 2 else 0.08, target.z)
		marker.rotation.y = 0 if i == 2 else atan2(float(target.nx), float(target.nz))
		var mesh: MeshInstance3D = marker.get_child(0)
		mesh.scale = Vector3(1.2, 0.08, 0.16) if i == 2 else Vector3(float(target.halfWidth)*2, 0.08, 0.22)
		var color := BALL if i == 2 else team_color(int(target.team))
		mesh.material_override.albedo_color = color
		var caption: Label3D = marker.get_child(1)
		caption.modulate = color
		caption.text = "BALL" if i == 2 else ("OWN · " if i == 0 else "ATTACK · ") + team_name(int(target.team))
	show()
	return selection
