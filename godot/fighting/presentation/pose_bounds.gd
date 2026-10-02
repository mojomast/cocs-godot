extends RefCounted
## Read-only skin envelope. Cache bind-local vertex boxes once, then transform
## their eight corners by the real presented skeleton; no animation API changes.
var groups: Array = []

func configure(provider: Node3D) -> void:
	groups.clear()
	for node: Node in provider.find_children("*","MeshInstance3D",true,false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or mesh_node.skin == null: continue
		var skeleton := mesh_node.get_node_or_null(mesh_node.skeleton) as Skeleton3D
		if skeleton == null: continue
		var boxes := {}
		var skin: Skin = mesh_node.skin
		for surface: int in mesh_node.mesh.get_surface_count():
			var arrays: Array = mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: Variant = arrays[Mesh.ARRAY_BONES]
			var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			if joints == null or weights == null or vertices.is_empty(): continue
			var stride := int(joints.size()/vertices.size())
			for i: int in vertices.size():
				for j: int in stride:
					if float(weights[i*stride+j]) <= 0.0: continue
					var bind := int(joints[i*stride+j])
					var point := skin.get_bind_pose(bind) * vertices[i]
					if boxes.has(bind): boxes[bind] = (boxes[bind] as AABB).expand(point)
					else: boxes[bind] = AABB(point,Vector3.ZERO)
		for bind: int in boxes:
			var bone := skin.get_bind_bone(bind)
			if not skin.get_bind_name(bind).is_empty(): bone = skeleton.find_bone(skin.get_bind_name(bind))
			if bone >= 0: groups.append({"node":mesh_node,"skeleton":skeleton,"bone":bone,"box":boxes[bind]})

func envelope() -> Rect2:
	var result := Rect2()
	var found := false
	for group: Dictionary in groups:
		if not is_instance_valid(group.node) or not group.node.visible: continue
		var skeleton: Skeleton3D = group.skeleton
		var transform := skeleton.global_transform * skeleton.get_bone_global_pose(int(group.bone))
		var box: AABB = group.box
		for i: int in 8:
			var point: Vector3 = transform * box.get_endpoint(i)
			var xy := Vector2(point.x,point.y)
			result = result.expand(xy) if found else Rect2(xy,Vector2.ZERO)
			found = true
	return result
