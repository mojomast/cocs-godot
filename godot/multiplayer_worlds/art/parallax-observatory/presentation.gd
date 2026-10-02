extends Node
## Map-specific authored interior light and responsive objective/route guide.
var session: Node
var guide := Label.new()
var help_open := false
var backdrop := ColorRect.new()
var previous_look := {}
var result_winner := ""
func on_results(frame: Dictionary) -> void:
 var winner: Variant=frame.get("state",{}).get("winner")
 result_winner="" if winner==null else str(winner)
func _exit_tree() -> void:
 if is_instance_valid(guide): guide.queue_free()
 if is_instance_valid(backdrop): backdrop.queue_free()
 if is_instance_valid(session):
  session.label.visible=true
  session.combat_label.visible=true
  session.objective_text.visible=true
  if not previous_look.is_empty() and is_instance_valid(session.sun) and is_instance_valid(session.environment):
   session.sun.light_energy=previous_look.sun
   session.environment.environment.background_color=previous_look.background
   session.environment.environment.ambient_light_color=previous_look.ambient
   session.environment.environment.ambient_light_energy=previous_look.energy
func bind(value: Node, data: Dictionary) -> void:
 session=value
 session.client.results.connect(on_results)
 previous_look={"sun":session.sun.light_energy,"background":session.environment.environment.background_color,"ambient":session.environment.environment.ambient_light_color,"energy":session.environment.environment.ambient_light_energy}
 session.sun.light_energy=.6
 session.environment.environment.background_color=Color("46566f")
 session.environment.environment.ambient_light_color=Color("bac7dc")
 session.environment.environment.ambient_light_energy=.45
 for roof: Dictionary in data.arena.overhead:
  for j in [0]:
   var light := OmniLight3D.new()
   light.position=Vector3(roof.x+j*roof.w*.3,roof.minY-.45,roof.z)
   light.light_color=Color("ffdda3")
   light.light_energy=1.2
   light.omni_range=20
   light.shadow_enabled=false
   session.world.add_child(light)
 var panel: VBoxContainer=session.label.get_parent()
 backdrop.color=Color(.018,.027,.045,.86)
 backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.get_parent().add_child(backdrop)
 panel.get_parent().move_child(backdrop,0)
 panel.add_child(guide)
 guide.text="F1 · Observatory route guide"
 for label: Label in [session.label,session.combat_label,session.objective_text,guide]:
  label.custom_minimum_size.x=0
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  label.add_theme_font_size_override("font_size",16)
  label.add_theme_color_override("font_color",Color("fff4dc"))
  label.add_theme_color_override("font_shadow_color",Color.BLACK)
  label.add_theme_constant_override("shadow_offset_x",2)
  label.add_theme_constant_override("shadow_offset_y",2)
func _process(_delta: float) -> void:
 if not is_instance_valid(session): return
 session.label.visible=not help_open
 session.combat_label.visible=not help_open and not session.combat_label.text.is_empty()
 session.objective_text.visible=not help_open and not session.objective_text.text.is_empty()
 if session.phase==3:
  session.label.text="PARALLAX OBSERVATORY · %s\n%s" % [session.selected_mode,session.presentation.hud_text]
 var panel: VBoxContainer=session.label.get_parent()
 panel.size.x=maxf(280,get_viewport().get_visible_rect().size.x-32)
 panel.size.y=panel.get_combined_minimum_size().y
 backdrop.position=panel.position-Vector2(8,6)
 backdrop.size=panel.size+Vector2(16,12)
 if session.phase==4:
  if session.selected_mode=="ctf": session.objective_text.text=session.objective_renderer.hud_text
  elif session.selected_mode in ["koth","uplink","holdout"]: session.objective_text.text="%s · Round complete · %s" % [session.selected_mode, str(session.zones.projection.get("scores",{}))]
  else: session.objective_text.text=session.presentation.hud_text+("\nAuthoritative winner: "+result_winner if not result_winner.is_empty() else "")
func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F1:
  help_open=not help_open
  session.combat_label.visible=not help_open
  session.objective_text.visible=not help_open
  guide.text="PARALLAX OBSERVATORY\nWASD move · Mouse aim/fire · Shift sprint · Space jump\nOchre meridian → lens dais / flags\nNorth: armillary hall +24 m · South: tidal cistern +0 m\nThree crosslinks reconnect the tiers. Sea beyond parapets is lethal.\nF1 closes guide · F12 settings" if help_open else "F1 · Observatory route guide"
  get_viewport().set_input_as_handled()
