extends Node3D
const Dressing = preload("res://multiplayer_worlds/dressing/binder.gd")
## Only JSON gameplay geometry owns physics. GLB nodes are art-only.
var geometry_hash := ""
var metrics := {}
var mat := {}

func material(kind: String) -> Material:
 if mat.has(kind): return mat[kind]
 var value := StandardMaterial3D.new()
 var colors := {"asphalt":"384650","wet-stone":"3c5964","roof":"777f7c","grating":"776d57","brick":"805e4b","concrete":"a29b89","steel":"45636b"}
 value.albedo_color = Color(colors.get(kind, "888888"))
 value.roughness = 0.78 if kind != "wet-stone" else 0.32
 value.metallic = 0.42 if kind in ["steel", "grating"] else 0.0
 value.cull_mode = BaseMaterial3D.CULL_DISABLED
 mat[kind] = value
 return value

func build(data: Dictionary) -> bool:
 if not data.get("arena") is Dictionary: return false
 var arena: Dictionary = data.arena
 geometry_hash = str(data.get("geometryHash", ""))
 if geometry_hash.length() != 64: return false
 var art_path := "res://multiplayer_worlds/art/" + ("worlds/" if data.has("recipeHash") else "") + str(data.id) + ".glb"
 # World-lane GLBs cover their authored terrain, bridge and overhead slabs.
 # Keep every source triangle as collision, but avoid drawing those same planes
 # twice (the old coplanar roofs flickered into black/white stripes). Urban
 # GLBs contain facades only, so their authority terrain stays visible.
 var art_covers_surfaces: bool = data.has("recipeHash") and arena.get("art") is Dictionary and (arena.get("art",{}) as Dictionary).has("ground") and ResourceLoader.exists(art_path)
 # Reviewed Helix mesh batches include every authoritative terrain surface.
 # Its nested art path and coverage are explicit; legacy worlds stay identical.
 if str(data.id) == "helix-conservatory":
  art_path = "res://multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb"
  art_covers_surfaces = ResourceLoader.exists(art_path)
 set_meta("multiplayer_world",true)
 var markers := Node3D.new()
 markers.name = "StaticPickupMarkers"
 add_child(markers)
 var count := 0
 for block: Dictionary in arena.blocks:
  var size := Vector3(float(block.w),float(block.h)-float(block.get("baseY",0)),float(block.d))
  var center := Vector3(float(block.x),(float(block.h)+float(block.get("baseY",0)))*0.5,float(block.z))
  var body := StaticBody3D.new()
  body.name = str(block.get("id", "Block" + str(count)))
  body.position = center
  var shape := BoxShape3D.new()
  shape.size = size
  var collider := CollisionShape3D.new()
  collider.shape = shape
  body.add_child(collider)
  add_child(body)
  count += 12
 for surface: Dictionary in arena.terrain.surfaces:
  var vertices := PackedVector3Array()
  var normals := PackedVector3Array()
  for indices: Array in surface.triangles:
   var a := _v(surface.vertices[indices[0]])
   var b := _v(surface.vertices[indices[1]])
   var c := _v(surface.vertices[indices[2]])
   var normal := (b-a).cross(c-a).normalized()
   for vertex: Vector3 in [a,b,c]:
    vertices.append(vertex)
    normals.append(normal)
  var arrays: Array = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_NORMAL] = normals
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh.surface_set_material(0,material(str(surface.material)))
  if not art_covers_surfaces:
   var instance := MeshInstance3D.new()
   instance.name = str(surface.id)
   instance.mesh = mesh
   add_child(instance)
  var body := StaticBody3D.new()
  body.name = str(surface.id) + "Collider"
  var shape := ConcavePolygonShape3D.new()
  shape.backface_collision = true
  shape.set_faces(vertices)
  var collision := CollisionShape3D.new()
  collision.shape = shape
  body.add_child(collision)
  add_child(body)
  count += vertices.size()/3
 for wall: Dictionary in arena.terrain.walls:
  var points: Array = wall.vertices
  var faces := PackedVector3Array()
  for i in range(1,points.size()-1):
   for index: int in [0,i,i+1]: faces.append(_v(points[index]))
  var body := StaticBody3D.new()
  body.name = "OverheadSide" + str(count)
  var shape := ConcavePolygonShape3D.new()
  shape.backface_collision = true
  shape.set_faces(faces)
  var collider := CollisionShape3D.new()
  collider.shape = shape
  body.add_child(collider)
  add_child(body)
  count += faces.size()/3
 if ResourceLoader.exists(art_path):
  var scene: Variant = load(art_path)
  if scene is PackedScene:
   var art: Node3D = scene.instantiate()
   art.name = "BlenderArtNoGameplayCollision"
   add_child(art)
 metrics = {"geometryHash":geometry_hash,"gameplayTriangles":count,"art":art_path}
 metrics["dressing"] = Dressing.apply(self, str(data.id), geometry_hash)
 return true

func set_dressing_detail(level: int) -> void:
 Dressing.set_root_detail(self, level)

func _v(value: Array) -> Vector3:
 return Vector3(float(value[0]),float(value[1]),float(value[2]))
