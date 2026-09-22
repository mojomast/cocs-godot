extends SceneTree
const Visual = preload("res://source_operators/operator_visual.gd")
const Rig = preload("res://source_operators/character_rig.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
var failures: Array[String] = []
var max_error: float = 0.0
var checked: int = 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func compare(visual: Node3D, expected: Dictionary, label: String) -> void:
	for key: String in expected:
		check(visual.nodes.has(key),label+" missing "+key)
		if not visual.nodes.has(key): continue
		var node: Node3D = visual.nodes[key]
		var values: Array = expected[key].world
		var actual: Transform3D = node.global_transform
		var columns: Array[Vector3] = [actual.basis.x,actual.basis.y,actual.basis.z,actual.origin]
		for col: int in range(4):
			for row: int in range(3):
				var error: float = absf(columns[col][row]-float(values[col*4+row]))
				max_error = maxf(max_error,error)
				check(error < 0.00002,"%s %s transform[%d,%d] delta %.8f" % [label,key,col,row,error])
		checked += 1

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/source_operators/source_transforms.json"))
	var base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for operator: Dictionary in fixture.operators:
		var visual = Visual.new()
		root.add_child(visual)
		visual.automatic_animation = false
		visual.apply_identity({"character":operator.id})
		# Remove the documented host center-to-feet wrapper translation for source comparison.
		visual.source.position.y = 0.0
		visual.rig.configure(visual.nodes)
		compare(visual,operator.snapshots.bind,operator.id+" bind")
		for key: String in fixture.states:
			visual.reset_pose()
			visual.rig.apply_pose(Rig.solve(fixture.states[key]))
			compare(visual,operator.snapshots[key],operator.id+" "+key)
		visual.rig.apply_source_death(Catalog.OPERATORS[operator.id].deathPose)
		compare(visual,operator.snapshots.death,operator.id+" death")
		visual.rig.update({"dt":0.1,"speed":8})
		compare(visual,operator.snapshots.death,operator.id+" dead rejects live writes")
		visual.reset_pose()
		compare(visual,operator.snapshots.reset,operator.id+" reset")
		for index: int in range(fixture.updateSequence.size()):
			visual.rig.update(fixture.updateSequence[index])
			if operator.sequence.has(str(index)):
				compare(visual,operator.sequence[str(index)],operator.id+" damped sequence "+str(index))
		for mesh: MeshInstance3D in visual.batches:
			for batch: Dictionary in Catalog.OPERATORS[operator.id].batches:
				if batch.name == str(mesh.name):
					check((mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON) == batch.castShadow,operator.id+" source shadow policy")
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var material: StandardMaterial3D = mesh.mesh.surface_get_material(0)
			for authored: Dictionary in Catalog.OPERATORS[operator.id].materials:
				if authored.name != material.resource_name: continue
				var color: Color = material.albedo_color.srgb_to_linear()
				check(Vector3(color.r,color.g,color.b).distance_to(Vector3(authored.color[0],authored.color[1],authored.color[2])) < 0.00002,operator.id+" "+material.resource_name+" original linear PBR color")
				check(absf(material.metallic-authored.metalness) < 0.00001,operator.id+" source metallic")
				check(absf(material.roughness-authored.roughness) < 0.00001,operator.id+" source roughness")
				check(material.vertex_color_use_as_albedo == authored.vertexColors,operator.id+" source precision vertex-color flag")
				var emission: Vector3 = Vector3(authored.emissive[0],authored.emissive[1],authored.emissive[2])*float(authored.emissiveIntensity)
				if emission.length() > 0.0:
					var imported: Color = material.emission.srgb_to_linear()
					check(material.emission_enabled and (Vector3(imported.r,imported.g,imported.b)*material.emission_energy_multiplier).distance_to(emission) < 0.00002,operator.id+" original emission")
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for sample: Array in operator.geometrySamples[str(mesh.name)]:
				var found: bool = false
				for i: int in range(0,indices.size(),3):
					for start: int in range(3):
						var matches: bool = true
						for corner: int in range(3):
							# glTF CCW -> Godot CW; coordinates and outward normals stay unchanged.
							var vertex: int = indices[i+(start+3-corner)%3]
							var expected: Array = sample[corner].position
							if verts[vertex].distance_to(Vector3(expected[0],expected[1],expected[2])) > 0.000002:
								matches = false; break
							var normal: Array = sample[corner].normal
							if normals[vertex].distance_to(Vector3(normal[0],normal[1],normal[2])) > 0.0002:
								matches = false; break
							if sample[corner].has("color"):
								var vertex_color: Color = arrays[Mesh.ARRAY_COLOR][vertex]
								if material.vertex_color_is_srgb: vertex_color = vertex_color.srgb_to_linear()
								var color: Array = sample[corner].color
								check(Vector3(vertex_color.r,vertex_color.g,vertex_color.b).distance_to(Vector3(color[0],color[1],color[2])) < 0.00002,operator.id+" precision source linear vertex colors")
						if matches: found = true; break
					if found: break
				check(found,operator.id+" "+str(mesh.name)+" source triangle normals/winding")
		for level: int in range(3):
			visual.set_lod(level)
			var draws: int = 0
			var triangles: int = 0
			for mesh: MeshInstance3D in visual.batches:
				if not mesh.visible: continue
				draws += mesh.mesh.get_surface_count()
				for surf: int in range(mesh.mesh.get_surface_count()):
					var arrays: Array = mesh.mesh.surface_get_arrays(surf)
					triangles += int(arrays[Mesh.ARRAY_INDEX].size()/3)
					var mat: StandardMaterial3D = mesh.mesh.surface_get_material(surf)
					check(mat != null, "Imported PBR material")
			var cost: Dictionary = visual.visible_cost()
			check(draws == int(cost.drawObjects),"%s LOD%d draw count %d != %d" % [operator.id,level,draws,cost.drawObjects])
			check(triangles == int(cost.triangles),"%s LOD%d triangles %d != %d" % [operator.id,level,triangles,cost.triangles])
		check(visual.anchor("Muzzle") != null,"Muzzle anchor exists")
		check(visual.anchor("Helmet") == visual.nodes.head,"Helmet follows source head joint")
		visual.configure({"id":4,"character":operator.id,"health":100,"vx":1,"vz":-4,"ads":true,"pitch":0.2},9)
		visual.kick()
		for frame: int in range(90): visual.advance(1.0/60.0)
		check(visual.rig.phase > 0.0,"Snapshot-driven gait advances")
		check(visual.nodes.gunAnchor.position.is_equal_approx(visual.rig.bind.gunAnchor.origin),"Recoil returns to authored mount")
		visual.apply_actor({"id":4,"character":operator.id,"health":100,"reduced":true,"pitch":0.4,"yaw":0.5})
		visual.kick()
		visual.advance(1.0/60.0)
		check(visual.nodes.gunAnchor.quaternion.is_equal_approx(Quaternion.IDENTITY),"Source reduced-motion mount stays at rest")
		visual.apply_actor({"id":4,"character":operator.id,"health":0})
		check(visual.rig.dead,"Dead lifecycle")
		visual.apply_actor({"id":4,"character":operator.id,"health":100})
		check(not visual.rig.dead,"Respawn resets lifecycle")
		visual.free()
	# Instantiation sharing and identity replacement exercise all nine resources.
	var roster: Array = []
	for i: int in range(32):
		var visual = Visual.new()
		root.add_child(visual)
		visual.apply_identity({"character":fixture.operators[i%fixture.operators.size()].id})
		roster.append(visual)
	if fixture.operators.size() == 9:
		check(roster[0].batches[0].mesh == roster[9].batches[0].mesh,"Instances share imported mesh resources")
		var neutral: Color = roster[9].team_material.albedo_color
		roster[0].apply_identity({"character":fixture.operators[0].id,"team":0})
		check(roster[0].team_material != roster[9].team_material,"Team colors are per instance")
		check(roster[9].team_material.albedo_color == neutral,"Team color never mutates shared identity")
		check(roster[0].team_bars[0].visible and not roster[0].team_bars[1].visible,"Source red one-bar marking")
		roster[0].apply_identity({"character":fixture.operators[0].id,"team":1})
		check(roster[0].team_bars[1].visible,"Source blue two-bar marking")
		roster[0].apply_identity({"character":fixture.operators[0].id})
		check(not roster[0].team_bars[0].visible and roster[0].team_material.albedo_color == neutral,"Neutral team reset")
	for visual in roster:
		for operator: Dictionary in fixture.operators: visual.apply_identity({"character":operator.id})
		visual.free()
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == base_nodes,"All operator nodes released after 32-roster/identity swaps")
	var report: Dictionary = {"passed":failures.is_empty(),"operators":fixture.operators.size(),"jointWorldMatricesCompared":checked,"maximumTransformError":max_error,"failures":failures}
	FileAccess.open(OS.get_environment("OPERATOR_EVIDENCE").path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
