extends RefCounted
## Authored world-leg overlay. Shared acceptance/timing, never FPS root offsets.
const KickMotion = preload("res://first_person/kick_motion.gd")
const Motion = preload("res://source_operators/motion_math.gd")
const Rig = preload("res://source_operators/character_rig.gd")
var sequence := KickMotion.new()
var sample_clock := -1.0
var clock_active := false

func accept(event: Dictionary) -> bool:
	var accepted := sequence.accept(event)
	if accepted: clock_active = true
	return accepted

func advance(dt: float) -> void:
	if sample_clock < 0:
		sequence.advance(dt)
	elif clock_active:
		sequence.age = clampf(sample_clock-sequence.last_time,0.0,KickMotion.DURATION)
		if sequence.age >= KickMotion.DURATION: clock_active = false

func interrupt() -> void:
	sequence.interrupt()
	clock_active = false

func reset_epoch() -> void:
	sequence.reset()
	sample_clock = -1.0
	clock_active = false

func side() -> String:
	return ("R" if sequence.step == 1 else "L") if sequence.age < KickMotion.DURATION else ""

func apply(rig: RefCounted, locomotion: RefCounted, grounded: bool, reduced: bool) -> void:
	var kicking := side()
	if kicking.is_empty(): return
	var support := "R" if kicking == "L" else "L"
	var pose: Dictionary = sequence.sample(reduced)
	var blend := smoothstep(0.0,0.045,sequence.age)*(1.0-smoothstep(0.20,KickMotion.DURATION,sequence.age))
	var quiet := 0.35 if reduced else 1.0
	var weight: float = pose.weight*quiet
	var sign := 1.0 if support == "R" else -1.0
	# Cosmetic pelvis shift over the support leg, braced torso counterrotation.
	# The authoritative wrapper/root-world and camera are never moved.
	rig.joints.root.position.x += sign*weight*0.025*(1.0 if grounded else 0.35)
	rig.joints.root.position.y -= weight*0.018
	rig.joints.hips.quaternion *= Quaternion(Vector3.UP,-sign*weight*0.07)
	rig.joints.torso.quaternion *= Quaternion(Vector3.RIGHT,-weight*0.07)
	rig.joints.chest.quaternion *= Quaternion(Vector3.UP,sign*weight*0.06)
	# Imported thigh/shin axes are DOWN. Positive Godot hip X chambers forward;
	# negative knee X folds the shin behind it. Do not use source pitch negation.
	var upper: Node3D = rig.joints["legUpper"+kicking]
	var lower: Node3D = rig.joints["legLower"+kicking]
	var foot: Node3D = rig.joints["foot"+kicking]
	upper.quaternion = upper.quaternion.slerp(Rig.xyz_quaternion(pose.hip),blend)
	lower.quaternion = lower.quaternion.slerp(Rig.xyz_quaternion(pose.knee),blend)
	foot.quaternion = foot.quaternion.slerp(Rig.xyz_quaternion(pose.ankle),blend)
	var contact: Dictionary = locomotion.contacts.get(support,{})
	# Correct only an already confirmed planted support. Running flight and air
	# retain their source supporting-leg pose; no fabricated support is introduced.
	if grounded and contact.get("supported",false) and contact.get("planted",false):
		var support_upper: Node3D = rig.joints["legUpper"+support]
		var support_lower: Node3D = rig.joints["legLower"+support]
		var support_foot: Node3D = rig.joints["foot"+support]
		var parent: Node3D = support_upper.get_parent()
		var frame: Node3D = rig.joints.root.get_parent()
		var anatomy: Dictionary = rig.anatomy[support]
		var target: Vector3 = contact.target
		var local := parent.to_local(target)-support_upper.position
		var pole := parent.global_basis.inverse()*(frame.global_basis*Vector3.FORWARD)
		var rotations := Motion.two_link(anatomy.upper,anatomy.lower,local,pole)
		support_upper.quaternion = rotations[0]
		support_lower.quaternion = rotations[1]
		var orientation: Quaternion = locomotion.feet[support].orientation
		support_foot.quaternion = support_lower.global_basis.get_rotation_quaternion().inverse()*orientation
	for leg: String in [kicking,support]:
		if not locomotion.contacts.has(leg): continue
		var sample: Dictionary = locomotion.contacts[leg]
		sample.ankle = rig.joints["foot"+leg].global_position
		sample.knee = rig.joints["legLower"+leg].global_position
		sample.hip = rig.joints["legUpper"+leg].global_position
		sample.error = (sample.ankle as Vector3).distance_to(sample.target)
		sample.meleeActive = leg == kicking
