"""FUTURE GRANT ONLY: fresh-read successor master; never touches U or reexports.

Run after the new build and reopen-export. Writes once in NEW revision folder.
"""
import json
import sys
import hashlib
from asset_author import paths,MAPS
from source_scene import k,kit_build,CaptureKit,world_vertices
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main(ident):
    import bpy
    if tuple(bpy.app.version)!=(4,5,14):raise ValueError('Pinned Blender 4.5.14 required')
    out,master=paths(ident);destination=out/'evaluated-proof.json'
    if destination.exists():raise ValueError('Archive successor evidence before measuring another attempt')
    authority=json.loads((out/'authority.json').read_text());bindings=json.loads((out/'bindings.json').read_text())
    reopen=json.loads((out/'reopen-report.json').read_text());glb=out/(ident+'.glb')
    if reopen['glbSha256']!=sha(glb) or reopen['geometryHash']!=authority['geometryHash']:raise ValueError('Stale reopen receipt')
    bpy.ops.wm.open_mainfile(filepath=str(master))
    if bpy.context.scene.get('geometry_hash')!=authority['geometryHash']:raise ValueError('Wrong successor master')
    bpy.data.collections['SOURCE - authority and map-variety kit'].hide_viewport=False
    bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get()
    def point(obj,p):
        v=obj.matrix_world@p;return [v.x,v.z,-v.y]
    def triangles(obj):
        evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        try:return [{'material':mesh.materials[t.material_index].name,
            'vertices':[point(obj,mesh.vertices[i].co) for i in t.vertices]} for t in mesh.loop_triangles]
        finally:evaluated.to_mesh_clear()
    components={}
    for d in authority['arena']['art']['kit']:
        kit=CaptureKit()
        for op in k.expand_kit([d],set(bindings['materials'])):kit_build.create_assembly(kit,op)
        for expected in kit.source.objects:
            obj=bpy.data.objects[expected.name];actual=[point(obj,v.co) for v in obj.data.vertices]
            wanted=world_vertices(expected)
            if len(actual)!=len(wanted) or any(max(abs(a-b) for a,b in zip(p,q))>1e-4 for p,q in zip(actual,wanted)):raise ValueError('Source placement differs '+expected.name)
            if [list(f.vertices) for f in obj.data.polygons]!=[list(f) for f in expected.faces]:raise ValueError('Source winding differs')
            components[expected.name]={'sourceVertices':actual,'evaluated':triangles(obj),'directive':d['id']}
    result={'geometryHash':authority['geometryHash'],'masterSha256':sha(master),'glbSha256':sha(glb),
        'components':components,'exportTriangles':[t for obj in bpy.data.collections['EXPORT - sector/material batches'].objects for t in triangles(obj)],
        'blender':list(bpy.app.version),'scope':'actual successor measurement; native pending'}
    destination.write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n')
if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    if len(args)!=1 or args[0] not in MAPS:raise ValueError('Exact successor map ID required')
    main(args[0])
