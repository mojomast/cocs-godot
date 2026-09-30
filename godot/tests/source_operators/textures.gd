extends SceneTree
const Visual = preload("res://source_operators/operator_visual.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	for id: String in Catalog.OPERATORS:
		var actor = Visual.new(); root.add_child(actor)
		actor.automatic_animation = false
		actor.apply_identity({"character":id})
		var count := actor.armor_details.size()
		var plate: MeshInstance3D = actor.nodes.chest.get_node("BreastplateL")
		var bind := plate.transform
		var neutral: Color = plate.material_override.albedo_color
		var uv: PackedVector2Array = plate.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		check(not uv.is_empty(),id + " has fitted UVs")
		for team: String in ["red","blue","neutral"]:
			actor.apply_identity({"character":id,"team":team})
			check(plate.material_override.albedo_texture != null,id + " keeps team texture")
			check(plate.material_override.albedo_color == actor.team_material.albedo_color,id + " tracks team tint")
		check(plate.material_override.albedo_color == neutral,id + " restores neutral tint")
		actor.nodes.chest.rotate_y(0.4)
		check(plate.transform == bind,id + " texture plate remains joint-local")
		actor.set_lod(2)
		for mesh: MeshInstance3D in actor.armor_details: check(not mesh.visible,id + " far LOD hides detail")
		actor.set_lod(0)
		check(plate.visible and actor.armor_details.size() == count,id + " near LOD restores detail")
		var twin = Visual.new(); root.add_child(twin)
		twin.apply_identity({"character":id})
		var twin_plate: MeshInstance3D = twin.nodes.chest.get_node("BreastplateL")
		check(plate.mesh == twin_plate.mesh,id + " shares UV mesh")
		check(plate.material_override == twin_plate.material_override,id + " shares detail material")
		twin.free(); actor.free()
	print(JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
