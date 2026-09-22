extends RefCounted
## Native supply miniatures; authored here, not imported viewmodel attachments.
## Source taxonomy: game/maps.mjs pickupWeapon and game/data.mjs POWERUPS /
## ECONOMY_PICKUPS. No starter-sidearm pickup exists in that mapping.
const WEAPONS := ["rocket", "rail", "scatter", "plasma", "grenade", "shock", "flak", "marksman", "smg"]
const KINDS := ["health", "megahealth", "armor", "ammo", "rocket", "rail", "scatter", "plasma", "grenade", "shock", "flak", "marksman", "smg", "haste", "overcharge", "overshield", "recon", "cloak", "weaponUpgrade", "deployable", "unknown"]
const COLORS := {
	"health": "54e5af", "megahealth": "adf8d9", "armor": "63baff", "ammo": "f4ce73",
	"rocket": "ff995c", "rail": "74e7f7", "scatter": "ffc977", "plasma": "69b3ff",
	"grenade": "b4df65", "shock": "c8a0ff", "flak": "ffa76b", "marksman": "a3e4ea", "smg": "f3dc9b",
	"haste": "72f1b8", "overcharge": "ff8f70", "overshield": "75baff", "recon": "7fe7ff",
	"cloak": "c8b6ff", "weaponUpgrade": "ffd166", "deployable": "8affc1", "unknown": "b6bfce",
}
static var _meshes: Dictionary = {}
static var _ring: TorusMesh
static var _dark: StandardMaterial3D
static var _white: StandardMaterial3D
var groups: Array[SurfaceTool] = []

static func canonical(kind: String) -> String:
	return kind if kind in KINDS else "unknown"

static func solid_material(white: bool) -> StandardMaterial3D:
	if _dark == null:
		_dark = StandardMaterial3D.new()
		_dark.albedo_color = Color("253747")
		_dark.metallic = 0.5
		_dark.roughness = 0.45
		_white = StandardMaterial3D.new()
		_white.albedo_color = Color("e7f1eb")
		_white.roughness = 0.55
	return _white if white else _dark

static func ring() -> TorusMesh:
	if _ring == null:
		_ring = TorusMesh.new()
		_ring.inner_radius = 0.345
		_ring.outer_radius = 0.365
		_ring.rings = 32
		_ring.ring_segments = 6
	return _ring

static func meshes(kind: String) -> Array:
	var key := canonical(kind)
	if not _meshes.has(key):
		var builder = load("res://combat_pickup_assets/catalog.gd").new()
		_meshes[key] = builder.build(key)
	return _meshes[key]

static func cache_size() -> int:
	return _meshes.size()

func part(mesh: Mesh, position: Vector3, group: int, rotation: Vector3 = Vector3.ZERO) -> void:
	groups[group].append_from(mesh, 0, Transform3D(Basis.from_euler(rotation), position))

func box(position: Vector3, size: Vector3, group: int, tilt: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	part(mesh, position, group, Vector3(0, 0, tilt))

func cylinder(position: Vector3, radius: float, height: float, group: int, top: float = -1.0, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	part(mesh, position, group, rotation)

func shield(scale_factor: float = 1.0) -> void:
	box(Vector3(0, 0.07, 0), Vector3(0.49, 0.30, 0.19) * scale_factor, 1)
	var tip := PrismMesh.new()
	tip.size = Vector3(0.49, 0.27, 0.19) * scale_factor
	part(tip, Vector3(0, -0.21, 0), 1, Vector3(0, 0, PI))
	for side in [-1.0, 1.0]:
		box(Vector3(0, 0.02, side * 0.105), Vector3(0.055, 0.3, 0.025), 2)
		box(Vector3(0, 0.12, side * 0.108), Vector3(0.3, 0.04, 0.025), 2)

func build(kind: String) -> Array:
	for i in range(3):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups.append(tool)
	# Small suspended docking shoe: no pedestal or collider suggesting cover.
	box(Vector3(0, -0.33, 0), Vector3(0.26, 0.055, 0.22), 0)
	box(Vector3(0, -0.30, 0.115), Vector3(0.13, 0.025, 0.015), 2)
	match kind:
		"health", "megahealth":
			cylinder(Vector3.ZERO, 0.22, 0.43, 1)
			for y in [-0.25, 0.25]: cylinder(Vector3(0, y, 0), 0.24, 0.065, 0)
			for side in [-1.0, 1.0]:
				box(Vector3(0, 0, side * 0.215), Vector3(0.08, 0.30, 0.025), 2)
				box(Vector3(0, 0, side * 0.215), Vector3(0.28, 0.08, 0.025), 2)
			if kind == "megahealth":
				for x in [-0.29, 0.29]: cylinder(Vector3(x, 0, 0), 0.055, 0.34, 2)
		"armor", "overshield":
			shield()
			for x in [-0.29, 0.29]:
				cylinder(Vector3(x, -0.01, 0), 0.055, 0.31, 0)
				if kind == "overshield": box(Vector3(x, 0.09, 0), Vector3(0.07, 0.39, 0.09), 2)
		"ammo":
			box(Vector3(0, -0.20, 0), Vector3(0.49, 0.12, 0.24), 0)
			for x in [-0.16, 0.0, 0.16]:
				cylinder(Vector3(x, 0.025, 0), 0.06, 0.37, 1)
				cylinder(Vector3(x, 0.225, 0), 0.055, 0.05, 2)
		"haste":
			for y in [-0.11, 0.13]:
				box(Vector3(-0.09, y, 0), Vector3(0.095, 0.29, 0.13), 1, -0.65)
				box(Vector3(0.09, y, 0), Vector3(0.095, 0.29, 0.13), 1, 0.65)
		"overcharge":
			box(Vector3.ZERO, Vector3(0.27, 0.27, 0.27), 1, PI / 4)
			for x in [-0.28, 0.28]: box(Vector3(x, 0, 0), Vector3(0.05, 0.27, 0.09), 2, -x)
		"recon":
			cylinder(Vector3.ZERO, 0.22, 0.09, 1, -1, Vector3(PI / 2, 0, 0))
			box(Vector3(0, -0.13, 0), Vector3(0.06, 0.3, 0.09), 0)
			box(Vector3(0.065, 0.07, 0.055), Vector3(0.035, 0.22, 0.025), 2, -0.65)
		"cloak":
			cylinder(Vector3.ZERO, 0.24, 0.48, 1, 0)
			box(Vector3(0, -0.07, 0.16), Vector3(0.25, 0.045, 0.025), 2)
		"weaponUpgrade":
			box(Vector3(0, -0.03, 0), Vector3(0.17, 0.34, 0.17), 1)
			for x in [-0.12, 0.12]: box(Vector3(x, 0.12, 0), Vector3(0.075, 0.30, 0.12), 2, signf(x) * 0.8)
		"deployable":
			box(Vector3(0, 0.05, 0), Vector3(0.38, 0.23, 0.25), 1)
			box(Vector3(0, 0.06, 0.18), Vector3(0.15, 0.10, 0.18), 2)
			for x in [-0.17, 0.17]: box(Vector3(x, -0.18, 0), Vector3(0.07, 0.25, 0.15), 0, x * 2)
		_:
			if kind in WEAPONS: weapon(kind)
			else:
				box(Vector3.ZERO, Vector3(0.37, 0.30, 0.27), 0)
				box(Vector3(0, 0, 0.145), Vector3(0.18, 0.18, 0.025), 1, PI / 4)
	var result: Array = []
	for tool in groups:
		tool.index()
		result.append(tool.commit())
	return result

func weapon(kind: String) -> void:
	# Broad source weapon identity, deliberately miniature rather than equipped guns.
	box(Vector3(-0.04, 0.01, 0), Vector3(0.34, 0.16, 0.16), 0)
	box(Vector3(-0.12, -0.16, 0), Vector3(0.095, 0.22, 0.12), 0, -0.18)
	box(Vector3(-0.25, 0.02, 0), Vector3(0.13, 0.13, 0.12), 2)
	var horizontal := Vector3(0, 0, PI / 2)
	match kind:
		"rocket":
			cylinder(Vector3(0.07, 0.08, 0), 0.13, 0.50, 1, -1, horizontal)
			cylinder(Vector3(0.32, 0.08, 0), 0.15, 0.07, 2, -1, horizontal)
		"rail", "marksman":
			box(Vector3(0.18, 0.04, 0), Vector3(0.41, 0.065, 0.075), 2)
			box(Vector3(0.04, 0.11, 0), Vector3(0.33, 0.065, 0.12), 1)
			if kind == "marksman": cylinder(Vector3(-0.045, 0.22, 0), 0.05, 0.20, 0, -1, horizontal)
			else:
				for x in [0.0, 0.10, 0.20]: box(Vector3(x, 0.16, 0), Vector3(0.035, 0.12, 0.15), 1)
		"scatter", "flak":
			for z in [-0.065, 0.065]: cylinder(Vector3(0.17, 0.04, z), 0.048 if kind == "scatter" else 0.073, 0.32, 2, -1, horizontal)
			box(Vector3(0.1, -0.065, 0), Vector3(0.25, 0.065, 0.20), 1)
			if kind == "flak": cylinder(Vector3(-0.02, -0.11, 0), 0.11, 0.22, 1, -1, Vector3(PI / 2, 0, 0))
		"plasma", "shock":
			cylinder(Vector3(0.09, 0.055, 0), 0.115, 0.27, 1, -1, horizontal)
			for z in [-0.115, 0.115]: box(Vector3(0.22, 0.055, z), Vector3(0.23, 0.045, 0.045), 2)
			if kind == "shock": box(Vector3(0.30, 0.13, 0), Vector3(0.14, 0.045, 0.045), 1)
		"grenade":
			cylinder(Vector3(0, -0.08, 0), 0.145, 0.24, 1, -1, Vector3(PI / 2, 0, 0))
			cylinder(Vector3(0.22, 0.07, 0), 0.085, 0.25, 2, -1, horizontal)
		"smg":
			box(Vector3(0.16, 0.015, 0), Vector3(0.24, 0.13, 0.12), 1)
			box(Vector3(0.05, -0.16, 0), Vector3(0.07, 0.24, 0.1), 2, 0.18)
