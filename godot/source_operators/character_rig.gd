extends RefCounted
## Native port of characterPose/CharacterRig in game/character-anim.mjs.
## Rigid Node3D joints, with Three's XYZ order and source pitch-axis convention.
## Source transform fixtures test the actual imported hierarchy, not a mock rig.

var joints: Dictionary = {}
var bind: Dictionary = {}
var phase: float = 0.0
var channels: Dictionary = {}
var last_grounded: bool = true
var dead: bool = false

func configure(nodes: Dictionary) -> void:
	joints = nodes
	bind.clear()
	for key: String in joints:
		bind[key] = joints[key].transform
	reset()

func reset() -> void:
	for key: String in bind:
		joints[key].transform = bind[key]
	phase = 0.0
	channels = {"speedNorm":0.0,"crouch":0.0,"ads":0.0,"strafe":0.0,"forward":0.0,"bank":0.0,"accel":0.0,"lateral":0.0,"hit":0.0,"land":0.0,"landRoll":0.0,"reload":0.0,"slide":0.0}
	last_grounded = true
	dead = false

static func damp(a: float, b: float, rate: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-rate * dt))

func update(state: Dictionary) -> void:
	if dead: return
	var dt: float = clampf(float(state.get("dt", 0.0)), 0.0, 0.1)
	var previous_speed: float = channels.speedNorm
	var previous_strafe: float = channels.strafe
	var speed: float = clampf(float(state.get("speed", 0.0)) / maxf(0.001, float(state.get("maxSpeed", 8.0))), 0.0, 1.0)
	channels.speedNorm = damp(channels.speedNorm, speed, 8.0, dt)
	for key: String in ["crouch", "ads"]:
		channels[key] = damp(channels[key], 1.0 if state.get(key, false) else 0.0, 10.0, dt)
	for key: String in ["strafe", "forward", "bank"]:
		channels[key] = damp(channels[key], clampf(float(state.get(key, 0.0)), -1.0, 1.0), 6.0 if key == "bank" else 8.0, dt)
	var rates: float = 1.0 / dt if dt > 0.0001 else 0.0
	channels.accel = damp(channels.accel, clampf((channels.speedNorm - previous_speed) * rates / 6.0, -1.0, 1.0), 5.0, dt)
	channels.lateral = damp(channels.lateral, clampf((channels.strafe - previous_strafe) * rates / 6.0, -1.0, 1.0), 5.0, dt)
	channels.hit = maxf(maxf(0.0, channels.hit - dt * 4.0), clampf(float(state.get("hit", 0.0)), 0.0, 1.0))
	var grounded: bool = state.get("grounded", true)
	if not last_grounded and grounded:
		channels.land = 1.0
		channels.landRoll = clampf(-channels.strafe, -1.0, 1.0)
	last_grounded = grounded
	channels.land = maxf(maxf(0.0, channels.land - dt * 5.5), float(state.get("land", 0.0)))
	channels.landRoll = damp(channels.landRoll, 0.0, 3.4 if channels.landRoll >= 0.0 else 6.2, dt)
	channels.reload = damp(channels.reload, clampf(float(state.get("reload", 0.0)), 0.0, 1.0), 8.0, dt)
	channels.slide = damp(channels.slide, 1.0 if state.get("sliding", false) else float(state.get("slide", 0.0)), 7.0, dt)
	if grounded: phase = fposmod(phase + lerpf(1.35, 3.4, channels.speedNorm) * TAU * dt, TAU)
	var inputs: Dictionary = channels.duplicate()
	inputs.merge({"phase":phase,"grounded":grounded,"contactGait":true,"time":state.get("time",0.0),"focusYaw":state.get("focusYaw",0.0),"focusPitch":state.get("focusPitch",0.0),"reduced":state.get("reduced",false)}, true)
	apply_pose(solve(inputs))

static func solve(s: Dictionary) -> Dictionary:
	var speed: float = clampf(float(s.get("speedNorm",0.0)),0.0,1.0)
	var crouch: float = clampf(float(s.get("crouch",0.0)),0.0,1.0)
	var ads: float = clampf(float(s.get("ads",0.0)),0.0,1.0)
	var strafe: float = clampf(float(s.get("strafe",0.0)),-1.0,1.0)
	var forward: float = clampf(float(s.get("forward",0.0)),-1.0,1.0)
	var time: float = float(s.get("time",0.0))
	var hit: float = clampf(float(s.get("hit",0.0)),0.0,1.0)
	var gait_phase: float = float(s.get("phase",0.0))
	var swing: float = sin(gait_phase)
	var p: Dictionary = {"rootY":0.0,"hips":Vector3.ZERO,"torso":Vector3(0.04,0,0),"chest":Vector3.ZERO,"head":Vector3.ZERO,"armL":Vector3(0.05,0.12,-0.35),"armR":Vector3(0.05,-0.12,-0.35),"legL":Vector3(0,0.08,0.04),"legR":Vector3(0,0.08,0.04)}
	if not s.get("grounded",true):
		p.legL = Vector3(-0.55,0.95,0.15); p.legR = Vector3(-0.32,0.6,0.2)
		p.armL = Vector3(-0.5,0.5,-0.6); p.armR = Vector3(-0.5,-0.5,-0.6)
		p.torso.x = 0.12; p.rootY = 0.02
	else:
		var stride: float = speed * (0.34 + 0.52 * speed)
		p.legL = Vector3(swing*stride,0.1+maxf(0,-swing)*(0.35+0.7*speed)*speed,-swing*stride*0.35)
		p.legR = Vector3(-swing*stride,0.1+maxf(0,swing)*(0.35+0.7*speed)*speed,swing*stride*0.35)
		var arm_swing: float = speed*(0.28+0.5*speed)*(1.0-ads*0.75)
		p.armL.x = -swing*arm_swing; p.armR.x = swing*arm_swing
		p.armL.z = -0.3-maxf(0,swing)*0.35*speed; p.armR.z = -0.3-maxf(0,-swing)*0.35*speed
		p.rootY = -absf(swing)*0.045*speed+(1.0-speed)*sin(time*1.6)*0.008
		p.torso.x = 0.05+0.16*speed+forward*0.05+(maxf(0,speed-0.6)*0.1)
		p.torso.z = -strafe*0.12*(0.4+speed)
		p.hips.z = strafe*0.05; p.hips.y = swing*0.08*speed
		p.chest.x = (1.0-speed)*sin(time*2.0)*0.012
		p.head.x = p.chest.x*0.4
	if crouch > 0:
		p.rootY -= crouch*0.34
		for key: String in ["legL","legR"]:
			p[key].y = lerpf(p[key].y,1.05,crouch); p[key].x = lerpf(p[key].x,-0.7,crouch)
		p.torso.x = lerpf(p.torso.x,0.34,crouch)
		p.armL.z -= crouch*0.25; p.armR.z -= crouch*0.25
	if ads > 0:
		for key: String in ["armL","armR"]:
			p[key].x = lerpf(p[key].x,-0.95,ads); p[key].z = lerpf(p[key].z,-0.55,ads)
		p.armL.y = lerpf(p.armL.y,0.22,ads); p.armR.y = lerpf(p.armR.y,-0.22,ads)
		p.chest.x = lerpf(p.chest.x,-0.06,ads)
	var bank: float = clampf(float(s.get("bank",0.0)),-1,1)
	p.torso.z += bank*0.16; p.hips.z += bank*0.08; p.chest.y -= bank*0.08
	p.legL.y = clampf(p.legL.y+strafe*0.06*speed,-1.25,1.25)
	p.legR.y = clampf(p.legR.y-strafe*0.06*speed,-1.25,1.25)
	p.head.z = clampf(strafe*0.04-bank*0.05,-0.5,0.5)
	var accel: float = clampf(float(s.get("accel",0.0)),-1,1)
	p.torso.x = clampf(p.torso.x+accel*0.12,-1.25,1.25); p.hips.x = clampf(p.hips.x-accel*0.05,-1.25,1.25)
	var lateral: float = clampf(float(s.get("lateral",0.0)),-1,1)
	p.torso.z = clampf(p.torso.z-lateral*0.16,-1.25,1.25); p.hips.z = clampf(p.hips.z+lateral*0.07,-1.25,1.25)
	p.chest.y = clampf(p.chest.y-lateral*0.05,-1.25,1.25)
	var land: float = clampf(float(s.get("land",0.0)),0,1)
	p.rootY -= land*0.12
	for key: String in ["legL","legR"]: p[key].y = clampf(p[key].y+land*0.22,-1.25,1.25)
	p.torso.x = clampf(p.torso.x+land*0.08,-1.25,1.25)
	p.armL.y = clampf(p.armL.y+land*0.12,-1.25,1.25); p.armR.y = clampf(p.armR.y-land*0.12,-1.25,1.25)
	var land_roll: float = clampf(float(s.get("landRoll",0.0)),-1,1)
	p.torso.z = clampf(p.torso.z+land_roll*0.14,-1.25,1.25); p.hips.z = clampf(p.hips.z+land_roll*0.08,-1.25,1.25)
	p.chest.y = clampf(p.chest.y-land_roll*0.05,-1.25,1.25)
	var slide: float = clampf(float(s.get("slide",0.0)),0,1)
	if slide > 0:
		p.rootY -= slide*0.18; p.torso.x = clampf(p.torso.x-slide*0.24,-1.25,1.25)
		p.legL.x = lerpf(p.legL.x,0.6,slide); p.legL.y = lerpf(p.legL.y,0.3,slide)
		p.legR.x = lerpf(p.legR.x,-0.15,slide); p.legR.y = lerpf(p.legR.y,0.7,slide)
		p.armL.x = lerpf(p.armL.x,-0.7,slide); p.armR.x = lerpf(p.armR.x,-0.7,slide)
	var reload_amount: float = clampf(float(s.get("reload",0.0)),0,1)
	if reload_amount > 0:
		p.armL.x = lerpf(p.armL.x,-0.65,reload_amount); p.armL.z = lerpf(p.armL.z,-1.05,reload_amount)
		p.armL.y = lerpf(p.armL.y,0.18,reload_amount)
		p.armR.x = lerpf(p.armR.x,-0.75,reload_amount); p.armR.z = lerpf(p.armR.z,-0.85,reload_amount)
		p.chest.x = clampf(p.chest.x+reload_amount*0.05,-1.25,1.25)
	var yaw: float = clampf(float(s.get("focusYaw",0.0)),-0.9,0.9)
	p.head.y = yaw*0.65; p.chest.y = yaw*0.2-bank*0.08; p.torso.y = yaw*0.12
	p.head.x = clampf(float(s.get("focusPitch",0.0)),-0.6,0.6)*0.6-p.torso.x*0.35
	p.chest.x -= hit*0.22; p.head.x -= hit*0.3; p.torso.z += hit*0.12
	p.armL.x -= hit*0.4; p.armR.x -= hit*0.25
	if s.get("grounded",true) and s.get("contactGait",true):
		var motion: float = 0.0 if s.get("reduced",false) else speed
		p.rootY = -0.012-motion*0.025-crouch*0.06-land*0.02-slide*0.12
		p.hips = Vector3.ZERO
		for i: int in range(2):
			var angle: float = gait_phase + i*PI
			var lift: float = maxf(0,sin(angle))*0.05*motion*(1.0-crouch*0.6)*(1.0-land*0.5)
			var z: float = cos(angle)*0.15*motion*(-1.0 if forward < -0.05 else 1.0)*(1.0-crouch*0.5)
			var height: float = 0.69+p.rootY-lift
			var distance: float = clampf(Vector2(height,z).length(),0.011,0.6899)
			var bend: float = acos(clampf((0.34*0.34+distance*distance-0.35*0.35)/(2.0*0.34*distance),-1,1))
			var hip: float = atan2(z,height)-bend
			var knee: float = PI-acos(clampf((0.34*0.34+0.35*0.35-distance*distance)/(2.0*0.34*0.35),-1,1))
			p["legL" if i == 0 else "legR"] = Vector3(hip,knee,-hip-knee)
	for key: String in ["hips","torso","chest","head","armL","armR","legL","legR"]:
		p[key] = p[key].clamp(Vector3.ONE*-1.25,Vector3.ONE*1.25)
	p.secondary = {} if s.get("reduced",false) else s.get("secondary",{})
	return p

static func xyz_quaternion(v: Vector3) -> Quaternion:
	var c: Vector3 = Vector3(cos(v.x*0.5),cos(v.y*0.5),cos(v.z*0.5))
	var s: Vector3 = Vector3(sin(v.x*0.5),sin(v.y*0.5),sin(v.z*0.5))
	return Quaternion(s.x*c.y*c.z+c.x*s.y*s.z,c.x*s.y*c.z-s.x*c.y*s.z,c.x*c.y*s.z+s.x*s.y*c.z,c.x*c.y*c.z-s.x*s.y*s.z)

func rotate_joint(key: String, angles: Vector3) -> void:
	if joints.has(key): joints[key].quaternion = xyz_quaternion(Vector3(-angles.x,angles.y,angles.z))

func apply_pose(p: Dictionary) -> void:
	var sec: Dictionary = p.get("secondary",{})
	joints.root.position.y = p.rootY
	for key: String in ["hips","torso"]: rotate_joint(key,p[key])
	rotate_joint("chest",p.chest+Vector3(0,sec.get("chestYaw",0),sec.get("chestRoll",0)))
	rotate_joint("head",p.head+Vector3(sec.get("headPitch",0),sec.get("headYaw",0),0))
	for side: String in ["L","R"]:
		var arm: Vector3 = p["arm"+side]
		var leg: Vector3 = p["leg"+side]
		rotate_joint("armUpper"+side,Vector3(arm.x,0,arm.y))
		rotate_joint("forearm"+side,Vector3(arm.z,0,0))
		rotate_joint("hand"+side,Vector3.ZERO)
		rotate_joint("legUpper"+side,Vector3(leg.x,0,0))
		rotate_joint("legLower"+side,Vector3(leg.y,0,0))
		rotate_joint("foot"+side,Vector3(leg.z,0,0))

func apply_source_death(source: Dictionary) -> void:
	# Source-sampled deterministic splay; world corpse trajectory stays host-owned.
	var p: Dictionary = source.duplicate(true)
	for key: String in ["hips","torso","chest","head"]:
		p[key] = Vector3(p[key].x,p[key].y,p[key].z)
	for side: String in ["L","R"]:
		var a: Dictionary = p["arm"+side]
		var l: Dictionary = p["leg"+side]
		p["arm"+side] = Vector3(a.shoulderX,a.shoulderZ,a.elbowX)
		p["leg"+side] = Vector3(l.hipX,l.kneeX,l.ankleX)
	dead = true
	apply_pose(p)
