extends Node3D
## Drop-in apply_identity plus opt-in state-driven animation API.
## Host uses center anchor actor.y+0.9; this wrapper translates source feet by -0.9.
## Source anatomy, -Z forward, and original scale are preserved exactly.
const Catalog = preload("res://source_operators/generated/catalog.gd")
const Rig = preload("res://source_operators/character_rig.gd")
const WorldWeapons = preload("res://source_operators/generated/world_weapons/catalog.gd")
const HandGrips = preload("res://source_operators/hand_grips.gd")
const WORLD_WEAPON_DIR := "res://source_operators/generated/world_weapons/"
var identity_key: String = ""
var character: String = ""
var source: Node3D
var nodes: Dictionary = {}
var batches: Array[MeshInstance3D] = []
var rig = Rig.new()
var snapshot: Dictionary = {}
var local_id: int = -1
var elapsed: float = 0.0
var lod_level: int = -1
var recoil: float = 0.0
var automatic_animation: bool = true
var team_material: StandardMaterial3D
var neutral_armor: Color
var team_bars: Array[MeshInstance3D] = []
var weapon_type: int = -1
var world_weapon: Node3D
var grip_error: Dictionary = {}
var grip_clamp: Dictionary = {}

func apply_identity(actor: Dictionary) -> void:
	if Catalog.OPERATORS.is_empty(): return
	var next: String = str(actor.get("character","chatgpt"))
	if not Catalog.OPERATORS.has(next): next = str(Catalog.OPERATORS.keys()[0])
	var next_key: String = next + ":" + str(actor.get("team",""))
	if identity_key == next_key: return
	identity_key = next_key
	set_meta("character",next)
	set_meta("team",actor.get("team",""))
	if character == next:
		_apply_team(actor.get("team"))
		return
	if is_instance_valid(source):
		remove_child(source)
		source.free()
	nodes.clear(); batches.clear(); snapshot.clear(); team_bars.clear(); team_material = null
	world_weapon = null
	weapon_type = -1
	grip_error.clear()
	grip_clamp.clear()
	character = next
	var path: String = "res://source_operators/generated/%s.glb" % character
	if not ResourceLoader.exists(path):
		# Unknown/missing character assets fall back to the first exported identity.
		character = str(Catalog.OPERATORS.keys()[0])
		path = "res://source_operators/generated/%s.glb" % character
	if not ResourceLoader.exists(path):
		push_warning("No exported source operator available for %s" % next)
		return
	var packed: PackedScene = load(path)
	if packed == null:
		push_warning("Exported source operator failed to load: %s" % path)
		return
	source = packed.instantiate()
	source.position.y = -0.9
	add_child(source)
	_collect(source)
	_apply_team(actor.get("team"))
	rig.configure(nodes)
	lod_level = -1
	set_lod(0)
	elapsed = 0.0; recoil = 0.0

func _collect(node: Node) -> void:
	if node is Node3D:
		if Catalog.OPERATORS[character].joints.has(str(node.name)): nodes[str(node.name)] = node
		if node is MeshInstance3D:
			if str(node.name).begins_with("TeamBar"):
				team_bars.append(node)
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				return
			batches.append(node)
			for surface: int in range(node.mesh.get_surface_count()):
				var mat: StandardMaterial3D = node.mesh.surface_get_material(surface)
				if mat.resource_name == Catalog.OPERATORS[character].teamArmorMaterial:
					if team_material == null:
						team_material = mat.duplicate()
						neutral_armor = mat.albedo_color
					node.set_surface_override_material(surface,team_material)
			var shadow: bool = true
			for batch: Dictionary in Catalog.OPERATORS[character].batches:
				if batch.name == str(node.name):
					shadow = batch.castShadow
					break
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children(): _collect(child)

func _apply_team(team: Variant) -> void:
	var key: String = str(team)
	var red: bool = key in ["0","0.0","red"]
	var blue: bool = key in ["1","1.0","blue"]
	if team_material:
		team_material.albedo_color = Color(Catalog.OPERATORS[character].teamPalette[0 if red else 1].color) if red or blue else neutral_armor
	for bar: MeshInstance3D in team_bars:
		var index: int = int(str(bar.name).right(1))
		bar.visible = (red or blue) and (index == 0 or blue)
		bar.position.x = (0.0 if red else -0.05) if index == 0 else 0.05

func configure(actor: Dictionary, local_actor_id: int = -1) -> void:
	local_id = local_actor_id
	apply_actor(actor)

func set_weapon(type: int) -> void:
	## Third-person source weapon replacement: the actual exported source
	## simpleWeaponModel for actor.weapon, mounted on the authored source
	## GunMount. The built-in pulse batches stay loaded but hidden.
	if WorldWeapons.WEAPONS.is_empty(): return
	type = clampi(type,0,WorldWeapons.WEAPONS.size()-1)
	if type == weapon_type and is_instance_valid(world_weapon): return
	if is_instance_valid(world_weapon):
		if world_weapon.get_parent() != null: world_weapon.get_parent().remove_child(world_weapon)
		world_weapon.free()
		world_weapon = null
	weapon_type = -1
	grip_error.clear()
	grip_clamp.clear()
	var mount: Node3D = nodes.get("gunAnchor")
	if mount == null: return
	if nodes.has("weapon") and nodes.weapon is Node3D: nodes.weapon.visible = false
	var path: String = WORLD_WEAPON_DIR + str(WorldWeapons.WEAPONS[type].file)
	if not ResourceLoader.exists(path):
		push_warning("Exported world weapon missing: %s" % path)
		return
	var packed: PackedScene = load(path)
	if packed == null: return
	world_weapon = packed.instantiate()
	world_weapon.name = "WorldWeapon"
	mount.add_child(world_weapon)
	weapon_type = type

func weapon_cost() -> Dictionary:
	if weapon_type < 0 or weapon_type >= WorldWeapons.WEAPONS.size(): return {}
	return WorldWeapons.WEAPONS[weapon_type]

func apply_actor(actor: Dictionary) -> void:
	apply_identity(actor)
	snapshot = actor.duplicate()
	visible = int(actor.get("id",-2)) != local_id
	if not is_instance_valid(source):
		visible = false
		return
	if float(actor.get("health",100)) <= 0:
		rig.apply_source_death(Catalog.OPERATORS[character].deathPose)
		return
	if rig.dead:
		rig.reset(); recoil = 0.0
	# The source only replaces a living actor's held weapon; corpses keep theirs.
	if actor.has("weapon"): set_weapon(int(actor.get("weapon",0)))

func reset_pose() -> void:
	rig.reset()
	recoil = 0.0

func kick(amount: float = 1.0) -> void:
	# Presentation-only bounded recoil overlay, on the source weapon mount.
	recoil = minf(1.0,recoil+maxf(0.0,amount))

func _process(dt: float) -> void:
	if not is_instance_valid(source): return
	if automatic_animation and not snapshot.is_empty(): advance(dt)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera: select_distance(global_position.distance_to(camera.global_position))

func advance(dt: float) -> void:
	if rig.dead or snapshot.is_empty(): return
	elapsed += dt
	var a: Dictionary = snapshot
	var yaw: float = float(a.get("yaw",0))
	var body_yaw: float = float(a.get("bodyYaw",yaw))
	var focus: float = wrapf(yaw-body_yaw,-PI,PI)
	var vx: float = float(a.get("vx",0)); var vz: float = float(a.get("vz",0))
	var mounted: bool = a.get("vehicleId") != null
	var state: Dictionary = {"dt":dt,"time":elapsed,"speed":0 if mounted else Vector2(vx,vz).length(),"maxSpeed":a.get("moveSpeed",8),"grounded":true if mounted else a.get("grounded",true),"crouch":not mounted and a.get("crouching",false),"ads":not mounted and a.get("ads",false),"reload":1 if not mounted and a.get("reloading",false) else 0,"strafe":0 if mounted else clampf((vx*cos(body_yaw)-vz*sin(body_yaw))/3.0,-1,1),"forward":0 if mounted else clampf(-(vx*sin(body_yaw)+vz*cos(body_yaw))/3.0,-1,1),"focusYaw":focus,"focusPitch":-float(a.get("pitch",0)),"bank":clampf((yaw-body_yaw)*1.1,-1,1),"hit":a.get("hit",0),"sliding":a.get("sliding",false),"reduced":a.get("reduced",false)}
	if state.reduced: state.bank = 0.0
	rig.update(state)
	recoil = maxf(0.0,recoil-dt*7.0)
	var mount: Node3D = nodes.gunAnchor
	mount.quaternion = Quaternion.IDENTITY if state.reduced else Rig.xyz_quaternion(Vector3(clampf(float(a.get("pitch",0)),-0.7,0.7)-recoil*0.06,clampf(focus,-0.9,0.9),0))
	mount.position = rig.bind.gunAnchor.origin + Vector3(0,0,0 if state.reduced else recoil*0.035)
	if is_instance_valid(world_weapon):
		# Source post-pose hand pass, after the source weapon was replaced.
		grip_clamp.clear()
		grip_error = HandGrips.align(nodes, world_weapon, grip_clamp)

func select_distance(distance: float) -> void:
	# Source LOD thresholds 5.8m precision / 18m anatomy, with hysteresis.
	var level: int = lod_level
	if level < 0: level = 0
	if level == 0 and distance > 5.8: level = 1
	if level == 1 and distance < 4.93: level = 0
	if level < 2 and distance > 18.0: level = 2
	if level == 2 and distance < 15.3: level = 1
	set_lod(level)

func set_lod(level: int) -> void:
	if level == lod_level: return
	lod_level = clampi(level,0,2)
	for mesh: MeshInstance3D in batches:
		# Name survives import, independently of glTF extras preservation.
		var mask: int = int(str(mesh.name).split("_")[0].trim_prefix("LOD"))
		mesh.visible = (mask & (1 << lod_level)) != 0

func anchor(anchor_name: String) -> Node3D:
	if anchor_name == "Muzzle" and is_instance_valid(world_weapon):
		var weapon_muzzle: Node3D = world_weapon.find_child("Muzzle",true,false)
		if weapon_muzzle != null: return weapon_muzzle
	var key: String = {"Helmet":"head","GunMount":"gunAnchor","GripLeft":"gripL","GripRight":"gripR","FeetOrigin":"SourceOperator"}.get(anchor_name,anchor_name)
	if nodes.has(key): return nodes[key]
	if not is_instance_valid(source): return null
	return source.find_child(key,true,false) as Node3D

func visible_cost() -> Dictionary:
	if not Catalog.OPERATORS.has(character): return {}
	return Catalog.OPERATORS[character].lods[lod_level]
