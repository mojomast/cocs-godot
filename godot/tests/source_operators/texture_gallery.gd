extends "res://tests/source_operators/render.gd"
## Matched texture-only A/B: same geometry, camera, pose, light, identity and LOD.
## Reuses the established native operator gallery stage and capture methods.

func untextured(actor: Node3D) -> void:
	for mesh: MeshInstance3D in actor.armor_details:
		if not mesh.has_meta("detail_style"): continue
		mesh.material_override = mesh.get_meta("undetailed_material")

func run() -> void:
	setup_stage()
	DirAccess.make_dir_recursive_absolute(evidence)
	visual.free()
	for id: String in Catalog.OPERATORS:
		for team: String in ["neutral","red","blue"]:
			for mode: String in ["after","before"]:
				visual = Visual.new(); stage.add_child(visual)
				visual.position.y = 0.9; visual.automatic_animation = false
				visual.apply_identity({"character":id,"team":team})
				if mode == "before": untextured(visual)
				for view: String in ["normal","close","pose"]:
					visual.reset_pose()
					if view == "pose": visual.rig.apply_pose(Rig.solve({"phase":1.1,"speedNorm":0.65,"forward":1,"time":0.4}))
					camera_pose(4.5 if view == "normal" else 2.3,0.24)
					await capture("%s-%s-%s-%s.png" % [id,team,view,mode])
				visual.free()
	for mode: String in ["after","before"]:
		var roster: Array[Node3D] = []
		var index := 0
		for id: String in Catalog.OPERATORS:
			var actor = Visual.new(); stage.add_child(actor)
			actor.position = Vector3((index % 3 - 1)*1.25,0.9,-(index / 3)*2.2)
			actor.automatic_animation = false
			actor.apply_identity({"character":id,"team":["neutral","red","blue"][index % 3]})
			if mode == "before": untextured(actor)
			roster.append(actor); index += 1
		camera.position = Vector3(5,5,-10); camera.look_at(Vector3(0,1,-2))
		await capture("roster-%s.png" % mode)
		for actor in roster: actor.free()
	print("OPERATOR_TEXTURE_GALLERY complete: 164 matched PNGs; " + RenderingServer.get_current_rendering_method())
	quit()
