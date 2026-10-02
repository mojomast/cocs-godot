extends Node3D
## Deferred native fixture: four rows = SVG red/blue, Moth red/blue.
const Visual = preload("res://source_operators/operator_visual.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
var actors: Array[Node3D] = []
var clock := 0.0
var phase := -1
var camera: Camera3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("18202a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.5
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-35,0)
	light.light_energy = 2.0
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,8,15)
	camera.look_at(Vector3(0,0,-3))
	camera.current = true
	for row in 4:
		for index in Catalog.OPERATORS.size():
			var id: String = str(Catalog.OPERATORS.keys()[index])
			var actor = Visual.new()
			actor.automatic_animation = false
			add_child(actor)
			actor.position = Vector3((index-4)*1.7,0,-row*2.4)
			actor.configure({"character":id,"team":"red" if row % 2 == 0 else "blue","id":index+row*9,"health":100,"weapon":0})
			if row < 2:
				actor.moth_finish.clear()
				actor.finish_report.installed = false
			else:
				print("MOTH_COVERAGE ",JSON.stringify(actor.finish_report))
				assert(actor.finish_report.get("installed",false), "Moth coverage absent: " + id)
			actors.append(actor)
			var label := Label3D.new()
			label.text = id + (" SVG " if row < 2 else " Moth ") + ("red" if row % 2 == 0 else "blue")
			label.position = actor.position + Vector3(0,1.9,0)
			label.font_size = 24
			add_child(label)

func _process(dt: float) -> void:
	clock += dt
	var next_phase := int(clock / 4.0) % 8
	for index in actors.size():
		var actor = actors[index]
		# Before/after views share the original per-operator rig/locomotion.
		actor.snapshot.vx = 0.0
		actor.snapshot.vz = -3.0 if next_phase == 1 else 0.0
		actor.snapshot.melee = 0.2 if next_phase == 3 else 0.0
		actor.snapshot.reloading = next_phase == 2
		actor.snapshot.reloadTimer = fmod(clock,1.0)
		actor.snapshot.reloadDuration = 1.0
		actor.advance(dt)
		if next_phase == 0: actor.kick(dt*2.0)
		if next_phase != phase:
			actor.set_lod(1 if next_phase == 5 else (2 if next_phase == 6 else 0))
			if next_phase == 4:
				actor.apply_identity({"character":actor.character,"team":"blue" if index / 9 == 2 else "red"})
			if next_phase == 7: actor.reset_pose()
	phase = next_phase

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R: get_tree().reload_current_scene()
		if event.keycode == KEY_C:
			camera.position = Vector3(-6,2,4)
			camera.look_at(Vector3(-6,0,-4))
