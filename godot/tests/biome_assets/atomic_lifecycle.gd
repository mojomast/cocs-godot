extends SceneTree
## Engine contract with injected scenes, NOT native production-asset proof.
const Pack = preload("res://biomes/expansion/scenery_pack.gd")

class Host extends Node3D:
	var recipe: Dictionary

class DoublePack extends "res://biomes/expansion/scenery_pack.gd":
	var calls := 0
	var bad_at := 6
	var mode := "null"
	var observed: Array = []
	var errors: Array = []
	var shared := StandardMaterial3D.new()
	func _exists(_path: String) -> bool: return mode != "missing"
	func _report_failure(code: String, path: String) -> void: errors.append([code,path])
	func _fail(pending: Array[Node3D], required: bool, code: String, path: String) -> bool:
		for instance: Node3D in pending: observed.append(weakref(instance))
		return super._fail(pending,required,code,path)
	func _load(_path: String) -> Resource:
		calls += 1
		assert(loaded_assets.is_empty() and recipe_hash.is_empty(),"No partial bookkeeping during preparation")
		if calls == bad_at and mode == "null": return null
		if calls == bad_at and mode == "resource": return Resource.new()
		var node: Node = Node.new() if calls == bad_at and mode == "root" else Node3D.new()
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.material = shared
		mesh.mesh = box
		if calls == bad_at and mode == "empty": mesh.mesh=null
		node.add_child(mesh);mesh.owner=node
		if calls == bad_at and mode == "collision":
			var collision := StaticBody3D.new()
			node.add_child(collision);collision.owner=node
		if calls == bad_at and mode == "transform": (node as Node3D).scale=Vector3.ZERO
		var packed := PackedScene.new()
		assert(packed.pack(node)==OK)
		node.free()
		return packed

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var host := Host.new()
	host.recipe=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/generated/rootfall-verge.json"))
	var pack := DoublePack.new()
	root.add_child(pack)
	assert(not Pack.valid_vector([INF,0,0]))
	assert(not Pack.valid_vector([1,0,1],true))
	assert(not Pack.valid_vector([1,2]))
	for mode: String in ["null","resource","root","collision","transform","empty","missing"]:
		for required: bool in [false,true]:
			pack.mode=mode;pack.calls=0;pack.observed.clear();pack.errors.clear()
			assert(not pack.build(host,required))
			assert(pack.loaded_assets.is_empty() and pack.recipe_hash.is_empty() and pack.get_child_count()==0)
			assert(pack.observed.all(func(w: WeakRef) -> bool: return w.get_ref()==null),"Failed pending instances freed synchronously")
			assert(pack.last_build.status==("failed" if required else "fallback"))
			assert(pack.errors.size()==(1 if required else 0))
	pack.mode="valid";pack.calls=0
	assert(pack.build(host,true))
	assert(pack.loaded_assets.size()==3 and pack.get_child_count()==6)
	var first: MeshInstance3D=pack.get_child(0).get_child(0)
	var second: MeshInstance3D=pack.get_child(1).get_child(0)
	assert(first.get_active_material(0)!=pack.shared and first.get_active_material(0)!=second.get_active_material(0))
	(first.get_active_material(0) as StandardMaterial3D).albedo_color=Color.RED
	assert(pack.shared.albedo_color!=Color.RED and (second.get_active_material(0) as StandardMaterial3D).albedo_color!=Color.RED)
	for value: bool in [true,true,false,false]:
		pack.set_reduced_detail(value)
		for instance: Node3D in pack.get_children():
			var lod: int=instance.get_meta("biome4_lod")
			assert(instance.visible==(not value or lod==1))
			var mesh: MeshInstance3D=instance.get_child(0)
			assert(mesh.visibility_range_begin==(85.0 if lod==1 and not value else 0.0))
	var old: Array=[]
	for instance: Node in pack.get_children(): old.append(weakref(instance))
	pack.calls=0
	assert(pack.build(host,true))
	assert(old.all(func(w: WeakRef) -> bool: return w.get_ref()==null))
	pack.mode="resource";pack.calls=0
	assert(not pack.build(host,true))
	assert(pack.loaded_assets.is_empty() and pack.get_child_count()==0 and pack.recipe_hash.is_empty())
	pack.clear();pack.clear()
	assert(pack.loaded_assets.is_empty() and pack.get_child_count()==0)
	pack.free();host.free()
	print("BIOME4_DOUBLE_LIFECYCLE_OK not-production-asset-proof")
	quit()
