extends SceneTree
const Numbers = preload("res://world/damage_numbers.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	assert(ok, message)
	if not ok: quit(1)

func _initialize() -> void:
	call_deferred("run")

func event(id: int, amount: Variant = 12.25, victim: int = 2, source: Variant = 1) -> Dictionary:
	return {"id":id, "type":"damage", "actor":victim, "source":source, "amount":amount}

func count(fx: Control) -> int:
	var total := 0
	for slot: Dictionary in fx.slots:
		if slot.active: total += 1
	return total

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var fx := Numbers.new()
	root.add_child(fx)
	fx.configure(camera, func(_from: Vector3, _to: Vector3) -> bool: return false)
	var actors := [{"id":2, "x":0.0, "y":0.0, "z":-8.0}]
	fx.consume([event(1), event(1)], 1, actors)
	check(count(fx) == 1 and fx.slots[0].amount == 12.25, "event value only; repeated ID contributes once")
	fx.advance(0.08)
	fx.consume([event(2, 0.25)], 1, actors)
	check(fx.slots[0].amount == 12.5 and Numbers.display_amount(fx.slots[0].amount) == "13", "fractional burst sums before deterministic half-up rounding")
	check(Numbers.display_amount(0.125) == "<1", "tiny damage never reads zero")
	actors[0].x = 1.5
	check(fx.slots[0].anchor == Vector3(0, 1, -8), "received anchor stays frozen when target moves")
	fx.advance(0.03)
	fx.consume([event(3)], 1, actors)
	check(count(fx) == 2, "fixed 100ms grouping cannot grow into unreadable perpetual burst")
	fx.consume([event(4, 14, 1, null), event(5, 999, 3, 4)], 1, actors)
	check(count(fx) == 3 and fx.slots[2].incoming, "environmental local hurt admitted, enemy-versus-enemy excluded")
	fx.clear_transient()
	fx.consume([event(1)], 1, actors)
	check(count(fx) == 0, "focus suspension drains without replaying IDs")
	for value: Variant in [NAN, INF, -1, 0, "12", null, true, 1000000001.0]:
		fx.consume([event(fx.highest+1, value)], 1, actors)
	check(count(fx) == 0, "malformed and unbounded source amounts rejected")
	fx.configure(camera, func(_from: Vector3, _to: Vector3) -> bool: return true)
	fx.consume([event(30)], 1, actors)
	check(count(fx) == 0, "occluded authority damage never draws through a wall")
	fx.configure(camera, func(_from: Vector3, _to: Vector3) -> bool: return false)
	actors[0].z = 8.0
	fx.consume([event(31)], 1, actors)
	check(count(fx) == 0, "behind-camera damage excluded")
	actors[0].z = -8.0
	actors[0].x = 100.0
	fx.consume([event(32)], 1, actors)
	check(count(fx) == 0, "outside-frustum damage never becomes a screen-edge tracker")
	actors[0].x = 0.0
	fx.apply_state([{"id":1, "health":0}], 1)
	fx.consume([event(33, 2, 1)], 1, actors)
	check(count(fx) == 0, "dead local actor drains and suppresses both lanes")
	fx.clear_round()
	fx.consume([event(1)], 1, actors)
	check(count(fx) == 1, "new epoch accepts reset IDs")
	fx.clear_round()
	for index in 80:
		var item := event(index, 1, index+2)
		item.pos = {"x":0.0,"y":0.0,"z":-8.0}
		fx.consume([item], 1, [])
	check(count(fx) == Numbers.CAP and fx.get_child_count() == 0, "burst is bounded to reusable draw slots without per-hit nodes")
	fx.advance(0.66)
	check(count(fx) == 0 and fx.slots.size() == Numbers.CAP, "expiration retains fixed pool")
	fx.consume([event(5000)], 1, actors)
	fx.consume([event(1)], 1, actors)
	check(fx.seen.size() == 1 and count(fx) == 1, "dedup storage bounded; stale IDs cannot replay")
	for viewport: Vector2 in [Vector2(760, 520)/1.5, Vector2(1280, 800)]:
		var occupied: Array[Rect2] = []
		var extent := fx.font.get_string_size("84", HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var outgoing := Numbers.layout_bounds(viewport*0.5+Vector2(extent.x*0.7+58, -32), extent, viewport, occupied)
		check(outgoing.has_area(), "center target readable at compact 150% and wide 100%")
		occupied.append(outgoing)
		extent = fx.font.get_string_size("−19", HORIZONTAL_ALIGNMENT_LEFT, -1, 29)
		var incoming := Numbers.layout_bounds(Vector2(viewport.x*0.28, viewport.y*0.65), extent, viewport, occupied)
		check(incoming.has_area() and not incoming.intersects(outgoing), "incoming lane fits compact/wide without colliding with outgoing")
		check(not Numbers.layout_bounds(Vector2(-100, -100), extent, viewport, occupied).has_area(), "offscreen targets never become edge trackers")
	print("DAMAGE_NUMBERS_OK checks=", checks)
	quit(0)
