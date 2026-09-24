extends SceneTree
## Rendered weapon-oomph evidence at 1280x800: real ADS rig, shipping effects
## controller, per-weapon muzzle blooms with pooled barrel lights, layered ray
## tracers with a travelling head, and real firing sequences (SMG, Scattergun,
## Rocket, Rail). Presentation only: no aim, spread, ammo, damage or endpoint is
## written or asserted here.
const Rig = preload("res://first_person/rig.gd")
const FX = preload("res://weapon_effects/controller.gd")
const Profiles = preload("res://weapon_effects/profiles.gd")
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

func settle(frames: int) -> void:
	step(frames)

## One source-shaped event on the shipping path: rig recoil plus controller FX.
func fire(target: Vector3, launch: bool = false) -> void:
	var event := event_for(target, launch)
	var alive := actor.duplicate()
	alive.health = 100
	rig.apply_events([event],7)
	fx.consume([event],7,[alive])

## Same event, effects controller only: isolates the bloom for the ADS gap check.
func fire_fx(target: Vector3, launch: bool = false) -> void:
	var alive := actor.duplicate()
	alive.health = 100
	fx.consume([event_for(target, launch)],7,[alive])

func event_for(target: Vector3, launch: bool) -> Dictionary:
	serial += 1
	var from: Vector3 = camera.global_transform * Vector3(0.24,-0.24,-0.42)
	return {"id":serial,"time":float(serial),"type":"launch" if launch else "shot","actor":7,"weapon":actor.weapon,"pos":{"x":from.x,"y":from.y,"z":from.z},"from":{"x":from.x,"y":from.y,"z":from.z},"to":{"x":target.x,"y":target.y,"z":target.z}}

## The ADS open-sight target gap, exactly the accepted ADS gate window.
func gap_pixels() -> int:
	var image: Image = rig.viewport.get_texture().get_image()
	var count := 0
	for x: int in range(root.size.x/2-2, root.size.x/2+2):
		for y: int in range(root.size.y/2-6, root.size.y/2-2):
			if image.get_pixel(x,y).a > 0.1: count += 1
	return count

func live_lights() -> int:
	var count := 0
	for slot: Dictionary in fx.lights:
		if is_instance_valid(slot.node) and slot.remaining > 0: count += 1
	return count

func light_energy() -> float:
	var energy := 0.0
	for slot: Dictionary in fx.lights:
		if is_instance_valid(slot.node) and slot.remaining > 0: energy = maxf(energy, slot.node.light_energy)
	return energy

func live_tracers() -> int:
	var count := 0
	for slot: Dictionary in fx.lines:
		if slot.remaining > 0: count += 1
	return count

func capture(name: String, note: String) -> void:
	caption.text = "WEAPON OOMPH · %s\n%s · %dx%d" % [note, note, root.size.x, root.size.y]
	hud.apply_state({"mapName":"weapon oomph fixture","config":{"mode":"deathmatch"},"actors":[actor]},7)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("%s.png" % name))
	metrics.append({
		"file":name, "weapon":actor.weapon, "note":note,
		"model":rig.manifest.weapons[actor.weapon].name,
		"flashes":fx.flashes, "tracers":fx.tracer_count, "light_flashes":fx.light_flashes,
		"live_lights":live_lights(), "light_energy":light_energy(),
		"live_slots":active_slots(), "live_tracers":live_tracers(),
		"recoil":rig.recoil, "punch":rig.punch,
		"kick_shove_m":rig.kick_shove, "kick_lift_deg":rad_to_deg(rig.kick_lift), "kick_roll_deg":rad_to_deg(rig.kick_roll),
		"aim_weight":rig.aim_weight,
	})

func active_slots() -> int:
	var count := 0
	for slot: Dictionary in fx.slots:
		if slot.remaining > 0: count += 1
	return count

func sheet(name: String, files: Array, columns: int, cell: Vector2i) -> void:
	var rows := int(ceil(float(files.size()) / float(columns)))
	var image := Image.create(columns * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("0b1118"))
	for index: int in files.size():
		var source := Image.load_from_file(directory.path_join("%s.png" % files[index]))
		source.convert(Image.FORMAT_RGBA8)
		source.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		image.blit_rect(source, Rect2i(Vector2i.ZERO, cell), Vector2i((index % columns) * cell.x, (index / columns) * cell.y))
	image.save_png(directory.path_join("%s.png" % name))

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
	cube(world, Vector3(0,-0.2,-10), Vector3(40,0.4,45), Color("141c22"))
	cube(world, Vector3(0,3,-14), Vector3(22,6,1), Color("243038"))
	for x: int in [-6,6]:
		cube(world,Vector3(x,2,-5),Vector3(2,4,5),Color("1e2a33"))
		cube(world,Vector3(x,4,-5),Vector3(2.1,0.15,5.1),Color("65acb7"))
	for z: int in range(-12,4,2): cube(world,Vector3(0,0.02,z),Vector3(0.06,0.01,0.9),Color("3b5560"))
	rig = Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	fx = FX.new()
	world.add_child(fx)
	fx.set_process(false)
	fx.attach_rig(rig)
	fx.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false) # Known-clear fixture world.
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
	root.size = Vector2i(1280,800)
	await process_frame
	hud.resize()
	cross.position = Vector2(root.size) / 2.0 - Vector2(7, 17)
	# A lateral target keeps the ray crossing the frame instead of pointing away
	# from the camera, so the tracer sheets actually show the trail and the head.
	var target: Vector3 = camera.global_transform * Vector3(-7.5, -0.5, -20)
	var flash_files: Array = []
	var tracer_files: Array = []
	var ads_files: Array = []
	for id: int in 10:
		rig.reset()
		fx.reset()
		actor.weapon = id
		actor.reloading = false
		rig.apply_actor(actor,true)
		rig.apply_aim(false)
		settle(90)
		# 1. Hip muzzle bloom at its peak.
		fire(target, id in [1,4,5])
		step(1)
		var profile: Dictionary = Profiles.ITEMS[id]
		check(active_slots() >= 1, "weapon %d spawns a pooled bloom" % id)
		if float(profile.light) > 0.0:
			check(live_lights() >= 1 and light_energy() > 0.0, "weapon %d lights its barrel" % id)
		await capture("flash-w%d" % id, "HIP BLOOM · %s · flash %.3f m / %.3f s · light %.1f" % [rig.manifest.weapons[id].name, float(profile.size)*float(profile.flash_scale)*2.4, float(profile.life)*float(profile.flash_life), profile.light])
		flash_files.append("flash-w%d" % id)
		# 2. Mid-life ray: bright core plus the fading trail behind the head.
		if not id in [1,4,5]:
			var ray_step: float = float(profile.tracer_life) * 0.6 - 1.0 / 60.0
			step(maxi(0, int(round(ray_step * 60.0))))
			check(live_tracers() >= 1, "weapon %d keeps its ray alive" % id)
			await capture("tracer-w%d" % id, "RAY TRACER · %s · width %.3f m / %.3f s" % [rig.manifest.weapons[id].name, profile.tracer_width, profile.tracer_life])
		else:
			await capture("tracer-w%d" % id, "PROJECTILE LAUNCH BLOOM · %s · exhaust is the projectile" % rig.manifest.weapons[id].name)
		tracer_files.append("tracer-w%d" % id)
		# 3. Settled ADS firing: the bigger bloom must not fill the open target gap.
		#    The gap is measured with the bloom alone (no recoil pose change), so
		#    the number isolates the flash from the sight post's firing movement.
		fx.reset()
		rig.apply_aim(true)
		settle(150)
		check(rig.aim_weight >= 0.98, "weapon %d settled ADS" % id)
		fire_fx(target, id in [1,4,5])
		step(1)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var gap := gap_pixels()
		check(gap == 0, "bloom keeps the open sight gap clear weapon %d (%d px)" % [id,gap])
		await capture("ads-bloom-w%d" % id, "ADS BLOOM ONLY · %s · target gap %d px" % [rig.manifest.weapons[id].name, gap])
		fire(target, id in [1,4,5])
		step(1)
		await capture("ads-fire-w%d" % id, "ADS FIRING POSE · %s · recoil %.3f" % [rig.manifest.weapons[id].name, rig.recoil])
		ads_files.append("ads-fire-w%d" % id)
		rig.apply_aim(false)
		settle(4)
	# 4. Real firing sequences: recoil + bloom + ray on the shipping path.
	var sequence_files: Array = []
	for id: int in [9, 3, 1, 2]:
		rig.reset()
		fx.reset()
		actor.weapon = id
		rig.apply_actor(actor,true)
		rig.apply_aim(false)
		settle(60)
		var interval: float = maxf(0.05, float(rig.manifest.weapons[id].handling.cycle) / 0.88)
		for shot: int in 5:
			fire(target, id == 1)
			step(1)
			await capture("sequence-w%d-%d" % [id, shot], "FIRING SEQUENCE · %s · shot %d/5 · shove %.3f m · lift %.2f deg" % [rig.manifest.weapons[id].name, shot+1, rig.kick_shove, rad_to_deg(rig.kick_lift)])
			sequence_files.append("sequence-w%d-%d" % [id, shot])
			step(maxi(1, int(round(interval * 60.0))) - 1)
	# 5. Contact sheets assembled from the real rendered PNGs.
	sheet("muzzle-flash-sheet-1280x800", flash_files, 5, Vector2i(384,240))
	sheet("tracer-sheet-1280x800", tracer_files, 5, Vector2i(384,240))
	sheet("ads-fire-sheet-1280x800", ads_files, 5, Vector2i(384,240))
	sheet("firing-sequence-sheet-1280x800", sequence_files, 5, Vector2i(384,240))
	FileAccess.open(directory.path_join("oomph-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":metrics,"godot":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name()}, "\t") + "\n")
	print("WEAPON_OOMPH_CAPTURE ", JSON.stringify({"checks":checks,"failures":failures,"captures":metrics.size()}))
	quit(0 if failures.is_empty() else 1)
