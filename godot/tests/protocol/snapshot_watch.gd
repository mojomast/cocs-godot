extends SceneTree
const Watch = preload("res://net/snapshot_watch.gd")
var checks := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		push_error("Watch assertion " + str(checks))
		quit(1)
		assert(ok)
func _initialize() -> void:
	var watch := Watch.new()
	check(watch.stale())
	watch.observe()
	check(not watch.stale() and watch.message().is_empty())
	watch.advance(0.99)
	check(not watch.stale())
	watch.advance(0.02)
	check(watch.stale() and "neutral" in watch.message())
	watch.advance(NAN)
	watch.advance(-4)
	check(is_equal_approx(watch.age, 1.01))
	watch.advance(100000)
	check(watch.age == 3600.0)
	watch.observe()
	check(not watch.stale() and watch.age == 0)
	watch.reset()
	check(watch.stale() and not watch.received)
	print("PORT_SNAPSHOT_WATCH_OK checks=", checks, " synthetic_clock=true")
	quit(0)
