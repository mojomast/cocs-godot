extends Camera3D
## Presentation only. Pose containment is hard; predictive zoom is eased at 60 Hz.
const PoseBounds = preload("res://fighting/presentation/pose_bounds.gd")
const MAX_JUMP := 8.0 # Reduced-motion locked reserve only, never normal neutral.
const TOP_MARGIN := 0.30 # Legacy framing() default; shell supplies measured HUD.
const BOTTOM_MARGIN := 0.12
const CENTER_LIMIT := 4.0 # All four authored crops retain x +/-45m behind +/-8m lane.
const LOOKAHEAD_TICKS := 8.0
const GROW_RATE := 0.18
const SHRINK_RATE := 0.035
const PAN_RATE := 0.12
const HOLD_TICKS := 24
const ZOOM_DEADBAND := 0.08
var reduced_motion := false
var profiles: Dictionary = {}
var rules: Dictionary = {"gravity":9,"stage_half_width":8000}
var poses: Array = []
var _last_tick := -1
var _last_view := Vector2.ZERO
var _last_safe := Vector2.ZERO
var _last_reduced := false
var _frame: Dictionary = {}
var _hold := 0

func configure(roster: Dictionary, match_rules: Dictionary, visuals: Array) -> void:
	profiles.clear()
	for profile: Dictionary in roster.get("operators",[]): profiles[str(profile.id)] = profile
	rules = match_rules.duplicate(true)
	poses.clear()
	for visual: Node3D in visuals:
		var bounds := PoseBounds.new()
		bounds.configure(visual)
		poses.append(bounds)
	reset()

func reset() -> void:
	_frame.clear()
	_last_tick = -1
	_hold = 0

static func apex(velocity: float, gravity: float) -> float:
	# Discrete upper bound including the launch tick; mm/tick -> metres.
	var ticks := ceili(maxf(velocity,0.0)/maxf(gravity,1.0))
	return maxf(0.0,(ticks*velocity-gravity*ticks*(ticks-1)*0.5)/1000.0)

static func fit(envelope: Rect2, aspect: float, safe: Vector2, center_x: float = INF) -> Dictionary:
	var center := clampf(envelope.get_center().x,-CENTER_LIMIT,CENTER_LIMIT) if is_inf(center_x) else clampf(center_x,-CENTER_LIMIT,CENTER_LIMIT)
	var horizontal := 2.0*maxf(center-envelope.position.x,envelope.end.x-center)/maxf(aspect,0.1)
	var height := maxf(envelope.size.y/maxf(1.0-safe.x-safe.y,0.1),horizontal)
	return {"height":height,"center":Vector3(center,envelope.position.y+height*(0.5-safe.y),24.0),"low":envelope.position.y}

static func framing(fighters: Array, aspect: float, locked: bool = false) -> Dictionary:
	# Public stateless compatibility helper used by focused source/native gates.
	var envelope := Rect2(Vector2(-1.6,-0.15),Vector2(3.2,2.75))
	for fighter: Dictionary in fighters:
		var x := float(fighter.get("x",0))/1000.0
		var y := float(fighter.get("y",0))/1000.0
		envelope = envelope.merge(Rect2(Vector2(x-1.6,minf(-0.15,y-0.15)),Vector2(3.2,maxf(y,0.0)+2.75)))
	if locked: envelope = envelope.merge(Rect2(-9.6,-0.15,19.2,MAX_JUMP+2.75))
	return fit(envelope,aspect,Vector2(TOP_MARGIN,BOTTOM_MARGIN))

func envelopes(fighters: Array, projectiles: Array, pose_rects: Array = []) -> Dictionary:
	var actual := Rect2()
	var predicted := Rect2()
	var first := true
	var gravity := maxf(float(rules.get("gravity",9)),1.0)
	var tallest := 0.0
	for i: int in fighters.size():
		var fighter: Dictionary = fighters[i]
		var profile: Dictionary = profiles.get(str(fighter.get("operator_id","")),{})
		var stats: Dictionary = profile.get("stats",{})
		var x := float(fighter.get("x",0))/1000.0
		var y := float(fighter.get("y",0))/1000.0
		var body_height := float(stats.get("height",2000))/1000.0
		var body := Rect2(x-0.6,y,1.2,body_height)
		if i < pose_rects.size() and (pose_rects[i] as Rect2).has_area(): body = body.merge(pose_rects[i])
		tallest = maxf(tallest,body.size.y)
		var safety := body.grow(0.18)
		actual = safety if first else actual.merge(safety)
		var forecast := safety.grow(0.45)
		var velocity := maxf(float(fighter.get("vy",0)),0.0)
		if y <= 0.0 and bool(fighter.get("jump_edge",false)):
			velocity = maxf(velocity,float(stats.get("jump_velocity",0)))
		var move: Dictionary = profile.get("moves",{}).get(str(fighter.get("move_id","")),{})
		var movement: Dictionary = move.get("movement",{})
		if str(movement.get("type","")) in ["super_jump","double_jump"] and int(fighter.get("move_frame",0)) <= int(movement.get("from",0)):
			velocity = maxf(velocity,float(movement.get("vy",0)))
		var rise := apex(velocity,gravity)
		forecast = forecast.expand(Vector2(forecast.end.x,forecast.end.y+rise))
		var dx := float(fighter.get("vx",0))*LOOKAHEAD_TICKS/1000.0
		forecast = forecast.merge(Rect2(forecast.position+Vector2(dx,0),forecast.size))
		predicted = forecast if first else predicted.merge(forecast)
		first = false
	if first: return {"actual":Rect2(-1.6,-0.15,3.2,2.75),"predicted":Rect2(-1.6,-0.15,3.2,2.75)}
	# Floor remains visible even when both fighters jump or enter a paired throw.
	actual = actual.expand(Vector2(actual.get_center().x,-0.18))
	predicted = predicted.expand(Vector2(predicted.get_center().x,-0.30))
	# Comfortable neutral horizontal room derives from the largest real silhouette.
	var center := predicted.get_center().x
	predicted = predicted.expand(Vector2(center-tallest*1.25,predicted.position.y))
	predicted = predicted.expand(Vector2(center+tallest*1.25,predicted.position.y))
	for projectile: Dictionary in projectiles:
		var x := float(projectile.get("x",0))/1000.0
		var y := float(projectile.get("y",0))/1000.0
		var width := float(projectile.get("width",400))/1000.0
		var height := float(projectile.get("height",400))/1000.0
		var box := Rect2(x-width*0.5,y-height*0.5,width,height).grow(0.2)
		actual = actual.merge(box)
		predicted = predicted.merge(box.grow(0.35))
	if reduced_motion:
		var half := float(rules.get("stage_half_width",8000))/1000.0+1.6
		# Fixed lock independent of changing attack-pose height. Actual containment
		# still expands if future content legitimately exceeds this review envelope.
		predicted = predicted.merge(Rect2(-half,-0.3,half*2.0,MAX_JUMP+4.0))
	return {"actual":actual,"predicted":predicted}

func present(fighters: Array, viewport_size: Vector2, snapshot: Dictionary = {}, hud_pixels: Vector2 = Vector2(155,78)) -> void:
	var tick := int(snapshot.get("tick",_last_tick+1))
	var safe := Vector2(clampf((hud_pixels.x+12.0)/maxf(viewport_size.y,1.0),0.12,0.48),clampf((hud_pixels.y+8.0)/maxf(viewport_size.y,1.0),0.08,0.25))
	if tick == _last_tick and viewport_size == _last_view and safe == _last_safe and reduced_motion == _last_reduced: return
	var pose_rects: Array = []
	for bounds in poses: pose_rects.append(bounds.envelope())
	var boxes := envelopes(fighters,snapshot.get("projectiles",[]),pose_rects)
	var aspect := viewport_size.x/maxf(viewport_size.y,1.0)
	var target := fit(boxes.predicted,aspect,safe)
	var discontinuity := _frame.is_empty() or tick < _last_tick or tick-_last_tick > 8 or viewport_size != _last_view or safe != _last_safe or reduced_motion != _last_reduced
	var frozen := not fighters.is_empty()
	for fighter: Dictionary in fighters:
		if int(fighter.get("hitstop",0)) <= 0: frozen = false
	if discontinuity: _frame = target
	elif not frozen:
		for unused: int in maxi(1,tick-_last_tick):
			var wanted := float(target.height)
			var current := float(_frame.height)
			if wanted > current+ZOOM_DEADBAND:
				_frame.height = lerpf(current,wanted,GROW_RATE)
				_hold = HOLD_TICKS
			elif _hold > 0: _hold -= 1
			elif wanted < current-ZOOM_DEADBAND: _frame.height = lerpf(current,wanted,SHRINK_RATE)
			if absf(target.center.x-_frame.center.x) > 0.15: _frame.center.x = lerpf(_frame.center.x,target.center.x,PAN_RATE)
			_frame.low = lerpf(float(_frame.low),float(target.low),SHRINK_RATE)
	# Hard containment overrides easing only if real current bounds require it.
	var required := fit(boxes.actual,aspect,safe,float(_frame.center.x))
	_frame.low = minf(float(_frame.low),float(required.low))
	_frame.height = maxf(float(_frame.height),maxf(float(required.height),(boxes.actual.end.y-float(_frame.low))/(1.0-safe.x-safe.y)))
	_frame.center.y = float(_frame.low)+float(_frame.height)*(0.5-safe.y)
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	size = float(_frame.height)
	position = _frame.center
	rotation = Vector3.ZERO
	near = 0.1
	far = 140.0
	_last_tick = tick
	_last_view = viewport_size
	_last_safe = safe
	_last_reduced = reduced_motion
