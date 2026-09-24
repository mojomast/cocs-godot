extends SceneTree
## First-person recoil response contract and weapon-oomph measurements.
##
## Presentation only: this proves the port-side response is stronger than the
## source-rate formula, per-weapon characteristic, bounded, honoured under
## reduced motion, and exactly zero at a settled ADS pose. No aim, spread, ammo
## or damage value is read or written.
const Rig = preload("res://first_person/rig.gd")
const Handling = preload("res://first_person/handling.gd")
const Profiles = preload("res://weapon_effects/profiles.gd")
const STEP := 1.0 / 240.0
var failures: Array[String] = []
var checks := 0
var measured: Array[Dictionary] = []
var volley := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func fire(rig: Node, weapon: int) -> void:
	volley += 1
	rig.apply_events([{"id":400000 + volley, "time":4000.0 + volley, "type":"shot", "actor":7, "weapon":weapon}], 7)

## Applied pose delta since a captured baseline, in the pivot's own frame: the
## right-multiplied recoil rotation and the backward shove.
func pose_delta(rig: Node, baseline: Transform3D) -> Vector3:
	var rotation: Vector3 = (baseline.basis.inverse() * rig.pivot.basis).get_euler()
	return Vector3(rotation.x, rotation.y, rotation.z)

func settle(rig: Node, frames: int) -> void:
	for frame: int in frames: rig.advance(1.0 / 60.0)

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var actor := {"id":7,"weapon":0,"health":100}
	for id: int in 10:
		rig.reset()
		actor.weapon = id
		rig.apply_actor(actor,true)
		settle(rig,10)
		var info: Dictionary = rig.manifest.weapons[id]
		var kick: Array = info.kick
		var profile: Dictionary = Profiles.ITEMS[id]
		var source_shove: float = float(kick[0]) * 0.45
		var source_lift: float = float(kick[1]) * 0.6
		# 1. The recoil profile is a pure function of the source feel triple.
		check(absf(rig.handling.kick_scale - Handling.recoil_scale(kick)) < 0.000001, "kick scale from source feel weapon %d" % id)
		check(rig.handling.kick_scale >= Handling.RECOIL_MIN_SCALE - 0.000001 and rig.handling.kick_scale <= Handling.RECOIL_MAX_SCALE + 0.000001, "kick scale band weapon %d" % id)
		check(absf(rig.handling.recover_speed - float(kick[2]) * Handling.RECOIL_RECOVER) < 0.000001, "recover rate from source feel weapon %d" % id)
		check(rig.handling.lift_hold >= Handling.RECOIL_PITCH_HOLD_MIN - 0.000001 and rig.handling.lift_hold <= Handling.RECOIL_PITCH_HOLD_MAX + 0.000001, "lift hold band weapon %d" % id)
		check(rig.handling.transient_rate >= Handling.PUNCH_RATE_HEAVY - 0.000001 and rig.handling.transient_rate <= Handling.PUNCH_RATE_LIGHT + 0.000001, "punch rate band weapon %d" % id)
		# 2. Single-shot peak response against the exact source-rate formula.
		var baseline: Transform3D = rig.pivot.transform
		fire(rig, id)
		var peak_shove := 0.0
		var peak_lift := 0.0
		var peak_roll := 0.0
		var recoil_zero := -1.0
		var punch_zero := -1.0
		var elapsed := 0.0
		var steps := int(ceil(2.0 / STEP))
		for step: int in steps:
			rig.advance(STEP)
			elapsed += STEP
			var delta := pose_delta(rig, baseline)
			peak_shove = maxf(peak_shove, absf(rig.pivot.position.z - baseline.origin.z))
			peak_lift = maxf(peak_lift, absf(delta.x))
			peak_roll = maxf(peak_roll, absf(delta.z))
			if recoil_zero < 0.0 and rig.recoil == 0.0: recoil_zero = elapsed
			if punch_zero < 0.0 and rig.punch == 0.0: punch_zero = elapsed
		check(peak_shove > source_shove * 1.5, "peak shove stronger than source weapon %d (%.4f/%.4f m)" % [id,peak_shove,source_shove])
		check(peak_shove < source_shove * 3.6, "peak shove bounded weapon %d (%.4f/%.4f m)" % [id,peak_shove,source_shove])
		check(peak_lift > source_lift * 1.4, "peak lift stronger than source weapon %d (%.2f/%.2f deg)" % [id,rad_to_deg(peak_lift),rad_to_deg(source_lift)])
		check(peak_lift < source_lift * 2.4, "peak lift bounded weapon %d (%.2f/%.2f deg)" % [id,rad_to_deg(peak_lift),rad_to_deg(source_lift)])
		check(peak_roll > source_lift * 0.35, "transient roll present weapon %d (%.2f deg)" % [id,rad_to_deg(peak_roll)])
		# 3. Recovery: longer than the source rate for the sustained scalar, and a
		#    fast punch that reaches exact zero (no stale residual pose).
		var source_settle: float = 1.0 / float(kick[2])
		check(recoil_zero >= source_settle * 1.15 and recoil_zero <= source_settle * 1.6, "sustained recoil settles longer than source weapon %d (%.3f/%.3f s)" % [id,recoil_zero,source_settle])
		check(punch_zero > 0.03 and punch_zero < 0.4, "transient punch decays to exact zero weapon %d (%.3f s)" % [id,punch_zero])
		# 4. Reduced motion: the rotation channels are cut hard, the shove stays.
		rig.reduced_motion = true
		var reduced_baseline: Transform3D = rig.pivot.transform
		fire(rig, id)
		var reduced_lift := 0.0
		var reduced_roll := 0.0
		var reduced_shove := 0.0
		for step: int in int(ceil(0.6 / STEP)):
			rig.advance(STEP)
			var delta := pose_delta(rig, reduced_baseline)
			reduced_lift = maxf(reduced_lift, absf(delta.x))
			reduced_roll = maxf(reduced_roll, absf(delta.z))
			reduced_shove = maxf(reduced_shove, absf(rig.pivot.position.z - reduced_baseline.origin.z))
		check(reduced_lift <= peak_lift * 0.55, "reduced motion caps lift weapon %d" % id)
		check(reduced_roll <= peak_roll * 0.55, "reduced motion caps roll weapon %d" % id)
		check(reduced_shove > peak_shove * 0.5, "reduced motion keeps the shove weapon %d" % id)
		rig.reduced_motion = false
		settle(rig, 60)
		# 5. Sustained fire at the weapon's own source rate: bounded, never runaway.
		var interval: float = maxf(0.02, float(info.handling.cycle) / 0.88)
		var frames: int = maxi(1, int(round(interval * 60.0)))
		var sustained_shove := 0.0
		var sustained_lift := 0.0
		for burst: int in 40:
			fire(rig, id)
			for frame: int in frames:
				rig.advance(1.0 / 60.0)
				sustained_shove = maxf(sustained_shove, absf(rig.kick_shove))
				sustained_lift = maxf(sustained_lift, absf(rig.kick_lift))
		check(sustained_shove <= peak_shove * 1.6, "sustained shove stays bounded weapon %d" % id)
		check(sustained_lift <= peak_lift * 1.6, "sustained lift stays bounded weapon %d" % id)
		# 6. Settled ADS returns exactly to the pre-shot cheek weld.
		settle(rig, 120)
		rig.apply_aim(true)
		settle(rig, 180)
		var settled: Transform3D = rig.pivot.transform
		fire(rig, id)
		settle(rig, 180)
		check(rig.pivot.transform == settled, "settled ADS is exactly still after recovery weapon %d" % id)
		check(rig.recoil == 0.0 and rig.punch == 0.0, "no residual recoil at settled ADS weapon %d" % id)
		rig.apply_aim(false)
		settle(rig, 10)
		measured.append({
			"weapon":id, "name":info.name,
			"kick_source":[float(kick[0]),float(kick[1]),float(kick[2])],
			"kick_scale":rig.handling.kick_scale,
			"lift_hold":rig.handling.lift_hold,
			"recover_speed":rig.handling.recover_speed,
			"punch_pitch":rig.handling.transient_pitch,
			"punch_roll":rig.handling.transient_roll,
			"punch_back":rig.handling.transient_back,
			"punch_rate":rig.handling.transient_rate,
			"source_shove_m":source_shove, "peak_shove_m":peak_shove,
			"source_lift_deg":rad_to_deg(source_lift), "peak_lift_deg":rad_to_deg(peak_lift),
			"peak_roll_deg":rad_to_deg(peak_roll),
			"recoil_zero_s":recoil_zero, "punch_zero_s":punch_zero,
			"sustained_shove_m":sustained_shove, "sustained_lift_deg":rad_to_deg(sustained_lift),
			"flash_size_m":float(profile.size) * float(profile.flash_scale) * 2.4,
			"flash_life_s":float(profile.life) * float(profile.flash_life),
			"flash_bright":profile.bright,
			"barrel_light":profile.light, "barrel_light_range":profile.light_range,
			"tracer_width_m":profile.tracer_width, "tracer_life_s":profile.tracer_life,
		})
	rig.free()
	camera.free()
	print("FIRST_PERSON_RECOIL ", JSON.stringify({"checks":checks,"failures":failures,"weapons":measured}))
	quit(0 if failures.is_empty() else 1)
