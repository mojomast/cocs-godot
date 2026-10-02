extends SceneTree
## Prepared actual-GDScript gate; run only with an explicit engine grant.
const Camera = preload("res://fighting/presentation/camera.gd")
var failures: Array = []

func _initialize() -> void:
	var camera := Camera.new()
	root.add_child(camera)
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	camera.configure(roster,rules,[])
	var fighters: Array = [{"operator_id":"meta","x":-600,"y":0,"vx":0,"vy":0,"hitstop":0},{"operator_id":"qwen","x":600,"y":0,"vx":0,"vy":0,"hitstop":0}]
	var view := Vector2(1280,800)
	var safe := Vector2(167.0/800.0,86.0/800.0)
	camera.present(fighters,view,{"tick":0,"projectiles":[]})
	check(camera.size < 6.0,"grounded framing no longer reserves an 8m jump")
	var initial_size := camera.size
	for tick: int in range(1,130):
		# Labelled envelope fixture, not a simulation/versus result.
		var velocity := maxi(0,255-(tick-5)*9)
		fighters[0].jump_edge = tick == 1
		fighters[0].move_id = "special2" if tick < 5 else ""
		fighters[0].move_frame = tick
		if tick >= 5 and tick < 62:
			fighters[0].y = maxi(0,int(fighters[0].y)+255-(tick-5)*9)
			fighters[0].vy = velocity
		else:
			fighters[0].y = 0
			fighters[0].vy = 0
		camera.present(fighters,view,{"tick":tick,"projectiles":[]})
		var boxes := camera.envelopes(fighters,[])
		contained(camera,boxes.actual,view.x/view.y,safe)
		var transform := camera.transform
		var height := camera.size
		camera.present(fighters,view,{"tick":tick,"projectiles":[]})
		check(camera.transform == transform and camera.size == height,"repeat render cannot advance camera")
	check(camera.size < initial_size+1.0,"landing recovers readable close framing")
	fighters[0].hitstop = 6; fighters[1].hitstop = 6
	var frozen := camera.transform
	var frozen_size := camera.size
	for tick: int in range(130,136): camera.present(fighters,view,{"tick":tick})
	check(camera.transform == frozen and camera.size == frozen_size,"hitstop holds camera exactly")
	for size: Vector2 in [Vector2(760,520),Vector2(1280,800),Vector2(1920,1080)]:
		for side: int in [-1,1]:
			fighters[0].x = side*7800; fighters[1].x = side*7000
			fighters[0].y = 8000
			var projectile := {"x":-side*8500,"y":2000,"width":900,"height":900}
			camera.reset()
			camera.present(fighters,size,{"tick":140,"projectiles":[projectile]},Vector2(232.5,117))
			var safe_scaled := Vector2(clampf(244.5/size.y,0.12,0.48),clampf(125.0/size.y,0.08,0.25))
			contained(camera,camera.envelopes(fighters,[projectile]).actual,size.x/size.y,safe_scaled)
	fighters[0].x = -600; fighters[1].x = 600
	fighters[0].y = 0
	camera.reset()
	camera.present(fighters,view,{"tick":0,"projectiles":[]})
	check(is_equal_approx(camera.size,initial_size),"rematch reset does not inherit prior zoom")
	print("FIGHTING_CAMERA_GATE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	camera.free()
	quit(0 if failures.is_empty() else 1)

func contained(camera: Camera3D, box: Rect2, aspect: float, safe: Vector2) -> void:
	var low := camera.position.y-camera.size*(0.5-safe.y)
	var high := camera.position.y+camera.size*(0.5-safe.x)
	check(camera.position.x-camera.size*aspect*0.5 <= box.position.x+0.00001,"left pose/projectile contained")
	check(camera.position.x+camera.size*aspect*0.5 >= box.end.x-0.00001,"right pose/projectile contained")
	check(low <= box.position.y+0.00001 and high >= box.end.y-0.00001,"floor and silhouette inside HUD-safe region")

func check(value: bool, label: String) -> void:
	if not value and not failures.has(label): failures.append(label)
