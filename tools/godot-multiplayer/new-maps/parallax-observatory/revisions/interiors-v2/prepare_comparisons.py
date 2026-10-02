"""Prepare native candidate comparisons without mutating accepted art."""
from pathlib import Path
HERE=Path(__file__).resolve().parent
out=HERE/'output'
physics=(out/'physics.gd').read_text()
physics=physics.replace(' var old_art :=', ' Map.Dressing.cleanup(world)\n var old_art :=')
physics=physics.replace(' Map.Dressing.cleanup(world)\n var old_art :=', ' Map.Dressing.cleanup(world)\n world.metrics["dressing"]={"status":"off-for-collision-isolation"}\n var old_art :=')
(out/'physics-current.gd').write_text(physics)
source=(out/'inspection.gd').read_text()
source=source.replace(' var old_art :=', ' Map.Dressing.cleanup(world)\n var old_art :=')
source=source.replace(' world.add_child(candidate_art)', ''' candidate_art.name="BlenderArtNoGameplayCollision"
 world.add_child(candidate_art)
 Map.Dressing.cleanup(world)
 var dressing := Map.Dressing.apply(world,"parallax-observatory",world.geometry_hash)
 assert(dressing.status=="ready" and dressing.errors.is_empty(),JSON.stringify(dressing))''')
start=source.index(' for shot: Dictionary in data.art.cameras:')
end=source.index(' var f := FileAccess.open',start)
source=source[:start]+''' var shots: Array = data.art.cameras.duplicate(true)
 shots.append({"id":"archive-retrieval","eye":[-44,13.65,1],"target":[-34,14.4,7.2]})
 shots.append({"id":"archive-storage","eye":[-29,13.65,-1],"target":[-39,14.3,-7.2]})
 shots.append({"id":"pump-hydraulics","eye":[16,1.65,77],"target":[26,2.2,85.2]})
 shots.append({"id":"archive-portal","eye":[-55,13.65,0],"target":[-35,14,0]})
 shots.append({"id":"pump-portal","eye":[5,1.65,78],"target":[25,2,78]})
 for detail in [0,2]:
  Map.Dressing.set_root_detail(world,detail)
  for shot: Dictionary in shots:
   camera.fov=45 if shot.id=="overview" else 76
   camera.position=world._v(shot.eye)
   camera.look_at(world._v(shot.target))
   for i in range(8): await process_frame
   await RenderingServer.frame_post_draw
   var key: String=shot.id+("-off" if detail==0 else "-full")
   assert(root.get_texture().get_image().save_png(out.path_join(key+".png"))==OK)
   views[key]={"dressing":dressing,"drawCalls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
'''+source[end:]
(out/'comparisons.gd').write_text(source)
