extends RefCounted
## One presentation gait owner. Never changes actor/root-world transforms.
const Motion = preload("res://source_operators/motion_math.gd")
const Ground = preload("res://source_operators/ground_contact.gd")
var distance_phase := 0.0
var landing := 0.0
var landing_velocity := 0.0
var previous_grounded := true
var previous_velocity := Vector2.ZERO
var previous_vertical_speed := 0.0
var lean := Vector2.ZERO
var lean_velocity := Vector2.ZERO
var grounded_weight := 1.0
var grounded_velocity := 0.0
var root_height := 0.0
var root_velocity := 0.0
var floor_offsets := Vector2.ZERO
var initialized := false
var previous_yaw := 0.0
var turn := 0.0
var turn_velocity := 0.0
var travel_angle := 0.0
var stop_age := 0.0
var feet: Dictionary = {}
var contacts: Dictionary = {}

func reset() -> void:
	distance_phase = 0.0
	landing = 0.0; landing_velocity = 0.0
	previous_grounded = true; previous_vertical_speed = 0.0
	previous_velocity = Vector2.ZERO
	lean = Vector2.ZERO; lean_velocity = Vector2.ZERO
	grounded_weight = 1.0; grounded_velocity = 0.0
	root_height = 0.0; root_velocity = 0.0
	floor_offsets = Vector2.ZERO
	initialized = false; previous_yaw = 0.0
	turn = 0.0; turn_velocity = 0.0; travel_angle = 0.0
	stop_age = 0.0
	feet.clear(); contacts.clear()

func apply(rig: RefCounted, state: Dictionary, actor: Dictionary, dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0: return
	var frame: Node3D = rig.joints.root.get_parent()
	var grounded: bool = state.grounded
	var mounted: bool = actor.get("vehicleId") != null
	var velocity: Vector2 = state.get("travelVelocity",Vector2(float(actor.get("vx",0)),float(actor.get("vz",0))))
	if mounted: velocity = Vector2.ZERO
	var speed := velocity.length()
	var reduced: bool = state.get("reduced",false)
	var crouch: float = rig.channels.crouch
	var slide: float = rig.channels.slide
	var yaw: float = frame.global_rotation.y
	var yaw_delta := wrapf(yaw-previous_yaw,-PI,PI) if initialized else 0.0
	if not initialized:
		previous_velocity = velocity
		previous_grounded = grounded
		grounded_weight = 1.0 if grounded else 0.0
		initialized = true
	previous_yaw = yaw
	var right := Vector2(cos(yaw),-sin(yaw))
	var forward := Vector2(-sin(yaw),-cos(yaw))
	var local_velocity := Vector2(velocity.dot(right),velocity.dot(forward))
	var direction := local_velocity.normalized() if speed > 0.01 else Vector2(0,1)
	travel_angle = atan2(direction.x,direction.y)
	var length: float = minf(rig.anatomy.L.length,rig.anatomy.R.length)
	var gait := Motion.gait(speed,crouch,length)
	var distance: float = state.get("travelDistance",speed*dt)
	var turning := grounded and speed < 0.15 and absf(yaw_delta) > 0.0001 and not mounted
	stop_age = stop_age+dt if grounded and speed < 0.15 and not turning else 0.0
	if grounded and not mounted:
		# No speedNorm multiplication on horizontal stride. During stance,
		# d(foot along travel)/dt == -distance/dt, exactly.
		distance_phase = fposmod(distance_phase+maxf(0,distance)*TAU/gait.x,TAU)
		if turning: distance_phase = fposmod(distance_phase+absf(yaw_delta)*2.4,TAU)
	if not previous_grounded and grounded:
		landing_velocity -= clampf(maxf(0,-previous_vertical_speed)*0.32,0.25,2.4)
	previous_grounded = grounded
	previous_vertical_speed = float(actor.get("vy",0))
	var response := Motion.spring(landing,landing_velocity,0.0,12.0,dt)
	landing = response.x; landing_velocity = response.y
	lean_velocity += Vector2((velocity-previous_velocity).dot(right)*0.075,(velocity-previous_velocity).dot(forward)*0.065)
	previous_velocity = velocity
	for i in 2:
		response = Motion.spring(lean[i],lean_velocity[i],0.0,9.0,dt)
		lean[i] = clampf(response.x,-0.09,0.09); lean_velocity[i] = response.y
	turn_velocity -= yaw_delta*5.0
	response = Motion.spring(turn,turn_velocity,0.0,10.0,dt)
	turn = clampf(response.x,-0.16,0.16); turn_velocity = response.y
	response = Motion.spring(grounded_weight,grounded_velocity,1.0 if grounded else 0.0,22.0,dt)
	grounded_weight = response.x; grounded_velocity = response.y
	var motion := Motion.smooth(speed/0.45)
	var running := Motion.smooth((speed-1.8)/4.5)
	var activity := maxf(motion,clampf(absf(turn)*6.0,0,1)) if not mounted else 0.0
	var steps: Array[Vector2] = []
	var reach := 0.0
	for i in 2:
		var step := Motion.stride_contact(distance_phase+i*PI,gait.x,gait.z,gait.y)
		# Only the rest transition blends horizontal reach. Above 0.45 m/s the
		# complete measured stride is used, independent of gameplay maxSpeed.
		step.x *= motion
		step.y *= activity
		steps.append(step)
		reach = maxf(reach,absf(step.x))
	var inputs: Dictionary = rig.channels.duplicate()
	inputs.merge({"phase":distance_phase,"grounded":grounded,"contactGait":false,"time":state.time,"focusYaw":state.focusYaw,"focusPitch":state.focusPitch,"reduced":reduced},true)
	# Landing compression is owned here, not counted twice by source channels.
	inputs.land = 0.0
	var pose: Dictionary = rig.solve(inputs)
	var secondary := 0.0 if reduced or mounted else 1.0
	var variation: float = state.get("motionVariant",0.0)
	var breath := sin(float(state.time)*(1.65+variation*0.12)+variation*TAU)
	# At quarter-cycle the left foot supports while the right swings: -X is L.
	var weight := -sin(distance_phase-0.35)*activity*grounded_weight
	# Reserve extension margin across the WHOLE stride, not a delayed response
	# to this frame's foot reach. Fast sprint cadence otherwise outruns the root
	# spring and visibly straightens/clamps the knee at each contact.
	reach = maxf(reach,gait.x*gait.y*0.5*motion)
	var compression := length-sqrt(maxf(0.01,pow(length*0.98,2)-reach*reach))
	var target_height := -compression-crouch*0.24+clampf(landing,-0.14,0.03)
	target_height -= absf(sin(distance_phase))*0.012*activity*secondary
	target_height -= slide*0.12
	if not grounded: target_height = 0.015
	response = Motion.spring(root_height,root_velocity,target_height,28.0,dt)
	root_height = response.x; root_velocity = response.y
	pose.rootY = root_height
	pose.hips = Vector3(-lean.y*0.3,weight*0.075+turn*0.45,-weight*0.032+lean.x*0.35)*secondary
	pose.torso.x = (0.045+motion*0.055+running*0.10+crouch*0.18+lean.y+maxf(0,-landing)*0.6)*secondary
	pose.torso.z = (-lean.x-weight*0.025)*secondary
	pose.torso.y += (-weight*0.04+turn*0.4)*secondary
	pose.chest.y += (-weight*0.055-turn*0.65)*(1.0-rig.channels.ads*0.65)*secondary
	pose.chest.x += breath*0.009*(1.0-motion)*secondary
	pose.head.z += weight*0.018*secondary
	pose.head.x -= maxf(0,-landing)*0.25*secondary
	pose.torso.x -= slide*0.20
	rig.apply_pose(pose)
	# Shift the pelvis over the support foot. IK below compensates the full
	# hip/torso hierarchy; knee flexion is measured from authored link vectors.
	rig.joints.root.position.x = rig.bind.root.origin.x+weight*0.014*secondary
	contacts.clear()
	for i in 2:
		var side := "L" if i==0 else "R"
		var anatomy: Dictionary = rig.anatomy[side]
		var rest: Vector3 = anatomy.ankle
		var step := steps[i]
		var local_target := rest+Vector3(direction.x*step.x,step.y,-direction.y*step.x)
		var foot_state: Dictionary = feet.get(side,{"locked":false,"target":rest,"point":Vector3.ZERO,"collider":0,"orientation":Quaternion.IDENTITY,"settling":false,"settleAge":0.0,"settleFrom":rest,"releaseOffset":Vector3.ZERO,"releaseVelocity":Vector3.ZERO})
		var was_locked: bool = foot_state.locked
		if speed < 0.15 and not turning:
			local_target = (foot_state.target as Vector3).lerp(rest,1.0-exp(-18.0*dt))
		foot_state.target = local_target
		var target := frame.to_global(local_target)
		var stance := fposmod((distance_phase+i*PI)/TAU,1.0)<gait.y
		if speed < 0.15 and not turning: stance = true
		# Finish a stop with alternating small recovery steps. Keeping both old
		# world pins forever strands the actor in a split stance after braking.
		if stop_age > 0.10+i*0.24 and foot_state.locked and not foot_state.settling:
			var rest_world := frame.to_global(rest)
			var pin: Vector3 = foot_state.point
			if Vector2(pin.x-rest_world.x,pin.z-rest_world.z).length() > 0.035:
				foot_state.settling = true
				foot_state.settleAge = 0.0
				foot_state.settleFrom = frame.to_local(pin)
		if stop_age == 0.0: foot_state.settling = false
		if foot_state.settling:
			foot_state.settleAge += dt
			var settle := clampf(float(foot_state.settleAge)/0.22,0,1)
			local_target = (foot_state.settleFrom as Vector3).lerp(rest,Motion.smooth(settle))
			local_target.y += sin(settle*PI)*0.045
			target = frame.to_global(local_target)
			stance = settle >= 1.0
			foot_state.locked = false
			foot_state.settling = not stance
			foot_state.target = local_target
		var hit: Dictionary = {}
		if grounded and not mounted:
			var query_point: Vector3 = foot_state.point if foot_state.locked else target
			hit = Ground.sample(frame,query_point,frame.global_position.y)
		var valid := not hit.is_empty()
		var sole := frame.global_basis.get_rotation_quaternion()
		if valid: sole = Quaternion(Vector3.UP,hit.normal)*sole
		if not grounded or not stance or not valid or mounted or slide > 0.1: foot_state.locked = false
		if valid:
			floor_offsets[i] = lerpf(floor_offsets[i],float(hit.offset),1.0-exp(-18.0*dt))
			target.y += floor_offsets[i]
			if foot_state.locked and foot_state.collider != hit.collider: foot_state.locked = false
			if stance and not foot_state.locked and slide <= 0.1 and (foot_state.releaseOffset as Vector3).length() < 0.015:
				foot_state.point = (hit.position as Vector3)+(hit.normal as Vector3)*rest.y
				foot_state.collider = hit.collider
				foot_state.orientation = sole
				foot_state.locked = true
		else:
			floor_offsets[i] = lerpf(floor_offsets[i],0.0,1.0-exp(-18.0*dt))
		if foot_state.locked:
			target = foot_state.point
			sole = foot_state.orientation
		var upper: Node3D = rig.joints["legUpper"+side]
		var lower: Node3D = rig.joints["legLower"+side]
		var foot: Node3D = rig.joints["foot"+side]
		var parent: Node3D = upper.get_parent()
		var local := parent.to_local(target)-upper.position
		var residual := maxf(0,local.length()-float(anatomy.length)+0.001)
		# Large ledges, root corrections and over-extension release contact,
		# rather than dragging the visual root or stretching a skeleton link.
		if residual > 0.012:
			foot_state.locked = false
			target = frame.to_global(local_target+Vector3(0,floor_offsets[i],0))
			local = parent.to_local(target)-upper.position
		if was_locked and not foot_state.locked:
			foot_state.releaseOffset = (foot_state.point as Vector3)-target
			foot_state.releaseVelocity = Vector3.ZERO
		if foot_state.locked:
			foot_state.releaseOffset = Vector3.ZERO
			foot_state.releaseVelocity = Vector3.ZERO
		else:
			# Inertialize unlock corrections, never low-pass a planted world pin.
			for axis in 3:
				var release := Motion.spring(foot_state.releaseOffset[axis],foot_state.releaseVelocity[axis],0.0,28.0,dt)
				foot_state.releaseOffset[axis] = release.x
				foot_state.releaseVelocity[axis] = release.y
			target += foot_state.releaseOffset
			local = parent.to_local(target)-upper.position
		residual = maxf(0,local.length()-float(anatomy.length)+0.001)
		var pole := parent.global_basis.inverse()*(frame.global_basis*Vector3(0,0,-1))
		var rotations := Motion.two_link(anatomy.upper,anatomy.lower,local,pole)
		# Air uses the source tucked-leg pose, never a walking sine cycle.
		# Extension anticipates impact only when descending over a real surface.
		var ik_weight := grounded_weight*(1.0-slide)
		if not grounded and previous_vertical_speed < -0.1:
			var approach := Ground.sample(frame,target,frame.global_position.y,0.25)
			if not approach.is_empty(): ik_weight = maxf(ik_weight,clampf(1.0-absf(float(approach.offset))/0.25,0,0.65))
		upper.quaternion = upper.quaternion.slerp(rotations[0],ik_weight)
		lower.quaternion = lower.quaternion.slerp(rotations[1],ik_weight)
		var ankle := lower.global_basis.get_rotation_quaternion().inverse()*sole
		foot.quaternion = foot.quaternion.slerp(ankle,ik_weight)
		contacts[side] = {"supported":valid,"planted":foot_state.locked,"stance":stance,"target":target,"error":foot.global_position.distance_to(target),"reachClamp":residual,"ankle":foot.global_position,"knee":lower.global_position,"hip":upper.global_position}
		feet[side] = foot_state
