extends SceneTree
const Guidance = preload("res://horde/mission_guidance.gd")
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok: failed += 1; push_error(message)
func _initialize() -> void:
	var mission := {"wave":1,"active":"south-feeder","completed":[],"stations":[
		{"id":"north-feeder","x":0,"z":0,"available":true,"progress":0,"required":5},
		{"id":"south-feeder","x":10,"z":0,"available":true,"progress":2,"required":5},
		{"id":"switch-pump","x":20,"z":0,"available":false,"progress":0,"required":12}]}
	var before := JSON.stringify(mission)
	var view := Guidance.project(mission,{"stageId":"A","gateMask":0},{"x":0,"z":0})
	check(view.priority.id=="south-feeder","active repair takes priority over closer available feeder")
	check("Return within 6.5m" in view.instruction,"out-of-range active repair explains paused progress")
	check(view.rows[2].status=="LOCKED" and view.rows[2].reason=="restore both feeders","dependency lock is distinct")
	check(JSON.stringify(mission)==before,"projection does not mutate source state")
	mission.active = null
	view = Guidance.project(mission,{"stageId":"B","gateMask":1},{"x":0,"z":0})
	check(view.priority.id=="north-feeder" and "E TO ARM" in view.instruction,"nearest available station has local interaction prompt")
	check("WEST OPEN" in view.route and "EAST CLOSED" in view.route,"gate mask is rendered independently of stage")
	check(Guidance.lock_reason("switch-pump",["north-feeder","south-feeder"],3)=="wave 4","wave lock survives completed prerequisites")
	check(Guidance.lock_reason("relief-valve",["switch-pump"],6)=="wave 7","valve wave lock")
	mission.completed = ["north-feeder","south-feeder","switch-pump","relief-valve"]
	view = Guidance.project(mission,{"stageId":"C","gateMask":3},{"x":0,"z":0})
	check(view.priority.is_empty() and "finish the waves" in view.instruction,"station chain is not victory")
	print("HORDE_GUIDANCE_TEST ",JSON.stringify({"failed":failed}))
	quit(1 if failed else 0)
