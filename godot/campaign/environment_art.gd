extends Node3D
## Purely visual campaign decorator. Called after CampaignTerrain.build(id), with no
## changes to authoritative source triangles, collision shapes, bounds or nav data.
const GROUND = preload("res://campaign/materials/ground.gdshader")
const ASSET_DIR := "res://campaign/art/environment/"
const CHUNK := 32.0
const BIOMES := [
	{"tree":"root_tree", "fern":"root_fern", "rock":"root_rock", "accent":"root_log"},
	{"fern":"silt_reed", "rock":"silt_stone", "accent":"silt_bank"},
	{"fern":"ember_scrub", "rock":"ember_basalt", "accent":"ember_slag"},
	{"tree":"crown_tree", "fern":"crown_tuft", "rock":"crown_boulder", "accent":"crown_debris"},
]
var replacement_instances := 0
var accent_instances := 0
var batch_count := 0
var _asset_cache: Dictionary = {}

func build(host: Node3D) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	replacement_instances = 0
	accent_instances = 0
	batch_count = 0
	if host == null or not host.get("recipe") is Dictionary or host.recipe.is_empty(): return
	var index := int(host.recipe.campaign.index)
	if index < 0 or index >= BIOMES.size(): return
	var palette: Array = host.recipe.palette
	var ground: ShaderMaterial = host.materials.get("terrain")
	if ground:
		ground.shader = GROUND
		ground.set_shader_parameter("ground_color", Color(str(palette[0])))
		ground.set_shader_parameter("trail_color", Color(str(palette[1])))
		ground.set_shader_parameter("stone_color", Color(str(palette[2])))
		ground.set_shader_parameter("weather_color", Color(str(palette[4])).darkened(.32))
		ground.set_shader_parameter("moisture", 1.0 if index == 1 else .25 if index == 0 else .05)
	var selected: Dictionary = BIOMES[index]
	# Only touch precisely identified original scenery batches carrying the terrain
	# builder's CPU transform mirror. Preserve horizon trees outside play bounds.
	var bounds: Dictionary = host.recipe.arena.bounds
	var groups: Dictionary = {}
	for node in host.get_children():
		if not node is MultiMeshInstance3D or not node.name.begins_with("Scenery_") or not node.has_meta("instance_transforms"): continue
		var kind := str(node.name).trim_prefix("Scenery_")
		var family := "rock" if kind.begins_with("crag-") else kind
		if not selected.has(family): continue
		var origin: Vector3 = node.position
		# Horizon silhouette belongs to the existing scenery system.
		if origin.x < float(bounds.minX)-CHUNK or origin.x > float(bounds.maxX)+CHUNK or origin.z < float(bounds.minZ)-CHUNK or origin.z > float(bounds.maxZ)+CHUNK: continue
		var transforms: Array = node.get_meta("instance_transforms")
		var asset := str(selected[family])
		if not groups.has(asset): groups[asset] = {}
		var chunk_key := "%d/%d" % [floori(origin.x/CHUNK),floori(origin.z/CHUNK)]
		if not groups[asset].has(chunk_key): groups[asset][chunk_key] = {"origin":origin,"transforms":[]}
		for transform: Transform3D in transforms:
			var world: Vector3 = origin + transform.origin
			if world.x < float(bounds.minX)-3 or world.x > float(bounds.maxX)+3 or world.z < float(bounds.minZ)-3 or world.z > float(bounds.maxZ)+3: continue
			groups[asset][chunk_key].transforms.append(Transform3D(transform.basis,world-groups[asset][chunk_key].origin))
		# Original scenery is hidden only when its complete mirrored batch is valid.
		if groups[asset][chunk_key].transforms.size() > 0: node.visible = false
	for asset: String in groups:
		for group: Dictionary in groups[asset].values():
			_batch(asset,group,false)
	# Candidate sites are existing recipe scenery locations; reject mission anchors
	# and the entire critical route with a generous radius, never create collisions.
	var accents: Dictionary = {}
	var candidates: Array = host.recipe.art
	for i in range(candidates.size()):
		var prop: Dictionary = candidates[i]
		if str(prop.kind) not in ["fern","crag","tree"] or i % 13 != index % 13: continue
		var site := Vector3(float(prop.position[0]),0,float(prop.position[2]))
		if not _clear_site(host,site): continue
		var y: float = host.height_at(site.x,site.z)
		if not is_finite(y): continue
		var asset := str(selected.accent)
		if index == 2 and i % 3 == 0: asset = "ember_debris"
		if not accents.has(asset): accents[asset] = {}
		var key := "%d/%d" % [floori(site.x/CHUNK),floori(site.z/CHUNK)]
		if not accents[asset].has(key): accents[asset][key] = {"origin":Vector3(floorf(site.x/CHUNK)*CHUNK,0,floorf(site.z/CHUNK)*CHUNK),"transforms":[]}
		var group: Dictionary = accents[asset][key]
		var spin := fposmod(float(i)*2.399963, TAU)
		var scale := Vector3(2.8,2.0,2.3) if index == 0 else Vector3(1.8,1.8,1.4) if index == 1 else Vector3(2.2,1.9,1.7)
		var offset := Vector3(site.x,y-.08,site.z)-group.origin
		group.transforms.append(Transform3D(Basis(Vector3.UP,spin).scaled(scale),offset))
	for asset: String in accents:
		for group: Dictionary in accents[asset].values(): _batch(asset,group,true)

func _clear_site(host: Node3D, site: Vector3) -> bool:
	var b: Dictionary = host.recipe.arena.bounds
	if site.x < b.minX+8 or site.x > b.maxX-8 or site.z < b.minZ+8 or site.z > b.maxZ-8: return false
	for anchor: Dictionary in host.recipe.campaign.anchors.values():
		if site.distance_to(Vector3(float(anchor.x),0,float(anchor.z))) < maxf(18.0,float(anchor.radius)+8.0): return false
	var path: Array = host.recipe.campaign.criticalPath
	for j in range(1,path.size()):
		var a := Vector2(float(path[j-1].x),float(path[j-1].z))
		var edge := Vector2(float(path[j].x),float(path[j].z))-a
		if edge.length_squared() < .01: continue
		var nearest := a+edge*clampf((Vector2(site.x,site.z)-a).dot(edge)/edge.length_squared(),0,1)
		if nearest.distance_to(Vector2(site.x,site.z)) < 13.0: return false
	return true

func _mesh(asset: String) -> Mesh:
	if _asset_cache.has(asset): return _asset_cache[asset]
	var scene: PackedScene = load(ASSET_DIR+asset+".glb")
	if scene == null: return null
	var root := scene.instantiate()
	var result: Mesh = _find_mesh(root)
	_asset_cache[asset] = result
	root.free()
	return result

func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D: return node.mesh
	for child in node.get_children():
		var mesh := _find_mesh(child)
		if mesh: return mesh
	return null

func _batch(asset: String, group: Dictionary, accent: bool) -> void:
	var mesh := _mesh(asset)
	if mesh == null: return
	var transforms: Array = group.transforms
	if transforms.is_empty(): return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	var union := AABB()
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		multi.set_instance_transform(i,t)
		var box := t*mesh.get_aabb()
		union = box if i == 0 else union.merge(box)
	multi.custom_aabb = union.grow(.3)
	var node := MultiMeshInstance3D.new()
	node.name = ("Accent_" if accent else "Biome_")+asset
	node.position = group.origin
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if accent else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.visibility_range_end = 95.0 if accent else 155.0 if asset.ends_with("fern") or asset.ends_with("reed") or asset.ends_with("scrub") or asset.ends_with("tuft") else 650.0
	node.visibility_range_end_margin = 18.0 if accent else 28.0
	node.set_meta("instance_transforms",transforms.duplicate())
	add_child(node)
	batch_count += 1
	if accent: accent_instances += transforms.size()
	else: replacement_instances += transforms.size()
