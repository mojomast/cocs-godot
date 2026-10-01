extends SceneTree
const Robot = preload("res://campaign/robot_visual.gd")
const Presentation = preload("res://world/presentation.gd")
const Projectiles = preload("res://world/projectiles.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scales := [0.72, 0.86, 1.28, 1.15, 1.5, 1.6]
	var rows: Array = []
	var points: Array = []
	for i: int in range(Robot.IDS.size()):
		var robot := Robot.new()
		robot.automatic_animation = false
		robot.automatic_lod = false
		root.add_child(robot)
		var actor := {"id":1, "npcModel":Robot.IDS[i], "health":100, "npcProfile":{"scale":scales[i]}, "vx":0.0}
		robot.configure(actor)
		robot.position.y = 0.9
		if Robot.IDS[i] == "bulwark":
			var shield: MeshInstance3D = robot.rigs[0].shield.get_node("SlabShield")
			print("SHIELD ",shield.global_transform * shield.get_aabb())
		for assembly: String in ["ArmorAndVents", "SensorHousing"]:
			var mesh: MeshInstance3D = robot.rigs[0].body.get_node(assembly) if assembly == "ArmorAndVents" else robot.rigs[0].turret.get_node(assembly)
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			rows.append({"model":Robot.IDS[i], "assembly":assembly, "min":[bounds.position.x,bounds.position.y,bounds.position.z], "max":[bounds.end.x,bounds.end.y,bounds.end.z]})
		# Sample real solid Blender chassis triangle centres, including asymmetric
		# shoulders. Terrain, body yaw and gait are applied by the real visual.
		for moving: bool in [false, true]:
			for yaw: float in [0.0, PI / 2.0, PI]:
				actor.vx = 3.0 if moving else 0.0
				actor.bodyYaw = yaw
				actor.yaw = yaw
				actor.pitch = 0.4 if moving else -0.4
				robot.rotation.y = yaw
				robot.position.y = 8.4
				robot.apply_actor(actor)
				robot.advance(0.13)
				var mesh: MeshInstance3D = robot.rigs[0].body.get_node("ArmorAndVents")
				var arrays: Array = mesh.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for triangle: int in range(0, indices.size(), 39):
					if triangle + 2 >= indices.size(): break
					var point: Vector3 = mesh.global_transform * ((vertices[indices[triangle]] + vertices[indices[triangle+1]] + vertices[indices[triangle+2]]) / 3.0)
					points.append({"model":Robot.IDS[i], "yaw":yaw, "moving":moving, "feet":7.5, "point":[point.x, point.y, point.z]})
				var sensor: MeshInstance3D = robot.rigs[0].turret.get_node("SensorHousing")
				var sensor_arrays: Array = sensor.mesh.surface_get_arrays(0)
				var sensor_vertices: PackedVector3Array = sensor_arrays[Mesh.ARRAY_VERTEX]
				var sensor_indices: PackedInt32Array = sensor_arrays[Mesh.ARRAY_INDEX]
				for triangle: int in range(0, sensor_indices.size(), 39):
					if triangle + 2 >= sensor_indices.size(): break
					var point: Vector3 = sensor.global_transform * ((sensor_vertices[sensor_indices[triangle]] + sensor_vertices[sensor_indices[triangle+1]] + sensor_vertices[sensor_indices[triangle+2]]) / 3.0)
					points.append({"model":Robot.IDS[i], "yaw":yaw, "moving":moving, "feet":7.5, "point":[point.x, point.y, point.z]})
		actor.campaignShieldHit = 0.1
		robot.apply_actor(actor)
		if robot.shield_material.emission_energy_multiplier <= 0.0:
			push_error("Shield block has no visible confirmation"); quit(1); return
		robot.free()
	print(JSON.stringify(rows))
	var points_path := OS.get_environment("CAMPAIGN_TARGETING_POINTS")
	if not points_path.is_empty():
		var file := FileAccess.open(points_path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write native targeting samples: " + points_path); quit(1); return
		file.store_string(JSON.stringify(points) + "\n")
		file.close()
	var presentation := Presentation.new()
	presentation.actor_visual_factory = func(_a: Dictionary, _id: int) -> Node3D: return Robot.new()
	presentation.interpolate_remote = true
	root.add_child(presentation)
	for mode: String in ["campaign", "horde", "deathmatch"]:
		presentation.clear_round()
		var actor := {"id":1,"x":0.0,"y":7.5,"z":0.0,"health":100,"isNpc":true,"npcModel":"skirmisher"}
		presentation.apply_state({"config":{"mode":mode},"actors":[actor]},0)
		actor.x = 1.0
		presentation.apply_state({"config":{"mode":mode},"actors":[actor]},0)
		presentation._process(0.016)
		if mode != "deathmatch" and not is_equal_approx(presentation.actors[1].position.x,1.0):
			push_error("Solo presentation trails collision"); quit(1); return
		if mode == "deathmatch" and not presentation.current_pose_npcs.is_empty():
			push_error("Multiplayer interpolation changed"); quit(1); return
	presentation.free()
	var projectiles := Projectiles.new()
	root.add_child(projectiles)
	projectiles.set_process(false)
	for speed: float in [46.0, 138.0]:
		projectiles.clear_round()
		for tick: int in range(3):
			projectiles.apply_state({"time":float(tick)/60.0,"rockets":[{"id":1,"owner":0,"weapon":4,"pos":{"x":0.0,"y":3.0,"z":-speed*float(tick)/60.0},"dir":{"x":0.0,"y":0.0,"z":-1.0}}]})
		if absf(projectiles.flight[1].velocity.length()-speed) > 0.01:
			push_error("Plasma visual speed differs from authority"); quit(1); return
		print("PLASMA_VISUAL measured_speed=",projectiles.flight[1].velocity.length())
	projectiles.free()
	print("PASS native body point extraction and campaign/Horde current-pose isolation; points=",points.size())
	quit()
