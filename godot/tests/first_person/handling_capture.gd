extends SceneTree
## Rendered handling evidence: real HUD, source chassis, authored anchors, the
## weapon-effects controller attached as the shipping session does, and five
## poses per weapon at both capture sizes. Presentation only; never writes aim,
## damage, spread or ammo authority.
const Rig = preload("res://first_person/rig.gd")
const FX = preload("res://weapon_effects/controller.gd")
const HUD = preload("res://ui/game_hud.gd")
var directory := ""
var failures: Array[String] = []
var checks := 0
var metrics: Array[Dictionary] = []
var rig: Node
var fx: Node
var camera: Camera3D
var hud: Node
var caption: Label
var cross: Label
var actor := {"id":7,"weapon":0,"health":100,"maxHealth":100,"armor":25,"ammo":[99,6,6,10,28,6,10,12,10,32],"frags":3,"deaths":1,"reloadDuration":2.0,"reloadTimer":1.0}
var serial := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func cube(parent: Node, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	node.material_override = material
	node.position = at
	parent.add_child(node)

func step(frames: int, delta: float = 1.0 / 60.0) -> void:
	for frame: int in frames:
		rig.advance(delta)
		fx.advance(delta)

## One source-shaped public shot, consumed by the shipping effects controller,
## which pools the casing at the authored Ejection port.
func shoot(target: Vector3) -> void:
	serial += 1
	var from: Vector3 = camera.global_transform * Vector3(0.24,-0.24,-0.42)
	var event := {"id":serial,"time":float(serial),"type":"shot","actor":7,"weapon":actor.weapon,"from":{"x":from.x,"y":from.y,"z":from.z},"to":{"x":target.x,"y":target.y,"z":target.z}}
	var alive := actor.duplicate()
	alive.health = 100
	rig.apply_events([event],7)
	fx.consume([event],7,[alive])

## Rig-only source event: identical public shape, no effects-controller hand-off.
func fire_rig_only(target: Vector3) -> void:
	serial += 1
	var from: Vector3 = camera.global_transform * Vector3(0.24,-0.24,-0.42)
	rig.apply_events([{"id":serial,"time":float(serial),"type":"shot","actor":7,"weapon":actor.weapon,"from":{"x":from.x,"y":from.y,"z":from.z},"to":{"x":target.x,"y":target.y,"z":target.z}}],7)

## Live (not pooled) effects-controller slots of every kind.
func active_fx() -> int:
	var count := 0
	for slot: Dictionary in fx.slots:
		if float(slot.remaining) > 0.0: count += 1
	return count

## Visible 3D nodes in the isolated viewport, with their scale and projected
## pixel position: this is what the overlay actually composites.
func viewport_inventory() -> Array:
	var items: Array = []
	for node: Node in rig.viewport.get_children():
		if not node is Node3D: continue
		for child: Node in node.find_children("*", "MeshInstance3D"):
			var mesh: MeshInstance3D = child
			if not mesh.visible or mesh.mesh == null: continue
			if mesh.get_parent() == rig.weapon or rig.weapon.is_ancestor_of(mesh): continue
			items.append({"node":mesh.name,"scale":[mesh.scale.x,mesh.scale.y,mesh.scale.z],"pixel":[rig.weapon_camera.unproject_position(mesh.global_position).x,rig.weapon_camera.unproject_position(mesh.global_position).y]})
	return items

func casing_count() -> int:
	var count := 0
	for slot: Dictionary in fx.slots:
		if int(slot.kind) == 12 and float(slot.remaining) > 0.0: count += 1
	return count

func settle(frames: int) -> void:
	step(frames)

func capture(state: String) -> void:
	caption.text = "HANDLING FIXTURE · %s · %s · %dx%d\nbolt %.4f m · heat %.3f · haze %.3f · puff %.3f · casings %d" % [rig.manifest.weapons[actor.weapon].name, state.to_upper(), root.size.x, root.size.y, rig.handling.bolt_offset, rig.handling.heat, rig.handling.haze_alpha, rig.handling.puff_alpha, casing_count()]
	hud.apply_state({"mapName":"weapon handling fixture","config":{"mode":"deathmatch"},"actors":[actor]},7)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("handling-%dx%d-w%d-%s.png" % [root.size.x,root.size.y,actor.weapon,state]))
	var image: Image = rig.viewport.get_texture().get_image()
	metrics.append({"weapon":actor.weapon,"state":state,"size":[root.size.x,root.size.y],"center_48px_occupied":occupancy(image,24),"target_gap_occupied":occupancy_gap(image),"bolt_offset_m":rig.handling.bolt_offset,"charge_offset_m":rig.handling.charge_offset,"magazine_curve":rig.handling.magazine_curve,"feed_offset_y_m":rig.parts["feed"].transform.origin.y - rig.rest["feed"].origin.y,"heat":rig.handling.heat,"haze_alpha":rig.handling.haze_alpha,"puff_alpha":rig.handling.puff_alpha,"active_puffs":rig.handling.active_puffs,"casing_slots":casing_count(),"active_fx":active_fx(),"viewport_fx":viewport_inventory(),"effect_slots":fx.slots.size(),"effect_lines":fx.lines.size(),"fx_nodes":rig.viewport.get_node("WeaponHandlingFx").get_child_count(),"aim_weight":rig.aim_weight})

## Count of viewport pixels above alpha 0.01 in a square box around the reticle.
func occupancy(image: Image, radius: int) -> int:
	var count := 0
	for x: int in range(root.size.x/2-radius, root.size.x/2+radius):
		for y: int in range(root.size.y/2-radius, root.size.y/2+radius):
			if image.get_pixel(x,y).a > 0.01: count += 1
	return count

## The front post terminates at the aiming point; sample immediately above it.
func occupancy_gap(image: Image) -> int:
	var count := 0
	for x: int in range(root.size.x/2-2, root.size.x/2+2):
		for y: int in range(root.size.y/2-6, root.size.y/2-2):
			if image.get_pixel(x,y).a > 0.1: count += 1
	return count

## Settled ADS contract: the front post stops at the aiming point and the sight
## axis is exactly on the reticle, exactly like the accepted ADS gate.
func ads_contract(state: String) -> void:
	var points: Dictionary = rig.get_sight_screen_positions()
	var centre := Vector2(root.size) / 2.0
	var rear_error: float = points.rear.distance_to(centre)
	var front_error: float = points.front.distance_to(centre)
	var rear: Vector3 = rig.anchors.SightRear.global_position
	var front: Vector3 = rig.anchors.SightFront.global_position
	var axis_error := rad_to_deg((front - rear).normalized().angle_to(Vector3.FORWARD))
	check(rear_error < 0.01 and front_error < 0.01 and axis_error < 0.001, "ADS centre/axis weapon %d %s" % [actor.weapon,state])
	var gap := occupancy_gap(rig.viewport.get_texture().get_image())
	check(gap == 0, "open sight target gap weapon %d %s" % [actor.weapon,state])
	var clearance := corridor(rig.anchors.HeatZone.global_position)
	metrics.back()["rear_error_px"] = rear_error
	metrics.back()["front_error_px"] = front_error
	metrics.back()["sight_axis_error_deg"] = axis_error
	metrics.back()["heat_corridor_deg"] = clearance
	check(clearance > 0.0, "authored heat station below the sight corridor weapon %d %s (%.2f deg)" % [actor.weapon,state,clearance])

## Signed angular clearance of a point from the view axis minus the quad radius.
func corridor(point: Vector3) -> float:
	var eye: Vector3 = rig.weapon_camera.global_position
	var to_point: Vector3 = point - eye
	if to_point.length() < 0.05: return -1.0
	var offset := rad_to_deg((-rig.weapon_camera.global_transform.basis.z).angle_to(to_point.normalized()))
	return offset - rad_to_deg(atan2(0.035, to_point.length()))

func run() -> void:
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	var world := Node3D.new()
	root.add_child(world)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 4)
	camera.rotation = Vector3(-0.02, 0.0, 0.0)
	camera.fov = 75
	world.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -20, 0)
	world.add_child(sun)
	cube(world, Vector3(0,-0.2,-10), Vector3(40,0.4,45), Color("34434a"))
	cube(world, Vector3(0,3,-14), Vector3(22,6,1), Color("708488"))
	for x: int in [-6,6]:
		cube(world,Vector3(x,2,-5),Vector3(2,4,5),Color("475b65"))
		cube(world,Vector3(x,4,-5),Vector3(2.1,0.15,5.1),Color("65acb7"))
	for z: int in range(-12,4,2): cube(world,Vector3(0,0.02,z),Vector3(0.06,0.01,0.9),Color("93aaa5"))
	rig = Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	fx = FX.new()
	world.add_child(fx)
	fx.set_process(false)
	fx.attach_rig(rig)
	fx.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false)
	hud = HUD.new()
	root.add_child(hud)
	hud.set_process(false)
	hud.root.show()
	hud.status_panel.hide()
	var layer := CanvasLayer.new()
	layer.layer = 4
	root.add_child(layer)
	cross = Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 24)
	layer.add_child(cross)
	caption = Label.new()
	caption.position = Vector2(24, 70)
	layer.add_child(caption)
	var target: Vector3 = camera.global_transform * Vector3(0,0,-24)
	for size: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		await process_frame
		hud.resize()
		cross.position = Vector2(size) / 2.0 - Vector2(7, 17)
		check(hud.layer > rig.overlay.layer, "HUD composited above isolated weapon")
		for id: int in 10:
			rig.reset()
			fx.reset()
			actor.weapon = id
			actor.reloading = false
			rig.apply_actor(actor,true)
			rig.apply_aim(false)
			camera.fov = 75.0
			settle(90)
			# 1. Cold hip pose: the source hip framing keeps the reticle clear.
			await capture("hip")
			check(metrics.back()["center_48px_occupied"] == 0, "cold hip keeps the reticle region clear weapon %d" % id)
			# 2. Settled ADS: exact sight axis, open target gap, no heat FX.
			check(rig.apply_aim(true), "local ADS accepted weapon %d" % id)
			settle(120)
			camera.fov = rig.get_aim_state(75.0).fov
			rig.advance(0)
			await capture("ads")
			ads_contract("ads")
			check(rig.handling.haze_alpha == 0.0 and rig.handling.puff_alpha == 0.0, "no heat micro-effect in the settled sight picture weapon %d" % id)
			# 3. Firing: recoil, authored bolt travel and a pooled casing at the port.
			shoot(target)
			step(1)
			await capture("fire")
			check(metrics.back()["bolt_offset_m"] > 0.0, "carrier cycles on the fired shot weapon %d" % id)
			check(metrics.back()["casing_slots"] <= 4, "casing pool bounded weapon %d" % id)
			if id in [0,8,9]:
				check(metrics.back()["casing_slots"] >= 1, "authored casing port ejects a pooled casing weapon %d" % id)
			else:
				check(metrics.back()["casing_slots"] == 0, "no invented casing for sealed/breech weapons weapon %d" % id)
			# 4. Authoritative reload at mid-window, ADS blocked by the source flag.
			#    The shipping effects controller is drained first, so this pose
			#    measures the viewmodel handling only, exactly like the rig gates.
			fx.reset()
			actor.reloading = true
			actor.reloadDuration = 2.0
			actor.reloadTimer = 1.0
			rig.apply_actor(actor,true)
			check(not rig.apply_aim(true), "reload rejects ADS weapon %d" % id)
			camera.fov = 75.0
			settle(30)
			await capture("reload")
			check(rig.handling.magazine_curve > 0.0 or float(rig.manifest.weapons[id].handling.reload.hinge) > 0.0, "feed mechanism outside rest during authoritative reload weapon %d" % id)
			check(metrics.back()["center_48px_occupied"] == 0, "reloading hip pose keeps the reticle region clear weapon %d" % id)
			# 5. Sustained fire at the weapon's own source rate to the heat cap.
			actor.reloading = false
			rig.apply_actor(actor,true)
			rig.apply_aim(false)
			var interval: float = maxf(0.02, float(rig.manifest.weapons[id].handling.cycle) / 0.88)
			var shots := int(3.0 / interval)
			for index: int in shots:
				shoot(target)
				step(int(maxi(1, roundf(interval * 60.0))))
			check(rig.handling.heat > 0.9, "sustained fire reaches the heat cap weapon %d (%.3f)" % [id,rig.handling.heat])
			check(rig.handling.puffs_spawned > 0, "sustained fire emits bounded smoke weapon %d" % id)
			check(rig.viewport.get_node("WeaponHandlingFx").get_child_count() == 4, "handling FX pool fixed weapon %d" % id)
			check(fx.slots.size() <= 64 and fx.lines.size() <= 128, "weapon effects pools bounded weapon %d" % id)
			await capture("heat")
			check(metrics.back()["heat"] > 0.9 and metrics.back()["haze_alpha"] > 0.0, "hot hip pose shows the authored micro-effect weapon %d" % id)
			# The sustained-fire heat case with the muzzle bloom drained: the barrel
			# is still hot and the authored heat micro-effect must not cover the
			# reticle region from the hip pose.
			step(42)
			await capture("heat-hold")
			check(metrics.back()["heat"] > 0.4 and metrics.back()["haze_alpha"] > 0.0 and metrics.back()["puff_alpha"] > 0.0, "hot barrel keeps its authored haze and smoke weapon %d" % id)
			check(metrics.back()["center_48px_occupied"] == 0, "heat micro-effect keeps the reticle region clear weapon %d" % id)
			# 6. Hot ADS: the same barrel heat, now with the cheek weld settled and
			#    the muzzle smoke drained. The sight picture must stay clear: no
			#    haze, no smoke, no casing in the corridor.
			fx.reset()
			rig.apply_aim(true)
			var hot_interval := maxi(1, int(round(interval * 60.0)))
			# Hold the barrel at the cap while the cheek weld settles, then let the
			# recoil recover: the barrel stays hot, the sight axis returns exactly
			# to the reticle, and no FX quad can enter the corridor.
			for index: int in 150:
				if index % hot_interval == 0: fire_rig_only(target)
				rig.advance(1.0 / 60.0)
				fx.advance(1.0 / 60.0)
			for index: int in 30:
				rig.advance(1.0 / 60.0)
				fx.advance(1.0 / 60.0)
			camera.fov = rig.get_aim_state(75.0).fov
			rig.advance(0)
			await capture("hot-ads")
			ads_contract("hot-ads")
			check(rig.handling.haze_alpha == 0.0 and rig.handling.puff_alpha == 0.0, "hot settled ADS keeps every heat quad dark weapon %d" % id)
			check(metrics.back()["heat"] > 0.5, "hot ADS still holds barrel heat weapon %d" % id)
			rig.apply_aim(false)
			camera.fov = 75.0
			rig.advance(0)
	FileAccess.open(directory.path_join("handling-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"godot":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name()}, "\t") + "\n")
	print("FIRST_PERSON_HANDLING_CAPTURE ", JSON.stringify({"checks":checks,"failures":failures,"images":metrics.size()}))
	quit(0 if failures.is_empty() else 1)
