extends RefCounted
## Direct native port of game/rig.mjs placeLimb + alignLivingCharacter hand pass.
## Applied after CharacterRig, gun aim/recoil, and source weapon replacement.

static func align(nodes: Dictionary, weapon: Node3D, diagnostics: Dictionary = {}) -> Dictionary:
	var errors: Dictionary = {}
	var orientation: Quaternion = weapon.global_basis.get_rotation_quaternion()
	for side: String in ["L","R"]:
		var hand: Node3D = nodes["hand"+side]
		var grip: Node3D = nodes["grip"+side]
		var contact: Node3D = weapon.find_child("WeaponGripLeft" if side == "L" else "WeaponGripRight",true,false)
		if contact == null: continue
		var target: Vector3 = contact.global_position
		var wrist: Vector3 = target - orientation * (grip.position * hand.global_basis.get_scale())
		var clamp: Dictionary = {}
		place_limb(nodes["armUpper"+side],nodes["forearm"+side],hand,wrist,orientation,Vector3(-1 if side == "L" else 1,-0.4,0.25),clamp)
		diagnostics["clamped"+side] = float(clamp.get("clamped",0.0))
		errors[side] = grip.global_position.distance_to(target)
	return errors

static func place_limb(upper: Node3D, lower: Node3D, end: Node3D, target: Vector3, orientation: Quaternion, pole: Vector3, diagnostics: Dictionary = {}) -> bool:
	var parent: Node3D = upper.get_parent()
	var local: Vector3 = parent.to_local(target) - upper.position
	var a: float = lower.get_parent().position.length()
	var b: float = end.position.length()
	var distance: float = local.length()
	if not is_finite(distance) or a <= 0 or b <= 0: return false
	var direction: Vector3 = local.normalized() if distance >= 0.00000001 else Vector3.DOWN
	var reach: float = clampf(distance,absf(a-b)+0.00001,a+b-0.00001)
	# Source contract: an unreachable contact keeps the wrist at maximum reach and
	# the reported residual equals this clamp; no faked solution is applied.
	diagnostics["clamped"] = maxf(0.0,distance-(a+b-0.00001))
	var along: float = (a*a+reach*reach-b*b)/(2.0*reach)
	var bend: Vector3 = pole-direction*pole.dot(direction)
	if bend.length_squared() < 0.00000001: bend = Vector3(0,0,1)-direction*direction.z
	bend = bend.normalized()*sqrt(maxf(0,a*a-along*along))
	var elbow: Vector3 = direction*along+bend
	upper.quaternion = Quaternion(Vector3.DOWN,elbow.normalized())
	var lower_direction: Vector3 = (direction*reach-elbow).normalized()
	var lower_q: Quaternion = Quaternion(Vector3.DOWN,lower_direction)
	lower.quaternion = upper.quaternion.inverse()*lower_q
	end.quaternion = lower.global_basis.get_rotation_quaternion().inverse()*orientation
	return true
