extends SceneTree
## Graphical shader-contract test with an explicitly synthetic opaque-black Moth
## frame. It does not consume or alter the reserved external pulse preview.
const ShaderFX = preload("res://weapon_effects/flash.gdshader")
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): output = arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	viewport.add_child(camera)
	camera.current = true
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for y: int in 64:
		for x: int in 64:
			var r := Vector2(x-31.5,y-31.5).length()/32.0
			if r < 0.4: image.set_pixel(x,y,Color(0.4,0.9,1.0,1.0))
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2,2)
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = ShaderFX
	material.set_shader_parameter("use_sheet",true)
	material.set_shader_parameter("frame_texture",ImageTexture.create_from_image(image))
	material.set_shader_parameter("tint",Color("70ffe6"))
	node.material_override = material
	node.position.z = -1
	viewport.add_child(node)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	var corner_alpha := rendered.get_pixel(2,2).a
	var black_edge_alpha := rendered.get_pixel(10,64).a
	var center_alpha := rendered.get_pixel(64,64).a
	var valid := corner_alpha < 0.01 and black_edge_alpha < 0.02 and center_alpha > 0.4
	var result := {"fixture":"synthetic opaque black frame; GL Compatibility shader output", "input_black_alpha":image.get_pixel(0,0).a,"corner_alpha":corner_alpha,"black_edge_alpha":black_edge_alpha,"center_alpha":center_alpha,"passed":valid}
	if not output.is_empty():
		rendered.save_png(output.path_join("moth-opaque-coverage.png"))
		FileAccess.open(output.path_join("moth-coverage.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("WEAPON_EFFECTS_MOTH_COVERAGE ",JSON.stringify(result))
	quit(0 if valid else 1)
