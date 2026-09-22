extends SceneTree
## Per-surface impacts: material tables, authority-only confirmation against
## real map geometry (including a recorded server shot), occlusion, dedup,
## pooling, quality switching and drain.
const Impacts = preload("res://player_fx/impacts.gd")
const Surface = preload("res://player_fx/surface.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_IMPACTS: " + message)

func _initialize() -> void: call_deferred("run")

func recorded_shot(id: int) -> Dictionary:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	for record: Dictionary in capture.frames:
		if record.get("direction") != "server": continue
		var frame: Variant = record.get("frame")
		if not frame is Dictionary or frame.get("type") != "events": continue
		for event: Variant in frame.get("items", []):
			if event is Dictionary and event.get("id") == id and event.get("type") == "shot": return event.duplicate(true)
	return {}

func run() -> void:
	# Documented classification tables.
	check(Surface.keyword_family("CrownIceButtress012") == Surface.ICE, "ice collider names classify as ice")
	check(Surface.keyword_family("SaltReachReactorFoundation") == Surface.METAL, "reactor collider names classify as metal")
	check(Surface.keyword_family("ObservatoryPlinth") == Surface.STONE, "observatory plinth classifies as stone")
	check(Surface.keyword_family("TurbineAccessIncline") == Surface.GROUND, "access incline classifies as ground")
	check(Surface.biome_family("snow") == Surface.ICE, "snow biome is ice")
	check(Surface.biome_family("urban") == Surface.METAL, "urban biome is metal")
	check(Surface.biome_family("volcanic") == Surface.STONE, "volcanic biome is stone")
	check(Surface.kind_family("tree") == Surface.GROUND, "tree blocks are ground")
	check(Surface.map_default("aurora-basin") == Surface.ICE and Surface.map_default("prism-foundry") == Surface.METAL, "native map defaults")
	check(Surface.classify({}, "UnknownPart", "", false) == Surface.STONE, "unknown surface falls back to neutral stone")
	check(Surface.classify({"biome": "urban"}, "", "", true) == Surface.GROUND, "unnamed walkable face is ground")
	check(Surface.classify({"biome": "urban"}, "IceButtress", "", false) == Surface.ICE, "explicit name beats biome")

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(24, 2.0, -22)
	camera.look_at(Vector3(29.654, 0.6, -30.069))
	var impacts: Node3D = Impacts.new()
	root.add_child(impacts)
	var catalog := Occlusion.Catalog.new()
	check(catalog.open(), "catalog opens")
	var map: Dictionary = catalog.resolve_map("meridian-exchange")
	var query := Occlusion.new()
	check(query.configure(camera, map), "semantic map configured")
	impacts.configure(camera, query)
	impacts.set_map(map)

	# A real recorded server shot whose endpoint lands on real map geometry.
	var recorded: Dictionary = recorded_shot(164)
	check(not recorded.is_empty() and recorded.get("hit") == false, "recorded server shot loaded")
	impacts.consume([recorded], 0)
	check(int(impacts.counters.shown) == 1, "recorded wall shot draws one confirmed impact")
	check(impacts.last_family == Surface.GROUND, "foundation top face is ground material")
	impacts.consume([recorded], 0)
	check(int(impacts.counters.shown) == 1 and int(impacts.counters.deduped) == 1, "recorded public ID never duplicates")
	impacts.advance(1.0)
	check(impacts.snapshot().active == 0, "impact expires")

	# Authority-only: no geometry at the endpoint, actor hits, legacy-owned cues.
	var air: Dictionary = {"id": 900, "type": "shot", "actor": 3, "hit": false, "from": {"x": 0, "y": 40, "z": 0}, "to": {"x": 0, "y": 60, "z": 0}}
	impacts.consume([air], 0)
	check(int(impacts.counters.shown) == 1 and int(impacts.counters.no_geometry) == 1, "open-air endpoint never fabricates an impact")
	var actor_hit: Dictionary = {"id": 901, "type": "shot", "actor": 3, "hit": 1, "from": {"x": 0, "y": 2, "z": -22}, "to": {"x": 29.654, "y": 0.6, "z": -30.069}}
	impacts.consume([actor_hit], 0)
	check(int(impacts.counters.actor_hits) == 1, "actor hits are not surface impacts")
	var legacy: Dictionary = {"id": 902, "type": "shot", "actor": 3, "hit": false, "surface_hit": true, "normal": {"x": 0, "y": 1, "z": 0}, "from": {"x": 0, "y": 2, "z": -22}, "to": {"x": 29.654, "y": 0.6, "z": -30.069}}
	impacts.consume([legacy], 0)
	check(int(impacts.counters.legacy) == 1, "legacy surface_hit cue is left to the weapon-effects owner")
	impacts.consume([{"id": 903, "type": "shot", "actor": 3, "hit": false, "from": {"x": 0}, "to": null}], 0)
	check(int(impacts.counters.shown) == 1, "malformed geometry skipped")

	# Occlusion: a wall between the camera and the confirmed endpoint hides it.
	var blocks := [
		{"x": 0, "z": 0, "w": 10, "h": 5, "d": 1, "kind": "building"},
		{"x": 0, "z": 6, "w": 10, "h": 5, "d": 1, "kind": "building"}]
	var wall_map: Dictionary = {"id": "fixture", "blocks": blocks}
	var wall_query := Occlusion.new()
	check(wall_query.configure(camera, wall_map), "occlusion fixture configured")
	camera.position = Vector3(0, 2.5, -5)
	camera.look_at(Vector3(0, 2.5, 6))
	impacts.configure(camera, wall_query)
	impacts.set_map(wall_map)
	var behind_wall: Dictionary = {"id": 904, "type": "shot", "actor": 3, "hit": false, "from": {"x": 0, "y": 2.5, "z": -2}, "to": {"x": 0, "y": 2.5, "z": 5.5}}
	impacts.consume([behind_wall], 0)
	check(int(impacts.counters.occluded) == 1 and int(impacts.counters.shown) == 1, "occluded endpoint is skipped")
	# The same confirmed endpoint is visible from the wall's own side.
	camera.position = Vector3(0, 2.5, 4)
	camera.look_at(Vector3(0, 2.5, 10))
	var visible_shot: Dictionary = behind_wall.duplicate(true)
	visible_shot.id = 905
	impacts.consume([visible_shot], 0)
	check(int(impacts.counters.shown) == 2, "confirmed endpoint in view draws")
	# A viewer facing away still never draws a cue behind itself.
	camera.position = Vector3(0, 2.5, 8)
	camera.look_at(Vector3(0, 2.5, 20))
	var behind_viewer: Dictionary = behind_wall.duplicate(true)
	behind_viewer.id = 906
	impacts.consume([behind_viewer], 0)
	check(int(impacts.counters.occluded) == 2, "endpoint behind the viewer is skipped")

	# Bounded pool and drop accounting at Extreme.
	impacts.reset()
	camera.position = Vector3(0, 2.5, 4)
	camera.look_at(Vector3(0, 2.5, 10))
	impacts.set_quality(2)
	for index in range(60):
		var shot := {"id": 1000 + index, "type": "shot", "actor": 3, "hit": false,
			"from": {"x": 0, "y": 2.5, "z": -2}, "to": {"x": 0, "y": 2.5, "z": 5.5}}
		impacts.consume([shot], 0)
	check(impacts.snapshot().pool <= impacts.limit(), "pool stays bounded")
	check(int(impacts.counters.dropped) > 0, "excess impacts are dropped, not leaked")

	# F9 quality switching shrinks the pool and the dust layer without leaking.
	var before: int = impacts.snapshot().pool
	impacts.set_quality(0)
	check(impacts.limit() == 6 and impacts.snapshot().pool <= 6, "Low quality caps the impact pool")
	check(int(impacts.snapshot().pool) <= before, "quality shrink releases pooled slots")
	for effect: Dictionary in impacts.effects:
		check(not effect.dust.visible, "Low quality hides the dust layer")
	impacts.set_quality(1)
	check(impacts.limit() == 12, "High quality restores the pool")

	# Drain and replay.
	impacts.reset()
	check(impacts.snapshot().active == 0, "reset drains active impacts")
	var replay: Dictionary = {"id": 101, "type": "shot", "actor": 3, "hit": false,
		"from": {"x": 0, "y": 2.5, "z": -2}, "to": {"x": 0, "y": 2.5, "z": 5.5}}
	impacts.consume([replay], 0)
	check(int(impacts.counters.shown) == 1 and impacts.snapshot().active == 1, "fresh visible shot draws")
	impacts.reset()
	check(impacts.snapshot().active == 0 and impacts.seen.is_empty(), "reset permits a fresh round's reused IDs")
	impacts.consume([replay], 0)
	check(int(impacts.counters.shown) == 1, "reused ID accepted once after reset")

	impacts.free()
	camera.free()
	if failures.is_empty():
		print("PLAYER_FX_IMPACTS_OK checks=", checks)
	else:
		print("PLAYER_FX_IMPACTS_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
