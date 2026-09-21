extends SceneTree

func _initialize() -> void:
	for id: String in ["axis-weapon", "meridian-exchange"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var result := document.append_from_file("res://content/probes/" + id + "/world.glb", state)
		if result != OK:
			push_error("GLB import failed: " + id)
			quit(1)
			return
		var scene: Node3D = document.generate_scene(state)
		if scene == null:
			quit(1)
			return
		if id == "axis-weapon":
			var axis: Node3D = scene.find_child("X_red", true, false)
			if axis == null or not axis.position.is_equal_approx(Vector3(1.5, 0, 0)) or scene.find_child("InstanceProbe_instance_1", true, false) == null:
				push_error("Axis or expanded-instance mismatch")
				scene.free()
				quit(1)
				return
		print("PORT_GLB_IMPORT_OK id=", id, " nodes=", state.get_nodes().size(), " meshes=", state.get_meshes().size())
		scene.free()
	quit(0)
