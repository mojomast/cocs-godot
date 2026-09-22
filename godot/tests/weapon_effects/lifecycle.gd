extends SceneTree
const FX = preload("res://weapon_effects/controller.gd")
const Origin = preload("res://weapon_effects/origin.gd")
var failures := 0
var state: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func provider() -> Dictionary:
	return state

func event(id: Variant = 1, time: float = 1.0, weapon: int = 3) -> Dictionary:
	return {"id":id,"time":time,"type":"shot","actor":7,"weapon":weapon,"from":{"x":0.24,"y":-0.24,"z":-0.42},"to":{"x":0,"y":0,"z":-30},"hit":false}

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,360)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var view_camera := Camera3D.new()
	viewport.add_child(view_camera)
	view_camera.fov = 59
	var tip := Node3D.new()
	viewport.add_child(tip)
	tip.position = Vector3(0.24,-0.15,-1.3)
	state = {"visible":true,"actor_id":7,"weapon":3,"camera":view_camera,"muzzles":[tip]}
	var fx := FX.new()
	world.add_child(fx)
	fx.set_process(false)
	fx.configure(camera, provider)
	var actors := [{"id":7,"weapon":3,"health":100}]
	await physics_frame
	fx.consume([event()],7,actors)
	check(fx.flashes == 0,"unconfigured mesh-only world visibility fails closed")
	fx.reset()
	fx.physics_occlusion_enabled = true # Fixture's world has real physics bodies.
	for bad: Variant in [false, true, null, "1", -1, 1.2]: fx.consume([event(bad)],7,actors)
	check(fx.flashes == 0, "non-numeric/unsafe identities rejected")
	var volley: Array = []
	for id: int in range(1,13): volley.append(event(id))
	fx.consume(volley,7,actors)
	check(fx.flashes == 1 and fx.tracer_count == 12,"12 pellets retain endpoints with one muzzle volley")
	fx.consume(volley,7,actors)
	check(fx.flashes == 1 and fx.tracer_count == 12,"numeric wire replay deduplicated")
	var shrapnel := event(13,2.0)
	shrapnel.shrapnel = 0
	fx.consume([shrapnel],7,actors)
	check(fx.flashes == 1,"secondary fragments never flash")
	check(fx.impacts == 0,"hit=false and absent normal never invent impact marks")
	var geometry_hit := event(15,2.5)
	geometry_hit.surface_hit = true
	geometry_hit.normal = {"x":0,"y":0,"z":1}
	fx.consume([geometry_hit],7,actors)
	check(fx.impacts == 1,"explicit source surface and valid normal allow a small mark")
	var mapping := Origin.map_tip(camera,view_camera,tip)
	check(not mapping.is_empty() and mapping.projection_error_px < 0.001,"different subviewport FOV/resolution maps to same normalized pixel")
	var endpoint: Vector3 = fx.lines[0].end
	tip.position.x += 0.08
	fx.advance(0.01)
	check(fx.lines[0].end == endpoint,"animated tip never changes authoritative endpoint")
	check(camera.unproject_position(fx.lines[0].start).distance_to(Origin.map_tip(camera,view_camera,tip).pixel) < 0.001,"active tracer follows animated actual tip")
	state.visible = false
	fx.consume([event(14,3.0)],7,actors)
	fx.advance(0)
	state.visible = true
	fx.consume([event(14,3.0)],7,actors)
	check(fx.flashes == 2,"hidden events consumed without replay")
	for actor: Dictionary in [{"id":7,"health":0},{"id":7,"health":100,"dead":true},{"id":7,"health":100,"hidden":true},{"id":false,"health":100}]:
		fx.consume([event(20+fx.seen.size(),4.0+fx.seen.size())],7,[actor])
	check(fx.flashes == 2,"dead/hidden/false actors cannot spawn")
	fx.advance(5)
	for slot: Dictionary in fx.slots + fx.lines: check(not slot.node.visible,"expiry hides every pooled node")
	fx.reset()
	fx.consume([event()],7,actors)
	check(fx.flashes == 1,"reset accepts reused wire IDs")
	for id: int in range(2,2300):
		fx.consume([event(id,float(id))],7,actors)
	check(fx.slots.size() <= FX.CAP and fx.lines.size() <= FX.LINE_CAP and fx.seen.size() <= FX.SEEN_CAP,"stress bounds nodes/materials/history")
	var before: int = fx.flashes
	fx.consume([event()],7,actors)
	check(fx.flashes == before,"evicted IDs cannot replay")
	fx.reset()
	state.weapon = 8
	fx.consume([event(1,1.0,8)],7,[{"id":7,"health":100,"weapon":8}])
	var shells := 0
	for slot: Dictionary in fx.slots:
		if slot.kind == 12: shells += 1
	check(shells == 0,"no invented casing origin without authored ejection anchor")
	var port := Node3D.new()
	viewport.add_child(port)
	port.position = Vector3(0.3,-0.2,-0.9)
	state.ejection = port
	fx.consume([event(2,2.0,8)],7,[{"id":7,"health":100,"weapon":8}])
	for slot: Dictionary in fx.slots:
		if slot.kind == 12:
			shells += 1
			check(slot.node.get_parent() == port,"casing originates at supplied model-space port")
	check(shells == 1,"kinetic profile ejects one supplied-port casing")
	state.erase("ejection")
	state.weapon = 3
	fx.reset()
	fx.set_quality(0)
	var remote_hit := geometry_hit.duplicate(true)
	remote_hit.actor = 8
	fx.consume([remote_hit],7,[{"id":8,"health":100,"weapon":3}])
	check(fx.slots.is_empty() and fx.lines.is_empty(),"quality disabled suppresses remote geometry marks as well as local fire")
	fx.set_quality(2)
	fx.reset()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5,5,0.1)
	shape.shape = box
	wall.add_child(shape)
	wall.position.z = -0.5
	world.add_child(wall)
	await physics_frame
	await physics_frame
	fx.consume([event()],7,actors)
	check(fx.flashes == 0 and fx.tracer_count == 0,"near wall occludes isolated muzzle and stops cosmetic path")
	check(fx.resolve_launch_origin({"actor":7,"weapon":3,"pos":{"x":0.24,"y":-0.24,"z":-0.42}},7).is_empty(),"projectile visual handshake fails closed behind wall")
	wall.free()
	fx.reset()
	# Mesh-only source maps use injected semantic geometry, not empty physics.
	fx.configure_occlusion(func(_a: Vector3, _b: Vector3) -> bool: return true)
	fx.consume([event()],7,actors)
	check(fx.flashes == 0,"semantic geometry callback occludes without physics body")
	fx.configure_occlusion(func(_a: Vector3, _b: Vector3) -> Variant: return null)
	fx.reset()
	fx.consume([event()],7,actors)
	check(fx.flashes == 0,"unknown semantic visibility fails closed")
	fx.configure_occlusion(Callable())
	fx.reset()
	var blocked := event()
	blocked.from = {"x":0,"y":0,"z":0}
	blocked.to = {"x":0.1,"y":-0.1,"z":-0.15}
	fx.consume([blocked],7,actors)
	check(fx.flashes == 0 and fx.tracer_count == 0,"source eye-origin blocked shot never flashes through protruding barrel")
	fx.reset()
	fx.consume([event()],7,actors)
	tip.free()
	fx.advance(0.01)
	fx.reset()
	check(fx.slots.is_empty() and fx.lines.is_empty(),"rig deletion and reset safely release external children")
	world.free()
	viewport.free()
	print("WEAPON_EFFECTS_LIFECYCLE failures=%d" % failures)
	quit(1 if failures else 0)
