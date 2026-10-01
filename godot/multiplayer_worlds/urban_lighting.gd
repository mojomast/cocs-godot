extends Node3D
## Port-scoped local interior lights for the authored sealed urban shop roofs.
## Visuals only; JSON overhead/slab remains the sole collision authority.

func build(arena: Dictionary, market: bool) -> void:
 for slab: Dictionary in arena.get("overhead",[]):
  if not str(slab.id).ends_with("-ceiling"): continue
  var light := OmniLight3D.new()
  light.name = str(slab.id) + "InteriorLamp"
  light.position = Vector3(float(slab.x),float(slab.minY)-.49,float(slab.z))
  light.light_color = Color("ffd6a2") if market else Color("e5f1ff")
  light.light_energy = 1.6
  light.omni_range = 9.0
  light.omni_attenuation = 1.7
  light.shadow_enabled = false
  add_child(light)
