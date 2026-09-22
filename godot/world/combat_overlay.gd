extends Control

# Native screen-space feedback. Confirmation comes only from authority events;
# the reticle itself is an aiming aid, not a hit or predicted damage indicator.
#
# Layout policy: hit markers and the reticle own the screen centre, while every
# player-state cue (damage direction, low health, shield break, death,
# materialize) is drawn on an inset screen-edge frame that follows the real
# viewport aspect ratio. No cue is ever drawn inside the frame, and ADS only
# scales cue intensity, so the existing reticle policy is unchanged.
var hit_strength: float = 0.0
var hurt_strength: float = 0.0
var aiming: bool = false
var ads_weight := 0.0
var fx: Dictionary = {}

const EDGE_MARGIN_FRACTION := 0.10
const ARC_HALF_WIDTH := 0.26
const LOW_TINT_MAX := 0.19
const HEARTBEAT_TINT := 0.09
const BREAK_TINT := 0.24
const DEATH_TINT := 0.2
const MATERIALIZE_TINT := 0.16
const TICK_LENGTH := 16.0

func set_ads_weight(value: float) -> void:
	ads_weight = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func update_feedback(active: bool, hit: float, hurt: float, state: Dictionary = {}) -> void:
	aiming = active
	hit_strength = clampf(hit / 0.2, 0.0, 1.0)
	hurt_strength = clampf(hurt / 0.35, 0.0, 1.0)
	fx = state if state is Dictionary else {}
	visible = aiming or hit_strength > 0.0 or hurt_strength > 0.0 or fx_active()
	queue_redraw()

func fx_active() -> bool:
	return bool(fx.get("direction", false)) or strength("low_health") > 0.0 or strength("heartbeat") > 0.0 \
		or strength("break") > 0.0 or strength("death") > 0.0 or strength("materialize") > 0.0

func strength(key: String) -> float:
	var value: Variant = fx.get(key, 0.0)
	if not (value is int or value is float): return 0.0
	var numeric := float(value)
	return clampf(numeric, 0.0, 1.0) if is_finite(numeric) else 0.0

static func edge_direction(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle)) if is_finite(angle) else Vector2.UP

## Screen-edge frame point for a bearing: the ray from the centre in that
## direction intersected with the inset viewport frame. Always outside the
## sight picture, whatever the viewport aspect ratio.
static func frame_point(half: Vector2, angle: float) -> Vector2:
	var direction := edge_direction(angle)
	var distance := INF
	if absf(direction.x) > 0.0001: distance = minf(distance, absf(half.x / direction.x))
	if absf(direction.y) > 0.0001: distance = minf(distance, absf(half.y / direction.y))
	if not is_finite(distance): return Vector2.ZERO
	return direction * distance

func _frame_half() -> Vector2:
	var margin := minf(size.x, size.y) * EDGE_MARGIN_FRACTION
	return Vector2(maxf(24.0, size.x * 0.5 - margin), maxf(24.0, size.y * 0.5 - margin))

func _draw() -> void:
	var center := size * 0.5
	var half := _frame_half()
	var ads_scale := 1.0 - 0.35 * ads_weight
	_draw_low_health(center, half)
	_draw_death(center, half)
	_draw_materialize(center, half)
	_draw_damage_direction(center, half, ads_scale)
	_draw_break(center, half, ads_scale)
	if hurt_strength > 0:
		# Keep the sight line clear: a brief edge pulse, never a full-screen flash.
		for step in range(6):
			var inset := float(step * 5)
			var tint := Color(0.9, 0.12, 0.08, hurt_strength * 0.16 * (1.0 - step / 6.0))
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2.ONE * inset * 2), tint, false, 5.0)
	if aiming and ads_weight < 0.98:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var start := center + direction * 5.0
			var end := center + direction * 11.0
			draw_line(start, end, Color(0.02, 0.04, 0.05, 0.9 * (1.0-ads_weight)), 4.0)
			draw_line(start, end, Color(0.86, 0.96, 1.0, 0.95 * (1.0-ads_weight)), 2.0)
	if hit_strength > 0:
		for direction: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
			var start := center + direction * 8.0
			var end := center + direction * 14.0
			draw_line(start, end, Color(0.02, 0.04, 0.05, hit_strength), 5.0)
			draw_line(start, end, Color(1.0, 0.87, 0.36, hit_strength), 3.0)

func _stroke_frame(center: Vector2, half: Vector2, color: Color, width: float) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for index in range(4):
		var from: Vector2 = center + corners[index] * half
		var to: Vector2 = center + corners[(index + 1) % 4] * half
		draw_line(from, to, color, width)

func _draw_low_health(center: Vector2, half: Vector2) -> void:
	var level := strength("low_health")
	var pulse := strength("heartbeat")
	if level <= 0.0 and pulse <= 0.0: return
	var tint := LOW_TINT_MAX * level + HEARTBEAT_TINT * pulse
	for step in range(4):
		var inset := Vector2(step * 6, step * 6)
		var alpha := tint * (1.0 - step / 4.0)
		_stroke_frame(center, half - inset, Color(0.72, 0.05, 0.04, alpha), 7.0)

func _draw_death(center: Vector2, half: Vector2) -> void:
	var level := strength("death")
	if level <= 0.0: return
	for step in range(4):
		var inset := Vector2(step * 7, step * 7)
		var alpha := DEATH_TINT * level * (1.0 - step / 4.0)
		_stroke_frame(center, half - inset, Color(0.34, 0.015, 0.02, alpha), 8.0)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p := center + Vector2(half.x * direction.x, half.y * direction.y)
		draw_line(p, p - direction * 18.0, Color(0.85, 0.12, 0.08, 0.4 * level), 4.0)

func _draw_materialize(center: Vector2, half: Vector2) -> void:
	var level := strength("materialize")
	if level <= 0.0: return
	var progress := 1.0 - level
	var expand := lerpf(-8.0, 26.0, progress)
	_stroke_frame(center, half + Vector2(expand, expand), Color(0.55, 0.92, 1.0, MATERIALIZE_TINT * level), 3.0)
	_stroke_frame(center, half + Vector2(expand + 8.0, expand + 8.0), Color(0.75, 0.98, 1.0, MATERIALIZE_TINT * 0.55 * level), 1.0)

func _draw_damage_direction(center: Vector2, half: Vector2, ads_scale: float) -> void:
	var level := strength("direction")
	if level <= 0.0: return
	if not bool(fx.get("direction_known", false)):
		# Environmental/unknown source: a neutral frame pulse, no invented bearing.
		if bool(fx.get("direction_environment", true)):
			_stroke_frame(center, half, Color(1.0, 0.32, 0.16, 0.14 * level * ads_scale), 6.0)
		return
	var angle: Variant = fx.get("direction_angle", 0.0)
	if not (angle is int or angle is float) or not is_finite(float(angle)): return
	var bearing := float(angle)
	var backing := Color(0.05, 0.01, 0.0, 0.55 * level * ads_scale)
	var color := Color(1.0, 0.42, 0.2, 0.66 * level * ads_scale)
	var from: Vector2 = center + frame_point(half, bearing - ARC_HALF_WIDTH)
	var to: Vector2 = center + frame_point(half, bearing + ARC_HALF_WIDTH)
	draw_line(from, to, backing, 14.0)
	draw_line(from, to, color, 7.0)
	# Inward tick so the segment reads as a direction, not a border.
	var at: Vector2 = center + frame_point(half, bearing)
	draw_line(at, at - edge_direction(bearing) * TICK_LENGTH, color, 5.0)

func _draw_break(center: Vector2, half: Vector2, ads_scale: float) -> void:
	var level := strength("break")
	if level <= 0.0: return
	var color := Color(0.66, 0.9, 1.0, BREAK_TINT * level * ads_scale)
	_stroke_frame(center, half, color, 3.0)
	_stroke_frame(center, half - Vector2(5, 5), Color(0.72, 0.55, 1.0, BREAK_TINT * 0.5 * level * ads_scale), 1.0)
	for step in range(6):
		var angle := TAU * float(step) / 6.0
		var at: Vector2 = center + frame_point(half, angle)
		draw_line(at, at - edge_direction(angle) * (TICK_LENGTH * 0.8), color, 4.0)
