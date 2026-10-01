extends RefCounted
const Motion = preload("res://source_operators/motion_math.gd")
## Presentation-only directional gait and critically damped landing response.
## Source pose solver remains available unchanged for provenance fixtures.
var distance_phase := 0.0
var landing := 0.0
var landing_velocity := 0.0
var previous_grounded := true
var previous_velocity := Vector2.ZERO
var lean := Vector2.ZERO
var previous_vertical_speed := 0.0
var grounded_weight := 1.0
var grounded_velocity := 0.0
var lean_velocity := Vector2.ZERO
var travel_angle := 0.0
var floor_offsets := Vector2.ZERO
var root_height := 0.0
var root_velocity := 0.0

func reset() -> void:
	distance_phase = 0.0
	landing = 0.0
	landing_velocity = 0.0
	previous_grounded = true
	previous_velocity = Vector2.ZERO
	lean = Vector2.ZERO
	previous_vertical_speed = 0.0
	grounded_weight = 1.0; grounded_velocity = 0.0; lean_velocity = Vector2.ZERO; travel_angle = 0.0
	floor_offsets = Vector2.ZERO
	root_height = 0.0; root_velocity = 0.0

func apply(rig: RefCounted, state: Dictionary, actor: Dictionary, dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0: return
	var grounded: bool = state.grounded
	var velocity := Vector2(float(actor.get("vx",0)),float(actor.get("vz",0)))
	if actor.get("vehicleId") != null: velocity = Vector2.ZERO
	var speed := velocity.length()
	var reduced: bool = state.get("reduced",false)
	var crouch: float = rig.channels.crouch
	var yaw: float = float(actor.get("bodyYaw",actor.get("yaw",0)))
	var right := Vector2(cos(yaw),-sin(yaw))
	var forward := Vector2(-sin(yaw),-cos(yaw))
	var direction := velocity/speed if speed > 0.01 else Vector2.ZERO
	var lateral: float = direction.dot(right)
	var longitudinal: float = direction.dot(forward)
	if grounded and speed > 0.08:
		distance_phase = fposmod(distance_phase + speed*dt*TAU/(1.05-crouch*0.35),TAU)
	if not previous_grounded and grounded:
		landing_velocity -= clampf(absf(previous_vertical_speed)*0.32,0.45,2.4)
	previous_grounded = grounded
	previous_vertical_speed = float(actor.get("vy",0))
	# A stable analytic spring: no overshoot explosion after a paused frame.
	var decay := exp(-12.0*dt)
	var spring: float = landing_velocity+12.0*landing
	landing = (landing+spring*dt)*decay
	landing_velocity = (landing_velocity-12.0*spring*dt)*decay
	# A velocity change is an impulse, not a frame-rate-dependent acceleration goal.
	lean_velocity += Vector2((velocity-previous_velocity).dot(right)*0.045,(velocity-previous_velocity).dot(forward)*0.035)
	previous_velocity = velocity
	for i in 2:
		var response := Motion.spring(lean[i], lean_velocity[i], 0.0, 9.0, dt)
		lean[i] = clampf(response.x, -0.06, 0.06); lean_velocity[i] = response.y
	var ground := Motion.spring(grounded_weight,grounded_velocity,1.0 if grounded else 0.0,22.0,dt)
	grounded_weight = ground.x; grounded_velocity = ground.y
	if reduced: return
	var inputs: Dictionary = rig.channels.duplicate()
	inputs.merge({"phase":distance_phase,"grounded":grounded,"contactGait":true,"time":state.time,"focusYaw":state.focusYaw,"focusPitch":state.focusPitch},true)
	var pose: Dictionary = rig.solve(inputs)
	pose.rootY -= crouch*0.24
	pose.rootY += clampf(landing,-0.14,0.05)
	var root_response := Motion.spring(root_height,root_velocity,pose.rootY,24.0,dt)
	root_height = root_response.x; root_velocity = root_response.y
	pose.rootY = root_height
	if grounded_weight > 0.001:
		var motion: float = rig.channels.speedNorm
		for i in 2:
			var phase := distance_phase+i*PI
			var step := Motion.contact(phase,1.05-crouch*0.35,0.075)*motion
			var lift := step.y*(1.0-crouch*0.5)
			var reach := step.x*(-1.0 if longitudinal < -0.05 else 1.0)
			var height: float = 0.69+pose.rootY-lift-floor_offsets[i]
			var distance := clampf(Vector2(height,reach).length(),0.03,0.6899)
			var bend := acos(clampf((0.34*0.34+distance*distance-0.35*0.35)/(2.0*0.34*distance),-1,1))
			var hip := atan2(reach,height)-bend
			var knee := PI-acos(clampf((0.34*0.34+0.35*0.35-distance*distance)/(2.0*0.34*0.35),-1,1))
			var key := "legL" if i==0 else "legR"
			# Airborne entry/landing preserve current chain rather than snapping.
			var airborne := Vector3(-0.55,0.95,0.15) if i==0 else Vector3(-0.32,0.6,0.2)
			pose[key] = airborne.lerp(Vector3(hip,knee,-hip-knee),grounded_weight)
	pose.torso.z -= lean.x
	pose.torso.x += lean.y
	rig.apply_pose(pose)
	if grounded_weight > 0.001:
		var weight: float = clampf(rig.channels.speedNorm*2.0,0.0,1.0)*(1.0-crouch*0.4)*grounded_weight
		# Rotate the complete hip/knee/ankle chain into the travel plane. Side
		# steps now plant laterally and backward steps reverse their foot cycle.
		var target_angle := atan2(lateral,longitudinal)
		# Keep backwards knees facing forward rather than rotating legs 180°.
		if absf(target_angle) > PI*0.5: target_angle = wrapf(target_angle+PI,-PI,PI)
		if grounded and speed > 0.08: travel_angle = lerp_angle(travel_angle,target_angle,1.0-exp(-12.0*dt))
		for side: String in ["L","R"]:
			var leg: Node3D = rig.joints["legUpper"+side]
			leg.quaternion = Quaternion(Vector3.UP,travel_angle*weight)*leg.quaternion
		# Counter-rotation lends the chest weight without swinging the weapon
		# off target. The hand-grip pass runs after this layer.
		var chest: Node3D = rig.joints.chest
		chest.rotate_y(sin(distance_phase)*0.035*weight*(1.0-rig.channels.ads))
