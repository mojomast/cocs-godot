extends Node3D
const Catalog = preload("res://multiplayer_worlds/catalog.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")

func _ready() -> void:
 var catalog := Catalog.new()
 if not catalog.open():
  push_error(catalog.error)
  get_tree().quit(2)
  return
 var result := []
 for id in ["breakwater-exchange","thermal-divide","sirocco-circuit","copper-bowl","tern-archipelago"]:
  var data: Dictionary=catalog.recipes[id]
  var arena: Dictionary=data.arena
  var instance := WorldMap.new()
  add_child(instance)
  if not instance.build(data):
   push_error("Could not build " + id)
   get_tree().quit(2)
   return
  await get_tree().physics_frame
  var space := get_world_3d().direct_space_state
  var points := []
  for p: Array in arena.spawns: points.append(Vector2(float(p[0]),float(p[1])))
  for p: Dictionary in arena.get("objectiveZones",[]): points.append(Vector2(float(p.x),float(p.z)))
  for p: Dictionary in arena.get("nodes",[]): points.append(Vector2(float(p.x),float(p.z)))
  for p: Dictionary in arena.get("vehicles",[]): points.append(Vector2(float(p.x),float(p.z)))
  for p: Dictionary in arena.get("flagSpawns",{}).values(): points.append(Vector2(float(p.x),float(p.z)))
  for p: Dictionary in arena.get("race",{}).get("gates",[]): points.append(Vector2(float(p.x),float(p.z)))
  var grounded := 0
  for p: Vector2 in points:
   var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,1.7,p.y),Vector3(p.x,-2,p.y))
   var hit: Dictionary=space.intersect_ray(ray)
   if hit.is_empty() or absf(float(hit.position.y))>0.12:
    push_error("Unmatched gameplay ground " + id + " @" + str(p) + ": " + str(hit))
    get_tree().quit(2)
    return
   grounded+=1
  var roofs := 0
  for box: Dictionary in arena.get("overhead",[]):
   var ray := PhysicsRayQueryParameters3D.create(Vector3(box.x,1.7,box.z),Vector3(box.x,float(box.maxY)+2,box.z))
   var hit: Dictionary=space.intersect_ray(ray)
   if hit.is_empty() or absf(float(hit.position.y)-float(box.minY))>.12:
    push_error("Unmatched overhead " + id + "/" + str(box.id) + ": " + str(hit))
    get_tree().quit(2)
    return
   roofs+=1
  # Player-height review positions and passage approaches: art is non-colliding,
  # but source blocks/overheads must still leave a standing actor clear.
  var passages := {
   "breakwater-exchange":[Vector2(-78,-13),Vector2(-31,41),Vector2(-31,-56)],
   "thermal-divide":[Vector2(-78,-12),Vector2(-49,15),Vector2(-24,39)],
   "sirocco-circuit":[Vector2(-58,-66),Vector2(-20,-93)],
   "copper-bowl":[Vector2(-34,-10),Vector2(40,0)],
   "tern-archipelago":[Vector2(-104,0),Vector2(-64,-55)]
  }
  var clear := 0
  var capsule := CapsuleShape3D.new()
  capsule.radius=.41
  capsule.height=1.7
  for p: Vector2 in passages[id]:
   var floor_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,10,p.y),Vector3(p.x,-3,p.y)))
   if floor_hit.is_empty():
    push_error("No passage floor " + id + " @" + str(p))
    get_tree().quit(2)
    return
   var query := PhysicsShapeQueryParameters3D.new()
   query.shape=capsule
   query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,float(floor_hit.position.y)+.87,p.y))
   if not space.intersect_shape(query,1).is_empty():
    push_error("Blocked player passage " + id + " @" + str(p))
    get_tree().quit(2)
    return
   clear+=1
  if id=="thermal-divide":
   for x in [-40.0,-35.0,-28.0,0.0,28.0,35.0,40.0]:
    var expected: float=clampf((44.0-absf(x))/4.0,0.0,4.0)
    var ray := PhysicsRayQueryParameters3D.create(Vector3(x,7,39),Vector3(x,-2,39))
    var hit: Dictionary=space.intersect_ray(ray)
    if hit.is_empty() or absf(float(hit.position.y)-expected)>.12:
     push_error("Alpine bridge ramp differs from source support x=" + str(x) + " " + str(hit))
     get_tree().quit(2)
     return
  result.append({"id":id,"hash":instance.geometry_hash,"groundProbes":grounded,"overheadProbes":roofs,"passageCapsules":clear,"triangles":instance.metrics.gameplayTriangles})
  remove_child(instance)
  instance.free()
  await get_tree().physics_frame
 print("WORLD_PHYSICS_OK ",JSON.stringify(result))
 get_tree().quit()
