extends SceneTree
## Test-only collision/mesh probe; excluded from production asset closure.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
var out := ""
var failures: Array[String] = []
var contacts: Array = []
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--helix-out="): out = arg.trim_prefix("--helix-out=")
 call_deferred("run")
func check(value: bool, note: String) -> void:
 if not value: failures.append(note); printerr("HELIX_PHYSICS_FAIL ",note)
func shot(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
 return space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b))
func vertex_key(v: Vector3) -> String:
 return "%d,%d,%d" % [roundi(v.x*1000),roundi(v.y*1000),roundi(v.z*1000)]
func triangle_key(a: Vector3,b: Vector3,c: Vector3) -> String:
 var points := [vertex_key(a),vertex_key(b),vertex_key(c)]
 points.sort()
 return "|".join(points)
func count_triangle(target: Dictionary,a: Vector3,b: Vector3,c: Vector3) -> void:
 var key := triangle_key(a,b,c)
 target[key] = int(target.get(key,0))+1
func visual_match(expected: Array, actual: Array) -> Dictionary:
 var buckets := {}
 for i in range(actual.size()):
  var t: Array = actual[i]
  var key := Vector3i(((t[0]+t[1]+t[2])/3.0/.1).floor())
  if not buckets.has(key): buckets[key]=[]
  buckets[key].append(i)
 var used := {}
 var missing := 0
 var error := 0.0
 for t: Array in expected:
  var key := Vector3i(((t[0]+t[1]+t[2])/3.0/.1).floor())
  var found := -1
  for x in range(-1,2):
   for y in range(-1,2):
    for z in range(-1,2):
     for i: int in buckets.get(key+Vector3i(x,y,z),[]):
      if used.has(i) or found>=0: continue
      var largest := 0.0
      for v: Vector3 in t:
       var nearest := INF
       for q: Vector3 in actual[i]: nearest=minf(nearest,v.distance_to(q))
       largest=maxf(largest,nearest)
      if largest<.0001: found=i; error=maxf(error,largest)
  if found<0: missing+=1
  else: used[found]=true
 return {"missing":missing,"extra":actual.size()-used.size(),"maxVertexErrorMetres":error}
func run() -> void:
 var world := WorldMap.new()
 root.add_child(world)
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/helix-conservatory.json"))
 check(world.build(data),"production map builds")
 var expected := {}
 var expected_visual := {}
 var visual_expected_triangles: Array = []
 var visual_actual_triangles: Array = []
 for surface: Dictionary in data.arena.terrain.surfaces:
  for t: Array in surface.triangles: count_triangle(expected,world._v(surface.vertices[t[0]]),world._v(surface.vertices[t[1]]),world._v(surface.vertices[t[2]]))
 for wall: Dictionary in data.arena.terrain.walls: count_triangle(expected,world._v(wall.vertices[0]),world._v(wall.vertices[1]),world._v(wall.vertices[2]))
 for mesh: Dictionary in data.arena.art.meshes:
  for t: Array in mesh.triangles:
   var triangle := [world._v(mesh.vertices[t[0]]),world._v(mesh.vertices[t[1]]),world._v(mesh.vertices[t[2]])]
   visual_expected_triangles.append(triangle)
   count_triangle(expected_visual,triangle[0],triangle[1],triangle[2])
 var native := {}
 var native_visual := {}
 var shapes := 0
 for node: Node in world.find_children("*","CollisionShape3D",true,false):
  shapes+=1
  var faces: PackedVector3Array = node.shape.get_faces()
  for i in range(0,faces.size(),3): count_triangle(native,node.global_transform*faces[i],node.global_transform*faces[i+1],node.global_transform*faces[i+2])
 var mesh_count := 0
 var surface_count := 0
 var visual_triangles := 0
 for node: Node in world.find_children("*","MeshInstance3D",true,false):
  mesh_count+=1
  surface_count+=node.mesh.get_surface_count()
  var faces: PackedVector3Array = node.mesh.get_faces()
  visual_triangles+=faces.size()/3
  if str(node.name).begins_with("wayfinding"): continue
  for i in range(0,faces.size(),3):
   var triangle := [node.global_transform*faces[i],node.global_transform*faces[i+1],node.global_transform*faces[i+2]]
   visual_actual_triangles.append(triangle)
   count_triangle(native_visual,triangle[0],triangle[1],triangle[2])
 check(expected==native,"every production collider triangle matches recipe at millimetre precision")
 # Float32 GLB transforms can cross a decimal rounding boundary even at <20um
 # error. Compare actual vertices within 0.1mm, with one-to-one triangle usage.
 var parity := visual_match(visual_expected_triangles,visual_actual_triangles)
 check(parity.missing==0 and parity.extra==0,"GLB recipe mesh triangles and transforms match within 0.1mm")
 await physics_frame
 var space := world.get_world_3d().direct_space_state
 check(shot(space,Vector3(52,10,-12),Vector3(52,10,12)).is_empty(),"archive portal open")
 check(not shot(space,Vector3(52,10,7),Vector3(42,10,7)).is_empty(),"archive side blocks")
 check(shot(space,Vector3(6,3,4),Vector3(6,3,8)).is_empty(),"glass transmits shot")
 check(not shot(space,Vector3(52,10,0),Vector3(52,20,0)).is_empty(),"vault ceiling blocks")
 for spec in [[Vector3(10.35,0,16),Vector3.RIGHT,13.35],[Vector3(17.65,0,16),Vector3.LEFT,14.65],[Vector3(43.5,7.633142309,7),Vector3.RIGHT,46.5],[Vector3(50.5,8,7),Vector3.LEFT,47.5],[Vector3(84.55146,16,17.753219),Vector3.RIGHT,87.55146],[Vector3(93.95146,16.72876,17.753219),Vector3.LEFT,90.95146]]:
  var body := CharacterBody3D.new()
  body.safe_margin = .001
  var shape := CollisionShape3D.new()
  var capsule := CapsuleShape3D.new()
  capsule.radius = .42
  capsule.height = 1.8
  shape.shape = capsule
  shape.position.y = .9
  body.add_child(shape)
  world.add_child(body)
  body.position = spec[0] + Vector3.UP*.01
  await physics_frame
  for i in range(120):
   body.velocity = spec[1]*7 + Vector3.DOWN*5
   body.move_and_slide()
   await physics_frame
  var gap: float = absf(body.position.x-float(spec[2]))
  check(gap>=.415 and gap<.5,"native body contact " + str(spec[0])+" gap="+str(gap))
  contacts.append({"start":str(spec[0]),"end":str(body.position),"gap":gap,"frames":120})
  body.queue_free()
  await physics_frame
 var report := {"geometryHash":world.geometry_hash,"collisionShapes":shapes,"uniqueCollisionTriangles":native.size(),"meshNodes":mesh_count,"meshSurfaces":surface_count,"visualTriangles":visual_triangles,"visualParity":parity,"contacts":contacts,"failures":failures}
 var file := FileAccess.open(out.path_join("native-physics.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("HELIX_PHYSICS ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
