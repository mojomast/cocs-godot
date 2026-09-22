extends SceneTree
## Real ADS rig integration test, separate from the labelled static-pose images.
const Rig = preload("res://first_person/rig.gd")
const FX = preload("res://weapon_effects/controller.gd")
const Origin = preload("res://weapon_effects/origin.gd")
var failures := 0
var maximum_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(12,4,8)
	camera.rotation = Vector3(-0.08,0.2,0)
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
	fx.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false) # Known empty fixture world.
	var actor := {"id":7,"health":100,"weapon":0}
	for weapon: int in 10:
		fx.reset()
		actor.weapon = weapon
		rig.apply_actor(actor,true)
		for i: int in 10: rig.advance(0.05)
		for ads: bool in [false,true]:
			fx.reset()
			rig.apply_aim(ads)
			for i: int in 30: rig.advance(1.0/60.0)
			var from: Vector3 = camera.global_transform * Vector3(0.24,-0.24,-0.42)
			var end: Vector3 = camera.global_transform * Vector3(0,0,-30)
			var event := {"id":weapon*2+int(ads)+1,"time":float(weapon*2+int(ads)+1),"type":"shot","actor":7,"weapon":weapon,"from":{"x":from.x,"y":from.y,"z":from.z},"to":{"x":end.x,"y":end.y,"z":end.z}}
			rig.apply_events([event],7)
			fx.consume([event],7,[actor])
			check(fx.flashes == rig.get_muzzle_count(),"real rig all authored barrels flash weapon %d ADS=%s" % [weapon,ads])
			var before: Vector3 = rig.anchors.Muzzle0.global_position
			rig.advance(0.016)
			fx.advance(0.016)
			check(not rig.flash.visible,"legacy opaque muzzle disabled")
			check(before.distance_to(rig.anchors.Muzzle0.global_position) > 0.00001,"authored muzzle follows recoil weapon=%d ADS=%s" % [weapon,ads])
			for line: Dictionary in fx.lines:
				var mapped := Origin.map_tip(camera,rig.weapon_camera,line.tip)
				var error: float = camera.unproject_position(line.start).distance_to(mapped.pixel)
				maximum_error = maxf(maximum_error,error)
				check(error < 0.001,"recoiling production ADS muzzle and world tracer project together")
				check(line.end.distance_to(end) < 0.00001,"source endpoint unchanged in production rig")
	fx.reset()
	rig.free()
	world.free()
	print("WEAPON_EFFECTS_REAL_RIG weapons=10 poses=2 max_projection_error_px=%.8f failures=%d" % [maximum_error,failures])
	quit(1 if failures else 0)
