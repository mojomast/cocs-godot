extends RefCounted
## Private, bounded material slots for one live viewmodel. The exported mesh
## names carry the source material roles; hands and handling effects are outside
## the imported weapon and cannot be tinted by this binder.
const Catalog = preload("res://first_person/generated/finishes.gd")
var slots: Array[Dictionary] = []
var active := ""
var write_count := 0

func bind(model: Node3D) -> void:
	slots.clear()
	active = ""
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
		var role := ""
		for candidate: String in ["dark", "light", "glow"]:
			if node.name.ends_with("-" + candidate):
				role = candidate
				break
		if role.is_empty() or node.mesh == null: continue
		for surface: int in node.mesh.get_surface_count():
			var material := node.get_surface_override_material(surface) as StandardMaterial3D
			if material == null: continue
			slots.append({"material":material, "role":role, "base":material.albedo_color,
				"emission":material.emission})

func apply(value: Variant) -> void:
	# Only an explicit catalog ID from the current actor snapshot can select a
	# finish. Null, absent, malformed and future IDs all restore stock colors.
	var next: String = value if value is String and Catalog.PALETTES.has(value) else ""
	if active == next: return
	active = next
	var palette: Dictionary = Catalog.PALETTES.get(next, {})
	for slot: Dictionary in slots:
		var material: StandardMaterial3D = slot.material
		if palette.is_empty():
			material.albedo_color = slot.base
			if slot.role == "glow": material.emission = slot.emission
		else:
			# Three.js Color.set(hex) converts sRGB into linear for PBR; Godot's
			# StandardMaterial3D stores linear albedo/emission. Keep the source
			# conversion before the renderer's linear-to-display transfer.
			var color := Color(palette[slot.role]).srgb_to_linear()
			material.albedo_color = color
			if slot.role == "glow": material.emission = color
		write_count += 1

func clear() -> void:
	apply(null)
