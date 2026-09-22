extends Node3D

const Catalog = preload("res://world/catalog.gd")
const EnvironmentStyle = preload("res://world/environment_style.gd")
const MothScenery = preload("res://moth_scenery/scenery.gd")
const ScenerySettings = preload("res://world/scenery_settings.gd")
var scenery_settings: Node
var catalog := Catalog.new()
var world: Node3D
var camera := Camera3D.new()
var label := Label.new()
var selector := OptionButton.new()
var ids: Array = []
var current_id: String = ""
var environment := WorldEnvironment.new()
var sun := DirectionalLight3D.new()
var style := EnvironmentStyle.new()

func _ready() -> void:
	add_child(camera)
	camera.far = 2000
	camera.position = Vector3(65, 48, 70)
	camera.look_at(Vector3(0, 2, 0))
	add_child(sun)
	add_child(environment)
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 16)
	ui.add_child(panel)
	panel.add_child(selector)
	panel.add_child(label)
	selector.item_selected.connect(func(index: int) -> void: load_map(ids[index]))
	if not catalog.open():
		label.text = catalog.error
		push_error(catalog.error)
		if "--smoke" in OS.get_cmdline_user_args(): get_tree().quit(1)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	load_map(ids[0])
	if "--visual-probe" in OS.get_cmdline_user_args():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file("res://content/probes/meridian-exchange/world.glb", state) != OK:
			get_tree().quit(1)
			return
		remove_child(world)
		world.free()
		world = document.generate_scene(state)
		add_child(world)
		label.text = "MERIDIAN EXCHANGE · actual exported world.glb\nImport spike — materials/effects and dynamic identities NOT accepted\nRight mouse: look · WASD/QE: fly"
	if "--smoke" in OS.get_cmdline_user_args():
		for iteration in range(2):
			for id: String in ids:
				if not load_map(id):
					get_tree().quit(1)
					return
				await get_tree().process_frame
		if not catalog.resolve_map("unknown-map").is_empty():
			get_tree().quit(1)
			return
		print("PORT_VIEWER_SMOKE_OK maps=", ids.size(), " cycles=2 unknown=rejected")
		get_tree().quit(0)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
			get_tree().quit(result)

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)

func load_map(id: String) -> bool:
	var map: Dictionary = catalog.resolve_map(id)
	if map.is_empty():
		label.text = catalog.error
		return false
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = Node3D.new()
	world.name = "SelectedMap"
	add_child(world)
	current_id = id
	style.configure(map, environment, sun)
	for b: Dictionary in map.get("blocks", []):
		box(Vector3(b.x, b.h / 2.0, b.z), Vector3(b.w, b.h, b.d), style.block_material(b), world)
	# Keep surface identity for native texture selection. Geometry and winding
	# remain the locked support triangles, grouped only for rendering materials.
	var surfaces: Dictionary = {}
	var shadow_surface := SurfaceTool.new()
	shadow_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shadow_triangles := 0
	var triangle_count: int = 0
	for triangle: Dictionary in map.get("terrain", {}).get("support_triangles", []):
		var kind := str(triangle.get("material", "concrete"))
		if not surfaces.has(kind):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[kind] = builder
		var surface: SurfaceTool = surfaces[kind]
		# Source uses CCW faces; Godot uses CW. Explicit source normals also
		# prevent unrelated support surfaces from being smoothed together.
		var normal: Array = triangle.normal
		var surface_id: String = triangle.get("surfaceId", "")
		var base_surface: bool = surface_id.begins_with("terrain-") or surface_id.begins_with("ground-") or surface_id in ["ash-floor", "grass-floor"]
		var priority := 1.0 if base_surface else 2.0
		# Flat zero-height support has nothing below it to shade; exclude it
		# from shadow casting to avoid grazing-angle self-shadow banding.
		var casts_shadow: bool = not base_surface and maxf(triangle.vertices[0][1], maxf(triangle.vertices[1][1], triangle.vertices[2][1])) > 0.05
		for index in [2, 1, 0]:
			var vertex: Array = triangle.vertices[index]
			surface.set_normal(Vector3(normal[0], normal[1], normal[2]))
			# Compatibility shader colors use the display-space semantic palette.
			# Pre-linearizing the packed vertex color crushes dark terrain twice.
			surface.set_color(style.terrain_color(triangle))
			surface.set_uv(Vector2(priority, 0))
			surface.add_vertex(Vector3(vertex[0], vertex[1], vertex[2]))
			if casts_shadow:
				shadow_surface.set_normal(Vector3(normal[0], normal[1], normal[2]))
				shadow_surface.add_vertex(Vector3(vertex[0], vertex[1], vertex[2]))
		if casts_shadow: shadow_triangles += 1
		triangle_count += 1
	if triangle_count > 0:
		var terrain := MeshInstance3D.new()
		terrain.name = "SemanticTerrain"
		var terrain_mesh := ArrayMesh.new()
		var kinds: Array = surfaces.keys()
		kinds.sort()
		for kind: String in kinds:
			var surface: SurfaceTool = surfaces[kind]
			surface.set_material(style.terrain_material(kind))
			surface.commit(terrain_mesh)
		terrain.mesh = terrain_mesh
		terrain.set_meta("surface_kinds", kinds)
		# The camera depth-priority shader must not bias the shadow map too.
		terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(terrain)
		if shadow_triangles > 0:
			var terrain_shadow := MeshInstance3D.new()
			terrain_shadow.name = "TerrainShadows"
			terrain_shadow.mesh = shadow_surface.commit()
			terrain_shadow.material_override = material(Color.WHITE)
			terrain_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			world.add_child(terrain_shadow)
	else:
		# Sports arenas intentionally have implicit zero-height support.
		box(Vector3(0, -0.1, 0), Vector3(260, 0.2, 220), style.surface_material("sports-floor", style.leaves if id == "aurora-stadium" else style.ground), world)
	style.decorate(map, world)
	var scenery := MothScenery.create(map, world)
	if is_inside_tree():
		if not is_instance_valid(scenery_settings):
			scenery_settings = ScenerySettings.new()
			add_child(scenery_settings)
		scenery_settings.bind_scenery(scenery)
	world.set_meta("semantic_block_count", map.get("blocks", []).size())
	world.set_meta("semantic_triangle_count", triangle_count)
	var pickup_markers := Node3D.new()
	pickup_markers.name = "StaticPickupMarkers"
	world.add_child(pickup_markers)
	var pickup_mat := material(Color(1, 0.75, 0.15))
	for pickup: Array in map.get("pickups", []):
		var marker := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.3
		mesh.height = 0.6
		mesh.radial_segments = 8
		mesh.rings = 4
		marker.mesh = mesh
		marker.material_override = pickup_mat
		marker.position = Vector3(pickup[1], support_height(map, pickup[1], pickup[2]) + 1, pickup[2])
		pickup_markers.add_child(marker)
	if "--diagnostic-markers" in OS.get_cmdline_user_args():
		var spawn_mat := material(Color(0.25, 1.0, 0.45))
		for point: Array in map.get("spawns", []):
			box(Vector3(point[0], support_height(map, point[0], point[1]) + 1.5, point[1]), Vector3(0.65, 3, 0.65), spawn_mat, world)
		box(Vector3(5, 0.3, 0), Vector3(10, 0.3, 0.3), material(Color.RED), world)
		box(Vector3(0, 5, 0), Vector3(0.3, 10, 0.3), material(Color.GREEN), world)
		box(Vector3(0, 0.3, -5), Vector3(0.3, 0.3, 10), material(Color.BLUE), world)
	selector.select(ids.find(id))
	label.text = "%s · NATIVE WORLD PREVIEW\nRight mouse: look · WASD/QE: fly · Shift: faster\nAuthored map identity; mode gameplay is separate." % map.name
	return true

func support_height(map: Dictionary, x: float, z: float) -> float:
	var best: float = -INF
	for t: Dictionary in map.get("terrain", {}).get("support_triangles", []):
		if not t.get("walkable", true): continue
		var a: Array = t.vertices[0]
		var b: Array = t.vertices[1]
		var c: Array = t.vertices[2]
		var denominator: float = (b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
		if absf(denominator) < 0.000000001: continue
		var u: float = ((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/denominator
		var v: float = ((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/denominator
		var w: float = 1-u-v
		if minf(u, minf(v, w)) >= -0.000000001: best = maxf(best, u*a[1]+v*b[1]+w*c[1])
	return best if is_finite(best) else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*0.003, -1.5, 1.5)

func _process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	if Input.is_physical_key_pressed(KEY_Q): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_E): direction.y += 1
	camera.position += camera.basis * direction.normalized() * delta * (80 if Input.is_physical_key_pressed(KEY_SHIFT) else 25)
