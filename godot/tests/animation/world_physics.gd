extends SceneTree
## Exercises real native directors/renderers/FX. No helper-only reset substitute
## for host pause, no engine/network control modifications in production.
const Director = preload("res://campaign/interlude_director.gd")
const Renderer = preload("res://vehicles/renderer.gd")
const FX = preload("res://weapon_effects/controller.gd")
const Settings = preload("res://ui/settings_access.gd")
var checks := 0
var failures: Array[String] = []

class SettingsFixture extends Node:
	var values := {"reduced_motion":false}
	func overlay_open() -> bool: return false

class HostFixture extends "res://campaign/demo.gd":
	# Keep the real demo._process and can_capture_pointer chain; only exclude
	# handshake/network startup from this detached deterministic host fixture.
	func _ready() -> void: pass
	func advance_handshake(_delta: float) -> bool: return false

class CheatsFixture extends CanvasLayer:
	var state := {"paused":false}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _initialize() -> void: call_deferred("run")

func beat(stage: int = 0, choice: Variant = null) -> Dictionary:
	return {"id":"physics-wheel","title":"Physics wheel","family":"choice","theme":"waterwheel","stage":stage,"choice":choice,"completed":stage == 2,"a":{"x":0.0,"y":0.0,"z":0.0},"b":{"x":3.0,"y":0.0,"z":0.0},"entry":{"x":0.0,"y":0.0,"z":6.0},"machine":{"x":0.0,"y":0.0,"z":-6.0},"actions":["A","B"],"cable":[{"x":0.0,"y":0.0,"z":0.0},{"x":1.0,"y":0.0,"z":0.0},{"x":3.0,"y":0.0,"z":0.0}]}

func apply_stage(director: Node3D, stage: int, choice: Variant = null) -> void:
	director.apply({"beats":[beat(stage,choice)]},"physics-map")

func steps(rate: int, duration: float) -> Array:
	var result: Array = []
	var elapsed := 0.0
	while elapsed < duration - 0.0000001:
		var dt := minf(1.0 / rate, duration - elapsed)
		result.append(dt)
		elapsed += dt
	return result

func sample(director: Node3D) -> Dictionary:
	var workshop: Node3D = director.workshops["physics-wheel"]
	var motor = workshop.get_meta("rotor_speed")
	var lamp: StandardMaterial3D = workshop.get_meta("lamps")[0].material_override
	return {"angle":workshop.get_meta("rotor").rotation.z,"speed":motor.value,"velocity":motor.velocity,"lid":workshop.get_meta("lids")[0].rotation.x,"color":lamp.albedo_color,"energy":lamp.emission_energy_multiplier}

func same(a: Dictionary, b: Dictionary, tolerance: float = 0.00001) -> bool:
	return absf(wrapf(a.angle-b.angle,-PI,PI)) < tolerance and absf(a.speed-b.speed) < tolerance and absf(a.velocity-b.velocity) < tolerance and absf(a.lid-b.lid) < tolerance and a.color.is_equal_approx(b.color) and absf(a.energy-b.energy) < tolerance

func new_director() -> Node3D:
	var director := Director.new()
	root.add_child(director)
	director.set_process(false)
	apply_stage(director,0)
	for dt: float in steps(60,1.0): director._process(dt)
	apply_stage(director,2,"a")
	return director

func workshops(settings: Node) -> void:
	var reference := new_director()
	for dt: float in steps(60,0.25): reference._process(dt)
	var expected := sample(reference)
	for rate: int in [30,144]:
		var director := new_director()
		for dt: float in steps(rate,0.25): director._process(dt)
		check(same(sample(director),expected),"workshop rotor/lid/light %d Hz equivalence" % rate)
		director.free()
	var irregular := new_director()
	for dt: float in [0.007,0.029,0.003,0.171,0.04]: irregular._process(dt)
	check(same(sample(irregular),expected),"workshop irregular/hitch equivalence")
	irregular.free()
	var workshop: Node3D = reference.workshops["physics-wheel"]
	var node_count := workshop.find_children("*","Node",true,false).size()
	var materials: Array = []
	for entry: Dictionary in workshop.get_meta("light_transitions"): materials.append(entry.material.get_instance_id())
	for dt: float in steps(144,0.4): reference._process(dt)
	var unchanged_materials: Array = []
	for entry: Dictionary in workshop.get_meta("light_transitions"): unchanged_materials.append(entry.material.get_instance_id())
	check(materials == unchanged_materials and workshop.find_children("*","Node",true,false).size() == node_count,"no frame-loop node/material churn")
	var retired: StandardMaterial3D = workshop.get_meta("lamps")[0].material_override
	var retired_color := retired.albedo_color
	var retired_energy := retired.emission_energy_multiplier
	apply_stage(reference,1)
	reference._process(0.08)
	apply_stage(reference,2,"b")
	for dt: float in steps(60,2.0): reference._process(dt)
	check(retired.albedo_color == retired_color and retired.emission_energy_multiplier == retired_energy,"stage switch retires old light targets")
	check(absf(workshop.get_meta("lids")[0].rotation.x) < 0.00001 and absf(workshop.get_meta("lids")[1].rotation.x + 0.65) < 0.00001,"mid-transition stage/choice selects latest lid target")
	for panel: MeshInstance3D in workshop.get_meta("panels"):
		check(panel.material_override.albedo_color.is_equal_approx(Color("7effcc")) and absf(panel.material_override.emission_energy_multiplier - 1.8) < 0.00001,"settled source-restored illumination")
	settings.values.reduced_motion = true
	for dt: float in steps(60,3.0): reference._process(dt)
	var stopped := sample(reference)
	reference._process(0.5)
	check(stopped.speed == 0.0 and same(sample(reference),stopped),"reduced motion motor settles then stops exactly")
	settings.values.reduced_motion = false
	reference._process(0.2)
	check(sample(reference).speed > 0.0,"reduced motion off resumes supported motor")
	reference.clear_round()
	check(reference.workshops.is_empty() and reference.chapter.is_empty() and reference.clock == 0.0,"clear-round drops all workshop targets and clock")
	reference._process(0.2)
	apply_stage(reference,0)
	var fresh: Node3D = reference.workshops["physics-wheel"]
	check(fresh != workshop and fresh.get_meta("rotor_speed").value == 0.0 and fresh.get_meta("lid_springs")[0].velocity == 0.0,"restart creates clean motor/lid state")
	reference.free()

func host_pause() -> void:
	# Detached like existing protocol probes: avoids window-focus ambiguity and
	# invokes the actual parent-owned campaign._process hook with a real gate.
	var host := HostFixture.new()
	host.phase = 3
	host.received_pose = true
	host.application_focused = true
	host.campaign.state = {"phase":"playing"}
	host.presentation.lifecycle.apply({"health":100},false)
	host.snapshot_watch.observe()
	host.solo_cheats = CheatsFixture.new()
	var director: Node3D = host.interlude_director
	root.add_child(director)
	director.set_process(false)
	apply_stage(director,2,"a")
	host._process(0.0)
	director._process(0.15)
	check(not director.animation_suspended and sample(director).speed > 0.0,"actual campaign host allows active animation")
	for reason: String in ["source-pause","focus","action-pending","death","stale"]:
		host.solo_cheats.state.paused = reason == "source-pause"
		host.application_focused = reason != "focus"
		host.action_pending = reason == "action-pending"
		host.presentation.lifecycle.apply({"health":0 if reason == "death" else 100},false)
		host.snapshot_watch.observe()
		if reason == "stale": host.snapshot_watch.advance(2.0)
		host._process(0.0)
		var frozen := sample(director)
		var clock: float = director.clock
		director._process(0.7)
		check(director.animation_suspended and same(sample(director),frozen) and director.clock == clock,"actual host %s freezes unfinished motion/light" % reason)
		host.solo_cheats.state.paused = false
		host.application_focused = true
		host.action_pending = false
		host.presentation.lifecycle.apply({"health":100},false)
		host.snapshot_watch.observe()
		host._process(0.0)
		director._process(0.025)
		check(not director.animation_suspended and not same(sample(director),frozen) and absf(director.clock-clock-0.025) < 0.00001,"actual host %s resumes without paused-time catch-up" % reason)
	# Free detached composition's preallocated nodes; no network startup occurred.
	root.remove_child(director)
	for property: Dictionary in host.get_property_list():
		var value: Variant = host.get(property.name)
		if is_instance_valid(value) and value is Node and value.get_parent() == null: value.free()
	host.free()

func vehicles(settings: Node) -> void:
	var renderer := Renderer.new()
	root.add_child(renderer)
	var v := {"id":0,"kind":"puma","x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"roll":0.15,"pitchBody":-0.05,"health":300,"respawnTimer":0.0,"vx":0.0,"vz":4.2,"turretYaw":0.2,"driver":0}
	var state := {"vehicles":[v],"actors":[],"time":1.0}
	check(renderer.apply_state(state),"wheel fixture accepted")
	var car: Node3D = renderer.vehicle_node(0)
	car.set_process(false)
	var source_transform := car.transform
	state.time = 1.05
	renderer.apply_state(state)
	check(absf(car.wheels[0].rotation.x-0.5) < 0.00001,"wheel source-sample angle published immediately")
	car._process(0.025)
	check(absf(car.wheels[0].rotation.x-0.75) < 0.00001,"wheel lead follows signed velocity/radius")
	car._process(2.0)
	var capped: float = car.wheels[0].rotation.x
	car._process(0.5)
	check(absf(capped-1.5) < 0.00001 and car.wheels[0].rotation.x == capped,"wheel lead bounded at 100ms then freezes on stale sample")
	check(car.transform == source_transform and car.turret.rotation.y == 0.2,"wheel animation never moves authoritative root/turret")
	for rate: int in [30,60,144]:
		car.observe_roll(4.2,0.0,true)
		for dt: float in steps(rate,0.075): car._process(dt)
		check(absf(car.wheels[0].rotation.x-0.75) < 0.00001,"wheel %d Hz lead equivalence" % rate)
	car.observe_roll(-4.2,0.0,true)
	car._process(0.05)
	check(car.wheels[0].rotation.x < 0.0,"reverse wheel sign")
	settings.values.reduced_motion = true
	car._process(0.05)
	check(car.wheels[0].rotation.x == car.roll_angle,"reduced motion removes wheel lead")
	settings.values.reduced_motion = false
	v.x = 20.0
	state.time = 1.1
	renderer.apply_state(state)
	check(car.roll_angle == 0.0 and car.roll_age == 0.0,"vehicle teleport clears rolling history")
	v.health = 0
	renderer.apply_state(state)
	v.health = 300
	state.time = 1.15
	renderer.apply_state(state)
	check(car.visible and car.roll_angle == 0.0,"respawn clears rolling history")
	state.time = 2.0
	renderer.apply_state(state)
	check(car.roll_angle == 0.0,"long source gap resets rolling phase")
	renderer.clear_round()
	check(renderer.nodes.is_empty() and renderer.stamps.is_empty(),"vehicle restart clears nodes and stamps")
	renderer.free()

func casing() -> void:
	var fx := FX.new()
	root.add_child(fx)
	fx.set_process(false)
	var origin := Vector3(0.2,0.1,-0.4)
	var initial := Vector3(0.65,0.5,0.1)
	var duration := 0.25
	var expected := origin + initial*duration + Vector3.DOWN * 0.5 * 2.5 * duration * duration
	var node_ids: Array = []
	for rate: int in [30,60,144]:
		# Exercise the real existing pool and advance path, isolating a cosmetic
		# casing from trigger acceptance already covered by weapon FX tests.
		var slot: Dictionary = fx._slot(fx,12)
		slot.merge({"remaining":0.38,"total":0.38,"size":1.0,"velocity":initial},true)
		slot.node.position = origin
		node_ids.append(slot.node.get_instance_id())
		for dt: float in steps(rate,duration): fx.advance(dt)
		check(slot.node.position.distance_to(expected) < 0.000002,"casing ballistic arc %d Hz" % rate)
		check(slot.velocity.distance_to(initial + Vector3.DOWN*2.5*duration) < 0.000002,"casing velocity %d Hz" % rate)
		fx.advance(1.0)
		check(slot.remaining == 0.0 and not slot.node.visible,"casing expires on hitch without lingering")
	check(node_ids[0] == node_ids[1] and node_ids[1] == node_ids[2] and fx.slots.size() == 1,"casing pool reuses its node")
	var slot: Dictionary = fx._slot(fx,12)
	slot.merge({"remaining":0.38,"total":0.38,"size":1.0,"velocity":initial},true)
	slot.node.position = origin
	for dt: float in [0.007,0.029,0.003,0.171,0.04]: fx.advance(dt)
	check(slot.node.position.distance_to(expected) < 0.000002,"casing irregular/hitch arc equivalence")
	var casing_node: Node3D = slot.node
	fx.reset()
	check(not is_instance_valid(casing_node) and fx.slots.is_empty(),"casing restart frees and drains transient")
	fx.free()

func run() -> void:
	var settings := Settings.service()
	var owned := settings == null
	if owned:
		settings = SettingsFixture.new()
		settings.name = "LocalSettings"
		root.add_child(settings)
	var previous_reduced: Variant = settings.values.get("reduced_motion",false)
	settings.values.reduced_motion = false
	workshops(settings)
	host_pause()
	vehicles(settings)
	casing()
	settings.values.reduced_motion = previous_reduced
	if owned: settings.free()
	await process_frame # drains director/vehicle clear_round queue_free nodes
	print("WORLD_ANIMATION_PHYSICS ",JSON.stringify({"checks":checks,"failures":failures,"host_hook":"campaign/demo._process","network_started":false}))
	quit(0 if failures.is_empty() else 1)
