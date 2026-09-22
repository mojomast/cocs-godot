extends Control

# Native screen-space feedback. Confirmation comes only from authority events;
# the reticle itself is an aiming aid, not a hit or predicted damage indicator.
var hit_strength: float = 0.0
var hurt_strength: float = 0.0
var aiming: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func update_feedback(active: bool, hit: float, hurt: float) -> void:
	aiming = active
	hit_strength = clampf(hit / 0.2, 0.0, 1.0)
	hurt_strength = clampf(hurt / 0.35, 0.0, 1.0)
	visible = aiming or hit_strength > 0 or hurt_strength > 0
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	if hurt_strength > 0:
		# Keep the sight line clear: a brief edge pulse, never a full-screen flash.
		for step in range(6):
			var inset := float(step * 5)
			var tint := Color(0.9, 0.12, 0.08, hurt_strength * 0.16 * (1.0 - step / 6.0))
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2.ONE * inset * 2), tint, false, 5.0)
	if aiming:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var start := center + direction * 5.0
			var end := center + direction * 11.0
			draw_line(start, end, Color(0.02, 0.04, 0.05, 0.9), 4.0)
			draw_line(start, end, Color(0.86, 0.96, 1.0, 0.95), 2.0)
	if hit_strength > 0:
		for direction: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
			var start := center + direction * 8.0
			var end := center + direction * 14.0
			draw_line(start, end, Color(0.02, 0.04, 0.05, hit_strength), 5.0)
			draw_line(start, end, Color(1.0, 0.87, 0.36, hit_strength), 3.0)
