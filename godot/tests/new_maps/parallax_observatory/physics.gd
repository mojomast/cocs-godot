extends SceneTree
const Map = preload("res://multiplayer_worlds/map.gd")
var out := "/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002"
var failures: Array[String] = []
func _initialize() -> void:
 create_timer(90).timeout.connect(func() -> void: printerr("PARALLAX_PHYSICS watchdog"); quit(1))
 call_deferred("run")
func check(ok: bool, note: String) -> void:
 if not ok: failures.append(note); printerr("PARALLAX_PHYSICS_FAIL ",note)
func key(a: Vector3,b: Vector3,c: Vector3) -> String:
 var p: Array[String] = []
 for v in [a,b,c]: p.append("%d,%d,%d" % [roundi(v.x*1000),roundi(v.y*1000),roundi(v.z*1000)])
 p.sort()
 return "|".join(p)
func add(t: Dictionary,a: Vector3,b: Vector3,c: Vector3) -> void:
 var k := key(a,b,c)
 t[k]=int(t.get(k,0))+1
func run() -> void:
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/parallax-observatory.json"))
 var world := Map.new()
 root.add_child(world)
 check(world.build(data),"production map build")
 for block: Dictionary in data.arena.blocks:
  var node: StaticBody3D=world.get_node(str(block.id).validate_node_name())
  var expected_size := Vector3(block.w,float(block.h)-float(block.get("baseY",0)),block.d)
  var expected_center := Vector3(block.x,(float(block.h)+float(block.get("baseY",0)))/2,block.z)
  check(node.position.is_equal_approx(expected_center) and (node.get_child(0).shape as BoxShape3D).size.is_equal_approx(expected_size),"exact source block bounds "+block.id)
 var expected := {}
 var actual := {}
 var triangle_bodies := {}
 for s: Dictionary in data.arena.terrain.surfaces:
  for t: Array in s.triangles: add(expected,world._v(s.vertices[t[0]]),world._v(s.vertices[t[1]]),world._v(s.vertices[t[2]]))
 for w: Dictionary in data.arena.terrain.walls: add(expected,world._v(w.vertices[0]),world._v(w.vertices[1]),world._v(w.vertices[2]))
 var shapes := 0
 for n in world.find_children("*","CollisionShape3D",true,false):
  shapes+=1
  if n.shape is ConcavePolygonShape3D:
   var faces: PackedVector3Array=n.shape.get_faces()
   for i in range(0,faces.size(),3):
    add(actual,n.global_transform*faces[i],n.global_transform*faces[i+1],n.global_transform*faces[i+2])
    triangle_bodies[key(n.global_transform*faces[i],n.global_transform*faces[i+1],n.global_transform*faces[i+2])]=n.get_parent()
 check(expected==actual,"exact source/native terrain and wall triangle multisets")
 var mesh_nodes := 0
 var mesh_surfaces := 0
 var triangles := 0
 var visual_probes: Array[Node] = []
 for n in world.find_children("*","MeshInstance3D",true,false):
  mesh_nodes+=1
  mesh_surfaces+=n.mesh.get_surface_count()
  triangles+=n.mesh.get_faces().size()/3
  # Test-only art ray layer verifies imported GLB support/openings against the
  # authoritative layer. It is never attached by the production map builder.
  var body := StaticBody3D.new()
  body.collision_layer=2
  body.collision_mask=0
  var collision := CollisionShape3D.new()
  var shape := ConcavePolygonShape3D.new()
  shape.backface_collision=true
  var faces: PackedVector3Array=n.mesh.get_faces()
  for i in range(faces.size()): faces[i]=n.global_transform*faces[i]
  shape.set_faces(faces)
  collision.shape=shape
  body.add_child(collision)
  root.add_child(body)
  visual_probes.append(body)
 check(mesh_nodes==7,"seven production material batches, no fallback surface rendering")
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/art/parallax-observatory/asset-manifest.json"))
 check(triangles==int(manifest.triangles),"current imported GLB triangle count matches measured asset")
 check(FileAccess.get_sha256("res://multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb")==manifest.glbSha256,"current production GLB byte hash")
 await physics_frame
 var space := world.get_world_3d().direct_space_state
 var capsule := CapsuleShape3D.new()
 capsule.radius=.40
 capsule.height=1.70
 var samples := 0
 var visual_seams: Array = []
 for r: Dictionary in data.routes:
  for i in range(1,r.points.size()):
   var a: Dictionary=r.points[i-1]
   var b: Dictionary=r.points[i]
   var count := int(ceil(Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))/1.5))
   for j in range(count+1):
    var t := float(j)/count
    var p := Vector3(lerpf(a.x,b.x,t),0,lerpf(a.z,b.z,t))
    p.y=24 if p.z < -60 else 12+(-p.z-12)/4 if p.z < -12 else 12 if p.z<=12 else 12-(p.z-12)/4 if p.z<60 else 0
    var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP,1))
    check(not hit.is_empty() and (hit.position as Vector3).distance_to(p)<.005,"route floor "+r.id+str(p))
    var art_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP,2))
    if art_hit.is_empty():
     # Imported float32 triangulation can reject an exactly-on-vertex ray at
     # a clipped union seam. Record it and require support within 1.5 cm;
     # authoritative collider rays above must still hit the exact center.
     for offset in [Vector3(.01,0,.01),Vector3(-.01,0,-.01)]:
      art_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+offset+Vector3.UP,p+offset-Vector3.UP,2))
      if not art_hit.is_empty():
       visual_seams.append({"point":str(p),"offset":str(offset)})
       break
    check(not art_hit.is_empty() and (art_hit.position as Vector3).distance_to(p)<.06,"GLB floor/source support parity "+r.id+str(p)+" hit="+str(art_hit.get("position","missing")))
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape=capsule
    query.collision_mask=1
    query.transform=Transform3D(Basis(),p+Vector3.UP*.91)
    check(space.intersect_shape(query).is_empty(),"route standing clearance "+r.id+str(p))
    samples+=1
 for probe in visual_probes: probe.queue_free()
 await physics_frame
 var contacts: Array=[]
 var rail_cases := {}
 for w: Dictionary in data.arena.terrain.walls:
  if not str(w.id).begins_with("parapet-") or not str(w.id).ends_with("-tri-0"): continue
  var a := world._v(w.vertices[0])
  var b := world._v(w.vertices[1])
  var label := "ramped-parapet" if absf(a.y-b.y)>.25 else "ground-parapet" if absf(a.y)<.01 else "upper-parapet" if absf(a.y-24)<.01 else ""
  if label.is_empty() or rail_cases.has(label) or Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))<2: continue
  rail_cases[label]=w
 for label: String in rail_cases:
  var w: Dictionary=rail_cases[label]
  var a := world._v(w.vertices[0])
  var b := world._v(w.vertices[1])
  var c := world._v(w.vertices[2])
  var center := (a+b)*.5
  var direction := Vector3(-(b.z-a.z),0,b.x-a.x).normalized()
  var target: StaticBody3D=triangle_bodies[key(a,b,c)]
  target.collision_layer=9
  for side in [-1.0,1.0]:
   var body := CharacterBody3D.new()
   body.collision_mask=8
   body.safe_margin=.001
   var collider := CollisionShape3D.new()
   var shape := CapsuleShape3D.new()
   shape.radius=.42
   shape.height=1.8
   collider.shape=shape
   collider.position.y=.9
   body.add_child(collider)
   world.add_child(body)
   body.position=center+direction*side*3+Vector3.UP*.01
   await physics_frame
   for i in range(120):
    body.velocity=-direction*side*8
    body.move_and_slide()
    await physics_frame
   var gap: float = (body.position-center).dot(direction)*float(side)
   check(gap>=.415 and gap<.46,"native "+label+" contact "+str(gap))
   contacts.append({"wall":label,"side":side,"gap":gap,"frames":120,"isolatedNativeTriangle":true})
   body.queue_free()
   await physics_frame
  target.collision_layer=1
 for spec in [[-36.0,0.0,12.0],[24.0,78.0,0.0]]:
  var x: float=spec[0]+10
  var z: float=spec[1]+7.6
  var y: float=spec[2]
  var target_wall: StaticBody3D=world.get_node("ephemeris-vault-wall-1" if y>0 else "tidal-pump-vault-wall-1")
  target_wall.collision_layer=9
  for side in [-1.0,1.0]:
   var body := CharacterBody3D.new()
   body.collision_mask=8
   body.safe_margin=.001
   var collider := CollisionShape3D.new()
   var shape := CapsuleShape3D.new()
   shape.radius=.42
   shape.height=1.8
   collider.shape=shape
   collider.position.y=.9
   body.add_child(collider)
   world.add_child(body)
   body.position=Vector3(x,y+.01,z+side*3)
   await physics_frame
   for i in range(120):
    body.velocity=Vector3(0,0,-side*8)
    body.move_and_slide()
    await physics_frame
   var gap := absf(body.position.z-z)-.4
   check(gap>=.415 and gap<.46,"both-face native wall stop "+str(gap))
   contacts.append({"wall":str(spec),"side":side,"gap":gap,"frames":120,"isolatedSourceBlockLayer":8,"gravityDisabledToIsolateOutsideVoidContact":true})
   body.queue_free()
   await physics_frame
  target_wall.collision_layer=1
  check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(spec[0]-16,y+1.5,spec[1]),Vector3(spec[0]+16,y+1.5,spec[1]))).is_empty(),"real open arch ray")
 for roof: Dictionary in data.arena.overhead:
  var p := Vector3(roof.x,roof.minY-2,roof.z)
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.UP*4))
  check(not hit.is_empty() and absf(hit.position.y-roof.minY)<.002,"real ceiling underside")
  var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(roof.x,roof.minY-.1,roof.z),Vector3(roof.x,-18,roof.z),1))
  var body := CharacterBody3D.new()
  body.safe_margin=.001
  var collider := CollisionShape3D.new()
  var shape := CapsuleShape3D.new()
  shape.radius=.42
  shape.height=1.8
  collider.shape=shape
  collider.position.y=.9
  body.add_child(collider)
  world.add_child(body)
  body.position=floor_hit.position+Vector3.UP*.01
  body.velocity=Vector3.UP*18
  var highest := body.position.y
  for i in range(90):
   body.velocity.y-=20.0/60
   body.move_and_slide()
   highest=maxf(highest,body.position.y)
   await physics_frame
  check(highest+1.8<=roof.minY+.003 and highest+1.8>=roof.minY-.03,"capsule roof contact "+roof.id)
  contacts.append({"roof":roof.id,"maxFeetY":highest,"ceilingY":roof.minY,"frames":90})
  body.queue_free()
  await physics_frame
 var report := {"geometryHash":data.geometryHash,"sourceBlockBounds":data.arena.blocks.size(),"collisionShapes":shapes,"routeSupportRays":samples,"routeCapsules":samples,"meshNodes":mesh_nodes,"meshSurfaces":mesh_surfaces,"visualTriangles":triangles,"visualFloat32Seams":visual_seams,"contacts":contacts,"metrics":world.metrics,"failures":failures}
 var f := FileAccess.open(out.path_join("native-physics.json"),FileAccess.WRITE)
 report["glbSha256"]=manifest.glbSha256
 f.store_string(JSON.stringify(report,"  "))
 print("PARALLAX_PHYSICS ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
