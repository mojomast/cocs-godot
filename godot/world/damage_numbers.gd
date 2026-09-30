extends Control
## Passive authority-event typography. Actor positions are frozen at receipt;
## visibility is rechecked against map geometry, never tracked through a wall.
const CAP := 16
const LIFE := 0.65
const GROUP_SECONDS := 0.10
const WINDOW := 4096
var camera: Camera3D
var blocked: Callable
var slots: Array[Dictionary] = []
var seen: Dictionary = {}
var highest := -1
var reduced_motion := false
var low := false
var alive := true
var clock := 0.0
var font: Font = ThemeDB.fallback_font

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bold := FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 0.8
	font = bold
	for index in CAP: slots.append({"active":false})

func configure(view: Camera3D, visibility_query: Callable) -> void:
	camera = view
	blocked = visibility_query

func set_quality(level: int) -> void:
	low = level == 0

func apply_state(actors: Array, local_id: int) -> void:
	for actor: Variant in actors:
		if actor is Dictionary and identity(actor.get("id")) == local_id:
			alive = numeric(actor.get("health")) and float(actor.health) > 0.0
			if not alive: clear_transient()
			return

static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func identity(value: Variant) -> int:
	if not numeric(value) or float(value) < 0 or float(value) > 9007199254740991.0 or float(value) != floor(float(value)): return -1
	return int(value)

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for axis in ["x", "y", "z"]:
		if not numeric(value.get(axis)) or absf(float(value[axis])) > 1000000.0: return null
	return Vector3(value.x, value.y, value.z)

static func display_amount(amount: float) -> String:
	# Round once after summing fractional authority values. Tiny positive damage
	# stays meaningful; neither the stored total nor authority is rounded.
	return "<1" if amount < 0.5 else str(int(floor(amount + 0.5)))

func consume(events: Array, local_id: int, actors: Array) -> void:
	for value: Variant in events.slice(0, 512):
		if not value is Dictionary: continue
		var event: Dictionary = value
		var id := identity(event.get("id"))
		if id < 0 or id <= highest-WINDOW or seen.has(id): continue
		highest = maxi(highest, id)
		seen[id] = true
		if event.get("type") != "damage" or not alive or local_id < 0: continue
		var victim := identity(event.get("actor"))
		var incoming := victim == local_id
		if victim < 0 or (not incoming and identity(event.get("source")) != local_id): continue
		var amount: Variant = event.get("amount")
		if not numeric(amount) or float(amount) <= 0.0 or float(amount) > 1000000000.0: continue
		var anchor: Variant = point(event.get("pos"))
		if not incoming and anchor == null:
			for actor: Variant in actors:
				if actor is Dictionary and identity(actor.get("id")) == victim:
					anchor = point(actor)
					if anchor != null: anchor += Vector3.UP
					break
		if not incoming and (anchor == null or not world_visible(anchor)): continue
		var grouped := false
		for slot: Dictionary in slots:
			if slot.active and slot.victim == victim and slot.incoming == incoming and clock-float(slot.born) <= GROUP_SECONDS:
				slot.amount += float(amount)
				grouped = true
				break
		if grouped: continue
		var selected := -1
		for index in CAP:
			if not slots[index].active:
				selected = index
				break
		if selected < 0: continue # Bounded draw slots: preserve existing readable hits.
		slots[selected] = {"active":true, "victim":victim, "incoming":incoming,
			"amount":float(amount), "anchor":anchor, "born":clock, "seed":id % 7}
	for id: int in seen.keys():
		if id <= highest-WINDOW: seen.erase(id)
	queue_redraw()

func world_visible(anchor: Vector3) -> bool:
	return is_instance_valid(camera) and not camera.is_position_behind(anchor) \
		and camera.is_position_in_frustum(anchor) \
		and camera.global_position.distance_to(anchor) < 90.0 and blocked.is_valid() \
		and not blocked.call(camera.global_position, anchor)

func clear_transient() -> void:
	for slot: Dictionary in slots: slot.active = false
	queue_redraw()

func clear_round() -> void:
	clear_transient()
	seen.clear()
	highest = -1
	clock = 0.0
	alive = true

func advance(delta: float) -> void:
	if not numeric(delta) or delta < 0: return
	clock += delta
	for slot: Dictionary in slots:
		if slot.active and clock-float(slot.born) >= LIFE: slot.active = false
	queue_redraw()

static func layout_bounds(origin: Vector2, extent: Vector2, viewport: Vector2, occupied: Array[Rect2]) -> Rect2:
	var safe := Rect2(Vector2(28, viewport.y*0.23), Vector2(viewport.x-56, viewport.y*0.53))
	var crosshair := Rect2(viewport*0.5-Vector2(30, 26), Vector2(60, 52))
	var bounds := Rect2(origin-extent*0.7-Vector2(8, 10), extent*1.4+Vector2(16, 20))
	for attempt in 5:
		var collision := bounds.intersects(crosshair)
		for prior: Rect2 in occupied: collision = collision or bounds.intersects(prior)
		if not collision: break
		bounds.position.y -= bounds.size.y+3
	if not safe.encloses(bounds) or bounds.intersects(crosshair): return Rect2()
	for prior: Rect2 in occupied:
		if bounds.intersects(prior): return Rect2()
	return bounds

func _draw() -> void:
	var viewport := get_viewport_rect().size
	var quiet := low or reduced_motion
	var occupied: Array[Rect2] = []
	# Logical viewport units already inherit LocalSettings.content_scale_factor.
	for slot: Dictionary in slots:
		if not slot.active: continue
		var age := clock-float(slot.born)
		var t := clampf(age/LIFE, 0.0, 1.0)
		var incoming: bool = slot.incoming
		if not incoming and not world_visible(slot.anchor):
			slot.active = false
			continue
		var weight := clampf(log(1.0+float(slot.amount))/log(101.0), 0.0, 1.0)
		var text := ("−" if incoming else "") + display_amount(slot.amount)
		var pixels := int(lerpf(23.0, 32.0, weight))
		var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels)
		var origin := Vector2(viewport.x*0.28, viewport.y*0.65) if incoming else camera.unproject_position(slot.anchor)+Vector2(extent.x*0.7+58, -32)
		var side := -1.0 if int(slot.seed)%2 == 0 else 1.0
		if not quiet: origin += Vector2(side*18.0*t, -sin(t*PI)*15.0-12.0*t)
		# Reserve the whole overshoot footprint; stack instead of covering digits.
		var bounds := layout_bounds(origin, extent, viewport, occupied)
		if not bounds.has_area(): continue
		occupied.append(bounds)
		origin = bounds.get_center()
		var pop := 1.0 if quiet else (1.0+0.24*sin(minf(age/0.16, 1.0)*PI))
		var stretch := Vector2(pop, 1.0/pop) if age < 0.16 else Vector2.ONE
		var angle := 0.0 if quiet else side*0.095*sin(t*PI)
		var alpha := 1.0-smoothstep(0.65, 1.0, t)
		var color := Color("ff9970") if incoming else Color("fff1bc").lerp(Color("ffd46a"), weight)
		color.a = alpha
		draw_set_transform(origin, angle, stretch)
		if not quiet and age < 0.22:
			for ray in 5:
				var direction := Vector2.from_angle(float(ray)*TAU/5.0+float(slot.seed))
				var start := direction*(extent.x*0.52+8.0+age*30.0)
				draw_line(start, start+direction*(5.0+weight*5.0)*(1.0-age/0.22), Color(color, alpha*(1.0-age/0.22)), 2.0, true)
		var baseline := Vector2(-extent.x*0.5, (font.get_ascent(pixels)-font.get_descent(pixels))*0.5)
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 6, Color(0.06, 0.035, 0.025, alpha))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)
		draw_set_transform(Vector2.ZERO)
