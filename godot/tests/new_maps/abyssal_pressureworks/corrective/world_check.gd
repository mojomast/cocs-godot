extends SceneTree
## Isolated project only. Exact imported candidate art, runtime WorldMap physics.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const Binder = preload("res://multiplayer_worlds/dressing/binder.gd")
const IDENTITY := "ee979520743dd4c73ac0d825774a2c99b5a8d85800a6eead5170f261abe61bea"
const HERE := "res://tests/new_maps/abyssal_pressureworks/corrective/"
var result := {"status": "started", "rays": [], "clearances": [], "wallBands": [], "wallEnds": [], "errors": []}
var report_path := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	call_deferred("run")
	create_timer(120.0).timeout.connect(func() -> void: fail("world check timed out"))

func fail(message: String) -> void:
	result.errors.append(message)
	result.status = "failed"
	finish(2)

func finish(code: int) -> void:
	if report_path != "":
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "\t") + "\n")
	quit(code)

func json_at(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Dictionary: return value
	return {}

func ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b)
	query.hit_back_faces = true
	return space.intersect_ray(query)

func run() -> void:
	if report_path == "":
		fail("missing explicit --report path")
		return
	var data := json_at(HERE + "candidate.json")
	var manifest := json_at(HERE + "stage-manifest.json")
	if data.get("geometryHash") != IDENTITY or manifest.get("geometryHash") != IDENTITY or FileAccess.get_sha256(HERE + "candidate.json") != manifest.get("candidateSha256") or FileAccess.get_sha256(HERE + "corrective.glb") != manifest.get("glbSha256") or FileAccess.get_sha256(HERE + "probes.json") != manifest.get("probesSha256"):
		fail("staged bytes or authority identity changed")
		return
	var world := WorldMap.new()
	root.add_child(world)
	if not world.build(data) or world.geometry_hash != IDENTITY:
		fail("corrected authority WorldMap build failed")
		return
	# WorldMap's default art lookup points at the accepted map. Remove it first;
	# corrected GLB remains art only and must supply no physics shapes.
	var old := world.get_node_or_null("BlenderArtNoGameplayCollision")
	if old != null:
		world.remove_child(old)
		old.free()
	var scene: Variant = load(HERE + "corrective.glb")
	if not scene is PackedScene:
		fail("imported corrective GLB is not a PackedScene")
		return
	var art: Node3D = scene.instantiate()
	art.name = "BlenderArtNoGameplayCollision"
	world.add_child(art)
	if art.find_children("*", "MeshInstance3D", true, false).is_empty() or not art.find_children("*", "CollisionObject3D", true, false).is_empty():
		fail("missing imported art meshes or art unexpectedly owns physics")
		return
	var dressed: Dictionary = Binder.apply(world, str(data.id), IDENTITY)
	if dressed.get("status", "") != "ready":
		fail("candidate-only production Binder profile did not apply: " + str(dressed))
		return
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	# Reviewed historical P1 rays: no false cave contact through the retaining wall;
	# authority floors must still support the two terrace centers.
	var checks := [
		{"name": "old-silt-side", "a": [-106, 7.2, -97], "b": [-106, 7.2, -100], "hit": false},
		{"name": "terrace-sw", "a": [-94, 10, -98.5], "b": [-94, 5, -98.5], "hit": true, "y": 6.0},
		{"name": "terrace-se", "a": [91, 4, -92.5], "b": [91, -1, -92.5], "hit": true, "y": 0.0},
		{"name": "south-shield", "a": [-94, 7.2, -100], "b": [-94, 7.2, -102], "hit": true, "z": -101.0},
		{"name": "east-shield", "a": [102, 1.2, -90], "b": [104, 1.2, -90], "hit": true, "x": 103.0},
	]
	for check: Dictionary in checks:
		var a: Array = check.a
		var b: Array = check.b
		var contact := ray(space, Vector3(a[0], a[1], a[2]), Vector3(b[0], b[1], b[2]))
		result.rays.append({"name": check.name, "contact": str(contact.get("position", "none")), "collider": str(contact.get("collider", "none"))})
		if contact.is_empty() == bool(check.hit):
			fail("unexpected contact on " + str(check.name))
			return
		if check.has("y") and abs(contact.position.y - float(check.y)) > 0.08:
			fail("incorrect terrace floor height on " + str(check.name))
			return
		if check.has("x") and abs(contact.position.x - float(check.x)) > 0.08:
			fail("shield wall X moved")
			return
		if check.has("z") and abs(contact.position.z - float(check.z)) > 0.08:
			fail("shield wall Z moved")
			return
	# Dense physical bands cover the length and jump-height body band of both
	# retaining walls, not merely a single center ray. Probe their endcaps too.
	for i in range(17):
		var x := -110.0 + float(i) * 2.0
		for height: float in [6.5, 7.8, 9.25]:
			var contact := ray(space, Vector3(x,height,-100), Vector3(x,height,-102))
			result.wallBands.append({"wall":"south-sw", "x":x, "y":height, "hit":str(contact.get("position", "none"))})
			if contact.is_empty() or abs(contact.position.z + 101.0) > .08:
				fail("south retaining wall gap in ordinary jump/body band: " + str([x,height]))
				return
	for i in range(9):
		var z := -94.0 + float(i)
		for height: float in [0.5, 1.8, 3.25]:
			var contact := ray(space, Vector3(102,height,z), Vector3(104,height,z))
			result.wallBands.append({"wall":"east-se", "z":z, "y":height, "hit":str(contact.get("position", "none"))})
			if contact.is_empty() or abs(contact.position.x - 103.0) > .08:
				fail("east retaining wall gap in ordinary jump/body band: " + str([z,height]))
				return
	for x: float in [-113.0, -75.0]:
		var contact := ray(space, Vector3(x,7.2,-100), Vector3(x,7.2,-102))
		result.wallEnds.append({"wall":"south-sw", "x":x, "contact":str(contact.get("position", "none"))})
		if not contact.is_empty():
			fail("south retaining wall extends beyond declared end or adjacent authority blocks approach: " + str(x))
			return
	for z: float in [-96.0, -84.0]:
		var contact := ray(space, Vector3(102,1.2,z), Vector3(104,1.2,z))
		result.wallEnds.append({"wall":"east-se", "z":z, "contact":str(contact.get("position", "none"))})
		if not contact.is_empty():
			fail("east retaining wall extends beyond declared end or adjacent authority blocks approach: " + str(z))
			return
	# Full-size finite body at actual spawn/objective anchors and near terraces.
	# Radius .52 includes nominal .42 collision radius + .05 bevel + margin.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.52
	capsule.height = 1.8
	var points: Array = []
	for spawn: Dictionary in data.spawnPoints: points.append({"name": "spawn", "point": spawn})
	for objective: Dictionary in data.arena.objectiveZones: points.append({"name": "objective", "point": objective})
	for entry: Dictionary in [{"x": -94, "y": 6, "z": -96}, {"x": 91, "y": 0, "z": -90}]:
		points.append({"name": "service-terrace", "point": entry})
	var route := json_at(HERE + "probes.json")
	if route.get("geometryHash") != IDENTITY or route.get("points", []).size() != 501:
		fail("501-point corrective route probe fixture missing")
		return
	for point: Dictionary in route.points: points.append({"name":"route", "point":point})
	for entry: Dictionary in points:
		var point: Dictionary = entry.point
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.transform = Transform3D(Basis.IDENTITY, Vector3(float(point.x), float(point.y) + 0.95, float(point.z)))
		q.margin = 0.001
		var overlaps := space.intersect_shape(q, 16)
		result.clearances.append({"name": entry.name, "point": point, "overlapCount": overlaps.size()})
		if not overlaps.is_empty():
			fail("finite-radius spawn/objective/terrace overlaps authority at " + str(point))
			return
	result.status = "imported art + corrected WorldMap physics + candidate Binder checks passed; host and finish pending"
	result.geometryHash = IDENTITY
	result.dressing = dressed
	result.artMeshes = art.find_children("*", "MeshInstance3D", true, false).size()
	result.pending = ["exterior falls/special traversal and hosted controller journeys", "production weather/finish"]
	finish(0)
