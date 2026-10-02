extends RefCounted
## Source candidates, not a declaration of native art acceptance.
const ENTRIES := [
	{"id":"basalt-reach","name":"Basalt Reach · canyon crossing","recipe":"res://identity_maps/generated/basalt-reach.json","origin":[0.0,0.0,8.0],"geometry_hash":"253ec79c236ace7cd014a3c54a8c16bac9f759b9d93b24de00642608061fa63a"},
	{"id":"canopy-divide","name":"Canopy Divide · fern ravine","recipe":"res://identity_maps/generated/canopy-divide.json","origin":[0.0,0.0,8.0],"geometry_hash":"bab038319c314a015ae4fbd125dd69b34354181888a2febf8d28bde768114d26"},
	{"id":"crown-array","name":"Crown Array · receiver court","recipe":"res://campaign/generated/crown-array.json","origin":[-13.76,71.82182,-3.44],"geometry_hash":"8d6ace0fcda6470d5e2fd656ee0eab3936fc2e6a5c273021a5116df4d2c62d3e"},
	{"id":"helix-conservatory","name":"Helix Conservatory · specimen lightwell","recipe":"res://multiplayer_worlds/generated/helix-conservatory.json","origin":[0.0,0.0,18.0],"geometry_hash":"f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2","glb":"res://multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb","glb_sha256":"0c462ffa475f02aa388101c38339d6d81eb3df9549a7d664ca65ec390c802d88"}]

static func available() -> Array:
	var result: Array = []
	for item: Dictionary in ENTRIES:
		if not FileAccess.file_exists(item.recipe): continue
		var recipe: Variant = JSON.parse_string(FileAccess.get_file_as_string(item.recipe))
		if not recipe is Dictionary or recipe.get("geometryHash","") != item.geometry_hash: continue
		if item.has("glb") and FileAccess.get_sha256(item.glb) != item.glb_sha256: continue
		result.append(item.duplicate(true))
	return result

static func entry(id: String) -> Dictionary:
	for item: Dictionary in ENTRIES:
		if item.id == id: return item.duplicate(true)
	return {}
