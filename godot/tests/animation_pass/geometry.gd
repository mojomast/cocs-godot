extends SceneTree
const Robot = preload("res://campaign/robot_visual.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var points: Array = []
	var scales := [0.72,0.86,1.28,1.15,1.5,1.6]
	for i in Robot.IDS.size():
		var robot := Robot.new(); robot.automatic_animation=false; robot.automatic_lod=false
		root.add_child(robot); robot.position.y=8.4
		for yaw: float in [0.0,PI/2,PI]:
			for pitch: float in [-0.5,0.0,0.5]:
				for mode: String in ["move","tell","damage","exposed"]:
					var state := {"id":1,"npcModel":Robot.IDS[i],"npcProfile":{"scale":scales[i]},"health":100,"yaw":yaw,"bodyYaw":yaw,"pitch":pitch,"vx":3.5,"vz":0.0,"grounded":true,"campaignAttackWindup":1.0 if mode=="tell" else 0.0,"campaignExposed":1.0 if mode=="exposed" else 0.0}
					state.yaw += -0.6 if mode=="tell" else (0.6 if mode=="damage" else 0.0)
					robot.configure(state); robot.rotation.y=yaw; robot.reset_pose(); robot.apply_actor(state)
					if mode=="damage": robot.hit_reaction=1; robot.kick()
					for frame in [0,3,12]:
						if frame>0: robot.advance(float(frame)/60)
						for mesh: MeshInstance3D in [robot.rigs[0].body.get_node("ArmorAndVents"),robot.rigs[0].turret.get_node("SensorHousing")]:
							var arrays: Array = mesh.mesh.surface_get_arrays(0)
							var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
							var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
							for triangle in range(0,indices.size()-2,117):
								var point: Vector3 = mesh.global_transform*((vertices[indices[triangle]]+vertices[indices[triangle+1]]+vertices[indices[triangle+2]])/3)
								points.append({"model":Robot.IDS[i],"yaw":yaw,"feet":7.5,"point":[point.x,point.y,point.z],"mode":mode,"pitch":pitch,"frame":frame})
		robot.free()
	var path := OS.get_environment("ACTOR_ANIMATION_POINTS")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(points)+"\n"); file.close()
	print("ACTOR_GEOMETRY_OK native solid samples=",points.size()," output=",path)
	quit()
