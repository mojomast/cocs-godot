class_name PortPresentation
extends Node3D

# Native visual actors only. Node simulation remains authoritative; no extrapolation.
const ActorVisual = preload("res://source_operators/operator_visual.gd")
const RemoteMotion = preload("res://world/remote_motion.gd")
const LocalLifecycle = preload("res://world/local_lifecycle.gd")
const MeleeEvents = preload("res://source_operators/melee_events.gd")
var melee_events := MeleeEvents.new()
var melee_client: Node
var melee_feedback: Node
var lifecycle := LocalLifecycle.new()
var motion := RemoteMotion.new()
var interpolate_remote: bool = false
## Route-owned factory: (actor, local_id) -> Node3D. Empty retains source visuals.
var actor_visual_factory: Callable
var local_actor_id: int = -1
var actors: Dictionary = {}
var rendered_remote_poses: int = 0
var last_shots: Dictionary = {}
var current_pose_npcs: Dictionary = {}
signal render_frame(now: float)

func _ready() -> void:
	# Several standalone world routes override Session._ready. Bind the common
	# presentation recipient once so those routes inherit the same pose bridge.
	var host := get_parent()
	if host != null and "client" in host:
		bind_melee_events(host.client,host.combat if "combat" in host else null)

func bind_melee_events(client: Node, feedback: Node = null) -> void:
	if melee_client == client:
		melee_feedback = feedback
		return
	_unbind_melee_events()
	if not is_instance_valid(client) or not client.has_signal("events"): return
	melee_client = client
	melee_feedback = feedback
	melee_client.connect("events",_on_melee_events)

func _unbind_melee_events() -> void:
	if is_instance_valid(melee_client) and melee_client.is_connected("events",_on_melee_events):
		melee_client.disconnect("events",_on_melee_events)
	melee_client = null
	melee_feedback = null

func _exit_tree() -> void:
	_unbind_melee_events()

func _on_melee_events(items: Array) -> void:
	var host := get_parent()
	var active: bool = host == null or not ("phase" in host) or host.phase in [3,"active"]
	# Read the common activity predicate without playing or flushing any effects.
	if is_instance_valid(melee_feedback) and melee_feedback.has_method("_allowed"):
		active = active and melee_feedback._allowed()
	apply_events(items,active)

func _process(_delta: float) -> void:
	melee_events.advance(_delta)
	var now: float = Time.get_ticks_usec() / 1000000.0
	# Shared render clock also serves local translation in sessions whose own
	# _process is overridden (notably Horde). No simulation state is advanced.
	render_frame.emit(now)
	if not interpolate_remote: return
	for id: int in actors:
		if id == local_actor_id or current_pose_npcs.has(id): continue
		var pose: Dictionary = motion.sample(id, now)
		if pose.is_empty(): continue
		actors[id].position = pose.position
		actors[id].rotation.y = pose.yaw
		rendered_remote_poses += 1
var local_actor: Dictionary = {}
var hud_text: String = "Waiting for authoritative snapshot"
var applied: int = 0

func clear_round() -> void:
	melee_events.interrupt(actors)
	melee_events.clear()
	lifecycle.clear()
	motion.clear()
	local_actor_id = -1
	rendered_remote_poses = 0
	last_shots.clear()
	current_pose_npcs.clear()
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
	current_pose_npcs.clear()
	var solo: bool = str(state.get("config", {}).get("mode", "")) in ["campaign", "horde"]
	for actor: Dictionary in state.get("actors", []):
		var id: int = int(actor.id)
		# Local authoritative solo targets must not trail their collision by 100ms.
		if solo and actor.get("isNpc") == true: current_pose_npcs[id] = true
		present[id] = true
		if not actors.has(id):
			var node: Node3D = actor_visual_factory.call(actor, local_id) if actor_visual_factory.is_valid() else ActorVisual.new()
			node.name = "Actor_%d" % id
			if "local_id" in node: node.local_id = local_id
			add_child(node)
			actors[id] = node
		var visual: Node3D = actors[id]
		if "local_id" in visual: visual.local_id = local_id
		# Snapshot-driven source pose; the host still owns position and body yaw.
		visual.apply_actor(actor)
		var position: Vector3 = Vector3(actor.x, actor.y + 0.9, actor.z)
		var body_yaw: float = float(actor.get("bodyYaw", actor.get("yaw", 0)))
		var alive: bool = LocalLifecycle.actor_alive(actor)
		motion.ingest(id, position, body_yaw, alive, now)
		var pose: Dictionary = motion.sample(id, now)
		var delayed: bool = interpolate_remote and id != local_id and not current_pose_npcs.has(id)
		visual.position = pose.position if delayed else position
		visual.rotation.y = pose.yaw if delayed else body_yaw
		# Opt-in visuals may finish a bounded cosmetic collapse. They own expiry
		# between snapshots; source actors retain immediate death hiding.
		var death_pose: bool = not alive and visual.has_method("wants_death_pose") and visual.wants_death_pose()
		visual.visible = id != local_id and (alive or death_pose)
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
	melee_events.observe(state,actors,local_actor_id)
	if local_actor.is_empty():
		hud_text = "Local actor absent — waiting"
	else:
		var a: Dictionary = local_actor
		var weapon: int = int(a.get("weapon", 0))
		var ammo: Array = a.get("ammo", [])
		var rounds: String = str(ammo[weapon]) if weapon >= 0 and weapon < ammo.size() else "?"
		hud_text = "%s | HP %s | Armor %s | Weapon %d | Ammo %s\nFrags %s · Deaths %s | %s" % [state.get("mapName", state.get("mapId", "")), a.get("health", 0), a.get("armor", 0), weapon, rounds, a.get("frags", 0), a.get("deaths", 0), lifecycle.label()]
	applied += 1

func apply_events(items: Array, active: bool = true) -> void:
	melee_events.consume(items,actors,local_actor_id,active)

func interrupt_melee() -> void:
	melee_events.interrupt(actors)

func set_melee_clock(time: float) -> void:
	for visual: Node in actors.values():
		if is_instance_valid(visual) and visual.has_method("set_world_melee_clock"): visual.set_world_melee_clock(time)

func eye_position() -> Vector3:
	return Vector3(local_actor.get("x", 0), float(local_actor.get("y", 0)) + float(local_actor.get("eyeHeight", 1.45)), local_actor.get("z", 0))
