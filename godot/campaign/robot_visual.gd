extends Node3D
## Presentation only. Host owns actor centre transform; local forward is -Z.
const Parts = preload("res://campaign/robot_parts.gd")
const Motion = preload("res://source_operators/motion_math.gd")
const Ground = preload("res://source_operators/ground_contact.gd")
const IDS := ["scrapper", "skirmisher", "sentinel", "mortar", "bulwark", "warden"]
const COLORS := [Color("b17e46"), Color("719486"), Color("66849d"), Color("98817f"), Color("577c8b"), Color("975d4c")]
static var art_meshes: Dictionary = {}
var automatic_animation: bool = true
var automatic_lod: bool = true
var model_id: String = ""
var snapshot: Dictionary = {}
var lod_level: int = 0
var elapsed: float = 0.0
var gait_phase: float = 0.0
var recoil: float = 0.0
var hit_reaction: float = 0.0
var death_elapsed: float = 0.0
var local_id: int = -1
var bands: Array[Node3D] = []
var rigs: Array[Dictionary] = []
var batches: Array[MeshInstance3D] = []
var feet: Node3D
var armor_material: StandardMaterial3D
var optic_material: StandardMaterial3D
var shield_material: StandardMaterial3D
var tell_strength: float = 0.0
var building_level: int = 0
var stride_weight := 0.0
var stride_velocity := 0.0
var travel := Vector3.FORWARD
var tell_pose := 0.0
var tell_velocity := 0.0
var ground_offsets: Array[float] = []

func _init() -> void:
	armor_material = StandardMaterial3D.new()
	armor_material.vertex_color_use_as_albedo = true
	armor_material.roughness = 0.46
	armor_material.metallic = 0.6
	optic_material = armor_material.duplicate()
	optic_material.emission_enabled = true
	optic_material.emission = Color("ff773b")
	optic_material.emission_energy_multiplier = 0.65
	shield_material = armor_material.duplicate()
	shield_material.emission_enabled = true
	shield_material.emission = Color("ffbc51")
	shield_material.emission_energy_multiplier = 0.0

func configure(actor: Dictionary, local_actor_id: int = -1) -> void:
	local_id = local_actor_id
	apply_actor(actor, local_actor_id)

func apply_identity(actor: Dictionary) -> void:
	var next: String = str(actor.get("npcModel", "scrapper"))
	if next not in IDS: next = "scrapper"
	if next == model_id: return
	for child: Node in get_children(): child.free()
	bands.clear(); rigs.clear(); batches.clear()
	model_id = next
	_load_art(next)
	feet = Node3D.new()
	feet.name = "FeetOrigin"
	feet.position.y = -0.9
	add_child(feet)
	for level: int in range(3): _build(level)
	reset_pose()
	set_lod(lod_level)
	# Factory opt-in survives an actor identity rebuild; stock-only callers stay stock.
	if get_meta("switchyard_enabled", false):
		preload("res://robot_assets/switchyard/skin_adapter.gd").install_role(self)

func _joint(parent: Node3D, label: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = label
	joint.position = pos
	joint.set_meta("rest", pos)
	parent.add_child(joint)
	return joint

static func _load_art(id: String) -> void:
	if art_meshes.has(id): return
	var meshes: Dictionary = {}
	var path: String = "res://campaign/art/robots/%s.glb" % id
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		var scene: Node = packed.instantiate()
		for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
			meshes[node.name] = (node as MeshInstance3D).mesh
		scene.free()
	art_meshes[id] = meshes

func _art_key(parent: Node3D, label: String) -> String:
	var assembly: String = parent.name
	if label == "Optics": assembly = "Optics"
	elif assembly == "Knee": assembly = "Shin" + parent.get_parent().name.trim_prefix("Hip")
	elif assembly == "WeaponCradle": assembly = "Weapon"
	elif assembly == "ShieldArm": assembly = "Shield"
	return "L%d_%s" % [building_level, assembly]

func _finish(parts: RefCounted, parent: Node3D, label: String, luminous: bool = false) -> void:
	var instance: MeshInstance3D = parts.finish(parent, optic_material if luminous else armor_material, label)
	if label == "SlabShield": instance.material_override = shield_material
	var authored: Dictionary = art_meshes.get(model_id, {})
	var key: String = _art_key(parent, label)
	if authored.has(key):
		instance.mesh = authored[key]
		var count: int = 0
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			count += (indices.size() if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		instance.set_meta("triangles", count)
	batches.append(instance)

func _build(level: int) -> void:
	building_level = level
	var band := _joint(feet, "LOD%d" % level, Vector3.ZERO)
	bands.append(band)
	var color: Color = COLORS[IDS.find(model_id)]
	var biped: bool = model_id in ["skirmisher", "bulwark"]
	var heavy: bool = model_id in ["mortar", "bulwark", "warden"]
	var height: float = 1.12 if biped else (0.72 if heavy else 0.48)
	var width: float = 0.38 if model_id == "skirmisher" else (1.05 if model_id == "warden" else 0.72)
	var body := _joint(band, "Chassis", Vector3(0, height, 0))
	var p := Parts.new()
	if model_id in ["scrapper", "skirmisher", "warden"]:
		p.shell(Vector3.ZERO, Vector3(width, 0.55 if biped else 0.4, 0.52 if biped else 0.9), color, 6 if level == 2 else 10)
	else:
		p.box(Vector3.ZERO, Vector3(width, 0.48 if biped else 0.3, 0.48 if biped else 0.82), color)
	if level < 2:
		p.box(Vector3(0, -0.14, 0), Vector3(width * 0.78, 0.16, 0.62), Parts.DARK)
		p.box(Vector3(0, 0.16, 0.12), Vector3(width * 0.75, 0.09, 0.38), Parts.STEEL)
	if level == 0:
		for x: float in [-0.22, 0.0, 0.22]:
			p.box(Vector3(x * width, 0.215, 0.16), Vector3(0.065, 0.035, 0.28), Parts.DARK)
		p.box(Vector3(0, 0, -0.43 if not biped else -0.255), Vector3(width * 0.55, 0.08, 0.035), Parts.RUBBER)
	if model_id == "skirmisher":
		p.shell(Vector3(-0.29, 0.12, 0), Vector3(0.3, 0.25, 0.4), color, 8)
		p.beam(Vector3(-0.27, 0.1, 0), Vector3(-0.3, -0.45, -0.13), 0.085, Parts.STEEL)
	_finish(p, body, "ArmorAndVents")
	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	var ends: Array[Vector3] = []
	var count: int = 2 if biped else (3 if model_id == "sentinel" else (6 if model_id == "warden" else 4))
	for i: int in range(count):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var origin := Vector3(side * width * 0.4, height - 0.12, 0)
		var tip := Vector3(side * (width * 0.5 + 0.38), 0.09, -0.5 if i < 2 else 0.5)
		if biped: tip = Vector3(side * width * 0.45, 0.09, 0)
		elif count == 6: tip.z = [-0.65, -0.65, 0.0, 0.0, 0.65, 0.65][i]
		elif count == 3:
			var angle: float = TAU * i / 3.0
			tip = Vector3(sin(angle) * 0.85, 0.09, cos(angle) * 0.85)
		origin.z = tip.z * 0.5
		var hip := _joint(band, "Hip%d" % i, origin)
		var knee_pos := Vector3(tip.x - origin.x, (tip.y - origin.y) * 0.48, (tip.z - origin.z) * 0.6 + (0.16 if biped else 0.0))
		var knee := _joint(hip, "Knee", knee_pos)
		legs.append(hip); knees.append(knee)
		p = Parts.new()
		p.beam(Vector3.ZERO, knee_pos, 0.15 if heavy else 0.105, Parts.DARK)
		if level < 2:
			p.cylinder(Vector3.ZERO, 0.13, 0.19, Parts.STEEL, 6, Vector3(0, 0, PI / 2))
			p.beam(knee_pos * 0.2, knee_pos * 0.8, 0.22 if heavy else 0.14, color)
		var end: Vector3 = tip - origin - knee_pos
		ends.append(end)
		if level == 2:
			# Far band preserves hip gait, merging each shin into its upper link.
			p.beam(knee_pos, tip - origin, 0.14 if heavy else 0.085, Parts.STEEL)
			p.box(tip - origin, Vector3(0.25 if heavy else 0.18, 0.18, 0.38 if biped else 0.23), Parts.DARK)
			_finish(p, hip, "CombinedLeg")
		else:
			_finish(p, hip, "UpperLink")
			p = Parts.new()
			p.beam(Vector3.ZERO, end, 0.14 if heavy else 0.085, Parts.STEEL)
			p.box(end, Vector3(0.25 if heavy else 0.18, 0.18, 0.38 if biped else 0.23), Parts.DARK)
			if level == 0: p.cylinder(Vector3.ZERO, 0.115, 0.2, color, 6, Vector3(0, 0, PI / 2))
			_finish(p, knee, "ShinAndFoot")
	var turret := _joint(body, "Turret", Vector3(0, 0.3 if biped else 0.22, -0.12))
	p = Parts.new()
	p.cylinder(Vector3.ZERO, width * 0.36, 0.3, Parts.DARK, 6 if level == 2 else 8)
	p.box(Vector3(0, 0.12, 0), Vector3(width * 0.8, 0.11, 0.4), color)
	if model_id == "warden":
		for side: float in [-1.0, 1.0]:
			p.box(Vector3(side * 0.5, 0.27, 0.08), Vector3(0.18, 0.62, 0.28), color, Vector3(0, 0, -side * 0.25))
	if model_id == "skirmisher":
		p.beam(Vector3(-0.18, 0.1, 0), Vector3(-0.3, 0.6, 0.1), 0.045, Parts.STEEL)
	_finish(p, turret, "SensorHousing")
	p = Parts.new()
	p.box(Vector3(0, 0.02, -width * 0.36), Vector3(width * 0.52, 0.075, 0.05), Color("ff9b4b"))
	_finish(p, turret, "Optics", true)
	var gun := _joint(turret, "WeaponCradle", Vector3(0.3 if biped else 0, -0.12, -0.2))
	p = Parts.new()
	if model_id == "scrapper":
		for side: float in [-1.0, 1.0]:
			p.beam(Vector3(side * 0.22, 0, 0), Vector3(side * 0.36, -0.1, -0.48), 0.12, Parts.STEEL)
	elif model_id == "mortar":
		p.cylinder(Vector3(0, 0.3, -0.2), 0.24, 0.88, color, 8, Vector3(-0.4, 0, 0))
		p.cylinder(Vector3(0, 0.71, -0.375), 0.185, 0.035, Parts.RUBBER, 8, Vector3(-0.4, 0, 0))
	else:
		p.box(Vector3(0, 0, -0.2), Vector3(0.24 if heavy else 0.15, 0.19, 0.55), Parts.DARK)
		p.cylinder(Vector3(0, 0, -0.52), 0.11 if heavy else 0.07, 0.35, Parts.STEEL, 6, Vector3(PI / 2, 0, 0))
	if level == 0: p.box(Vector3(0, 0.13, -0.14), Vector3(0.075, 0.07, 0.2), color)
	_finish(p, gun, "Weapon")
	var shield: Node3D = null
	if model_id == "bulwark":
		shield = _joint(body, "ShieldArm", Vector3(-0.46, 0.04, -0.27))
		p = Parts.new()
		p.box(Vector3(0, -0.05, -0.15), Vector3(0.6, 1.06, 0.2), color, Vector3(0, 0.12, 0))
		if level < 2:
			p.box(Vector3(0, -0.05, -0.265), Vector3(0.11, 0.92, 0.03), Parts.STEEL)
			p.box(Vector3(0, 0.17, -0.28), Vector3(0.42, 0.08, 0.04), Parts.DARK)
		_finish(p, shield, "SlabShield")
	rigs.append({"body":body, "turret":turret, "gun":gun, "legs":legs, "knees":knees, "ends":ends, "shield":shield})

func apply_actor(actor: Dictionary, local_actor_id: int = -1) -> void:
	# Presentation assigns local_id before its one-argument apply_actor call.
	# An omitted argument must not turn a local body into a remote one.
	if local_actor_id >= 0: local_id = local_actor_id
	apply_identity(actor)
	if not snapshot.is_empty():
		if int(actor.get("shots", 0)) > int(snapshot.get("shots", 0)): kick()
		if float(actor.get("melee", 0)) > float(snapshot.get("melee", 0)): kick(0.7)
		if float(actor.get("health", 100)) > 0 and float(snapshot.get("health", 100)) <= 0: reset_pose()
	if not snapshot.is_empty():
		var loss: float = float(snapshot.get("health", 0)) + float(snapshot.get("armor", 0)) - float(actor.get("health", 0)) - float(actor.get("armor", 0))
		if loss > 0: hit_reaction = maxf(hit_reaction, clampf(loss / 35.0, 0.18, 1.0))
	snapshot = actor.duplicate(true)
	visible = int(actor.get("id", -2)) != local_id and (float(actor.get("health", 100)) > 0 or wants_death_pose())
	var profile: Dictionary = actor.get("npcProfile", {})
	var source_scale: float = clampf(float(profile.get("scale", 1.0)), 0.25, 3.0)
	feet.scale = Vector3.ONE * source_scale
	var next_tell: float = _tell(actor)
	# A released/cancelled authority windup settles the cradle, never spawns a hit.
	if tell_strength > 0 and next_tell == 0: recoil = maxf(recoil, 0.7)
	tell_strength = next_tell
	_pose()

func _tell(actor: Dictionary) -> float:
	if float(actor.get("campaignAttackWindup", 0)) > 0: return 0.65
	var fields := [["artilleryWindup", "npcArtillery", 1.2], ["phalanxWindup", "npcPhalanx", 0.55], ["flankWindup", "npcFlank", 0.5]]
	for entry: Array in fields:
		if actor.get(entry[0]) is float or actor.get(entry[0]) is int:
			var profile: Dictionary = actor.get(entry[1], {})
			return 0.3 + 0.7 * (1.0 - clampf(float(actor[entry[0]]) / maxf(0.01, float(profile.get("telegraph", entry[2]))), 0, 1))
	if actor.get("bossStompWindup") is float or actor.get("bossStompWindup") is int:
		var duration: float = float(actor.get("campaignSlamDuration", [1.1, 0.95, 0.8][clampi(int(actor.get("bossPhase", 1)) - 1, 0, 2)]))
		return 0.3 + 0.7 * (1.0 - clampf(float(actor.bossStompWindup) / duration, 0, 1))
	return 0.0

func wants_death_pose() -> bool:
	# The 0.65-second collapse gets a short settled beat, never an immortal corpse.
	return not snapshot.is_empty() and float(snapshot.get("health", 100)) <= 0 and death_elapsed < 0.8

func advance(dt: float) -> void:
	if not is_finite(dt) or dt <= 0: return
	elapsed += dt
	var speed := Vector2(float(snapshot.get("vx", 0)), float(snapshot.get("vz", 0))).length()
	var planted := tell_strength > 0.0 or float(snapshot.get("campaignStagger", 0)) > 0 or float(snapshot.get("campaignExposed", 0)) > 0
	var grounded: bool = snapshot.get("grounded", true)
	var target := clampf(speed / 1.2, 0.0, 1.0) if grounded and not planted else 0.0
	var stride := Motion.spring(stride_weight, stride_velocity, target, 18.0, dt)
	stride_weight = stride.x; stride_velocity = stride.y
	var tell := Motion.spring(tell_pose, tell_velocity, tell_strength, 22.0, dt)
	tell_pose = tell.x; tell_velocity = tell.y
	if grounded and not planted and speed > 0.04:
		gait_phase = fposmod(gait_phase + dt * minf(speed, 18.0) * TAU / _cycle_length(), TAU)
		var yaw := float(snapshot.get("bodyYaw", snapshot.get("yaw", 0)))
		var velocity := Vector3(float(snapshot.get("vx", 0)), 0, float(snapshot.get("vz", 0)))
		travel = travel.lerp(Basis(Vector3.UP, -yaw) * velocity.normalized(), 1.0-exp(-14.0*dt))
	if grounded and not rigs.is_empty():
		var rig: Dictionary = rigs[lod_level]
		ground_offsets.resize(rig.legs.size())
		for i in rig.legs.size():
			var hip: Node3D = rig.legs[i]
			var rest: Vector3 = hip.position + rig.knees[i].get_meta("rest") + rig.ends[i]
			var point: Vector3 = bands[lod_level].to_global(rest)
			var height := Ground.offset(self,point,feet.global_position.y,0.12*feet.scale.y)/feet.scale.y
			ground_offsets[i] = lerpf(ground_offsets[i],height,1.0-exp(-18.0*dt))
	recoil *= exp(-dt * 12.0)
	hit_reaction *= exp(-dt * 15.0)
	if float(snapshot.get("health", 100)) <= 0:
		death_elapsed += dt
		if not wants_death_pose(): hide()
	_pose()

func _pose() -> void:
	if rigs.is_empty(): return
	var rig: Dictionary = rigs[lod_level]
	var dead: bool = float(snapshot.get("health", 100)) <= 0
	var collapse: float = Motion.smooth(death_elapsed / 0.65) if dead else 0.0
	var speed := Vector2(float(snapshot.get("vx", 0)), float(snapshot.get("vz", 0))).length()
	var stride: float = stride_weight * (1.0 - collapse)
	var body: Node3D = rig.body
	body.position = body.get_meta("rest")
	# Keep living damage surfaces inside the reviewed six-centimetre margin.
	# Role anticipation is in the cradle/legs, never a displaced hitbox chassis.
	body.position.y += sin(gait_phase * 2) * 0.008 * stride - collapse * 0.32
	body.rotation = Vector3(0, 0, collapse * 0.22)
	body.position.z += hit_reaction * 0.012
	var turret: Node3D = rig.turret
	var focus := wrapf(float(snapshot.get("yaw",0))-float(snapshot.get("bodyYaw",snapshot.get("yaw",0))),-PI,PI)
	# Wide solid sensor towers stay in the body-yaw volume; the excluded cradle
	# carries the remaining aim articulation, rather than inventing a wider torso.
	turret.rotation = Vector3(clampf(float(snapshot.get("pitch", 0)), -0.4, 0.4), clampf(focus,-0.025,0.025), collapse * 0.35)
	var gun: Node3D = rig.gun
	gun.position = gun.get_meta("rest")
	gun.position.z += recoil * 0.13
	gun.rotation.y = focus-turret.rotation.y
	gun.rotation.x = -tell_pose * (0.45 if model_id == "mortar" else 0.2) + recoil * 0.12 + collapse * 0.6
	for i: int in range(rig.legs.size()):
		# Alternating bipeds, ripple tripod, diagonal quadrupeds, alternating hexapod.
		var offset := TAU * float(i) / 3.0 if rig.legs.size() == 3 else (PI if (i + i / 2) % 2 == 0 else 0.0)
		var step := Motion.contact(gait_phase + offset, _cycle_length(), 0.10 if model_id in ["skirmisher", "scrapper"] else 0.065) * stride
		var hip: Node3D = rig.legs[i]
		var knee: Node3D = rig.knees[i]
		var upper: Vector3 = knee.get_meta("rest")
		var lower: Vector3 = rig.ends[i]
		var foot := upper + lower + travel.normalized() * step.x + Vector3.UP * step.y
		if ground_offsets.size() > i: foot.y += ground_offsets[i]
		if model_id == "warden" and i < 2: foot.y += tell_pose * 0.15
		var rotations := Motion.two_link(upper, lower, foot, upper)
		hip.quaternion = rotations[0]
		knee.quaternion = rotations[1]
		if lod_level == 2:
			# Far mesh has a fused shin: retain a low-cost directional rigid swing.
			hip.rotation = Vector3(step.x * -travel.z, 0, step.x * travel.x)
		if dead:
			hip.rotate_x(collapse * 0.35); knee.rotate_x(-collapse * 0.6)
	if rig.shield != null: rig.shield.rotation.x = -tell_pose * 0.2 + collapse * 0.45 + (0.9 if float(snapshot.get("campaignExposed", 0)) > 0 else 0.0)
	# A short sensor flare accompanies confirmed chassis loss; an exposed core
	# stays cool-colored for exactly the authority's punish window.
	optic_material.emission = Color("b8edff") if float(snapshot.get("campaignExposed", 0)) > 0 else Color("ff773b")
	optic_material.emission_energy_multiplier = 0.0 if dead else 0.65 + tell_strength * 1.5 + hit_reaction * 2.0
	# Amber plate flash confirms an authority-reduced shield contact, unlike a miss.
	shield_material.emission_energy_multiplier = 2.4 if float(snapshot.get("campaignShieldHit", 0)) > 0 and not dead else 0.0

func kick(amount: float = 1.0) -> void:
	recoil = maxf(recoil, clampf(amount, 0, 2))
	_pose()

func reset_pose() -> void:
	elapsed = 0; gait_phase = 0; recoil = 0; hit_reaction = 0; death_elapsed = 0; tell_strength = 0
	stride_weight = 0; stride_velocity = 0; tell_pose = 0; tell_velocity = 0; travel = Vector3.FORWARD
	ground_offsets.clear()
	_pose()

func _cycle_length() -> float:
	return {"scrapper":0.9, "skirmisher":1.05, "sentinel":0.7, "mortar":0.8, "bulwark":0.85, "warden":0.95}.get(model_id, 0.9)

func select_distance(distance: float) -> void:
	set_lod(0 if distance < 22 else (1 if distance < 48 else 2))

func set_lod(level: int) -> void:
	lod_level = clampi(level, 0, 2)
	for i: int in range(bands.size()): bands[i].visible = i == lod_level
	_pose()

func visible_cost() -> Dictionary:
	var cost := {"draws":0, "surfaces":0, "triangles":0, "meshes":0, "lod":lod_level}
	for batch: MeshInstance3D in batches:
		if not batch.is_visible_in_tree(): continue
		cost.meshes += 1
		cost.surfaces += batch.mesh.get_surface_count()
		cost.draws += batch.mesh.get_surface_count()
		cost.triangles += int(batch.get_meta("triangles", 0))
	return cost

func _process(dt: float) -> void:
	if automatic_animation: advance(dt)
	if automatic_lod:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null: select_distance(global_position.distance_to(camera.global_position))
