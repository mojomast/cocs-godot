extends SceneTree
## Grant-only native/source collider comparison. Never uses GLB as authority.
var failures: Array[String] = []

func _initialize() -> void:
 call_deferred("run")

func require(value: bool, message: String) -> void:
 if not value: failures.append(message)

func run() -> void:
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/vesper-viaduct.json"))
 var world := Node3D.new()
 root.add_child(world)
 var geometry := Node3D.new()
 geometry.set_script(load("res://multiplayer_worlds/map.gd"))
 world.add_child(geometry)
 require(geometry.build(data), "map build")
 await physics_frame
 await physics_frame
 var space := world.get_world_3d().direct_space_state
 var cases := [
  ["tall wall", Vector3(-94,14,-10), Vector3.RIGHT, 10.0, 4.0],
  ["sill", Vector3(-66,12.6,-18), Vector3.BACK, 10.0, 3.0],
  ["open window", Vector3(-63,14,-18), Vector3.BACK, 6.0, -1.0],
  ["open doorway", Vector3(-94,14,0), Vector3.RIGHT, 12.0, -1.0],
  ["roof underside", Vector3(-66,14,0), Vector3.UP, 30.0, 11.0],
  ["canal void", Vector3(0,2,-110), Vector3.DOWN, 10.0, -1.0],
  ["supported bridge", Vector3(-100,2,-110), Vector3.DOWN, 10.0, 2.0]
 ]
 for p: Dictionary in data.spawnPoints:
  cases.append(["spawn support",Vector3(p.x,p.y+2,p.z),Vector3.DOWN,3.0,2.0])
 for row: Array in cases:
  var origin: Vector3 = row[1]
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+row[2]*row[3]))
  if row[4] < 0:
   require(hit.is_empty(), str(row[0])+" unexpectedly blocked")
  else:
   require(not hit.is_empty(),str(row[0])+" missing collision")
   if not hit.is_empty(): require(abs(origin.distance_to(hit.position)-float(row[4])) < 0.06,str(row[0])+" differs from source ray")
 var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/new_maps/vesper_viaduct/source-probes.json"))
 require(probes.geometryHash == data.geometryHash,"route probe identity")
 for point: Dictionary in probes.support:
  var origin := Vector3(point.x,point.y+.25,point.z)
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN))
  require(not hit.is_empty(),"route missing floor "+str(point))
  if not hit.is_empty(): require(abs(float(hit.position.y)-float(point.y))<.025,"route floor disagreement "+str(point))
 var contacts: Array = []
 for item: Array in [["tall-wall",Vector3(-94,12.85,-10),Vector3.RIGHT],["open-door",Vector3(-94,12.85,0),Vector3.RIGHT],["ceiling",Vector3(-66,14,0),Vector3.UP]]:
  var actor := CharacterBody3D.new()
  var shape := CollisionShape3D.new()
  var capsule := CapsuleShape3D.new()
  capsule.radius = .42
  capsule.height = 1.7
  shape.shape = capsule
  actor.add_child(shape)
  world.add_child(actor)
  actor.position = item[1]
  await physics_frame
  var impacts := 0
  for tick in range(360):
   var hit := actor.move_and_collide(item[2]*.04)
   if hit != null: impacts += 1
  if item[0] == "tall-wall": require(actor.position.x < -90 and impacts>100,"sustained native tall-wall body contact")
  if item[0] == "open-door": require(actor.position.x > -88 and impacts==0,"native body doorway closed")
  if item[0] == "ceiling": require(actor.position.y < 24.6 and impacts>0,"native body roof contact")
  contacts.append({"id":item[0],"position":str(actor.position),"impacts":impacts})
  actor.queue_free()
  await physics_frame
 print(JSON.stringify({"gate":"vesper-native-source-rays","cases":cases.size(),"routeSupports":probes.support.size(),"bodyContacts":contacts,"failures":failures,"geometryHash":data.geometryHash}))
 quit(0 if failures.is_empty() else 1)
