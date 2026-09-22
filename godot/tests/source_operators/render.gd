extends SceneTree
const Visual = preload("res://source_operators/operator_visual.gd")
const Rig = preload("res://source_operators/character_rig.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
var stage: Node3D
var camera: Camera3D
var visual: Node3D
var evidence: String

func _init() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(file: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(evidence.path_join(file))

func camera_pose(distance: float, angle: float) -> void:
	camera.position = Vector3(sin(angle)*distance,1.05,-cos(angle)*distance)
	camera.look_at(Vector3(0,1.05,0))

func run() -> void:
	evidence = OS.get_environment("OPERATOR_EVIDENCE")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1280,800)
	stage = Node3D.new(); root.add_child(stage)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("25313d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world: WorldEnvironment = WorldEnvironment.new(); world.environment = env; stage.add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light); light.position = Vector3(-3,5,-4); light.look_at(Vector3.ZERO)
	light.light_energy = 2.0
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new(); plane.size = Vector2(80,80)
	floor_mesh.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new(); floor_mat.albedo_color = Color("374652"); floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat; stage.add_child(floor_mesh)
	camera = Camera3D.new(); camera.fov = 50.0; camera.near = 0.05; camera.far = 100.0; stage.add_child(camera)
	camera.make_current()
	visual = Visual.new(); stage.add_child(visual); visual.automatic_animation = false
	# Visual wrapper retains actor-center API; stage feet stay on source origin.
	visual.position.y = 0.9
	for size: Vector2i in [Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size = size
		for id: String in ["claude","grok","meta"]:
			if not Catalog.OPERATORS.has(id): continue
			visual.apply_identity({"character":id})
			visual.rig.apply_pose(Rig.solve({"time":1.2}))
			for view: String in ["front","side","back","10m","25m"]:
				var distance: float = 3.0 if view in ["front","side","back"] else (10.0 if view == "10m" else 25.0)
				camera_pose(distance,PI/2.0 if view == "side" else (PI if view == "back" else 0.0))
				await capture("native-%s-%s-%d.png" % [id,view,size.x])
	root.size = Vector2i(512,512)
	visual.apply_identity({"character":"claude"})
	camera_pose(2.7,0.32)
	for frame: int in range(12):
		visual.rig.apply_pose(Rig.solve({"phase":frame*TAU/12.0,"speedNorm":0.65,"forward":1,"time":0.4}))
		await capture("native-walk-%02d.png" % frame)
	visual.free()
	# Rendered frame timing, not headless timing. CPU/software GPU identified in log.
	var reports: Array = []
	for size: Vector2i in [Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size = size
		for count: int in [16,32]:
			var roster: Array = []
			for i: int in range(count):
				var actor = Visual.new(); stage.add_child(actor)
				actor.position = Vector3((i%8-3.5)*1.45,0.9,-(i/8)*1.8)
				actor.configure({"id":i,"character":Catalog.OPERATORS.keys()[i%Catalog.OPERATORS.size()],"health":100,"vx":0,"vz":-3.2,"ads":i%3 == 0},-1)
				actor.automatic_animation = false
				roster.append(actor)
			camera.position = Vector3(0,4,-16); camera.look_at(Vector3(0,1,-2))
			for frame: int in range(12): await settle()
			var timings: Array[float] = []
			var animation_cpu: Array[float] = []
			for frame: int in range(60):
				var before: int = Time.get_ticks_usec()
				for actor in roster: actor.advance(1.0/60.0)
				animation_cpu.append((Time.get_ticks_usec()-before)/1000.0)
				await process_frame
				await RenderingServer.frame_post_draw
				timings.append((Time.get_ticks_usec()-before)/1000.0)
			timings.sort()
			animation_cpu.sort()
			var costs: Array = [0,0,0]
			for actor in roster: costs[actor.lod_level] += 1
			var report: Dictionary = {"count":count,"width":size.x,"height":size.y,"frames":60,"medianMs":timings[30],"p95Ms":timings[57],"animationCpuMedianMs":animation_cpu[30],"animationCpuP95Ms":animation_cpu[57],"viewportDrawCalls":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"viewportPrimitives":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),"lodPopulation":costs}
			reports.append(report)
			await capture("native-roster-%d-%d.png" % [count,size.x])
			for actor in roster: actor.free()
	var result: Dictionary = {"renderer":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_current_rendering_method(),"method":"Rendered Compatibility frames, vsync-off requested (driver warns unsupported), 12 warmup pairs + 60 samples. CPU column times only native snapshot-driven animation updates for the complete roster. Host is llvmpipe, shared with concurrent agents; not hardware GPU or gameplay benchmark. Directional plus ambient, no shadows/postprocess. Entire 16/32 mixed-identity roster framed at near LOD.","results":reports}
	FileAccess.open(evidence.path_join("performance.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit()
