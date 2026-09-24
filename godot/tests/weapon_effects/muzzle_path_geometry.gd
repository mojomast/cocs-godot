extends SceneTree
## Tracer and projectile-launch visuals originate at the moving physical barrel,
## then converge on the unchanged eye-ray endpoint. Includes projectile alt modes.
const Rig = preload("res://first_person/rig.gd")
const FX = preload("res://weapon_effects/controller.gd")
const Origin = preload("res://weapon_effects/origin.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func point(value: Vector3) -> Dictionary:
	return {"x":value.x, "y":value.y, "z":value.z}

func step(rig: Node, frames: int) -> void:
	for frame: int in frames: rig.advance(1.0 / 60.0)

func run() -> void:
	root.size = Vector2i(1280, 800)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(8, 2, 5)
	camera.rotation = Vector3(-0.12, 0.3, 0.0)
	camera.h_offset = 0.02
	camera.v_offset = -0.01
	world.add_child(camera)
	camera.current = true
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	rig.reduced_motion = true
	var fx := FX.new()
	world.add_child(fx)
	fx.set_process(false)
	fx.attach_rig(rig)
	fx.set_quality(1)
	fx.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false)
	var actor := {"id":7, "health":100, "weapon":0}
	for weapon: int in 10:
		actor.weapon = weapon
		rig.apply_actor(actor, true)
		step(rig, 12)
		for ads: bool in [false, true]:
			fx.reset()
			rig.apply_aim(ads)
			step(rig, 120)
			var start: Vector3 = camera.get_camera_transform() * Vector3(0.24, -0.24, -0.42)
			var end: Vector3 = camera.project_position(Vector2(root.size) * 0.5, 30.0)
			var event := {"type":"shot", "id":weapon * 10 + int(ads) + 1,
				"time":float(weapon * 10 + int(ads) + 1), "actor":7, "weapon":weapon,
				"from":point(start), "to":point(end)}
			var original: Dictionary = event.duplicate(true)
			rig.apply_events([event], 7)
			fx.consume([event], 7, [actor])
			var label := "weapon %d ADS=%s" % [weapon, ads]
			check(event == original, label + " shot authority unchanged")
			check(fx.flashes == rig.get_muzzle_count(), label + " every physical barrel flashes once")
			check(fx.lines.size() == 1, label + " one local tracer per shot")
			for slot: Dictionary in fx.slots:
				if slot.node.visible:
					check(slot.node.get_parent() in rig.anchors.values(), label + " flash attached to a barrel station")
			if fx.lines.is_empty(): continue
			var line: Dictionary = fx.lines[0]
			var mapped: Dictionary = Origin.map_tip(camera, rig.weapon_camera, line.tip)
			check(not mapped.is_empty(), label + " barrel can be mapped to source world")
			if mapped.is_empty(): continue
			check(camera.unproject_position(line.start).distance_to(mapped.pixel) < 0.05,
				label + " tracer starts on projected physical tip")
			check(line.start.distance_to(start) < 0.7,
				label + " visual muzzle stays near authoritative source depth")
			check(camera.unproject_position(line.start).distance_to(rig.weapon_camera.unproject_position(line.tip.global_position)) < 0.05,
				label + " tracer begins on visible muzzle pixel")
			check(line.end.distance_to(end) < 0.00001 and camera.unproject_position(line.end).distance_to(Vector2(root.size) * 0.5) < 0.05,
				label + " tracer ends on unchanged crosshair aim")
			var before: Vector3 = line.start
			step(rig, 1)
			fx.advance(1.0 / 60.0)
			mapped = Origin.map_tip(camera, rig.weapon_camera, line.tip)
			check(not mapped.is_empty() and camera.unproject_position(line.start).distance_to(mapped.pixel) < 0.05,
				label + " active tracer follows recoiling barrel")
			check(before.distance_to(line.start) > 0.00001, label + " recoil changes tracer start")
			check(line.end.distance_to(end) < 0.00001, label + " recoil cannot displace authoritative endpoint")
	# Four projectile alternate modes share the same physical launch handshake.
	for weapon: int in [1, 4, 5, 7]:
		fx.reset()
		actor.weapon = weapon
		rig.apply_actor(actor, true)
		step(rig, 12)
		rig.apply_aim(true)
		step(rig, 120)
		var launch: Dictionary = {"type":"launch", "id":1000 + weapon,
			"time":float(1000 + weapon), "actor":7, "weapon":weapon, "alt":true,
			"pos":point(camera.get_camera_transform() * Vector3(0.24, -0.24, -0.42))}
		var authority: Dictionary = launch.duplicate(true)
		var resolved: Dictionary = fx.resolve_launch_origin(launch, 7)
		check(not resolved.is_empty(), "alt weapon %d resolves physical launch origin" % weapon)
		if resolved.is_empty(): continue
		check(resolved.position.distance_to(FX.point(launch.pos)) < 0.7,
			"alt weapon %d starts near authoritative muzzle depth, not distant private-view depth" % weapon)
		var pixel: Vector2 = rig.get_muzzle_screen_position()
		check(camera.unproject_position(resolved.position).distance_to(pixel) < 0.05,
			"alt weapon %d launch is projected over visible muzzle" % weapon)
		fx.consume([launch], 7, [actor])
		check(fx.flashes == rig.get_muzzle_count(), "alt weapon %d flashes all physical barrels" % weapon)
		check(launch == authority, "alt weapon %d launch authority unchanged" % weapon)
		fx.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return true)
		check(fx.resolve_launch_origin(launch, 7).is_empty(), "alt weapon %d blocked muzzle fails closed" % weapon)
		fx.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false)
	# World-model muzzle (not the eye ray) owns remote flashes and moving tracer
	# starts. The host only supplies an animated exported Muzzle anchor.
	fx.reset()
	var world_tip := Node3D.new()
	world.add_child(world_tip)
	var remote_start: Vector3 = camera.get_camera_transform() * Vector3(0.1, -0.1, -3.0)
	world_tip.global_position = remote_start + camera.global_basis * Vector3(0.18, -0.1, -0.35)
	fx.configure_remote_muzzles(func(id: int, weapon: int) -> Node3D:
		return world_tip if id == 44 and weapon == 0 else null)
	var distant: Vector3 = camera.project_position(Vector2(root.size) * 0.5, 30.0)
	var remote_event := {"type":"shot", "id":2001, "time":2001.0, "actor":44, "weapon":0,
		"from":point(remote_start), "to":point(distant)}
	fx.consume([remote_event], 7, [{"id":44, "health":100, "weapon":0}])
	check(fx.flashes == 1 and fx.lines.size() == 1, "remote exported muzzle flashes and emits one tracer")
	if not fx.lines.is_empty():
		check(fx.lines[0].start.distance_to(world_tip.global_position) < 0.0001, "remote tracer starts on world muzzle")
		world_tip.global_position += Vector3(0.03, 0.0, 0.0)
		fx.advance(0.01)
		check(fx.lines[0].start.distance_to(world_tip.global_position) < 0.0001, "remote tracer follows animated muzzle")
		check(fx.lines[0].end == distant, "remote world muzzle never alters authoritative aim")
	fx.reset()
	fx.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return true)
	fx.consume([remote_event], 7, [{"id":44, "health":100, "weapon":0}])
	check(fx.flashes == 0 and fx.lines.is_empty(), "remote muzzle behind cover never flashes or draws an eye-origin tracer")
	fx.free()
	rig.free()
	world.free()
	print("WEAPON_EFFECTS_MUZZLE_PATH_GEOMETRY ", JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
