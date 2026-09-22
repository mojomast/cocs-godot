extends SceneTree
## Verifies the exported world weapons and the post-pose hand pass against the
## real source alignLivingCharacter fixtures (450 cases: 9 operators x 10 weapons
## x 5 poses). Source-exact comparison, no mock rig.
const Visual = preload("res://source_operators/operator_visual.gd")
const Rig = preload("res://source_operators/character_rig.gd")
const HandGrips = preload("res://source_operators/hand_grips.gd")
const WorldWeapons = preload("res://source_operators/generated/world_weapons/catalog.gd")
var failures: Array[String] = []
var max_error: float = 0.0
var max_grip_error: float = 0.0
var max_report_error: float = 0.0
var max_clamp_excess: float = 0.0
var compared: int = 0
var weapons_seen: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func compare_world(node: Node3D, expected: Array, label: String) -> void:
	var actual: Transform3D = node.global_transform
	var columns: Array[Vector3] = [actual.basis.x,actual.basis.y,actual.basis.z,actual.origin]
	for col: int in range(4):
		for row: int in range(3):
			var error: float = absf(columns[col][row]-float(expected[col*4+row]))
			max_error = maxf(max_error,error)
			check(error < 0.00002,"%s world[%d,%d] delta %.8f" % [label,col,row,error])

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/source_operators/source_grips.json"))
	check(WorldWeapons.WEAPONS.size() == 10,"World weapon catalog holds ten source weapons")
	var base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for operator: Dictionary in fixture.operators:
		var visual = Visual.new()
		root.add_child(visual)
		visual.automatic_animation = false
		visual.apply_identity({"character":operator.id})
		check(is_instance_valid(visual.source),operator.id+" exported operator loads")
		if not is_instance_valid(visual.source): visual.free(); continue
		# Remove the documented host center-to-feet wrapper for source comparison.
		visual.source.position.y = 0.0
		visual.rig.configure(visual.nodes)
		for entry: Dictionary in operator.entries:
			var state: Dictionary = fixture.states[entry.state]
			visual.rig.reset()
			visual.rig.apply_pose(Rig.solve(state))
			visual.nodes.gunAnchor.quaternion = Rig.xyz_quaternion(Vector3(-float(state.get("focusPitch",0)),float(state.get("focusYaw",0)),0))
			visual.set_weapon(int(entry.type))
			var label: String = "%s weapon%d %s" % [operator.id,int(entry.type),str(entry.state)]
			check(is_instance_valid(visual.world_weapon),label+" world weapon instantiates")
			if not is_instance_valid(visual.world_weapon): continue
			check(visual.world_weapon.get_parent() == visual.nodes.gunAnchor,label+" mounts on the source GunMount")
			check(visual.nodes.weapon.visible == false,label+" built-in source pulse hidden")
			check(visual.anchor("Muzzle") == visual.world_weapon.find_child("Muzzle",true,false),label+" muzzle anchor follows world weapon")
			weapons_seen[int(entry.type)] = true
			var clamp_info: Dictionary = {}
			var errors: Dictionary = HandGrips.align(visual.nodes,visual.world_weapon,clamp_info)
			max_report_error = maxf(max_report_error,float(errors.get("L",0.0)))
			max_report_error = maxf(max_report_error,float(errors.get("R",0.0)))
			for side: String in ["L","R"]:
				check(float(clamp_info.get("clamped"+side,0.0)) == 0.0,label+" grip%s source contact is reachable" % side)
			for side: String in ["L","R"]:
				var grip: Node3D = visual.nodes["grip"+side]
				var expected: Array = entry.grips[side]
				var error: float = grip.global_position.distance_to(Vector3(expected[0],expected[1],expected[2]))
				max_grip_error = maxf(max_grip_error,error)
				check(error < 0.00002,"%s grip%s source world %.8f" % [label,side,error])
				var contact: Node3D = visual.world_weapon.find_child("WeaponGripLeft" if side == "L" else "WeaponGripRight",true,false)
				check(contact != null,label+" grip%s chassis contact exists" % side)
				if contact != null:
					check(grip.global_position.distance_to(contact.global_position) < 0.00002,"%s grip%s chassis distance %.8f" % [label,side,grip.global_position.distance_to(contact.global_position)])
			for key: String in entry.joints:
				var values: Dictionary = entry.joints[key]
				var q_expected: Array = values.quaternion
				var q: Quaternion = visual.nodes[key].quaternion
				var expected_q := Quaternion(float(q_expected[0]),float(q_expected[1]),float(q_expected[2]),float(q_expected[3]))
				var delta: float = minf((q-expected_q).length(),(q+expected_q).length())
				max_error = maxf(max_error,delta)
				check(delta < 0.00002,"%s %s local quaternion %.8f" % [label,key,delta])
				compare_world(visual.nodes[key],values.world,label+" "+key)
			compared += 1
		# Reach clamp contract: an extreme dynamic pose may exceed arm reach; the
		# reported residual must never exceed the clamp (no faked solution).
		var excess: float = 0.0
		for frame: int in range(120):
			visual.apply_actor({"id":4,"character":operator.id,"health":100,"weapon":1,"shots":frame,"pitch":0.7,"yaw":0.9,"bodyYaw":0.0,"vx":0.0,"vz":0.0,"ads":frame%2==0,"crouching":frame%3==0})
			visual.advance(1.0/60.0)
			for side: String in visual.grip_error:
				excess = maxf(excess,float(visual.grip_error[side])-float(visual.grip_clamp.get("clamped"+side,0.0)))
		max_clamp_excess = maxf(max_clamp_excess,excess)
		check(excess < 0.0001,operator.id+" reach clamp never fakes a solution (excess %.8f)" % excess)
		# Weapon switching frees the previous actual source mesh instance.
		var previous: Node3D = visual.world_weapon
		visual.set_weapon((int(visual.weapon_type)+1) % WorldWeapons.WEAPONS.size())
		check(not is_instance_valid(previous),operator.id+" weapon switch frees previous instance")
		visual.free()
	check(weapons_seen.size() == 10,"All ten weapon types exercised")
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == base_nodes,"Grip fixtures release all nodes")
	var report: Dictionary = {"passed":failures.is_empty(),"cases":compared,"weapons":WorldWeapons.WEAPONS.size(),"maximumJointError":max_error,"maximumGripWorldError":max_grip_error,"maximumReportedContactError":max_report_error,"maximumClampExcess":max_clamp_excess,"failures":failures}
	var evidence: String = OS.get_environment("OPERATOR_EVIDENCE")
	if not evidence.is_empty():
		FileAccess.open(evidence.path_join("grips.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
