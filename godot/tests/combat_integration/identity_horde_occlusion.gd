extends SceneTree

const Occlusion = preload("res://world/combat_occlusion.gd")
const IdentityMap = preload("res://identity_maps/map.gd")

func _initialize() -> void:
	var world := Node3D.new()
	var map := IdentityMap.new()
	world.add_child(map)
	var body := StaticBody3D.new()
	map.add_child(body)
	var failures := 0
	if Occlusion.native_root(world, "nacre-engine") != null: failures += 1
	map.recipe = {"id":"nacre-engine"}
	if Occlusion.native_root(world, "nacre-engine") != map: failures += 1
	if Occlusion.native_root(world, "lacuna-court") != null: failures += 1
	var geometry := Occlusion.new()
	if not geometry.configure(null, {"id":"nacre-engine", "collision_root":Occlusion.native_root(world, "nacre-engine")}): failures += 1
	if geometry.snapshot().physics_bodies != 1: failures += 1
	world.free()
	if failures == 0:
		print("IDENTITY_HORDE_OCCLUSION_OK checks=5")
	quit(1 if failures else 0)
