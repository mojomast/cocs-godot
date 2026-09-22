extends RefCounted
## Review props: the representative geometry each family is judged on.
##
## Deliberately ordinary shapes: a floor slab, a wall, a rail, a prop and a
## rounded object. Nothing here is gameplay; nothing here has collision, terrain,
## spawn or nav meaning.

const Language = preload("res://material_language/library.gd")
# Plain Array consts: GDScript cannot resolve a PackedStringArray const across
# scripts at parse time, and this table is only ever iterated.
const ROLES := ["floor", "wall", "rail", "prop", "round"]
const ROLE_LABELS := ["floor slab", "wall", "rail", "prop", "rounded"]

static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func cylinder(radius: float, height: float, segments: int = 48) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh

static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	return mesh

## One material per family, plus one variant where the family has variants, so a
## station shows the family and one of its swaps. Shared across the station.
static func materials(family: String) -> Dictionary:
	var variants: PackedStringArray = Language.variants(family)
	var main: Material = Language.material(family, {})
	var variant_name: String = variants[1] if variants.size() > 1 else ""
	var variant: Material = Language.material(family, {"variant": variant_name}) if variant_name != "" else main
	var rail: Material = Language.material(family, {
		"variant": variant_name,
		"tiles_per_metre": float(Language.describe(family).density.tiles_per_metre) * 1.6,
		"normal_strength": 0.42,
	}) if variant_name != "" else main
	var round_material: Material = main
	return {
		"floor": main, "wall": main, "rail": rail, "prop": variant, "round": round_material,
		"variant": variant_name,
	}

## Builds a station at the origin. Caller positions/rotates it.
static func build(family: String, parent: Node) -> Dictionary:
	var station := Node3D.new()
	station.name = family
	parent.add_child(station)
	var assigned := materials(family)
	var nodes: Array[MeshInstance3D] = []
	# Floor slab: flat, wide, the surface that shows tiling and distance fade.
	nodes.append(_add(station, box(Vector3(3.7, 0.24, 2.7)), Vector3(0, 0, 0), assigned.floor, "FloorSlab"))
	# Wall: vertical face, shows the same tile on a second axis (triplanar).
	nodes.append(_add(station, box(Vector3(0.26, 2.3, 2.7)), Vector3(-1.72, 1.15, 0), assigned.wall, "Wall"))
	# Rail: a long thin cylinder, the worst case for texel density.
	var rail := _add(station, cylinder(0.075, 3.3, 24), Vector3(0, 1.32, 1.05), assigned.rail, "Rail")
	rail.rotation_degrees = Vector3(0, 0, 90)
	nodes.append(rail)
	# Prop: a small machinery stack, three boxes at three sizes.
	var prop := Node3D.new()
	prop.name = "Prop"
	prop.position = Vector3(1.18, 0.12, -0.72)
	station.add_child(prop)
	_add(prop, box(Vector3(0.72, 0.62, 0.72)), Vector3(0, 0.31, 0), assigned.prop, "PropBody")
	_add(prop, box(Vector3(0.52, 0.34, 0.44)), Vector3(0.06, 0.79, 0.05), assigned.prop, "PropHead")
	_add(prop, box(Vector3(0.2, 0.5, 0.2)), Vector3(-0.42, 0.25, 0.3), assigned.prop, "PropPost")
	# Rounded object: sphere plus a torus ring, the curvature test for the accent.
	var round_node := _add(station, sphere(0.58), Vector3(0.95, 0.7, 0.86), assigned.round, "Round")
	nodes.append(round_node)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.72
	ring.outer_radius = 0.78
	ring.rings = 48
	ring.ring_segments = 10
	var ring_node := _add(station, ring, Vector3(0.95, 0.7, 0.86), assigned.rail, "Ring")
	ring_node.rotation_degrees = Vector3(16, 0, 8)
	nodes.append(ring_node)
	station.set_meta("nodes", nodes)
	station.set_meta("assigned", assigned)
	return {"station": station, "assigned": assigned, "nodes": nodes}

static func _add(parent: Node, mesh: Mesh, position: Vector3, material: Material, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node

## A long floor strip for the distance/shimmer check: the same material stretched
## away from the camera.
static func distance_strip(family: String, parent: Node, length: float = 60.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "DistanceStrip"
	node.mesh = box(Vector3(6.0, 0.2, length))
	node.position = Vector3(0, -0.1, -length * 0.5 + 2.0)
	node.material_override = Language.material(family, {})
	parent.add_child(node)
	return node
