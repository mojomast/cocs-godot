extends RefCounted
## A viewmodel has its own camera/projection/world. Preserve its normalized pixel
## coordinate, then reconstruct at its camera-space depth in the source world.
static func map_tip(source: Camera3D, view_camera: Camera3D, tip: Node3D) -> Dictionary:
	if not is_instance_valid(source) or not is_instance_valid(view_camera) or not is_instance_valid(tip): return {}
	if not source.is_inside_tree() or not view_camera.is_inside_tree() or not tip.is_inside_tree(): return {}
	var local := view_camera.get_camera_transform().affine_inverse() * tip.global_position
	if not local.is_finite() or -local.z < 0.03 or -local.z > 4.0 or local.length() > 5.0: return {}
	var view_size := view_camera.get_viewport().get_visible_rect().size
	var world_size := source.get_viewport().get_visible_rect().size
	if view_size.x <= 0 or view_size.y <= 0 or world_size.x <= 0 or world_size.y <= 0: return {}
	var uv := view_camera.unproject_position(tip.global_position) / view_size
	if not uv.is_finite() or uv.x < -0.1 or uv.x > 1.1 or uv.y < -0.1 or uv.y > 1.1: return {}
	var pixel := uv * world_size
	var world := source.project_position(pixel, -local.z)
	if not world.is_finite() or source.get_camera_transform().origin.distance_to(world) > 6.0: return {}
	return {"position":world, "pixel":pixel, "depth":-local.z, "projection_error_px":source.unproject_position(world).distance_to(pixel)}

static func blocked(camera: Camera3D, from: Vector3, to: Vector3, mask: int = 1, occlusion: Callable = Callable()) -> bool:
	if from.distance_squared_to(to) < 0.000001: return false
	if occlusion.is_valid():
		var result: Variant = occlusion.call(from, to)
		# Callback uses source/semantic geometry for mesh-only original maps.
		# Unknown/malformed answers fail closed rather than asserting clear sight.
		return result if result is bool else true
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.hit_from_inside = true
	return not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func resolve(source: Camera3D, view_camera: Camera3D, tip: Node3D, authoritative: Vector3, endpoint: Vector3, mask: int = 1, occlusion: Callable = Callable()) -> Dictionary:
	var mapped := map_tip(source, view_camera, tip)
	if mapped.is_empty() or not authoritative.is_finite() or not endpoint.is_finite(): return {}
	if authoritative.distance_to(source.get_camera_transform().origin) > 8.0: return {}
	var direction := endpoint - authoritative
	# A projectile has no ray endpoint yet. If the actual visible barrel tip is
	# already behind cover, shortening its cosmetic depth to the public muzzle
	# would make a launch appear in front of that cover. Reject it instead.
	if direction.length_squared() <= 0.000001 and blocked(source, source.get_camera_transform().origin, mapped.position, mask, occlusion): return {}
	# The viewmodel is deliberately larger/farther than the public muzzle. Use
	# its *pixel*, not its private-world depth: a world tracer or projectile at
	# the viewmodel depth could start behind a nearby wall or even its target.
	var camera_space := source.get_camera_transform().affine_inverse()
	var depth := -(camera_space * authoritative).z
	if direction.length_squared() > 0.000001:
		depth = minf(depth, -(camera_space * endpoint).z - 0.06)
	if depth < 0.03: return {}
	var origin: Vector3 = source.project_position(mapped.pixel, depth)
	if not origin.is_finite(): return {}
	mapped["view_depth"] = mapped.depth
	mapped["depth"] = depth
	mapped["position"] = origin
	if direction.length_squared() > 0.000001:
		# An eye ray can hit a wall *behind* the visible barrel mouth. Do not
		# draw a backwards round from a muzzle already beyond that hit. A
		# projectile launch has no endpoint yet and is checked separately below.
		if (camera_space * endpoint).z > (camera_space * origin).z + 0.02: return {}
	# Fail closed near walls. Never move a public endpoint or synthesize an impact.
	if blocked(source, source.get_camera_transform().origin, origin, mask, occlusion): return {}
	var join := authoritative + direction.normalized() * minf(1.25, direction.length() * 0.25)
	if blocked(source, origin, join, mask, occlusion): return {}
	mapped["join"] = join
	mapped["endpoint"] = endpoint
	return mapped

## A remote weapon already occupies the source world. The host supplies its
## actual animated world-model muzzle; no first-person projection is involved.
## Keep the public ray/end intact and reject mismatched actors or cover edges.
static func resolve_world(camera: Camera3D, muzzle: Vector3, authoritative: Vector3, endpoint: Vector3, occlusion: Callable) -> Dictionary:
	if not is_instance_valid(camera) or not muzzle.is_finite() or not authoritative.is_finite() or not endpoint.is_finite(): return {}
	if muzzle.distance_to(authoritative) > 2.0: return {}
	if blocked(camera, authoritative, muzzle, 1, occlusion): return {}
	var direction := endpoint - authoritative
	var join := authoritative + direction.normalized() * minf(1.25, direction.length() * 0.25)
	if direction.length_squared() > 0.000001 and (endpoint - muzzle).dot(direction) <= 0.0: return {}
	if blocked(camera, muzzle, join, 1, occlusion): return {}
	return {"position":muzzle, "join":join, "endpoint":endpoint}
