extends Node3D
## Native capture fixture. Requires real fighter_visual and an explicit engine grant.
## Synthetic contact cases are labelled; --battle instead consumes core.step events.
const Director = preload("res://fighting/effects/director.gd")
var director
var camera: Camera3D
var visuals: Array = []
var output := "/home/mojo/.tmp-on-disk/cocs-fighting-effects-evidence-20261002/native"
var ids: Array[String] = ["chatgpt","claude","grok","meta","gemini","deepseek","mistral","kimi","qwen"]
var manifest: Array = []
var audible := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--sound": audible = true
	DirAccess.make_dir_recursive_absolute(output)
	if not ResourceLoader.exists("res://fighting/visuals/fighter_visual.gd"):
		push_error("Native fighter assets unavailable: inspection UNRUN")
		get_tree().quit(2)
		return
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07,0.09,0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(18,0.1,3)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.06
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0,1.25,12)
	add_child(camera)
	camera.current = true
	director = Director.new()
	add_child(director)
	var visual_script: Script = load("res://fighting/visuals/fighter_visual.gd")
	for i in range(2):
		var visual: Node3D = visual_script.new()
		add_child(visual)
		visuals.append(visual)
	if "--battle" in OS.get_cmdline_user_args(): await battle()
	else: await capture_cases()
	var file := FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"captures require human review","cases":manifest},"\t"))
	director.reset()
	get_tree().quit()

func fighter(id: int, operator: String, move: String = "stand_m", frame: int = 8) -> Dictionary:
	return {"id":id,"operator_id":operator,"x":-750 if id == 0 else 750,"y":0,"facing":1 if id == 0 else -1,
		"state":"attack","move_id":move,"move_frame":frame,"animation":move,"animation_frame":frame,"hitstop":0,"resources":{}}

func save_capture(name: String, detail: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")
	detail.file = name+".png"
	detail.metrics = director.metrics()
	manifest.append(detail)

func capture_cases() -> void:
	var cases: Array = [["normal","hit","stand_m"],["projectile","projectile_spawn","special1"],
		["grapple","throw_grab","special3"],["release","throw_release","throw_f"],["super","super","super"],
		["guard","block","crouch_m"],["tech","throw_tech","throw_f"],["cable","mobility","special2"],
		["counter","counter_hit","stand_h"],["startup","move_start","stand_h"],["whiff","whiff","stand_h"],
		["clash","projectile_clash","special1"],["reflect","projectile_reflect","special1"]]
	for compact in [false,true]:
		get_window().size = Vector2i(960,600) if compact else Vector2i(1600,900)
		camera.size = 8.0 if compact else 12.0
		for operator in ids:
			if not visuals[0].configure(operator) or not visuals[1].configure("meta"):
				push_error("Missing authored fighter visual: "+operator)
				get_tree().quit(2)
				return
			var operator_cases: Array = cases.duplicate(true)
			if operator == "gemini":
				for move in ["palm_l","palm_m","palm_h"]: operator_cases.append([move,"hit",move])
			for reduced in [false,true]:
				for case in operator_cases:
					director.configure({"quality":"low" if reduced else "high","reduced_motion":reduced,"muted":not audible})
					var fighters: Array = [fighter(0,operator,str(case[2])),fighter(1,"meta","guard_hi")]
					for i in range(2): visuals[i].present(fighters[i],1.0)
					var event := {"id":1,"tick":1,"type":case[1],"actor":0,"target":1,"move_id":case[2],"x":300,"y":1050,"effect":operator+":"+str(case[2])}
					director.consume([event,event],fighters)
					director.advance(0.09)
					var name := operator+"_"+str(case[0])+ ("_compact" if compact else "_wide") + ("_reduced" if reduced else "")
					await save_capture(name,{"operator":operator,"case":case[0],"synthetic_contacts":true,"reduced":reduced,"compact":compact})

func battle() -> void:
	var core_path := "res://fighting/core/simulation.gd"
	if not ResourceLoader.exists(core_path):
		push_error("Core unavailable: playing-battle inspection UNRUN")
		get_tree().quit(2)
		return
	var core = load(core_path).new()
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	core.configure(roster,rules)
	camera.size = 12
	for operator in ids:
		visuals[0].configure(operator)
		visuals[1].configure("meta")
		director.configure({"muted":not audible,"quality":"high"})
		core.start_match({"operators":[operator,"meta"],"stage_id":"basalt-reach","seed":91,"training":true})
		var ledger: Array = []
		var seen: Dictionary = {}
		var captures := 0
		for tick in range(720):
			var buttons: int = [1,2,4,8,16,32,256][int(tick/45)%7] if tick%45 == 0 else 0
			var inputs: Array = [{"axis_x":1 if tick<120 else 0,"axis_y":0,"held":buttons,"pressed":buttons},
				{"axis_x":-1 if tick<120 else 0,"axis_y":0,"held":64 if tick%120<60 else 0,"pressed":0}]
			var snapshot: Dictionary = core.step(inputs)
			var fighters: Array = snapshot.fighters
			for i in range(2):
				visuals[i].present(fighters[i],1.0)
				director.present_fighter(fighters[i],visuals[i])
			director.consume(snapshot.events,fighters)
			director.present_projectiles(snapshot.projectiles,fighters)
			director.advance(1.0/60.0)
			var fresh: Array = []
			for event in snapshot.events:
				if not seen.has(event.id):
					seen[event.id] = true
					fresh.append(event)
			ledger.append({"tick":snapshot.tick,"events":fresh,"metrics":director.metrics()})
			if not fresh.is_empty() and captures < 12:
				captures += 1
				await save_capture(operator+"_battle_"+str(tick),{"operator":operator,"tick":tick,"synthetic_contacts":false,"events":snapshot.events})
			else: await get_tree().process_frame
		var file := FileAccess.open(output+"/"+operator+"_battle-events.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(ledger))
