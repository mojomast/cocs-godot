extends RefCounted
## Presentation-only directional gait and critically damped landing response.
## Source pose solver remains available unchanged for provenance fixtures.
var distance_phase := 0.0
var landing := 0.0
var landing_velocity := 0.0
var previous_grounded := true
var previous_velocity := Vector2.ZERO
var lean := Vector2.ZERO
var previous_vertical_speed := 0.0

func reset() -> void:
	distance_phase = 0.0
	landing = 0.0
	landing_velocity = 0.0
	previous_grounded = true
	previous_velocity = Vector2.ZERO
	lean = Vector2.ZERO
	previous_vertical_speed = 0.0

func apply(rig: RefCounted, state: Dictionary, actor: Dictionary, dt: float) -> void:
	dt = clampf(dt,0.0,0.05)
	if dt <= 0.0: return
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
		distance_phase = fposmod(distance_phase + speed*dt*TAU/(2.35-crouch*0.75),TAU)
	if not previous_grounded and grounded:
		landing_velocity -= clampf(absf(previous_vertical_speed)*0.32,0.45,2.4)
	previous_grounded = grounded
	previous_vertical_speed = float(actor.get("vy",0))
	# A stable analytic spring: no overshoot explosion after a paused frame.
	var decay := exp(-12.0*dt)
	var spring: float = landing_velocity+12.0*landing
	landing = (landing+spring*dt)*decay
	landing_velocity = (landing_velocity-12.0*spring*dt)*decay
	var acceleration := (velocity-previous_velocity)/dt
	previous_velocity = velocity
	var target := Vector2(clampf(acceleration.dot(right)*0.008,-0.13,0.13),clampf(acceleration.dot(forward)*0.006,-0.10,0.10))
	lean = lean.lerp(target,1.0-exp(-8.0*dt))
	if reduced: return
	var inputs: Dictionary = rig.channels.duplicate()
	inputs.merge({"phase":distance_phase,"grounded":grounded,"contactGait":true,"time":state.time,"focusYaw":state.focusYaw,"focusPitch":state.focusPitch},true)
	var pose: Dictionary = rig.solve(inputs)
	pose.rootY -= crouch*0.24
	pose.rootY += clampf(landing,-0.14,0.05)
	if grounded:
		var motion := clampf(speed/8.0,0.0,1.0)
		for i in 2:
			var phase := distance_phase+i*PI
			var lift := maxf(0,sin(phase))*0.055*motion*(1.0-crouch*0.5)
			var reach := cos(phase)*0.18*motion*(1.0-crouch*0.45)*(-1.0 if longitudinal < -0.05 else 1.0)
			var height: float = 0.69+pose.rootY-lift
			var distance := clampf(Vector2(height,reach).length(),0.03,0.6899)
			var bend := acos(clampf((0.34*0.34+distance*distance-0.35*0.35)/(2.0*0.34*distance),-1,1))
			var hip := atan2(reach,height)-bend
			var knee := PI-acos(clampf((0.34*0.34+0.35*0.35-distance*distance)/(2.0*0.34*0.35),-1,1))
			pose["legL" if i==0 else "legR"] = Vector3(hip,knee,-hip-knee)
	pose.torso.z -= lean.x
	pose.torso.x += lean.y
	rig.apply_pose(pose)
	if grounded:
		var weight := clampf(speed/4.0,0.0,1.0)*(1.0-crouch*0.4)
		# Rotate the complete hip/knee/ankle chain into the travel plane. Side
		# steps now plant laterally and backward steps reverse their foot cycle.
		var travel_angle := atan2(lateral,longitudinal)
		# Keep backwards knees facing forward rather than rotating legs 180°.
		if absf(travel_angle) > PI*0.5: travel_angle = wrapf(travel_angle+PI,-PI,PI)
		for side: String in ["L","R"]:
			var leg: Node3D = rig.joints["legUpper"+side]
			leg.quaternion = Quaternion(Vector3.UP,travel_angle*weight)*leg.quaternion
		# Counter-rotation lends the chest weight without swinging the weapon
		# off target. The hand-grip pass runs after this layer.
		var chest: Node3D = rig.joints.chest
		chest.rotate_y(sin(distance_phase)*0.035*weight*(1.0-rig.channels.ads))
