extends Node3D
## Optional workshops are snapshot presentation. All eligibility, aiming, E,
## rewards and retry state live in native-campaign/interludes.mjs.
var chapter := ""
var workshops: Dictionary = {}
var clock := 0.0
var animation_suspended := false # Optional host gate for source/debug pause.
const Spring = preload("res://animation/critical_spring.gd")
const SettingsAccess = preload("res://ui/settings_access.gd")

func clear_round() -> void:
	for node: Node3D in workshops.values(): node.queue_free()
	workshops.clear()
	chapter = ""
	clock = 0.0
	animation_suspended = false

func material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.65
	mat.roughness = 0.38
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	return mat

func part(host: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	host.add_child(node)
	return node

func box(host: Node3D, at: Vector3, size_: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_
	return part(host, mesh, at, mat)

func tube(host: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	var node := part(host, mesh, (a+b)*0.5, mat)
	var direction := (b-a).normalized()
	var side := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.95 else direction.cross(Vector3.UP).normalized()
	node.basis = Basis(side, direction, side.cross(direction).normalized())
	return node

func point(value: Dictionary) -> Vector3:
	return Vector3(float(value.x), float(value.y), float(value.z))

func label(host: Node3D, text: String, at: Vector3, size_: int) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = at
	node.font_size = size_
	node.pixel_size = 0.012
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.modulate = Color("fff1d4")
	node.outline_size = 8
	node.visibility_range_end = 23
	node.visibility_range_begin = 3
	host.add_child(node)
	return node

func build(beat: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Interlude_" + str(beat.id)
	add_child(root)
	var metal := material(Color("3b505b"))
	var copper := material(Color("cb8746"))
	var dark := material(Color("142d38"))
	var gold := material(Color("ffce69"), true)
	var lamps: Array[MeshInstance3D] = []
	var lids: Array[Node3D] = []
	for key: String in ["a", "b"]:
		var p := point(beat[key])
		# Small waist-high controls, visual-only like existing story characters.
		# The interaction disk is intentionally wider than the decorative plinth.
		box(root, p+Vector3(0,0.45,0), Vector3(0.65,0.9,0.65), metal)
		var lid := Node3D.new()
		root.add_child(lid)
		lid.position = p+Vector3(0,1,0)
		box(lid, Vector3.ZERO, Vector3(1.1,0.15,0.8), copper)
		lamps.append(box(lid, Vector3(0,0.11,0), Vector3(0.65,0.06,0.45), dark))
		lids.append(lid)
		var action := str(beat.actions[0 if key == "a" else 1])
		label(root, action, p+Vector3(0,2.0,0), 24)
		if beat.family == "align" and key == "b":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.9
			ring.outer_radius = 1.2
			var target := part(root, ring, p+Vector3(0,2.5,0), gold)
			target.rotation.x = PI/2
			tube(root, p, p+Vector3(0,2.5,0), 0.1, copper)
	var wires: Array[MeshInstance3D] = []
	var path: Array = beat.cable
	for i: int in range(1,path.size()):
		wires.append(tube(root, point(path[i-1])+Vector3.UP*0.12, point(path[i])+Vector3.UP*0.12, 0.075, copper))
	var machine := Node3D.new()
	root.add_child(machine)
	machine.position = point(beat.machine)
	# Face the approach instead of an arbitrary world axis. Keep the operating
	# wheel above its solid housing so the restored silhouette is readable.
	var approach := point(beat.entry)
	approach.y = machine.position.y
	machine.look_at(approach)
	var rotor := Node3D.new()
	machine.add_child(rotor)
	rotor.position.y = 3.1
	var ring := TorusMesh.new()
	ring.inner_radius = 2.6 if beat.theme == "waterwheel" else 1.8
	ring.outer_radius = 3.1 if beat.theme == "waterwheel" else 2.1
	var wheel := part(rotor, ring, Vector3.ZERO, copper)
	wheel.rotation.x = PI/2
	for i: int in 8:
		var spoke := box(rotor, Vector3.ZERO, Vector3(0.16,5.4,0.18), metal)
		spoke.rotation.z = i*PI/4
	var panels: Array[MeshInstance3D] = []
	# The garden's visible reward follows the player's cable route, rather than
	# only switching lamps on the distant tower. Nursery trays use the same
	# supported points, set just outside the walking line.
	if beat.theme in ["nursery", "garden"]:
		for i: int in range(1,path.size()-1,2):
			var p := point(path[i])+Vector3(0.8,0,0.8)
			box(root,p+Vector3(0,0.2,0),Vector3(0.65,0.4,0.65),copper)
			tube(root,p,p+Vector3.UP*1.5,0.08,metal)
			panels.append(box(root,p+Vector3.UP*1.5,Vector3(0.4,0.65,0.4),dark))
	for i: int in 5:
		var p := Vector3((i-2)*1.15, 0.3+sin(i*PI/4)*2, -0.6)
		panels.append(box(machine,p,Vector3(0.85,1.2,0.35),dark))
	# Chapter-specific machinery silhouettes: a wheel, vent stack, seed trays,
	# or a radial choir. These sit above already-solid authored architecture.
	rotor.visible = beat.theme in ["waterwheel", "receiver", "choir", "nursery"]
	if beat.theme == "nursery":
		rotor.scale = Vector3.ONE*0.35
		rotor.position.y = 1.5
		rotor.rotation.x = PI/2
	if beat.theme in ["condenser", "foundry"]:
		for i: int in 3: tube(machine,Vector3((i-1)*1.8,0,0),Vector3((i-1)*1.8,4-i*0.7,0),0.45,metal)
	if beat.theme in ["nursery", "garden"]:
		for i: int in 5:
			box(machine,Vector3((i-2)*1.5,-0.4,0),Vector3(1.2,0.5,1.6),copper)
			tube(machine,Vector3((i-2)*1.5,0,0),Vector3((i-2)*1.5,1.6,0),0.18,material(Color("699654")))
	var title := label(root, str(beat.title)+"\nOPTIONAL WORKSHOP", point(beat.entry)+Vector3(0,3,0), 30)
	root.set_meta("lamps",lamps)
	root.set_meta("wires",wires)
	root.set_meta("lids",lids)
	root.set_meta("panels",panels)
	root.set_meta("rotor",rotor)
	root.set_meta("title",title)
	root.set_meta("stage",-1)
	root.set_meta("lid_springs",[Spring.new(), Spring.new()])
	root.set_meta("lid_targets",[0.0, 0.0])
	root.set_meta("rotor_speed",Spring.new())
	root.set_meta("light_transitions",[])
	return root

func transition(root: Node3D, node: MeshInstance3D, target: StandardMaterial3D) -> void:
	var previous := node.material_override as StandardMaterial3D
	var start := previous.albedo_color if previous != null else target.albedo_color
	var energy := previous.emission_energy_multiplier if previous != null and previous.emission_enabled else 0.0
	var goal_energy := target.emission_energy_multiplier if target.emission_enabled else 0.0
	# Stage changes only allocate a material; the render loop mutates fixed references.
	node.material_override = target.duplicate()
	var mat := node.material_override as StandardMaterial3D
	mat.albedo_color = start
	mat.emission_enabled = true
	mat.emission = target.albedo_color
	mat.emission_energy_multiplier = energy
	var transitions: Array = root.get_meta("light_transitions")
	transitions.append({"material":mat,"color":target.albedo_color,"energy":goal_energy})

func apply(value: Dictionary, map_id: String) -> void:
	if chapter != map_id:
		clear_round()
		chapter = map_id
	for beat: Dictionary in value.get("beats", []):
		var root: Node3D = workshops.get(beat.id)
		if root == null:
			root = build(beat)
			workshops[beat.id] = root
		var stage := int(beat.stage)
		if int(root.get_meta("stage")) == stage: continue
		root.set_meta("stage",stage)
		root.set_meta("light_transitions",[])
		var live := material(Color("7effcc"),true)
		var lamps: Array = root.get_meta("lamps")
		for i: int in lamps.size():
			transition(root, lamps[i], live if stage == 2 or stage == 1 and i == 0 else material(Color("c39445"),true))
		var wires: Array = root.get_meta("wires")
		for i: int in wires.size():
			transition(root, wires[i], live if stage == 2 or stage == 1 and i < wires.size()/2 else material(Color("cb8746")))
		for panel: MeshInstance3D in root.get_meta("panels"):
			transition(root, panel, live if stage == 2 else material(Color("253843")))
		var title: Label3D = root.get_meta("title")
		title.text = str(beat.title)+("\nRESTORED" if stage == 2 else "\nOPTIONAL WORKSHOP")
		var lids: Array = root.get_meta("lids")
		for i: int in lids.size():
			root.get_meta("lid_targets")[i] = -0.65 if stage == 2 and (beat.choice == null or beat.choice == ("a" if i == 0 else "b")) else 0.0

func _process(dt: float) -> void:
	if not is_finite(dt) or dt < 0.0: return
	if animation_suspended or SettingsAccess.overlay_open(): return
	clock += dt
	var settings := SettingsAccess.service()
	var reduced: bool = settings != null and settings.values.get("reduced_motion", false) == true
	for root: Node3D in workshops.values():
		var restored := int(root.get_meta("stage")) == 2
		var springs: Array = root.get_meta("lid_springs")
		var lids: Array = root.get_meta("lids")
		var targets: Array = root.get_meta("lid_targets")
		for i: int in lids.size():
			lids[i].rotation.x = springs[i].advance(dt, float(targets[i]), 18.0 if reduced else 12.0, 0.65)
		var motor: RefCounted = root.get_meta("rotor_speed")
		var rotor: Node3D = root.get_meta("rotor")
		# Integrate the critical spring exactly so angular distance, not just
		# final motor speed, is independent of the render cadence.
		var goal := 0.8 if restored and not reduced else 0.0
		var offset: float = motor.value - goal
		var j: float = motor.velocity + 6.0 * offset
		var decay := exp(-6.0 * dt)
		var travel: float = goal * dt + offset * (1.0 - decay) / 6.0 + j * (1.0 - decay * (1.0 + 6.0 * dt)) / 36.0
		motor.advance(dt, goal, 6.0, 0.8)
		rotor.rotation.z = wrapf(rotor.rotation.z + travel, -PI, PI)
		for entry: Dictionary in root.get_meta("light_transitions"):
			var mat: StandardMaterial3D = entry.material
			var weight := 1.0 - exp(-dt * 10.0)
			mat.albedo_color = mat.albedo_color.lerp(entry.color, weight)
			mat.emission_energy_multiplier = lerpf(mat.emission_energy_multiplier, float(entry.energy), weight)
