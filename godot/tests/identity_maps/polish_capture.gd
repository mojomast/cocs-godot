extends "res://tests/identity_maps/capture.gd"
## Controlled renderer comparison using identical authored geometry/cameras.
## Production environment path vs inspection path; not a connected gameplay run.
const PlayEnvironment = preload("res://native_arenas/identity_environment.gd")
const WeatherLook = preload("res://ambience/weather_look.gd")
var composition := false

func _initialize() -> void:
	composition="--composition" in OS.get_cmdline_user_args()
	super._initialize()
	report.scope="Static authored geometry: production composition environment" if composition else "Static authored geometry: inspection environment"
	report.cadence_claim=false

func _rig(id: String, map: Node3D) -> void:
	if not composition:
		super._rig(id,map)
		return
	var rig := PlayEnvironment.new()
	stage.add_child(rig)
	assert(rig.build(map.recipe),"production environment builds")
	camera=Camera3D.new()
	camera.far=320
	camera.fov=72
	stage.add_child(camera)
	camera.make_current()

func _sample(entry: Dictionary, view: Dictionary) -> void:
	if not entry.cameras.is_empty(): return # One identical authored camera per map.
	camera.position=Vector3(view.at[0],view.at[1],view.at[2])
	camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
	var environments := stage.find_children("*","WorldEnvironment",true,false)
	var suns := stage.find_children("*","DirectionalLight3D",true,false)
	assert(environments.size()==1 and suns.size()==1,"single rig ownership")
	var environment: WorldEnvironment=environments[0]
	var sun: DirectionalLight3D=suns[0]
	var original := environment.environment
	var weather := WeatherLook.new()
	weather.bind(stage,environment,sun)
	for mode: String in ["dry","storm","restored"]:
		if mode=="storm": weather.apply("storm",0.0,true)
		if mode=="restored":
			weather.clear()
			assert(environment.environment==original,"weather returns exact authored environment")
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var file := "%s/%s-%s-%s.png"%[output,entry.id,"composition" if composition else "inspection",mode]
		assert(root.get_texture().get_image().save_png(file)==OK,"actual native image saved")
		print("IDENTITY_POLISH_FRAME ",file)
	entry.cameras.append({"id":view.id,"at":view.at,"target":view.target,"environment_path":"composition" if composition else "inspection","restored":environment.environment==original})
