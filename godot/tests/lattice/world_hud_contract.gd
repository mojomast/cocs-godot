extends SceneTree
const Hud = preload("res://lattice/world_hud.gd")

func _initialize() -> void:
	var hud := Hud.new()
	var authored := {"nodes":[{"id":"home","archetype":"hq","x":0,"z":0}, {"id":"front","archetype":"front","x":20,"z":0}], "lattice":[["home", "front"]]}
	assert(hud.bind_authored_map("fixture", authored))
	var actor := {"x":0,"z":0}
	var nodes := [{"id":"home","x":0,"z":0,"owner":0,"live":true}, {"id":"front","x":20,"z":0,"owner":1,"live":true,"contested":true}]
	hud.apply_projection({"team":0,"nodes":nodes}, actor)
	var front: Label3D = hud.markers["front"]
	assert(front.text.contains("Team 1 · CONTESTED"))
	assert(front.text.contains("capture LEGAL · supply LINKED"))
	assert(front.text.contains("20 m (planar)"))
	assert((hud.markers["home"] as Label3D).text.contains("own HOLD"))
	nodes[1].erase("owner")
	nodes[1].erase("live")
	nodes[1].erase("contested")
	hud.apply_projection({"nodes":nodes}, actor)
	assert(front.text.contains("Owner unknown · activity unknown"))
	assert(front.text.contains("capture unknown · supply UNKNOWN"))
	assert(not front.text.contains("Team 1") and not front.text.contains("LEGAL"))
	nodes[1].owner = 1
	nodes[1].live = false
	hud.apply_projection({"team":0,"nodes":nodes}, actor)
	assert(front.text.contains("Team 1 · inactive"))
	assert(front.text.contains("capture unavailable"))
	hud.clear_round()
	hud.free()
	print("WORLD_HUD_CONTRACT passed")
	quit(0)
