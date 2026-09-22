extends SceneTree
const Candidate = preload("res://player_models/candidate.gd")
const Builder = preload("res://player_models/builder.gd")
var checks := 0
var failed := false
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("PLAYER_MODEL_CHECK: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(Builder.load_recipes(),"recipe load")
	if failed: quit(1); return
	for mutator: Callable in [
		func(d): d.extra = 1,
		func(d): d.version = true,
		func(d): d.variants.claude[0].yaw = NAN,
		func(d): d.variants.claude = [],
		func(d): d.variants.claude[0].op = "execute",
		func(d): d.variants.claude[0].size[0] = INF,
		func(d): d.variants.claude[0].size[0] = -1,
		func(d): d.variants.claude[0].size[0] = true,
		func(d): d.variants.claude[0].bevel = 0.5,
		func(d): d.variants.claude[0].material = "res://secret",
		func(d): d.variants.claude.append(d.variants.claude[0]),
		func(d): d.variants.claude.resize(65)]:
		var invalid: Dictionary = Builder.recipes.duplicate(true)
		mutator.call(invalid)
		check(not Builder.validate(invalid).is_empty(),"reject invalid recipe")
	var a := Candidate.new()
	var b := Candidate.new()
	root.add_child(a)
	root.add_child(b)
	var helmet: int = a.get_node("Helmet").get_instance_id()
	var mesh_count := Builder.meshes.size()
	var summaries := []
	for id: String in ["claude","grok","meta","chatgpt","gemini","deepseek","mistral","kimi","qwen","unknown"]:
		a.apply_identity({"character":id,"team":0.0})
		b.apply_identity({"character":id,"team":1.0})
		check(a.armor != b.armor and a.identity != b.identity,"instance materials")
		check(a.armor.albedo_color != b.armor.albedo_color,"team colors")
		check(a.identity.albedo_color == b.identity.albedo_color,"character retained")
		check(a.team_marks[0].visible and not a.team_marks[1].visible and b.team_marks[1].visible,"team geometry")
		check(a.get_node("Helmet").get_instance_id() == helmet,"stable helmet across variants")
		var bounds := AABB()
		var first := true
		var triangles := 0
		var canonical := []
		for child: MeshInstance3D in a.get_children():
			check(child.transform.is_finite(),"finite transform")
			var box: AABB = child.transform * child.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			check(child.mesh.get_surface_count() == 1,"single surface")
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			check(vertices.size() > 0 and vertices.size()%3 == 0 and vertices.size()==normals.size(),"array shape")
			triangles += int(vertices.size()/3)
			for i: int in range(0,vertices.size(),3):
				var v: Vector3 = vertices[i]
				var cross: Vector3 = (vertices[i+1]-v).cross(vertices[i+2]-v)
				check(v.is_finite() and vertices[i+1].is_finite() and vertices[i+2].is_finite(),"finite vertices")
				check(cross.length_squared()>1e-16,"nondegenerate")
				check(cross.dot(normals[i])<0,"CW normal")
				check(normals[i].dot((v+vertices[i+1]+vertices[i+2])/3)>0,"outward convex normal")
			canonical.append([str(child.name),var_to_str(child.transform),var_to_str(vertices),var_to_str(normals)])
		check(is_equal_approx(bounds.position.y,-.9) and is_equal_approx(bounds.end.y,.9),"height envelope")
		check(bounds.size.x <= .701,"width envelope")
		check(triangles<=5000 and a.get_child_count()<=64,"budgets")
		check(a.get_node("Muzzle").position.z < -.5,"muzzle forward")
		for pair: Array in [["HandL","Weapon"],["HandR","WeaponGrip"]]:
			var hand: MeshInstance3D = a.get_node(pair[0])
			var attachment: MeshInstance3D = a.get_node(pair[1])
			check((hand.transform*hand.get_aabb()).intersects(attachment.transform*attachment.get_aabb()),"palm contacts compatibility weapon")
		check(a.get_node("Helmet").mesh == b.get_node("Helmet").mesh,"geometry resources shared")
		for team: Variant in [0,0.0,"0","red",1,1.0,"1","blue",null]:
			a.apply_identity({"character":id,"team":team})
			var expected: bool = team in [1,1.0,"1","blue"]
			check(a.team_marks[1].visible == expected,"numeric and string teams")
		for update: int in range(100): a.apply_identity({"character":id,"team":1.0})
		check(Builder.meshes.size()==mesh_count,"no snapshot generation")
		summaries.append({"id":id,"triangles":triangles,"meshes":a.get_child_count(),"nodes":a.get_child_count()+1,"canonical_sha256":JSON.stringify(canonical).sha256_text()})
	var populations := []
	for count: int in [1,16,32]:
		var samples := []
		for repetition: int in range(11):
			var actors := []
			var start := Time.get_ticks_usec()
			for index: int in range(count): actors.append(Candidate.new())
			samples.append(Time.get_ticks_usec()-start)
			for actor: Node in actors: actor.free()
		populations.append({"count":count,"construction_usec":samples})
	a.free()
	b.free()
	print("PLAYER_MODEL_RESULT ",JSON.stringify({"checks":checks,"passed":not failed,"variants":summaries,"cache_meshes":mesh_count,"synthetic_cpu_construction_only":populations}))
	quit(1 if failed else 0)
