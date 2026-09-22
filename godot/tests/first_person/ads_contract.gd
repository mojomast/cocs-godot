extends SceneTree
const Rig = preload("res://first_person/rig.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var actor := {"id":7,"weapon":0,"health":100}
	for id: int in 10:
		actor.weapon = id
		var weights: Array[float] = []
		for hz: int in [30,60,120]:
			rig.reset()
			rig.apply_actor(actor,true)
			for n: int in 6: rig.advance(0.05)
			rig.apply_aim(true)
			for n: int in hz/10: rig.advance(1.0 / hz)
			weights.append(rig.aim_weight)
		check(absf(weights[0]-weights[1]) < 0.000001 and absf(weights[1]-weights[2]) < 0.000001,"frame partition invariant weapon %d" % id)
		var expected := 1.0 - exp(-float(rig.manifest.weapons[id].ads.enter)*0.1)
		check(absf(weights[0]-expected) < 0.000001,"source ADS enter timing weapon %d" % id)
		rig.apply_aim(false)
		for n: int in 6: rig.advance(1.0/60.0)
		check(absf(rig.aim_weight-expected*exp(-float(rig.manifest.weapons[id].ads.exit)*0.1)) < 0.000001,"source ADS exit timing weapon %d" % id)
		rig.apply_aim(true,0.35)
		for n: int in 180: rig.advance(1.0/60.0)
		check(absf(rig.aim_weight-0.35) < 0.00001 and not rig.get_aim_state().ready,"partial target weight stays partial weapon %d" % id)
		for invalid: float in [-1.0,NAN,INF]:
			check(not rig.apply_aim(true,invalid),"invalid aim weight rejected")
		var before := rig.pivot.transform
		var weight := rig.aim_weight
		for invalid: float in [-1.0,NAN,INF]: rig.advance(invalid)
		check(rig.pivot.transform == before and rig.aim_weight == weight,"invalid frame delta cannot poison pose")
	# Block presentation requests while source posture/weapon state disallows ADS.
	for field: String in ["reloading","sprinting","weaponSwitch"]:
		var blocked := actor.duplicate()
		blocked[field] = 0.5 if field == "weaponSwitch" else true
		rig.apply_actor(blocked,true)
		check(not rig.apply_aim(true),"source state blocks aim: " + field)
		for n: int in 90: rig.advance(1.0/60.0)
		check(rig.aim_weight == 0.0,"blocked pose exits: " + field)
		rig.apply_actor(actor,true)
		rig.apply_aim(true)
		for n: int in 90: rig.advance(1.0/60.0)
	var other := Rig.new()
	root.add_child(other)
	other.attach_to(camera)
	other.set_process(false)
	other.apply_actor(actor,true)
	other.advance(0.05)
	check(rig.aim_weight == 1.0 and other.aim_weight == 0.0,"two rigs have independent aim state")
	actor.weapon = 2
	rig.apply_actor(actor,true)
	check(rig.aim_weight == 0 and not rig.aim_requested,"weapon switch clears prior aim pose")
	rig.apply_aim(true)
	rig.advance(0.05)
	check(rig.aim_weight == 0 and not rig.get_aim_state().ready,"switch lowering precedes fresh ADS request")
	for n: int in 120: rig.advance(1.0/60.0)
	var source_camera := camera.transform
	var source_fov := camera.fov
	var state := rig.get_aim_state(75.0)
	check(absf(state.magnification-3.6) < 0.00001 and absf(state.fov-24.064209) < 0.001,"rail source magnification, exact perspective FOV")
	check(camera.transform == source_camera and camera.fov == source_fov,"FOV recommendation has no gameplay-camera writes")
	rig.external_muzzle_fx = true
	rig.apply_events([{"id":1,"time":1.0,"type":"shot","actor":7,"weapon":2}],7)
	rig.advance(0)
	check(rig.recoil > 0 and not rig.flash.visible,"external FX suppresses fallback flash but preserves recoil")
	rig.clear_round()
	check(rig.aim_weight == 0 and not rig.aim_requested and not rig.showing,"round restart clears aim state")
	rig.free()
	other.free()
	camera.free()
	print("NATIVE_ADS_CONTRACT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
