extends Node3D
## Native collision contract for the two refined urban recipes, no art collider.
const Catalog = preload("res://multiplayer_worlds/catalog.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")

func probe(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, expected: float, id: String) -> void:
 var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
 if hit.is_empty() or absf(float(hit.position.y)-expected)>.07:
  push_error("Urban collision " + id + " expected y=" + str(expected) + " got " + str(hit))
  get_tree().quit(2)

func clearance(space: PhysicsDirectSpaceState3D, floor_position: Vector3, id: String) -> void:
 var capsule := CapsuleShape3D.new()
 capsule.radius = .41
 capsule.height = 1.7
 var support: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_position+Vector3(0,2,0),floor_position-Vector3(0,1,0)))
 if support.is_empty():
  push_error("Urban actor has no floor " + id)
  get_tree().quit(2)
  return
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = capsule
 query.transform = Transform3D(Basis.IDENTITY,Vector3(floor_position.x,float(support.position.y)+.87,floor_position.z))
 if not space.intersect_shape(query,1).is_empty():
  push_error("Urban actor clearance " + id + " at " + str(floor_position))
  get_tree().quit(2)

func _ready() -> void:
 var catalog := Catalog.new()
 if not catalog.open():
  push_error(catalog.error)
  get_tree().quit(2)
  return
 var rows := []
 for id in ["switchyard-ward","rainmarket-exchange"]:
  var data: Dictionary = catalog.recipes[id]
  var arena: Dictionary = data.arena
  var world := WorldMap.new()
  add_child(world)
  if not world.build(data):
   push_error("Urban map did not build " + id)
   get_tree().quit(2)
   return
  await get_tree().physics_frame
  var space := get_world_3d().direct_space_state
  var ground := 0
  for pair: Array in arena.spawns:
   probe(space,Vector3(pair[0],2,pair[1]),Vector3(pair[0],-2,pair[1]),0,id + " spawn " + str(pair))
   ground+=1
  for zone: Dictionary in arena.objectiveZones:
   probe(space,Vector3(zone.x,2,zone.z),Vector3(zone.x,-2,zone.z),float(zone.y),id + " objective " + str(zone.id))
   ground+=1
  var curbs := 0
  var roofs := 0
  var ramps := 0
  for surface: Dictionary in arena.terrain.surfaces:
   var vertices: Array = surface.vertices
   var center := (Vector3(vertices[0][0],vertices[0][1],vertices[0][2])+Vector3(vertices[2][0],vertices[2][1],vertices[2][2]))/2
   if "sidewalk" in surface.id or "promenade" in surface.id or "boardwalk" in surface.id:
    probe(space,center+Vector3(0,1,0),center-Vector3(0,1,0),.12,id + " curb " + surface.id)
    clearance(space,center,id + " curb walk " + surface.id)
    curbs+=1
   if surface.walkable and ("roof" in surface.id or "overlook" in surface.id):
    probe(space,center+Vector3(0,2,0),center-Vector3(0,2,0),center.y,id + " roof " + surface.id)
    roofs+=1
   if "ramp" in surface.id:
    probe(space,center+Vector3(0,1,0),center-Vector3(0,1,0),center.y,id + " ramp " + surface.id)
    clearance(space,center,id + " ramp walk " + surface.id)
    ramps+=1
  var counters := 0
  var guards := 0
  var ceilings := 0
  var doors := 0
  var actor_points := 0
  var entries := {"switchyard-ward":[[-18.0,0.0,5.5,0.0],[18.0,0.0,-5.5,0.0],[0.0,-24.0,0.0,-4.5],[0.0,24.0,0.0,4.5]],
   "rainmarket-exchange":[[26.0,19.0,-6.5,0.0],[-25.0,20.0,6.0,0.0],[11.0,-25.0,0.0,-5.5],[28.0,-17.0,-6.0,0.0]]}
  for door: Array in entries[id]:
   var x: float = float(door[0])
   var z: float = float(door[1])
   var dx: float = float(door[2])
   var dz: float = float(door[3])
   var opening := Vector3(x+dx,0,z+dz)
   for offset: float in [-1.0,0.0,1.0]:
    var point := opening + Vector3(-signf(dx)*offset,0,-signf(dz)*offset)
    clearance(space,point,id + " door " + str(door) + "/" + str(offset))
    actor_points+=1
   doors+=1
  for surface: Dictionary in arena.terrain.surfaces:
   if surface.walkable and ("roof" in surface.id or "overlook" in surface.id):
    var v: Array = surface.vertices
    var middle := (Vector3(v[0][0],v[0][1],v[0][2])+Vector3(v[2][0],v[2][1],v[2][2]))/2
    clearance(space,middle,id + " accessible roof " + surface.id)
    actor_points+=1
  for slab: Dictionary in arena.overhead:
   var x: float = float(slab.x)
   var z: float = float(slab.z)
   probe(space,Vector3(x,2,z),Vector3(x,-1,z),0,id + " shop interior floor " + slab.id)
   probe(space,Vector3(x,1,z),Vector3(x,5,z),float(slab.minY),id + " sealed underside " + slab.id)
   probe(space,Vector3(x,6,z),Vector3(x,3,z),float(slab.maxY),id + " sealed roof top " + slab.id)
   clearance(space,Vector3(x,0,z),id + " standing inside " + slab.id)
   ceilings+=1
  for block: Dictionary in arena.blocks:
   if "-counter-" in block.id:
    probe(space,Vector3(block.x,block.h+1,block.z),Vector3(block.x,block.h-.5,block.z),block.h,id + " counter " + block.id)
    counters+=1
   if "-guard-" in block.id:
    probe(space,Vector3(block.x,block.h+1,block.z),Vector3(block.x,block.baseY+.2,block.z),block.h,id + " guard " + block.id)
    var horizontal := Vector3(0,0,1) if float(block.w)>float(block.d) else Vector3(1,0,0)
    var middle := Vector3(block.x,float(block.baseY)+.35,block.z)
    var side_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(middle-horizontal*.6,middle+horizontal*.6))
    if side_hit.is_empty() or not str(side_hit.collider.name).contains("guard"):
     push_error("Urban roof guard side collision missing " + id + "/" + str(block.id))
     get_tree().quit(2)
     return
    guards+=1
  rows.append({"id":id,"hash":world.geometry_hash,"ground":ground,"curbs":curbs,"roofs":roofs,"ramps":ramps,"counters":counters,"guards":guards,"doors":doors,"sealedShopCeilings":ceilings,"actorClearancePoints":actor_points})
  remove_child(world)
  world.free()
  await get_tree().physics_frame
 print("URBAN_PHYSICS_OK ",JSON.stringify(rows))
 get_tree().quit(0)
