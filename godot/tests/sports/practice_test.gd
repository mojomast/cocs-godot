extends SceneTree
const Practice = preload("res://sports/practice.gd")
const HUD = preload("res://sports/hud.gd")
var checks := 0

func check(ok: bool) -> void:
	checks += 1
	assert(ok)

func _initialize() -> void:
	check(Practice.option_error([]).is_empty())
	check(Practice.option_error(["--map=aurora-stadium", "--round-target=1"]).is_empty())
	for arg in ["--practice", "--practice=true", "--practice=0", "--practice=garbage"]:
		check(Practice.option_error([arg]).contains("fills soccer to four"))
	check(Practice.describe({}, {}).is_empty())
	var pitch := {"minZ":-24.0,"maxZ":24.0}
	for side in [-1, 1]:
		var target := {"team":0 if side == 1 else 1,"ball":{"x":0.0,"z":0.0},"opponent":{"x":44.0*side,"z":0.0},"own":{"x":-44.0*side,"z":0.0},"vehicle":{"x":-8.0*side,"z":0.0,"yaw":PI/2*side}}
		var before := JSON.stringify(target)
		check(Practice.describe(target, pitch).contains("Aligned"))
		check(JSON.stringify(target) == before)
		target.vehicle.x = 8.0*side
		check(Practice.describe(target, pitch).contains("Circle behind"))
		target.vehicle.x = -8.0*side
		target.vehicle.z = 5.0
		check(Practice.describe(target, pitch).contains("Line up"))
		target.vehicle.z = 0.0
		target.vehicle.yaw = 0.0
		check(Practice.describe(target, pitch).contains("Brake and turn"))
		target.ball.z = 22.0
		check(Practice.describe(target, pitch).contains("side board"))
	var hud := HUD.new()
	hud.update({"mode":"puma-soccer","phase":"results","state":{},"soccer_guidance":{}})
	check(not hud.text.contains("Shot practice"))
	hud.update({"mode":"puma-soccer","phase":"active","age":1.0,"state":{},"soccer_guidance":{}})
	check(not hud.text.contains("Shot practice"))
	hud.free()
	print("PRACTICE PASS ", checks, " checks")
	quit()
