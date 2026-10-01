extends SceneTree
const Effects = preload("res://weapon_effects/controller.gd")
var failures := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var tip := Node3D.new()
	root.add_child(tip)
	tip.position = Vector3(0,0,-1)
	var fx := Effects.new()
	root.add_child(fx)
	fx.set_process(false)
	fx.configure(camera,func() -> Dictionary: return {})
	fx.configure_occlusion(func(_a: Vector3,_b: Vector3) -> bool: return false)
	fx.configure_remote_muzzles(func(_actor: int,_weapon: int) -> Node3D: return tip)
	for quality: int in [1,2]:
		fx.set_quality(quality)
		for weapon: int in 10:
			fx.reset()
			var projectile: bool = weapon in [1,4,5]
			var event := {"type":"launch" if projectile else "shot","actor":7,"weapon":weapon,"id":1,"time":1.0,
				"from":{"x":0,"y":0,"z":-1},"pos":{"x":0,"y":0,"z":-1},"to":{"x":0,"y":0,"z":-20}}
			fx.consume([event],0,[{"id":7,"health":100}])
			check(fx.flashes==1,"accepted event flashes weapon %d quality %d" % [weapon,quality])
			check(fx.tracer_count==(0 if projectile else 1),"launch does not fake an instant hit path")
			var count: int = fx.slots.size()
			fx.consume([event],0,[{"id":7,"health":100}])
			check(fx.slots.size()==count and fx.flashes==1,"source ID replay does not duplicate weapon FX")
			if projectile:
				fx.consume([{"type":"explosion","weapon":weapon,"id":2,"time":2.0,"pos":{"x":0,"y":0,"z":-20}}],0,[])
				check(fx.blasts==1,"primary explosion has a source-confirmed identity")
			fx.advance(0.0)
			check(fx.slots.size()<=Effects.CAP and fx.lines.size()<=Effects.LINE_CAP,"bounded all-weapon pools")
			fx.advance(5.0)
			for slot: Dictionary in fx.slots+fx.lines: check(not slot.node.visible,"finite effect retirement")
	fx.reset()
	fx.reduced_motion = true
	fx._fire(tip,4,{})
	for slot: Dictionary in fx.slots: check(slot.kind not in [10,12,17],"reduced motion suppresses secondary muzzle motion")
	fx._primary_blast(Vector3(0,0,-5),5)
	for slot: Dictionary in fx.slots: check(slot.kind!=12,"reduced motion suppresses grenade fragments")
	fx.reset()
	fx.reduced_motion = false
	for index: int in 1000:
		fx.consume([{"type":"explosion","weapon":[1,4,5][index%3],"id":index+1,"time":index+1.0,"pos":{"x":0,"y":0,"z":-5}}],0,[])
	check(fx.slots.size()==Effects.CAP,"1000 primary blasts reuse the existing 64 slots")
	fx.set_quality(0)
	for slot: Dictionary in fx.slots: check(not slot.node.visible,"disabled quality retires active FX")
	fx.reset()
	check(fx.slots.is_empty() and fx.lines.is_empty() and fx.lights.is_empty(),"reset releases all effect resources")
	fx.free()
	tip.free()
	camera.free()
	print("EDGE_WEAPONS ",checks," checks; failures=",failures)
	quit(0 if failures==0 else 1)
