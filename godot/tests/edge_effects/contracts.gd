extends SceneTree
const Occlusion = preload("res://world/combat_occlusion.gd")
const Impacts = preload("res://player_fx/impacts.gd")
const Structures = preload("res://campaign/structure_art.gd")
const Marks = preload("res://player_fx/mark_pool.gd")
var failures: Array[String] = []
var checks := 0
class Host extends Node3D:
	var recipe: Dictionary
	func height_at(_x: float, _z: float) -> float: return 0.0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
func _initialize() -> void: call_deferred("run")
func vector(p: Dictionary) -> Vector3: return Vector3(p.x,p.y,p.z)
func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("EDGE_SOURCE_EVENTS")))
	var host := Host.new()
	host.recipe = fixture.data
	root.add_child(host)
	var art := Structures.new()
	host.add_child(art)
	art.build(host)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0,2,8)
	var geometry := Occlusion.new()
	check(geometry.configure(camera,{"id":"source-cabin","collision_root":host}),"actual facade bodies configured")
	await physics_frame
	await physics_frame
	for record: Dictionary in fixture.records:
		if record.kind != "ray": continue
		var from := vector(record.o)
		var hit := geometry.contact(from,from+vector(record.d)*record.max)
		var distance: float = from.distance_to(hit.position) if not hit.is_empty() else float(record.max)
		check(absf(distance-float(record.after)) < 0.0001,"imported facade/native source distance " + str(record.o))
	var effects := Impacts.new()
	root.add_child(effects)
	effects.configure(camera,geometry)
	effects.set_map({"id":"source-cabin","collision_root":host})
	var face := geometry.contact(Vector3(0,2,8),Vector3(0,2,0))
	check(not face.is_empty(),"front closed wall")
	var surface: Dictionary = effects._surface_at(face.position,Vector3.FORWARD)
	check(not surface.is_empty() and surface.normal.dot(Vector3.BACK)>0.99,"incoming native probe returns outward face normal")
	check(effects._surface_at(Vector3(10,3,10),Vector3.DOWN).is_empty(),"open air never fabricates a blast plane")
	check(effects._surface_at(face.position+Vector3.BACK*0.04,Vector3.FORWARD).is_empty(),"range ending 4cm before wall never invents impact")
	for record: Dictionary in fixture.records:
		if record.kind != "muzzle-cover": continue
		effects.reset()
		effects.consume(record.after.events,0)
		check(effects.counters.actor_hits==0 and effects.counters.confirmed==1,"source blocked-candidate event draws true wall cue")
	# Semantic geometry includes wall triangles, returns actual slope normals,
	# and slab normals are chosen by entry parameter rather than nearest centre.
	var semantic := Occlusion.new()
	semantic.configure(camera,{"id":"slab","blocks":[{"x":0,"z":0,"w":2,"d":2,"h":2}],"terrain":{"wall_triangles":[{"vertices":[[4,0,-2],[4,4,-2],[4,0,2]]}]}})
	for x: float in [0.999,1.0,1.001]:
		var hit := semantic.contact(Vector3(x,1,3),Vector3(x,1,-3))
		check(not hit.is_empty() if x <= 1.0 else hit.is_empty(),"semantic exact box epsilon " + str(x))
	check(semantic.segment_blocked(Vector3(3,1,0),Vector3(5,1,0)),"semantic wall triangle occludes")
	check(semantic.contact(Vector3(0,3,0),Vector3(0,1,0)).normal == Vector3.UP,"top face normal")
	check(semantic.contact(Vector3(0,-1,0),Vector3(0,1,0)).normal == Vector3.DOWN,"underside face normal")
	effects.configure(camera,semantic)
	effects.set_map({"id":"slab","blocks":[{"x":0,"z":0,"w":2,"d":2,"h":2}]})
	check(effects._mark_flat(Vector3(0,1,1),Vector3.BACK,Marks.basis(Vector3.BACK,0),0.3),"mark supported in face interior")
	check(not effects._mark_flat(Vector3(0.99,1,1),Vector3.BACK,Marks.basis(Vector3.BACK,0),0.3),"wall-edge footprint cannot float into air")
	check(not effects._mark_flat(Vector3(0,1,1.02),Vector3.BACK,Marks.basis(Vector3.BACK,0),0.3),"nearby parallel surface is not the same mark plane")
	var slope := Occlusion.new()
	slope.configure(camera,{"id":"slope","terrain":{"support_triangles":[{"vertices":[[-2,0,-2],[-2,0,2],[2,2,2]]}]}})
	var crossing := slope.contact(Vector3(-0.5,3,0.5),Vector3(-0.5,-1,0.5))
	check(not crossing.is_empty() and absf(crossing.position.y-0.75)<0.001,"TriangleMesh Dictionary position is consumed")
	check(not crossing.is_empty() and crossing.normal.dot(Vector3(-0.5,1,0).normalized())>0.999,"slope uses real triangle normal, not fabricated UP")
	# Finite stress: reuse every preallocated node/material; no per-shot growth.
	var pool := Marks.new()
	root.add_child(pool)
	pool.configure(camera)
	var identities: Array[int] = []
	for slot: Dictionary in pool.slots: identities.append(slot.node.get_instance_id())
	for index: int in 1000: pool.place(Vector3.ZERO,Vector3.BACK,"metal",0,0.3,index)
	check(pool.live()==44 and pool.get_child_count()==44,"1000 marks bounded at high cap")
	for index: int in pool.slots.size(): check(pool.slots[index].node.get_instance_id()==identities[index],"pool identity stable")
	pool.advance(0.0)
	check(pool.live()==44,"zero elapsed pause retains marks")
	pool.set_quality(0)
	check(pool.live()==20,"quality reduces pool immediately")
	pool.reset()
	check(pool.live()==0,"reset retires all marks")
	pool.free()
	effects.free()
	host.free()
	camera.free()
	print("EDGE_EFFECTS_CONTRACTS ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
