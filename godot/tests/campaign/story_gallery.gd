extends SceneTree
## Authored wire fixture for visual inspection and capture; no pretend authority.
const Director = preload("res://campaign/story_director.gd")
const Widgets = preload("res://campaign/story_widgets.gd")
var director: Node3D
var widgets: Control
var camera: Camera3D
var elapsed := 0.0
var last_step := -1

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.5, -0.4)
	world.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18, 18)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("455e53")
	ground.material_override = mat
	world.add_child(ground)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 2.2, 5)
	camera.look_at(Vector3(0, 0.65, 0))
	camera.make_current()
	director = Director.new()
	world.add_child(director)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	widgets = Widgets.new()
	layer.add_child(widgets)
	update_fixture(0)

func update_fixture(step: int) -> void:
	var characters := ["chatgpt", "claude", "gemini", "deepseek"]
	var chapter := ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"][step % 4]
	var poses := ["wave", "work", "point", "idle"]
	var entity := {"id":"patch", "kind":"puppy", "name":"Patch", "x":0.65, "y":0.0, "z":0.0, "yaw":-0.35, "pose":"sit" if step % 2 == 0 else "happy", "active":true, "reactionSerial":1 if step % 4 == 1 else 0}
	var operator := {"id":"friendly", "kind":"operator", "name":"Mara", "character":characters[step % 4], "x":-1.2, "y":0.0, "z":-0.6, "yaw":0.15, "pose":poses[step % 4], "active":true, "reactionSerial":0}
	var fixture := {"version":1, "entities":[entity, operator], "prompt":{"entityId":"patch", "action":"pet", "text":"Pet Patch"}, "caption":{"id":chapter, "speaker":"Mara", "text":"There you are, Patch. Good to see you again."}, "completed":[], "pets":step % 4}
	director.apply(fixture, chapter)
	widgets.observe(fixture, true)
	print("STORY_GALLERY ", chapter, " ", poses[step % 4])

func _process(dt: float) -> void:
	elapsed += dt
	var step := int(elapsed / 4.0)
	if step != last_step:
		last_step = step
		update_fixture(step)
