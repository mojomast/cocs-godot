extends SceneTree
const Route = preload("res://campaign/smoke_route.gd")

func _initialize() -> void:
	var route := Route.new()
	# A right-angle turn followed by a leg returning close to the spawn. A
	# nearest-waypoint shortcut would incorrectly skip the first two legs.
	var recipe := {"campaign":{"criticalPath":[{"x":0,"y":0,"z":0},
		{"x":0,"y":0,"z":-10}, {"x":10,"y":0,"z":-10}, {"x":1,"y":0,"z":0}]}}
	assert(route.configure(recipe, 0))
	var controls := route.sample(Vector3.ZERO, 0)
	assert(route.index == 1 and is_equal_approx(controls.x, 0) and is_equal_approx(controls.z, -1), "authored first leg beats a nearby later vertex")
	assert(controls.fire and is_equal_approx(controls.yaw, 0), "real fire and forward look retained")
	controls = route.sample(Vector3(0, 0, -5), 1)
	assert(route.index == 1 and controls.z == -1, "mid-leg observation cannot advance route")
	controls = route.sample(Vector3(0, 0, -10), 2)
	assert(route.index == 2 and is_equal_approx(controls.x, 1) and is_equal_approx(controls.z, 0), "guidance turns at authored corner")
	assert(is_equal_approx(controls.yaw, -PI / 2), "look follows the turn")
	controls = route.sample(Vector3(10, 0, -10), 3)
	assert(route.index == 3 and controls.x < 0 and controls.z > 0, "return leg remains ordered")
	assert(is_equal_approx(Vector2(controls.x, controls.z).length(), 1), "diagonal movement stays normal source speed")
	controls = route.sample(Vector3(1, 0, 0), 4)
	assert(route.index == 4 and controls.x == 0 and controls.z == 0 and controls.fire, "route end stops movement while awaiting public evidence")
	# Use authoritative feet height: being underneath an elevated vertex is not
	# arrival. A blocked source actor must fail rather than jump/teleport ahead.
	assert(route.configure({"campaign":{"criticalPath":[{"x":0,"y":4,"z":0},{"x":10,"y":4,"z":0}]}}, 0))
	route.sample(Vector3.ZERO, 0)
	assert(route.index == 0)
	route.sample(Vector3.ZERO, Route.BLOCKED_SECONDS - 0.01)
	assert(route.error.is_empty())
	route.sample(Vector3.ZERO, Route.BLOCKED_SECONDS)
	assert(route.error.contains("blocked") and route.index == 0, "no-progress timeout cannot fabricate movement")
	assert(route.configure(recipe, 30), "fresh chapter/retry resets failed guidance")
	route.sample(Vector3.ZERO, 30)
	route.sample(Vector3(0, 0, -2), 40)
	route.sample(Vector3(0, 0, -4), 50)
	assert(route.error.is_empty(), "genuine authoritative progress refreshes blocked watchdog")
	assert(not route.configure({}, 0), "no fallback route is invented")
	assert(not route.configure({"campaign":{"criticalPath":[{"x":0,"y":0,"z":0},{"x":1,"z":1}]}}, 0), "feet coordinates required")
	print("CAMPAIGN_SMOKE_ROUTE_OK")
	quit()
