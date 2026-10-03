"""Ground-rooted named attachment graph; frozen-U negative and successor math."""
import json
import math
import unittest
import subprocess
from source_scene import ROOT,load,k,kit_build,CaptureKit,world_vertices
from geometry import RayIndex,glb_triangles,TriangleInventory
from capsule import segment_triangle,Capsules

def components(arena):
    bindings=json.loads((ROOT/'tools/godot-multiplayer/new-maps/helix-conservatory/variety_bindings.json').read_text())
    kit=CaptureKit()
    for op in k.expand_kit([d for d in arena['art']['kit'] if d['id']=='greenhouse-frame-v4'],set(bindings['materials'])):
        kit_build.create_assembly(kit,op)
    return {o.name:o for o in kit.source.objects}

def attachments(arena,measured=None,tolerance=1e-8):
    """Executable named contract, reusable with future measured component verts.

    Every end face must bear on its OWN full-width post, not just be near an
    unrelated mesh. Longitudinal eaves and ridge pass through each named joint.
    """
    specs=arena['art']['greenhouseAttachments'];objects=components(arena)
    verts=lambda obj:measured[obj.name] if measured is not None else world_vertices(obj)
    directive=next(d for d in arena['art']['kit'] if d['id']==specs['assembly'])
    p=directive['params'];ground=specs['groundY'];spring=ground+p['spring']
    result=[];edges=[]
    for member in specs['members']:
        angle=math.radians(member['angle']);u=[math.cos(angle),math.sin(angle)];t=[-u[1],u[0]]
        rib=objects[member['rib']];vertices=verts(rib)
        for side,index in [(-1,0),(1,1)]:
            post=objects[member['posts'][index]];pv=verts(post)
            r=p['radius']+side*(p['inner']+p['outer'])/2
            center=[r*u[0],spring,r*u[1]]
            end=[v for v in vertices if abs(v[1]-spring)<tolerance and
                (v[0]*u[0]+v[2]*u[1]-p['radius'])*side>0]
            assert len(end)==4,'Missing entire rib end cross-section'
            assert abs(min(v[1] for v in pv)-ground)<tolerance
            assert abs(max(v[1] for v in pv)-(spring+.02))<tolerance
            # Full radial width and tangential depth lie inside the post section.
            for v in end:
                delta=[v[0]-center[0],v[2]-center[2]]
                assert abs(sum(x*y for x,y in zip(delta,u)))<=(p['outer']-p['inner'])/2+tolerance
                assert abs(sum(x*y for x,y in zip(delta,t)))<=(p['depth']+.2)/2+tolerance
            # The actual post vertices, not only recipe parameters, have these
            # section extents after the full compound world transform.
            for axis,width in [(u,p['outer']-p['inner']),(t,p['depth']+.2)]:
                coords=[(v[0]-center[0])*axis[0]+(v[2]-center[2])*axis[1] for v in pv]
                assert abs(min(coords)+width/2)<tolerance and abs(max(coords)-width/2)<tolerance
            eave=objects[member['eaves'][index]]
            ev=verts(eave)
            # Kit pipe has one ring per angle; its ring centre is the joint.
            j=specs['members'].index(member);ring=ev[j*10:(j+1)*10]
            ring_center=[sum(v[k] for v in ring)/10 for k in range(3)]
            assert math.dist(ring_center,center)<tolerance,'Eave misses intended joint'
            result.append({'rib':rib.name,'post':post.name,'eave':eave.name,'center':center,
                'endCrossSection':end,'postVertices':pv,'groundY':ground,'bearingOverlap':.02})
            edges.extend([(rib.name,post.name),(post.name,'ground'),(rib.name,eave.name)])
        ridge=objects[member['ridge']];rv=verts(ridge);j=specs['members'].index(member)
        crown=[p['radius']*u[0],spring+(p['inner']+p['outer'])/2,p['radius']*u[1]]
        ring_center=[sum(v[i] for v in rv[j*10:(j+1)*10])/10 for i in range(3)]
        assert math.dist(ring_center,crown)<tolerance,'Ridge misses named arch crown'
        # Crown ring radius .18 lies strictly inside the .8m rib section and .6m depth.
        assert .18<(p['outer']-p['inner'])/2 and .18<p['depth']/2
        edges.append((rib.name,ridge.name))
    reachable={'ground'}
    for _ in range(len(objects)):
        for a,b in edges:
            if a in reachable or b in reachable:reachable.update([a,b])
    assert set(objects)<=reachable,'Floating component in intended attachment graph'
    return result,edges

class GreenhouseTests(unittest.TestCase):
    def test_U_actual_outer_end_is_floating(self):
        # Independent review's exact outer endpoint. Exclude actual triangles
        # of this rib, preserving every other real scene primitive.
        root=ROOT/'tools/godot-multiplayer/new-maps/botanical-stage/evidence/helix-conservatory'
        measured=json.loads((root/'evaluated.json').read_text())
        rows=glb_triangles((ROOT/'port/new-maps/helix-conservatory/variety/revision-3/helix-conservatory.glb').read_bytes())
        inventory=TriangleInventory(rows);gaps=[]
        bounds=[([min(v[k] for v in r['vertices']) for k in range(3)],
                 [max(v[k] for v in r['vertices']) for k in range(3)]) for r in rows]
        for angle in [70,76,82,88,94]:
            c=measured['components'][f'greenhouse-rib-{angle}']
            excluded=set(inventory.match(c['evaluated']))
            a=math.radians(angle)
            for side in [-1,1]:
                p=[87*math.cos(a)-side*13.8*math.sin(a),24.8,87*math.sin(a)+side*13.8*math.cos(a)]
                best=float('inf')
                for i,row in enumerate(rows):
                    if i in excluded:continue
                    lo,hi=bounds[i]
                    lower=math.sqrt(sum(max(lo[k]-p[k],0,p[k]-hi[k])**2 for k in range(3)))
                    if lower<best:best=min(best,segment_triangle(p,p,row['vertices']))
                gaps.append(best)
        self.assertEqual(sum(g>.04 for g in gaps),6,str(gaps))
        self.assertGreater(gaps[0],8.7);self.assertLess(gaps[0],8.75)

    def test_all_ten_bearings_and_whole_graph_grounded(self):
        arena=load('helix-conservatory','revision-4')['arena'];joints,edges=attachments(arena)
        self.assertEqual(len(joints),10)
        self.assertEqual(len({j['rib'] for j in joints}),5)
        self.assertEqual(len({j['post'] for j in joints}),10)
        self.assertEqual(len(edges),35)

    def test_ground_footprints_on_original_y16_terrace(self):
        old=load('helix-conservatory','revision-3')['arena']
        triangles=[[s['vertices'][i] for i in f] for s in old['terrain']['surfaces'] if s.get('walkable',True) for f in s['triangles']]
        ground=RayIndex(triangles)
        arena=load('helix-conservatory','revision-4')['arena']
        for j in attachments(arena)[0]:
            for p in j['postVertices']:
                if abs(p[1]-16)<1e-8:self.assertAlmostEqual(ground.ray([p[0],16.1,p[2]],[0,-1,0],.2),.1,places=7)

    def test_all_5240_decorations_and_prior_routes_unchanged(self):
        old=load('helix-conservatory','revision-3')['arena'];new=load('helix-conservatory','revision-4')['arena']
        self.assertEqual(old['art']['meshes'],new['art']['meshes'])
        self.assertEqual(len(k.decorative_plan(new)['lineage']),5240)
        self.assertEqual(old['routes'],new['routes'])
        self.assertEqual(old['navNodes'],new['navNodes'])
        self.assertEqual(old['art']['portals'],new['art']['portals'])

    def test_dense_finite_capsules_do_not_hit_any_new_frame_member(self):
        arena=load('helix-conservatory','revision-4')['arena'];objects=components(arena)
        triangles=[]
        for o in objects.values():
            v=world_vertices(o)
            triangles.extend([[v[f[0]],v[f[i]],v[f[i+1]]] for f in o.faces for i in range(1,len(f)-1)])
        query=Capsules(triangles)
        points=json.loads(subprocess.check_output(['node',str(ROOT/'tools/godot-multiplayer/new-maps/botanical-correction/route_points.mjs')],cwd=ROOT))
        self.assertGreater(len(points),15000)
        # Frozen U's exact fixture also supplies mode spawns/team objectives,
        # accepted routes and supported camera origins; never regenerate it.
        fixture=ROOT/'godot/tests/new_maps/botanical_stage/artifacts/helix-conservatory/probes.json'
        points+=json.loads(fixture.read_text())['points']
        for p in points:self.assertIsNone(query.overlaps(p['x'],p['y']+.001,p['z']),p)

if __name__=='__main__':unittest.main()
