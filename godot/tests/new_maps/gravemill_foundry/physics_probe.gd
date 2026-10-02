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
 var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/new_maps/gravemill_foundry/probes.json"))
 var world := WorldMap.new()
 root.add_child(world)
 if not require_ok(world.build(data), "Production world build failed"): return
 if not require_ok(world.geometry_hash == probes.geometryHash, "Collider/source probe hash mismatch"): return
 var visual_triangles := {}
 var visual_faces := PackedVector3Array()
 var art: Node = world.get_node("BlenderArtNoGameplayCollision")
 var meshes := art.find_children("*", "MeshInstance3D", true, false)
 for mesh_node: MeshInstance3D in meshes:
  for s in range(mesh_node.mesh.get_surface_count()):
   var arrays: Array = mesh_node.mesh.surface_get_arrays(s)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   for j in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
    var points: Array[Vector3] = []
    for k in range(3): points.append(mesh_node.global_transform * vertices[indices[j+k] if not indices.is_empty() else j+k])
    visual_triangles[triangle_key(points)] = true
    for point: Vector3 in points: visual_faces.append(point)
 var matched := 0
 for wall: Dictionary in data.arena.terrain.walls:
  if wall.id == "boundary": continue # Eight explicit map-edge containment triangles, not architecture.
  var points: Array[Vector3] = []
  for p: Array in wall.vertices: points.append(Vector3(p[0],p[1],p[2]))
  if not visual_triangles.has(triangle_key(points)):
   print("VISUAL_TRIANGLE_MISMATCH ",triangle_key(points)," examples=",visual_triangles.keys().slice(0,8))
   if not require_ok(false, "Source wall absent from imported visual mesh: " + str(wall.id)): return
  matched += 1
 var matched_surfaces := 0
 for surface: Dictionary in data.arena.terrain.surfaces:
  if surface.get("walkable",false): continue # Ground is partitioned into material inlays.
  for indices: Array in surface.triangles:
   var points: Array[Vector3] = []
   for index: int in indices:
    var p: Array = surface.vertices[index]
    points.append(Vector3(p[0],p[1],p[2]))
   if not require_ok(visual_triangles.has(triangle_key(points)),"Source overhead absent from visual mesh: " + str(surface.id)): return
   matched_surfaces += 1
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
 var mineral_stop := body.global_position.x
 var architecture_contacts := 0
 for sample: Array in [[-66.0,-52.0,0.0,Vector3(0,0,1)],[57.0,29.0,12.0,Vector3(1,0,0)],[0.0,-77.81,0.0,Vector3(0,0,1)]]:
  var center := Vector3(sample[0],sample[2]+.88,sample[1]+.14*sample[0])
  var axis: Vector3 = sample[3]
  for side in [-1.0,1.0]:
   body.global_position = center+axis*side*2
   await physics_frame
   for i in range(100): body.move_and_collide(-axis*side*.12)
   if not require_ok((body.global_position-center).dot(axis)*side>0,"New architecture capsule wall leak"): return
   architecture_contacts += 100
 body.queue_free()
 await physics_frame
 for sample: Array in [[-90.0,-38.0,1.5], [10.0,-64.0,1.5], [66.0,36.0,13.5], [-66.0,36.0,13.5]]:
  var a := Vector3(sample[0],sample[2],sample[1]+.14*sample[0])
  if not require_ok(not space.intersect_ray(PhysicsRayQueryParameters3D.create(a,a+Vector3(0,30,0))).is_empty(),"District ceiling ray escaped"): return
 for y in [14.5,17.0]:
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(48,y,36.72),Vector3(48,y,40.72)))
  if not require_ok(hit.is_empty()==(y==14.5),"Assay inspection aperture/lintel mismatch"): return
 # Test-only layer for ray comparison against the actual imported GLB triangles.
 # Production art stays non-colliding. All production physics checks above used
 # only the real binder's authoritative collider bodies.
 var art_body := StaticBody3D.new()
 art_body.collision_layer = 2
 art_body.collision_mask = 0
 var art_shape := ConcavePolygonShape3D.new()
 art_shape.backface_collision = true
 art_shape.set_faces(visual_faces)
 var art_collision := CollisionShape3D.new()
 art_collision.shape = art_shape
 art_body.add_child(art_collision)
 world.add_child(art_body)
 await physics_frame
 await physics_frame
 var max_visual_floor_error := 0.0
 for p: Dictionary in probes.points:
  var origin := Vector3(p.x,p.y+1.5,p.z)
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin-Vector3(0,2,0),2))
  if not require_ok(not hit.is_empty(),"Imported floor absent at source probe"): return
  max_visual_floor_error = maxf(max_visual_floor_error,absf(float(hit.position.y)-float(p.y)))
  if not require_ok(max_visual_floor_error<.08,"Imported art/support floor mismatch"): return
 var result := {"id":"gravemill-foundry", "geometryHash":world.geometry_hash,"importedVisualWallTrianglesMatched":matched,"excludedBoundaryTriangles":8,"importedVisualOverheadTrianglesMatched":matched_surfaces,"importedMeshBatches":meshes.size(),"visualFloorRays":checked,"maxVisualFloorError":max_visual_floor_error, "routeCapsules":checked, "routeSupportRays":checked, "galleryShotProbes":8,"districtCeilings":4,"assayInspectionRays":2,"architectureContactSteps":architecture_contacts, "wallContactSteps":160,"wallContactX":mineral_stop,"conveyorUnderside":conveyor.position.y,"metrics":world.metrics}
 print("GRAVEMILL_PRODUCTION_PHYSICS_OK ", JSON.stringify(result))
 quit()

func triangle_key(points: Array[Vector3]) -> String:
 var keys: Array[String] = []
 for p: Vector3 in points: keys.append("%d,%d,%d" % [roundi(p.x*1000),roundi(p.y*1000),roundi(p.z*1000)])
 keys.sort()
 return "|".join(keys)
