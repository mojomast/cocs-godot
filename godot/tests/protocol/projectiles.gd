extends SceneTree

const Projectiles = preload("res://world/projectiles.gd")
const Combat = preload("res://world/combat_feedback.gd")
const Client = preload("res://net/client.gd")
const Session = preload("res://world/session.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func rocket(id: int, pos: Vector3, dir: Vector3, weapon: int = 1) -> Dictionary:
	return {"id":id,"owner":0,"weapon":weapon,"pos":{"x":pos.x,"y":pos.y,"z":pos.z},"dir":{"x":dir.x,"y":dir.y,"z":dir.z}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var combat := Combat.new()
	root.add_child(combat)
	combat.set_process(false)
	var first := rocket(17, Vector3(1,2,3), Vector3.FORWARD)
	combat.apply_state({"rockets":[first, rocket(23, Vector3(-4,3,-10), Vector3.RIGHT)]})
	var visuals: Node3D = combat.projectiles
	var node: MeshInstance3D = visuals.markers[17]
	var instance := node.get_instance_id()
	check(node.position == Vector3(1,2,3) and -node.basis.z == Vector3.FORWARD, "source position and -Z rocket axis")
	check(visuals.markers[23].position == Vector3(-4,3,-10) and -visuals.markers[23].basis.z == Vector3.RIGHT, "independent crossing trajectory")
	for direction: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3(1,2,-3).normalized(), Vector3.LEFT]:
		combat.apply_state({"rockets":[rocket(17, Vector3(3,4,5), direction)]})
		check(node.get_instance_id() == instance and node.position == Vector3(3,4,5) and (-node.basis.z).is_equal_approx(direction), "same identity follows curved/vertical source direction without allocation")
	check(not visuals.markers.has(23), "absent projectile removed")
	combat.apply_state({"rockets":[rocket(17, Vector3.ZERO, Vector3.UP, 5)]})
	check(node.mesh == visuals.generic_mesh, "non-rocket projectiles remain visible and distinct")
	var removed: WeakRef = weakref(node)
	combat.apply_state({"rockets":[]})
	check(removed.get_ref() == null and combat.blasts.is_empty() and combat.hits == 0, "disappearance frees node without inventing explosion/damage")
	var invalid: Array = [null, 5, {}, rocket(1, Vector3(INF,0,0), Vector3.UP), rocket(2, Vector3.ZERO, Vector3.ZERO)]
	for field: String in ["id", "owner", "weapon", "pos", "dir"]:
		var bad := first.duplicate(true)
		bad[field] = null
		invalid.append(bad)
	for id: Variant in [false, "17", 0.5, -1, NAN]:
		var bad := first.duplicate(true)
		bad.id = id
		invalid.append(bad)
	combat.apply_state({"rockets":invalid})
	check(visuals.markers.is_empty(), "malformed rows cannot alias identity zero or poison transforms")
	combat.apply_state({"rockets":[first, rocket(17, Vector3(100,0,0), Vector3.UP)]})
	check(visuals.markers.size() == 1 and visuals.markers[17].position == Vector3(1,2,3), "duplicate ID first valid sample wins")
	var many: Array = []
	for id: int in range(700): many.append(rocket(id, Vector3.ZERO, Vector3.FORWARD))
	combat.apply_state({"rockets":many})
	check(visuals.markers.size() == Projectiles.MAX_PROJECTILES and visuals.get_child_count() == Projectiles.MAX_PROJECTILES, "bounded mesh ownership under saturation")
	combat.apply_state({"rockets":null})
	check(visuals.markers.is_empty(), "malformed collection clears stale flight")
	var client := Client.new()
	client.events.connect(func(items: Array) -> void: combat.apply_events(items, 0))
	var launch := {"id":10,"type":"launch","actor":0,"weapon":1,"pos":{"x":1,"y":2,"z":3}}
	var explosion := {"id":11,"type":"explosion","weapon":1,"pos":{"x":4,"y":2,"z":3}}
	var packet := JSON.stringify({"type":"events","items":[launch,explosion]})
	check(client.decode_text(packet), "real event schema accepted")
	check(combat.launches == 1 and combat.local_launches == 1 and combat.shots == 0 and combat.tracers.is_empty(), "launch counted separately without self-tracer")
	check(combat.explosions == 1 and combat.blasts[0].node.position == Vector3(4,2,3) and combat.hits == 0 and combat.hurts == 0, "actorless source explosion at exact position without inferred hit")
	check(client.decode_text(packet) and combat.launches == 1 and combat.blasts.size() == 1, "network dedup prevents duplicate feedback")
	check(combat.audio_feedback._last_play_usec.has("launch") and combat.audio_feedback._last_play_usec.has("explosion") and not combat.audio_feedback._last_play_usec.has("shot"), "real launch/explosion cues without duplicate shot audio")
	await create_timer(0.35).timeout
	combat.audio_feedback.set_muted(true)
	combat.apply_events([null, 3, {"type":"launch","actor":null,"weapon":1,"pos":launch.pos}, {"type":"explosion","pos":{"x":NAN,"y":0,"z":0}}], 0)
	check(combat.launches == 1 and combat.explosions == 1, "malformed event fields ignored")
	combat.advance(0.16)
	check(combat.blasts[0].node.scale.x > 0.18, "brief authoritative flash expands")
	combat.advance(0.2)
	check(combat.blasts.is_empty(), "flash expires")
	for index: int in range(100): combat.apply_events([explosion], 0)
	check(combat.blasts.size() == Combat.MAX_BLASTS, "bounded explosion burst")
	combat.apply_state({"rockets":[first]})
	combat.clear_round()
	check(visuals.markers.is_empty() and combat.blasts.is_empty() and combat.launches == 0 and combat.local_launches == 0 and combat.explosions == 0, "round reset clears all projectile ownership/counters")
	combat.apply_state({"rockets":[first],"over":true})
	check(visuals.markers.is_empty(), "results never leave active projectiles")
	combat.apply_state({"rockets":[first]})
	var owned: WeakRef = weakref(visuals.markers[17])
	combat.free()
	check(owned.get_ref() == null, "free during flight releases owned mesh nodes")
	client.free()
	# Detached shipped-session boundary methods, preserving weapon controls.
	var session := Session.new()
	for child: Node in [session.camera,session.label,session.selector,session.client,session.presentation,session.pickups,session.combat,session.combat_label,session.environment,session.sun]: session.add_child(child)
	session.combat.apply_state({"rockets":[first]})
	session.on_started({})
	check(session.combat.projectiles.markers.is_empty(), "actual session round-start reset")
	session.combat.apply_state({"rockets":[first]})
	session.on_error("Synthetic projectile teardown")
	check(session.combat.projectiles.markers.is_empty(), "actual session error reset")
	session.free()
	await create_timer(0.1).timeout
	print("PORT_PROJECTILES_OK checks=", checks)
	quit(0)
