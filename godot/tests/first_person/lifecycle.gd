extends SceneTree
const Rig = preload("res://first_person/rig.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error(text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var actor := {"id":7, "weapon":0, "health":100, "vx":2, "vz":1}
	rig.apply_actor(actor, true)
	rig.advance(0.05)
	check(rig.showing and rig.current_weapon == 0, "alive local actor shown")
	check(rig.viewport.world_3d != camera.get_world_3d(), "world depth and wall clipping isolated")
	check(rig.weapon_camera.fov == camera.fov, "source FOV aligned")
	var before := rig.weapon.get_instance_id()
	for i: int in 1000: rig.apply_actor(actor, true)
	check(rig.weapon.get_instance_id() == before and rig.build_count == 1, "snapshot path retains geometry")
	var shot := {"id":12, "time":1.0, "actor":7, "weapon":0, "type":"shot"}
	rig.apply_events([shot], 7)
	check(rig.recoil_count == 1 and rig.recoil > 0, "source shot recoils")
	for i: int in 100: rig.apply_events([shot], 7)
	check(rig.recoil_count == 1, "replayed snapshot events do not repeat recoil")
	var pellet := shot.duplicate()
	pellet.id = 13
	rig.apply_events([pellet], 7)
	check(rig.recoil_count == 1, "pellet volley produces one kick")
	var next_volley := shot.duplicate()
	next_volley.id = 17
	next_volley.time = 1.1
	rig.apply_events([next_volley], 7)
	pellet.id = 18
	rig.apply_events([pellet], 7)
	check(rig.recoil_count == 2, "interleaved late pellet does not repeat an older volley")
	pellet.time = 1.2
	pellet.id = 14
	pellet.shrapnel = 0
	rig.apply_events([pellet], 7)
	check(rig.recoil_count == 2, "secondary shrapnel is not muzzle fire")
	rig.apply_events([{"id":15,"time":2.0,"actor":8,"weapon":0,"type":"shot"}, {"type":"damage","actor":7,"source":8}, {"id":null,"time":2,"actor":7,"weapon":0,"type":"shot"}], 7)
	check(rig.recoil_count == 2, "remote/damage/malformed events ignored")
	var melee := {"id":21,"time":2.1,"actor":7,"hit":8,"type":"melee"}
	rig.apply_events([melee], 7)
	rig.advance(0.04)
	check(rig.kick_count == 1 and rig.kick_leg.visible and rig.kick_leg.get_node("Boot") is MeshInstance3D,
		"accepted source melee swings a visible modeled boot")
	check(rig.kick_leg.position.y > -0.68 and rig.kick_leg.position.z < -0.58,
		"the foot extends forward from below the camera")
	rig.apply_events([melee, {"id":22,"time":2.2,"actor":8,"type":"melee"}], 7)
	check(rig.kick_count == 1, "replayed and remote melee never animate a local attack")
	rig.advance(0.20)
	check(not rig.kick_leg.visible, "fast kick returns in under a quarter second")
	rig.apply_events([{"id":23,"time":2.7,"actor":7,"hit":null,"type":"melee"}], 7)
	check(rig.kick_count == 2, "another source-approved kick is visible on the next cooldown")
	for field: String in ["dead", "spectating", "health", "vehicleId"]:
		var hidden := actor.duplicate()
		hidden[field] = 0 if field == "health" else 3 if field == "vehicleId" else true
		rig.apply_actor(hidden, true)
		check(not rig.showing and rig.recoil == 0 and not rig.flash.visible and not rig.kick_leg.visible, "hidden on " + field)
		rig.apply_actor(actor, true)
	rig.apply_actor(actor, false)
	shot.id = 20
	shot.time = 3.0
	rig.apply_events([shot], 7)
	rig.apply_actor(actor, true)
	rig.apply_events([shot], 7)
	check(rig.recoil_count == 2, "can_show focus/stale gate consumes events without replay")
	var bounds: Dictionary = {}
	for id: int in 10:
		actor.weapon = id
		rig.apply_actor(actor, true)
		rig.advance(0.05)
		var meshes := rig.weapon.find_children("*", "MeshInstance3D")
		check(meshes.size() <= 11 and meshes.size() >= 8, "bounded weapon instances %d" % id)
		check(rig.pivot.get_child_count() == 3, "one live weapon assembly %d" % id)
		var combined := AABB()
		for mesh: MeshInstance3D in meshes:
			var box: AABB = rig.weapon.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			combined = combined.merge(box)
		check(combined.size.length() < 1.6 and combined.size.z > 0.8, "source dimensions bounded %d" % id)
		bounds[str(combined)] = true
	check(bounds.size() == 10, "ten different authored silhouette envelopes")
	check(rig.scenes.size() == 10, "resource cache bounded to ten")
	actor.weapon = 3
	actor.reloading = true
	actor.reloadDuration = 2.0
	actor.reloadTimer = 1.0
	rig.apply_actor(actor, true)
	rig.advance(0.05)
	check(rig.parts.has("barrel-assembly") and rig.parts["barrel-assembly"].rotation.x > 0.2, "authoritative reload opens source hinge")
	actor.reloading = false
	rig.apply_actor(actor, true)
	rig.advance(0.05)
	check(rig.parts["barrel-assembly"].transform == rig.rest["barrel-assembly"], "reload ends only from snapshot flag")
	var other := Rig.new()
	root.add_child(other)
	other.attach_to(camera)
	other.apply_actor(actor, true)
	other.set_process(false)
	var a: MeshInstance3D = rig.weapon.find_children("*", "MeshInstance3D")[0]
	var b: MeshInstance3D = other.weapon.find_children("*", "MeshInstance3D")[0]
	check(a.mesh == b.mesh, "immutable geometry shared between rigs")
	check(a.get_surface_override_material(0) != b.get_surface_override_material(0), "mutable materials isolated between rigs")
	var old_color: Color = b.get_surface_override_material(0).albedo_color
	a.get_surface_override_material(0).albedo_color = Color.RED
	check(b.get_surface_override_material(0).albedo_color == old_color, "material changes cannot leak")
	var aim := camera.transform
	rig.apply_look_delta(Vector2(500, -500))
	rig.advance(0.05)
	check(camera.transform == aim and rig.look_lag.length() < 0.04, "sway bounded and aim untouched")
	for i: int in 5000:
		rig.apply_events([{"id":100+i,"time":10.0+i,"actor":8,"weapon":0,"type":"shot"}], 7)
	check(rig.seen.size() == 4096, "event memory bounded")
	var count := rig.recoil_count
	shot.time = 1.0
	shot.id = 12
	shot.weapon = 3
	rig.apply_events([shot],7)
	check(rig.recoil_count == count, "expired old event cannot replay after bounded-cache eviction")
	rig.reset()
	check(not rig.showing and rig.seen.is_empty() and rig.recoil == 0 and rig.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "round/disconnect reset complete")
	rig.apply_actor(actor,true)
	rig.apply_events([shot],7)
	check(rig.recoil_count == 1, "new round can reuse event IDs and times after explicit reset")
	rig.free()
	other.free()
	camera.free()
	print("FIRST_PERSON_LIFECYCLE ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
