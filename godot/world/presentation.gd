class_name PortPresentation
extends Node3D

# Native visual actors only. Node simulation remains authoritative; no extrapolation.
const ActorVisual = preload("res://source_operators/operator_visual.gd")
const RemoteMotion = preload("res://world/remote_motion.gd")
const LocalLifecycle = preload("res://world/local_lifecycle.gd")
var lifecycle := LocalLifecycle.new()
var motion := RemoteMotion.new()
var interpolate_remote: bool = false
var local_actor_id: int = -1
var actors: Dictionary = {}
var rendered_remote_poses: int = 0
var last_shots: Dictionary = {}
signal render_frame(now: float)

func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_usec() / 1000000.0
	# Shared render clock also serves local translation in sessions whose own
	# _process is overridden (notably Horde). No simulation state is advanced.
	render_frame.emit(now)
	if not interpolate_remote: return
	for id: int in actors:
		if id == local_actor_id: continue
		var pose: Dictionary = motion.sample(id, now)
		if pose.is_empty(): continue
		actors[id].position = pose.position
		actors[id].rotation.y = pose.yaw
		rendered_remote_poses += 1
var local_actor: Dictionary = {}
var hud_text: String = "Waiting for authoritative snapshot"
var applied: int = 0

func clear_round() -> void:
	lifecycle.clear()
	motion.clear()
	local_actor_id = -1
	rendered_remote_poses = 0
	last_shots.clear()
	for node: Node3D in actors.values():
		remove_child(node)
		node.free()
	actors.clear()
	local_actor = {}
	hud_text = "Waiting for authoritative snapshot"
	applied = 0

func apply_state(state: Dictionary, local_id: int) -> void:
	local_actor_id = local_id
	var now: float = Time.get_ticks_usec() / 1000000.0
	var present: Dictionary = {}
	local_actor = {}
	for actor: Dictionary in state.get("actors", []):
		var id: int = int(actor.id)
		present[id] = true
		if not actors.has(id):
			var node := ActorVisual.new()
			node.name = "Actor_%d" % id
			node.local_id = local_id
			add_child(node)
			actors[id] = node
		var visual: Node3D = actors[id]
		visual.local_id = local_id
		# Snapshot-driven source pose; the host still owns position and body yaw.
		visual.apply_actor(actor)
		var position: Vector3 = Vector3(actor.x, actor.y + 0.9, actor.z)
		var body_yaw: float = float(actor.get("bodyYaw", actor.get("yaw", 0)))
		var alive: bool = LocalLifecycle.actor_alive(actor)
		motion.ingest(id, position, body_yaw, alive, now)
		var pose: Dictionary = motion.sample(id, now)
		visual.position = pose.position if interpolate_remote and id != local_id else position
		visual.rotation.y = pose.yaw if interpolate_remote and id != local_id else body_yaw
		visual.visible = id != local_id and alive
		# Recoil only on genuine increasing authoritative shot counts, never on
		# round resets or snapshot reordering.
		var shots: int = int(actor.get("shots", 0))
		if id != local_id and alive and last_shots.has(id):
			var delta: int = shots - int(last_shots[id])
			if delta > 0: visual.kick(minf(2.0, float(delta)))
		last_shots[id] = shots
		if id == local_id: local_actor = actor.duplicate(true)
	for id: int in actors.keys():
		if not present.has(id):
			var node: Node3D = actors[id]
			remove_child(node)
			node.free()
			actors.erase(id)
			motion.tracks.erase(id)
			last_shots.erase(id)
	lifecycle.apply(local_actor, bool(state.get("over", false)))
	if local_actor.is_empty():
		hud_text = "Local actor absent — waiting"
	else:
		var a: Dictionary = local_actor
		var weapon: int = int(a.get("weapon", 0))
		var ammo: Array = a.get("ammo", [])
		var rounds: String = str(ammo[weapon]) if weapon >= 0 and weapon < ammo.size() else "?"
		hud_text = "%s | HP %s | Armor %s | Weapon %d | Ammo %s\nFrags %s · Deaths %s | %s" % [state.get("mapName", state.get("mapId", "")), a.get("health", 0), a.get("armor", 0), weapon, rounds, a.get("frags", 0), a.get("deaths", 0), lifecycle.label()]
	applied += 1

func eye_position() -> Vector3:
	return Vector3(local_actor.get("x", 0), float(local_actor.get("y", 0)) + float(local_actor.get("eyeHeight", 1.45)), local_actor.get("z", 0))
