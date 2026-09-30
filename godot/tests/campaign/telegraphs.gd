extends SceneTree
const Telegraphs = preload("res://campaign/telegraphs.gd")
var checks: int = 0
var failures: int = 0

class Slope extends Node3D:
	func height_at(x: float, z: float) -> float:
		return 7.0 + 0.2 * x - 0.15 * z

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func actor(id: int = 1) -> Dictionary:
	return {"id":id, "health":100, "artilleryWindup":1.2, "artilleryMark":{"x":10.0,"z":-4.0}}

func event(id: int = 1, who: int = 1, time: float = 10.0) -> Dictionary:
	return {"id":id,"type":"enemy-telegraph","kind":"artillery","actor":who,"time":time,"x":10.0,"z":-4.0,"radius":5.5,"duration":1.2}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var terrain := Slope.new()
	root.add_child(terrain)
	var view := Telegraphs.new()
	root.add_child(view)
	view.bind_terrain(terrain)
	view.apply_events([event()])
	check(view.get_child_count() == 0, "no render before corresponding actor snapshot")
	view.apply_state({"time":10.0,"actors":[actor()]})
	check(view.rings.size() == 1 and view.get_child_count() == 1, "event-before-state creates targeted warning")
	var mesh: MeshInstance3D = view.rings["1:artillery"].node
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_radius: float = 0
	var terrain_error: float = 0
	for vertex: Vector3 in vertices:
		max_radius = maxf(max_radius, Vector2(vertex.x - 10, vertex.z + 4).length())
		terrain_error = maxf(terrain_error, absf(vertex.y - terrain.height_at(vertex.x, vertex.z) - 0.055))
	check(absf(max_radius - 5.5) < 0.001, "event radius and source mark respected")
	check(terrain_error < 0.001, "every circumference/icon vertex follows nonzero sloped terrain")
	view.apply_events([event()])
	check(view.get_child_count() == 1, "duplicate event is idempotent")
	var old_mesh: int = mesh.mesh.get_instance_id()
	await create_timer(0.05).timeout
	check(view.authority_time == 10.0 and mesh.mesh.get_instance_id() == old_mesh, "wall clock cannot advance or trigger attack")
	view.apply_state({"time":10.6,"actors":[actor()]})
	check(mesh.mesh.get_instance_id() != old_mesh, "authority clock updates value/pulse arc")
	view.apply_state({"time":9.0,"actors":[]})
	check(view.rings.size() == 1 and view.authority_time == 10.6, "older snapshot cannot rewind or cancel current cue")
	var cancelled: Dictionary = actor()
	cancelled.erase("artilleryWindup")
	view.apply_state({"time":10.7,"actors":[cancelled]})
	check(view.rings.is_empty(), "cancelled source windup removes warning")
	var impact: Dictionary = event(2, 1, 10.7)
	impact.type = "enemy-artillery"
	view.apply_events([impact])
	check(view.rings.size() == 1 and view.rings["1:artillery"].flash, "confirmed source event alone supplies impact flash")
	view.apply_state({"time":10.93,"actors":[cancelled]})
	check(view.rings.is_empty(), "flash expires on authority clock")
	view.clear_round()
	view.apply_state({"time":10.0,"actors":[actor()]})
	view.apply_events([event()])
	check(view.rings.size() == 1, "clear permits reused event IDs and state-before-event")
	var changed: Dictionary = actor()
	changed.artilleryMark.x = 20
	view.apply_state({"time":10.1,"actors":[changed]})
	check(view.rings.is_empty(), "stale event cannot draw old target after mark changes")
	view.clear_round()
	view.apply_state({"time":10.0,"actors":[actor()]})
	view.apply_events([event()])
	var dead: Dictionary = actor()
	dead.health = 0
	view.apply_state({"time":10.1,"actors":[dead]})
	check(view.rings.is_empty(), "dead source cancels warning")
	view.clear_round()
	view.apply_state({"time":10.0,"actors":[actor()]})
	view.apply_events([event()])
	view.apply_state({"time":10.1,"actors":[]})
	check(view.rings.is_empty(), "missing source cancels warning")
	view.clear_round()
	var boss: Dictionary = {"id":1,"health":100,"bossStompWindup":0.8,"bossStompMark":{"x":10,"z":-4}}
	var warning: Dictionary = event()
	warning.kind = "boss"
	warning.radius = 9.0
	view.apply_state({"time":10.0,"actors":[boss]})
	view.apply_events([warning])
	check(view.rings.has("1:boss") and view.rings["1:boss"].radius == 9.0, "boss radius comes from event without guessing phase profile")
	view.apply_state({"time":11.21,"actors":[boss]})
	check(view.rings.is_empty(), "expired event cannot survive stale actor windup")
	view.clear_round()
	var many_actors: Array = []
	var events: Array = []
	for i: int in range(300):
		many_actors.append(actor(i))
		events.append(event(i, i))
	view.apply_state({"time":10.0,"actors":many_actors})
	view.apply_events(events)
	check(view.rings.size() == Telegraphs.MAX_RINGS and view.get_child_count() == Telegraphs.MAX_RINGS, "hostile event volume has bounded rings and meshes")
	check(view.seen.size() <= Telegraphs.MAX_SEEN, "event dedup memory bounded")
	view.clear_round()
	check(view.rings.is_empty() and view.get_child_count() == 0 and view.seen.is_empty() and not view.has_state, "round clear releases all cue and timing state")
	view.apply_state({"time":10.0,"actors":[actor()]})
	var unknown: Dictionary = event()
	unknown.kind = "other"
	view.apply_events([unknown, event(2, 99), {"type":"boss-slam"}])
	check(view.rings.is_empty(), "unknown malformed or absent-source events produce no cue")
	view.free(); terrain.free()
	print("CAMPAIGN_TELEGRAPHS_OK" if failures == 0 else "CAMPAIGN_TELEGRAPHS_FAILED", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
