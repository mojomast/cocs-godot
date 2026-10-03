extends SceneTree
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func require(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func v(p: Array) -> Vector3: return Vector3(p[0],p[1],p[2])
func run() -> void:
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/abyssal-pressureworks.json"))
 var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/new_maps/abyssal_pressureworks/source-probes.json"))
 require(probes.geometryHash==data.geometryHash,"exact probe identity")
 var world := Node3D.new()
 root.add_child(world)
 var geometry := Node3D.new()
 geometry.set_script(load("res://multiplayer_worlds/map.gd"))
 world.add_child(geometry)
 require(geometry.build(data),"native world build")
 await physics_frame
 await physics_frame
 var space := world.get_world_3d().direct_space_state
 for p: Dictionary in probes.support:
  var origin := Vector3(p.x,p.y+.2,p.z)
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*.4))
  require(not hit.is_empty(),"missing support "+str(p))
  if not hit.is_empty(): require(absf(hit.position.y-p.y)<.025,"different support "+str(p))
 for p: Dictionary in probes.rays:
  var query := PhysicsRayQueryParameters3D.create(v(p.from),v(p.from)+v(p.dir)*p.length)
  query.hit_back_faces = true
  var hit := space.intersect_ray(query)
  var distance: float = v(p.from).distance_to(hit.position) if not hit.is_empty() else float(p.length)
  require(absf(distance-p.distance)<.06,str(p.id)+" source/native ray disagreement")
 var contacts: Array = []
 for p: Dictionary in probes.bodies:
  var body := CharacterBody3D.new()
  var collision := CollisionShape3D.new()
  var capsule := CapsuleShape3D.new()
  capsule.radius = .42
  capsule.height = 1.7
  collision.shape = capsule
  body.add_child(collision)
  world.add_child(body)
  body.position = v(p.from)
  await physics_frame
  var impacts := 0
  for frame in range(p.ticks):
   if body.move_and_collide(v(p.dir)*.04)!=null: impacts += 1
  var travelled := body.position.distance_to(v(p.from))
  require(impacts>20 if p.kind!="portal" else impacts==0,str(p.id)+" body contact")
  if p.kind=="portal": require(travelled>7,"portal journey distance")
  contacts.append({"id":p.id,"kind":p.kind,"impacts":impacts,"travelled":travelled})
  body.queue_free()
  await physics_frame
 var report := {"geometryHash":data.geometryHash,"supportSamples":probes.support.size(),"rays":probes.rays.size(),"bodies":contacts,"failures":failures}
 var file := FileAccess.open(OS.get_environment("ASSET_STAGE_EVIDENCE").path_join("collision.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("ABYSSAL_COLLISION ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
