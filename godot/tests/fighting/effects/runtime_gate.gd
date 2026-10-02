extends SceneTree
## Prepared engine gate; requires explicit serial grant. No gameplay authority.
const Director = preload("res://fighting/effects/director.gd")
const Geometry = preload("res://fighting/effects/geometry.gd")
const SocketProbe = preload("res://tests/fighting/effects/socket_probe.gd")
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func event(id: int, type: String = "hit", actor: int = 0, move: String = "stand_m") -> Dictionary:
	return {"id":id,"tick":id,"type":type,"actor":actor,"target":1-actor,"move_id":move,"x":350,"y":1100,"effect":"chatgpt:"+move}

func run() -> void:
	var initial_children := root.get_child_count()
	var director := Director.new()
	root.add_child(director)
	var fighters: Array = [{"id":0,"operator_id":"chatgpt","facing":1,"x":-700,"y":0},
		{"id":1,"operator_id":"qwen","facing":-1,"x":700,"y":0}]
	for tier in ["low","high","detail"]:
		director.configure({"quality":tier,"muted":true})
		var before := director.metrics()
		var batch: Array = []
		for i in range(100): batch.append(event(i))
		var frozen := JSON.stringify([batch,fighters])
		director.consume(batch,fighters)
		check(JSON.stringify([batch,fighters]) == frozen,"read-only input "+tier)
		check(director.metrics().active == before.mesh_slots,"bounded pool "+tier)
		check(director.metrics().dropped == 100-int(before.mesh_slots),"overflow accounting "+tier)
		director.consume(batch,fighters)
		check(director.metrics().duplicates == 100,"dedup "+tier)
		director.set_paused(true)
		director.advance(1.0)
		check(director.metrics().active == before.mesh_slots,"pause "+tier)
		director.set_paused(false)
		director.advance(1.0)
		check(director.metrics().active == 0,"finite lifetime "+tier)
		director.reset()
		check(director.metrics().pool_nodes == before.pool_nodes,"reset retains bounded pool "+tier)
		director.consume([event(0,"throw_tech")],fighters)
		check(director.metrics().accepted == 1,"session reset accepts reused IDs "+tier)
		director.consume([event(1,"throw_tech",0,"")],fighters)
		check(director.metrics().spawned == 2,"core empty-move tech cue resolves "+tier)
		director.advance(1.0)
		director.consume([event(101,"projectile_reflect",1,"special1")],fighters)
		for slot in director._slots:
			if slot.active: check(slot.operator == "qwen","reflection transfers visual ownership")
		director.reset()
		director.consume([event(0,"throw_end",0,"throw_f"),event(1,"land",0,"")],fighters)
		check(director.metrics().spawned == 2,"core release and empty-move land names")
		director.reset()
		director.consume([event(3),event(1),event(2)],fighters)
		check(director.metrics().accepted == 3,"arrival order tolerates bounded reordering")
		director.reset()
		for i in range(4200): director.consume([event(i,"unhandled")],fighters)
		check(director.metrics().dedup_size == 4096,"bounded dedup ledger")
		director.consume([event(0)],fighters)
		check(director.metrics().duplicates == 1,"old replay cannot reappear after eviction")
		director.reset()
		director.present_projectiles([{"id":5,"owner":0,"move_id":"special1","x":0,"y":1000}],fighters)
		director.present_projectiles([{"id":5,"owner":1,"move_id":"special1","x":1000,"y":1000}],fighters)
		check(director.metrics().active == 1,"projectile snapshot uses one slot")
		for slot in director._slots:
			if slot.active:
				check(slot.operator == "qwen","tracked reflection changes form")
				check(is_equal_approx(slot.node.position.x,1.0),"projectile units")
		director.present_projectiles([],fighters)
		check(director.metrics().active == 0,"clash/despawn removes projectile presentation")
		director.reset()
		var anchored: Array = fighters.duplicate(true)
		anchored[1].anchor_left = 60
		anchored[1].anchor_x = 1300
		director.consume([],anchored)
		check(director.metrics().active == 1,"explicit anchor snapshot creates persistent tether")
		director.consume([],fighters)
		check(director.metrics().active == 0,"anchor disappears on authority removal, not guessed expiry")
	# Actual generated vertices are finite and structurally distinct at several times.
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/assets/effects/catalog.json"))
	var fingerprints: Dictionary = {}
	for operator in catalog.families:
		var signature := ""
		for reduced in [false,true]:
			for time in [0.0,0.05,0.14,0.25]:
				var mesh := ImmediateMesh.new()
				var count := Geometry.draw(mesh,catalog.families[operator],{"operator":operator,"age":time,"life":0.3,"scale":1.0,"facing":1,"mode":"impact"},32,reduced)
				check(count <= 32,"segment budget")
				var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for v in vertices:
					check(v.is_finite() and v.length() < 3.0,"finite bounded vertices "+str(operator))
				if not reduced: signature += str(vertices)
		fingerprints[signature.sha256_text()] = true
	check(fingerprints.size() == 9,"nine sampled native geometry fingerprints")
	var claw := ImmediateMesh.new()
	var palm := ImmediateMesh.new()
	var sample := {"operator":"gemini","age":0.1,"life":0.3,"scale":1.0,"facing":1,"mode":"impact"}
	Geometry.draw(claw,catalog.families.gemini,sample,32,false)
	sample.shape_variant = "palm"
	Geometry.draw(palm,catalog.families.gemini,sample,32,false)
	check(str(claw.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]) != str(palm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]),"Gemini palm fan differs from claw petals")
	var probe := SocketProbe.new()
	root.add_child(probe)
	director.configure({"muted":true})
	var sample_fighter := {"id":0,"operator_id":"chatgpt","move_id":"stand_m","animation_frame":1,"x":0,"y":0,"facing":1}
	director.present_fighter(sample_fighter,probe)
	check(director.metrics().spawned == 0,"first socket sample emits no bridging streak")
	sample_fighter.animation_frame = 2
	probe.sample.x += 0.1
	director.present_fighter(sample_fighter,probe)
	check(director.metrics().spawned == 1,"continuous frame can emit bounded socket accent")
	sample_fighter.animation_frame = 1
	director.present_fighter(sample_fighter,probe)
	check(director.metrics().spawned == 1,"seek clears old trail")
	sample_fighter.animation_frame = 3
	sample_fighter.facing = -1
	director.present_fighter(sample_fighter,probe)
	check(director.metrics().spawned == 1,"facing flip clears old trail")
	sample_fighter.animation_frame = 4
	probe.sample.x = 1.5
	director.present_fighter(sample_fighter,probe)
	check(director.metrics().spawned == 1,"teleport cannot draw arena-crossing streak")
	director.configure({"muted":true,"reduced_motion":true})
	director.present_fighter(sample_fighter,probe)
	sample_fighter.animation_frame = 5
	director.present_fighter(sample_fighter,probe)
	check(director.metrics().spawned == 0,"reduced motion suppresses socket accents")
	probe.queue_free()
	director.queue_free()
	await process_frame
	check(root.get_child_count() == initial_children,"director teardown releases owned nodes")
	print(JSON.stringify({"gate":"fighting-effects","failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
