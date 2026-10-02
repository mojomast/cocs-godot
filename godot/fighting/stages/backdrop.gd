extends Node3D
## Visual-only native resource composition. No FPS scene/build() is instantiated.
const Catalog = preload("res://fighting/stages/catalog.gd")
const Biome = preload("res://biomes/map.gd")
const Campaign = preload("res://campaign/terrain.gd")
var metrics: Dictionary = {}

func build(id: String) -> bool:
	var spec := Catalog.entry(id)
	if spec.is_empty(): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec.recipe))
	if not parsed is Dictionary or parsed.get("geometryHash","") != spec.geometry_hash: return false
	var recipe: Dictionary = parsed
	var origin := Vector3(spec.origin[0],spec.origin[1],spec.origin[2])
	origin.y = _floor_height(recipe,origin.x,origin.z)
	if not is_finite(origin.y): return false
	var source := Node3D.new()
	source.name = "SourceGeometry"
	source.add_to_group("fighting_backdrop")
	source.position = -origin
	add_child(source)
	if id == "helix-conservatory": return _helix(source,spec,origin)
	var helper = Campaign.new() if id == "crown-array" else Biome.new()
	helper.recipe = recipe
	if id != "crown-array": helper.forest = id == "canopy-divide"
	helper._make_materials()
	var materials: Dictionary = helper.materials
	var triangles := 0
	# Whole source vertices preserved. Only triangles fully behind the lane and
	# inside the crop survive; never create cut-face physics or interpolate art.
	var surfaces: Array = recipe.arena.terrain.surfaces.duplicate()
	if id != "crown-array": surfaces.append_array(recipe.art)
	for surface: Dictionary in surfaces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := 0
		for tri: Array in surface.triangles:
			var a := _v(surface.vertices[tri[0]])
			var b := _v(surface.vertices[tri[1]])
			var c := _v(surface.vertices[tri[2]])
			if not _inside(a,origin) or not _inside(b,origin) or not _inside(c,origin): continue
			var normal := (b-a).cross(c-a).normalized()
			for vertex: Vector3 in [a,c,b]:
				st.set_normal(normal)
				st.add_vertex(vertex)
			count += 1
		if count == 0: continue
		var node := MeshInstance3D.new()
		node.name = str(surface.id)
		node.mesh = st.commit()
		node.material_override = materials.get(surface.material,materials.get("ground"))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		source.add_child(node)
		triangles += count
	if id == "crown-array":
		_crown(source,helper,recipe,origin)
	else:
		_biome(source,helper,recipe,origin)
	helper.free()
	# A full flat visual platform lies at the sim's y=0, z=0. No native collider.
	_platform(id)
	metrics = {"stage":id,"geometry_hash":spec.geometry_hash,"source_origin":[origin.x,origin.y,origin.z],"terrain_triangles":triangles,"native_profile":"pending","art_inspection":"pending"}
	return triangles > 0

func _platform(id: String) -> void:
	var floor := MeshInstance3D.new()
	floor.name = "FightPlatform"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(20,0.35,5)
	floor.mesh = mesh
	floor.position = Vector3(0,-0.175,0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("505c61") if id == "crown-array" else Color("526e51") if id == "helix-conservatory" else Color("646451") if id == "canopy-divide" else Color("826f59")
	mat.roughness = 0.94
	floor.material_override = mat
	add_child(floor)
	if id == "helix-conservatory":
		var trim := MeshInstance3D.new()
		var trim_mesh := BoxMesh.new()
		trim_mesh.size = Vector3(20,0.04,0.12)
		trim.mesh = trim_mesh
		trim.position = Vector3(0,-0.02,2.4)
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color("a18b55")
		gold.roughness = 0.8
		trim.material_override = gold
		add_child(trim)

static func _v(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])

static func _inside(p: Vector3, origin: Vector3) -> bool:
	var local := p-origin
	return absf(local.x) <= 45.0 and local.z <= -4.0 and local.z >= -65.0

static func _floor_height(recipe: Dictionary, x: float, z: float) -> float:
	var best := -INF
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		for tri: Array in surface.triangles:
			var a := _v(surface.vertices[tri[0]])
			var b := _v(surface.vertices[tri[1]])
			var c := _v(surface.vertices[tri[2]])
			var denominator := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
			if absf(denominator) < 0.000001: continue
			var u := ((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/denominator
			var v := ((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/denominator
			var w := 1.0-u-v
			if minf(u,minf(v,w)) >= -0.00001: best = maxf(best,u*a.y+v*b.y+w*c.y)
	return best

func _biome(root: Node3D, helper: Variant, recipe: Dictionary, origin: Vector3) -> void:
	var trees: Array[Transform3D] = []
	for block: Dictionary in recipe.arena.blocks:
		var at := Vector3(block.x,block.baseY,block.z)
		if not _inside(at,origin) or block.z+block.d*0.5 > origin.z-4: continue
		if str(block.id).begins_with("tree-"):
			trees.append(Transform3D(Basis.IDENTITY,at))
			continue
		var node := MeshInstance3D.new()
		node.name = str(block.id)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(block.w,block.h-block.baseY,block.d)
		node.mesh = mesh
		node.position = Vector3(block.x,(block.h+block.baseY)*0.5,block.z)
		node.material_override = helper.materials[block.material]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	if not trees.is_empty():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = helper._tree_mesh()
		multi.instance_count = trees.size()
		for i: int in trees.size(): multi.set_instance_transform(i,trees[i])
		var node := MultiMeshInstance3D.new()
		node.name = "NativeCanopyTrees"
		node.multimesh = multi
		var foliage := ShaderMaterial.new()
		foliage.shader = load("res://biomes/foliage.gdshader")
		node.material_override = foliage
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)

func _crown(root: Node3D, helper: Variant, recipe: Dictionary, origin: Vector3) -> void:
	# Reuse actual campaign prop mesh assets. Retain source rotation convention.
	var groups := {}
	for prop: Dictionary in recipe.art:
		var at := _v(prop.position)
		var scale_value := _v(prop.scale)
		if not _inside(at,origin) or at.z+scale_value.z*0.5 > origin.z-4: continue
		if prop.kind == "dish" and scale_value.x > 20:
			var scene: PackedScene = load("res://campaign/art/landmarks/crown-receiver.glb")
			var instance := scene.instantiate()
			# Copy only mesh resources/local transforms, omitting any imported scripts.
			_copy_meshes(instance,Transform3D(Basis.from_scale(scale_value),at),root)
			instance.free()
			continue
		helper._group(groups,str(prop.kind),str(prop.material),at,scale_value)
	for group: Dictionary in groups.values():
		helper._batch(group,false)
	for child: Node in helper.get_children():
		helper.remove_child(child)
		root.add_child(child)
		if child is GeometryInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _copy_meshes(node: Node, transform: Transform3D, root: Node3D) -> void:
	if node is Node3D: transform = transform * node.transform
	if node is MeshInstance3D:
		var copy := MeshInstance3D.new()
		copy.mesh = node.mesh
		copy.transform = transform
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(copy)
	for child: Node in node.get_children(): _copy_meshes(child,transform,root)

func _helix(source: Node3D, spec: Dictionary, origin: Vector3) -> bool:
	if FileAccess.get_sha256(spec.glb) != spec.glb_sha256: return false
	var scene: PackedScene = load(spec.glb)
	if scene == null: return false
	var instance := scene.instantiate()
	var count := _crop_glb(instance,Transform3D.IDENTITY,source,origin)
	instance.free()
	_platform("helix-conservatory")
	metrics = {"stage":spec.id,"geometry_hash":spec.geometry_hash,"glb_sha256":spec.glb_sha256,"source_origin":[origin.x,origin.y,origin.z],"triangles":count,"native_profile":"pending","art_inspection":"pending"}
	return count > 0

func _crop_glb(node: Node, transform: Transform3D, root: Node3D, origin: Vector3) -> int:
	if node is Node3D: transform = transform * node.transform
	var count := 0
	if node is MeshInstance3D:
		var combined := ArrayMesh.new()
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var kept := 0
			var total := vertices.size() if indices.is_empty() else indices.size()
			for i: int in range(0,total,3):
				var points: Array[Vector3] = []
				for j: int in 3: points.append(transform * vertices[i+j if indices.is_empty() else indices[i+j]])
				if not _inside(points[0],origin) or not _inside(points[1],origin) or not _inside(points[2],origin): continue
				var normal := (points[2]-points[0]).cross(points[1]-points[0]).normalized()
				for j: int in 3:
					var index := i+j if indices.is_empty() else indices[i+j]
					st.set_normal(normal)
					if arrays[Mesh.ARRAY_TEX_UV] != null: st.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
					if arrays[Mesh.ARRAY_COLOR] != null: st.set_color(arrays[Mesh.ARRAY_COLOR][index])
					st.add_vertex(points[j])
				kept += 1
			if kept > 0:
				st.set_material(node.mesh.surface_get_material(surface))
				st.commit(combined)
				count += kept
		if combined.get_surface_count() > 0:
			var copy := MeshInstance3D.new()
			copy.name = str(node.name)
			copy.mesh = combined
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(copy)
	for child: Node in node.get_children(): count += _crop_glb(child,transform,root,origin)
	return count
