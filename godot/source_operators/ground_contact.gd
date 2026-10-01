extends RefCounted
## Read-only native static-surface query; never moves the authoritative root.
## Missing terrain/water/large ledges keep the source feet plane, not a new fall.
static func offset(owner: Node3D, point: Vector3, plane_y: float, limit: float = 0.12) -> float:
	if not owner.is_inside_tree() or owner.get_world_3d() == null: return 0.0
	var from := Vector3(point.x,plane_y+0.30,point.z)
	var to := Vector3(point.x,plane_y-0.30,point.z)
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	query.collide_with_areas = false
	var hit := owner.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is StaticBody3D: return 0.0
	var difference: float = hit.position.y-plane_y
	return clampf(difference,-limit,limit)
