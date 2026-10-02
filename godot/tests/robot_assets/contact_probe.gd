extends SceneTree
const Robot = preload("res://campaign/robot_visual.gd")
const Adapter = preload("res://robot_assets/switchyard/skin_adapter.gd")
var points: Array[Dictionary] = []
var failures: Array[String] = []
var comparisons := 0
var max_foot_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	for skin: String in Adapter.SKINS:
		for use_skin: bool in [false,true]:
			var robot := Robot.new(); root.add_child(robot)
			robot.automatic_animation = false; robot.automatic_lod = false
			var role: String = Adapter.SKINS[skin]
			var scale_: float = {"skirmisher":.86,"bulwark":1.5,"mortar":1.15}[role]
			robot.position.y = 20.9
			var actor := {"id":3,"npcModel":role,"health":100,"grounded":true,"npcProfile":{"scale":scale_}}
			robot.configure(actor)
			if use_skin: assert(Adapter.install_role(robot))
			for lod: int in range(3):
				robot.set_lod(lod)
				for yaw: float in [0.0,PI/2]:
					for pitch: float in [-.4,0.0,.4]:
						for phase: String in ["idle","walk","attack","react"]:
							robot.reset_pose(); robot.rotation.y = yaw
							actor.yaw = yaw; actor.bodyYaw = yaw; actor.pitch = pitch
							actor.vz = -1.4 if phase == "walk" else 0.0
							actor.campaignAttackWindup = .8 if phase == "attack" else 0.0
							robot.apply_actor(actor)
							if phase == "react": robot.hit_reaction = 1
							for frame in range(12): robot.advance(1.0/60)
							for mesh: MeshInstance3D in [robot.rigs[lod].body.get_node("ArmorAndVents"),robot.rigs[lod].turret.get_node("SensorHousing")]:
								var arrays := mesh.mesh.surface_get_arrays(0)
								var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
								var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
								var count := indices.size() if not indices.is_empty() else vertices.size()
								for i in range(0,count-2,180):
									var center := Vector3.ZERO
									for j in range(3): center += vertices[indices[i+j] if not indices.is_empty() else i+j]/3.0
									var point := mesh.to_global(center)
									points.append({"model":role,"skin":skin if use_skin else "original","feet":20,"yaw":yaw,"pitch":pitch,"phase":phase,"lod":lod,"point":[point.x,point.y,point.z]})
			robot.free()
	# Use real static physics floors for bounded IK. Compare stock/skinned joint
	# transforms on flat, slope and two-height step, including sideways gait.
	for surface: String in ["flat","slope","step"]:
		var floors: Array[Node3D] = []
		for side: int in ([-1,1] if surface == "step" else [0]):
			var floor_ := StaticBody3D.new(); root.add_child(floor_); floors.append(floor_)
			var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
			shape.size = Vector3(2 if side != 0 else 8,.1,8); collision.shape = shape; floor_.add_child(collision)
			floor_.position = Vector3(side, -.05 + (side*.04 if side != 0 else 0.0),0)
			if surface == "slope": floor_.rotation.z = .06
		await physics_frame; await physics_frame
		for skin: String in Adapter.SKINS:
			var pair: Array[Node3D] = []
			for is_skin: bool in [false,true]:
				var r := Robot.new(); r.automatic_animation = false; r.automatic_lod = false
				root.add_child(r); r.position.y = .9
				r.configure({"id":4,"npcModel":Adapter.SKINS[skin],"health":100,"grounded":true})
				if is_skin: assert(Adapter.install_role(r))
				pair.append(r)
			for mode: String in ["plant","strafe"]:
				for r in pair:
					var a: Dictionary = r.snapshot.duplicate(true); a.vx = 1.3 if mode == "strafe" else 0.0; r.apply_actor(a)
				for frame in range(90):
					for r in pair: r.advance(1.0/60)
					for i in pair[0].rigs[0].legs.size():
						comparisons += 1
						if not pair[0].rigs[0].legs[i].transform.is_equal_approx(pair[1].rigs[0].legs[i].transform): failures.append("skin displaced source hip")
						if not pair[0].rigs[0].knees[i].transform.is_equal_approx(pair[1].rigs[0].knees[i].transform): failures.append("skin displaced source knee")
				if mode == "plant":
					var r := pair[1]
					for i in r.rigs[0].knees.size():
						var foot: Vector3 = r.rigs[0].knees[i].to_global(r.rigs[0].ends[i])
						var query := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.3,foot-Vector3.UP*.4,1)
						var hit := r.get_world_3d().direct_space_state.intersect_ray(query)
						if hit.is_empty(): failures.append("floor contact query missing")
						else:
							var error: float = absf(foot.y-.09-hit.position.y)
							max_foot_error = maxf(max_foot_error,error)
							if error > .025: failures.append("planted IK contact exceeds 2.5cm")
			for r in pair: r.free()
		for floor_ in floors: floor_.free()
	var out := OS.get_environment("ASSET_STAGE_EVIDENCE")
	var file := FileAccess.open(out.path_join("targeting-points.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(points)); file.close()
	var summary := {"points":points.size(),"jointComparisons":comparisons,"maxPlantedFootError":max_foot_error,"failures":failures}
	file = FileAccess.open(out.path_join("contacts.json"),FileAccess.WRITE); file.store_string(JSON.stringify(summary,"  ")); file.close()
	print("SWITCHYARD_CONTACTS ",JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
