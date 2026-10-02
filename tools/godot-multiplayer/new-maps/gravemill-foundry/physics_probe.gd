extends SceneTree
## Grant-gated test of the PRODUCTION world binder, not a substitute collider.
const WorldMap = preload("res://multiplayer_worlds/map.gd")

func _initialize() -> void:
 call_deferred("run")

func require_ok(ok: bool, message: String) -> bool:
 if not ok:
  push_error(message)
  quit(2)
 return ok

func run() -> void:
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/gravemill-foundry.json"))
 var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/gravemill-foundry-probes.json"))
 var world := WorldMap.new()
 root.add_child(world)
 if not require_ok(world.build(data), "Production world build failed"): return
 if not require_ok(world.geometry_hash == probes.geometryHash, "Collider/source probe hash mismatch"): return
 await physics_frame
 await physics_frame
 var space := world.get_world_3d().direct_space_state
 var capsule := CapsuleShape3D.new()
 capsule.radius = .41
 capsule.height = 1.7
 var checked := 0
 for p: Dictionary in probes.points:
  var origin := Vector3(p.x, p.y + 1.5, p.z)
  var ray := PhysicsRayQueryParameters3D.create(origin, origin - Vector3(0, 2, 0))
  var hit: Dictionary = space.intersect_ray(ray)
  if not require_ok(not hit.is_empty() and absf(float(hit.position.y) - float(p.y)) < .08, "Floor differs " + str(p)): return
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = capsule
  query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, p.y + .88, p.z))
  if not require_ok(space.intersect_shape(query, 1).is_empty(), "Standing capsule blocked " + str(p)): return
  checked += 1
 for cx in [-66.0, 66.0]:
  var a := Vector3(cx - 28, 13.5, 36 + .14 * (cx - 28))
  var b := Vector3(cx + 28, 13.5, 36 + .14 * (cx + 28))
  if not require_ok(space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b)).is_empty(), "Phantom gallery portal"): return
  a = Vector3(cx, 13.5, 36 + .14 * cx)
  if not require_ok(not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3(0, 20, 0))).is_empty(), "Vault shot escaped"): return
  var x: float = cx - 52.0 / 3.0
  for y in [14.5, 17.5]:
   a = Vector3(x, y, 24 + .14 * x)
   b = Vector3(x, y, 29 + .14 * x)
   var empty: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b)).is_empty()
   if not require_ok(empty == (y == 14.5), "Window/header shot contract mismatch"): return
 var body := CharacterBody3D.new()
 var contact_shape := CollisionShape3D.new()
 contact_shape.shape = capsule
 body.add_child(contact_shape)
 world.add_child(body)
 body.global_position = Vector3(-81, .88, -73.34)
 await physics_frame
 for i in range(160): body.move_and_collide(Vector3(.12,0,0))
 if not require_ok(body.global_position.x < -78.3, "Production capsule crossed mineral wall"): return
 var wall_ray := PhysicsRayQueryParameters3D.create(Vector3(-81,1.4,-73.34),Vector3(-70,1.4,-73.34))
 wall_ray.exclude = [body.get_rid()]
 if not require_ok(not space.intersect_ray(wall_ray).is_empty(), "Production wall ray escaped"): return
 var conveyor := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-24,1.5,-71.36),Vector3(-24,20,-71.36)))
 if not require_ok(not conveyor.is_empty() and absf(float(conveyor.position.y)-13.0)<.08, "Conveyor underside mismatch"): return
 var result := {"id":"gravemill-foundry", "geometryHash":world.geometry_hash, "routeCapsules":checked, "routeSupportRays":checked, "galleryShotProbes":8, "wallContactSteps":160,"wallContactX":body.global_position.x,"conveyorUnderside":conveyor.position.y,"metrics":world.metrics}
 print("GRAVEMILL_PRODUCTION_PHYSICS_OK ", JSON.stringify(result))
 quit()
