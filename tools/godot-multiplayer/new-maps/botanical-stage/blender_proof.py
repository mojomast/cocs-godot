"""FUTURE GRANT ONLY: reopen the packed candidate and dump measured topology.

Run after asset_author.py build; this saves matched inspection cameras into the
candidate master, then performs fresh reopen-export. No accepted files touched.
"""
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from config import HERE, DEST, MAPS, entry, read, write, sha

def run(map_id):
    import bpy
    from mathutils import Vector
    if bpy.app.version[:3] != (4,5,14):raise ValueError('Pinned Blender 4.5.14 required')
    author,data,_,_,_=entry(map_id)
    evidence=HERE/'evidence'/map_id
    evidence.mkdir(parents=True,exist_ok=True)
    build=read(author.REPORT)
    if build.get('geometryHash')!=data['geometryHash'] or 'files' not in build:raise ValueError('Fresh build receipt required')
    for path,digest in build['files'].items():
        from config import ROOT
        if sha(ROOT/path)!=digest:raise ValueError('Build artifact changed: '+path)
    write(evidence/'build-report.json',build)
    bpy.ops.wm.open_mainfile(filepath=str(author.MASTER))
    scene=bpy.context.scene
    if scene['geometry_hash']!=data['geometryHash']:raise ValueError('Stale master')
    collection=bpy.data.collections.new('Botanical matched native inspection cameras')
    scene.collection.children.link(collection)
    cameras=read(DEST/(map_id+'-cameras.json'))['cameras']
    for view in cameras:
        camera=bpy.data.cameras.new('native-'+view['id']);camera.type='PERSP'
        camera.lens=36/(2*__import__('math').tan(__import__('math').radians(view['fov'])/2));camera.sensor_width=36;camera.sensor_fit='HORIZONTAL'
        obj=bpy.data.objects.new(camera.name,camera);collection.objects.link(obj)
        obj.location=(view['eye'][0],-view['eye'][2],view['eye'][1])
        target=Vector((view['target'][0],-view['target'][2],view['target'][1]))
        obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler();camera.clip_end=2000
        obj['camera_lineage']=json.dumps(view)
    bpy.ops.wm.save_as_mainfile(filepath=str(author.MASTER))
    import kit_build
    reopened=kit_build.reopen_export(author.ROOT,author.MASTER,author.EXPORT,author.REPORT,author.AUTHORITY)
    write(evidence/'reopen-report.json',reopened)
    depsgraph=bpy.context.evaluated_depsgraph_get()
    def point(obj,v):
        p=obj.matrix_world@v
        return [float(p.x),float(p.z),float(-p.y)]
    def triangles(obj):
        evaluated=obj.evaluated_get(depsgraph);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        try:return [{'material':mesh.materials[t.material_index].name,
                     'vertices':[point(obj,mesh.vertices[i].co) for i in t.vertices]} for t in mesh.loop_triangles]
        finally:evaluated.to_mesh_clear()
    exports=[row for obj in bpy.data.collections['EXPORT - sector/material batches'].objects for row in triangles(obj)]
    components={}
    from source_geometry import CaptureKit,world_vertices
    import kit_expander
    arena=data['arena'];bindings=read(author.BINDINGS)
    for directive in arena['art']['kit']:
        kit=CaptureKit()
        for op in kit_expander.expand_kit([directive],set(bindings['materials'])):kit_build.create_assembly(kit,op)
        for expected in kit.source.objects:
            obj=bpy.data.objects.get(expected.name)
            if obj is None:raise ValueError('Missing source component '+expected.name)
            actual=[point(obj,v.co) for v in obj.data.vertices];wanted=world_vertices(expected)
            if len(actual)!=len(wanted) or any(max(abs(a-b) for a,b in zip(p,q))>1e-4 for p,q in zip(actual,wanted)):
                raise ValueError('Source component world transform differs '+expected.name)
            if [list(p.vertices) for p in obj.data.polygons]!=[list(f) for f in expected.faces]:raise ValueError('Source component winding differs')
            components[expected.name]={'directive':directive['id'],'class':directive['class'],
                'sourceVertices':actual,'sourceFaces':[list(f) for f in expected.faces],
                'material':expected.material,'evaluated':triangles(obj)}
    write(evidence/'evaluated.json',{'geometryHash':data['geometryHash'],
        'masterSha256':sha(author.MASTER),'glbSha256':sha(author.EXPORT),'blender':list(bpy.app.version),
        'cameras':cameras,'exportTriangles':exports,'components':components})

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    if len(args)!=1 or args[0] not in MAPS:raise ValueError('Expected exact botanical map ID')
    run(args[0])
