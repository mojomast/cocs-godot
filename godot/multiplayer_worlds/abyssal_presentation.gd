extends RefCounted
## Abyssal-only dry-habitat illumination. No physics or authority participation.
static func attach(world: Node3D, arena: Dictionary) -> void:
 var fixtures := Node3D.new()
 fixtures.name = "AbyssalPressureLighting"
 world.add_child(fixtures)
 for room: Dictionary in arena.structures:
  if not room.has("silhouette"): continue
  var light := OmniLight3D.new()
  light.name = str(room.id)+"NeutralWorklight"
  light.position = Vector3(room.x,room.y+6,room.z)
  light.omni_range = 29
  light.omni_attenuation = .65
  light.light_color = Color("d6e4e4")
  light.light_energy = 1.15
  light.shadow_enabled = false
  fixtures.add_child(light)
 for gallery: Dictionary in arena.routes:
  var a: Array = gallery.points[1]
  var b: Array = gallery.points[2]
  var light := OmniLight3D.new()
  light.name = str(gallery.id)+"GalleryWorklight"
  var floor_y := 10.0
  if gallery.id.begins_with("low-"): floor_y = 3
  elif gallery.id.begins_with("operations-"): floor_y = 20
  elif gallery.id.begins_with("crosslink-0"): floor_y = 7
  elif gallery.id.begins_with("crosslink-1"): floor_y = 15
  light.position = Vector3((a[0]+b[0])*.5,floor_y+4,(a[1]+b[1])*.5)
  light.omni_range = 23
  light.light_energy = .55
  light.light_color = Color("d6e4e4")
  light.shadow_enabled = false
  fixtures.add_child(light)

static func configure(sun: DirectionalLight3D, env: Environment) -> void:
 sun.light_color = Color("a8c1ce")
 sun.light_energy = .28
 env.background_color = Color("081b30")
 env.ambient_light_color = Color("c5d1d6")
 env.ambient_light_energy = .75
