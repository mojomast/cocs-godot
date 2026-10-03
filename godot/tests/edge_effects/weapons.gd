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
	# Mirrors source Core.detonate(): emit adds id/time around this exact payload,
	# and the ordinary detonation payload contains pos without weapon attribution.
	var generic_event := {"type":"explosion", "id":7001, "time":7.0,
		"pos":{"x":2.0,"y":3.0,"z":-4.0}, "radius":5.0}
	fx.consume([generic_event],0,[])
	check(fx.blasts==1 and fx.slots.size()==1,"source-shaped weaponless detonation gets generic burst")
	check(fx.slots[0].node.global_position==Vector3(2,3,-4),"generic burst uses authoritative source position")
	var generic_count := fx.slots.size()
	fx.consume([generic_event],0,[])
	check(fx.blasts==1 and fx.slots.size()==generic_count,"generic explosion replay deduplicates on source id/time")
	fx.reset()
	fx.consume([{"type":"explosion","id":7010,"time":7.1,"pos":{"x":0,"y":0,"z":-3},"alt":true,"altId":"unknown"}],0,[])
	check(fx.blasts==0 and fx.slots.is_empty(),"unknown alt without weapon is not reclassified generic")
	fx.consume([{"type":"explosion","id":7011,"time":7.2,"pos":{"x":0,"y":0,"z":-3},"weapon":-1}],0,[])
	check(fx.blasts==0 and fx.rejected==1,"malformed explicit weapon is rejected")
	fx.consume([{"type":"explosion","id":7012,"time":7.3,"pos":{"x":0,"y":0,"z":-3},"weapon":1}],0,[])
	check(fx.blasts==1 and fx.slots.size()>0,"recognized primary rocket preserves source-specific presentation")
	fx.reset()
	fx.set_quality(1)
	fx.consume([{"type":"explosion","id":7013,"time":7.4,"pos":{"x":0,"y":0,"z":-3},"weapon":9,"alt":true,"altId":"bomb"}],0,[])
	check(fx.blasts==1 and fx.blast_shards==4,"recognized altId keeps its distinct blast ahead of weapon fallback")
	fx.reset()
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
