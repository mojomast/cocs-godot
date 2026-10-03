"""Bounded regressions against the actual committed Kit API, without bpy."""
import json
import math
import struct
import sys
import unittest
import zlib
from unittest.mock import patch
from collections import defaultdict
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path[:0] = [str(HERE), str(ROOT/'tools/map-variety-pipeline')]
import kit_expander as expand
import kit_build
from blender_kit import Kit, _pipe_rings
from export_audit import verify_albedo, srgb_byte, validate_bindings, audit_glb
from source_geometry import solid_geometry, world_vertices
from map_materials import adapter_bindings, load_reviewed_materials, assert_packed_materials, PRESERVED
from base_craft import base_craft_plan
from triangle_policy import triangle_advisory
from glb_test_fixtures import geometry_fixture, encode_glb, preserved_bindings


class MeshObject:
    pass


class CaptureKit(Kit):
    """Exercise real prism/framed_bay/rib/pipe methods, replacing only bpy mesh."""
    def __init__(self):
        self.source = SimpleNamespace(objects=[])

    def mesh(self, name, vertices, faces, material, **kwargs):
        obj = MeshObject()
        obj.name, obj.vertices, obj.faces = name, vertices, expand.outward_faces(vertices,faces)
        obj.material, obj.location, obj.rotation_euler = material, (0,0,0), (0,0,0)
        self.source.objects.append(obj)
        return obj


def candidates():
    for name, revision in [('helix-conservatory','revision-3'),('parallax-observatory','districts-v3'),('vesper-viaduct','urban-v2')]:
        arena = json.loads((ROOT/f'port/new-maps/{name}/variety/{revision}/authority.json').read_text())['arena']
        path = next((ROOT/f'tools/godot-multiplayer/new-maps/{name}').glob('**/variety_bindings.json'))
        binding = json.loads(path.read_text())
        yield name,arena,binding


def png(rgb):
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(bytes([0,*rgb])))+chunk(b'IEND',b'')


class RepairTests(unittest.TestCase):
    def test_real_framed_api_places_every_created_part(self):
        kit=CaptureKit()
        op={'op':'framed_bay','name':'portal','material':'frame','trimMaterial':'trim','sector':'s','at':[7,-19,12],'rot':math.pi/2,'width':3,'height':4,'depth':1,'arch':True}
        created=kit_build.create_assembly(kit,op)
        self.assertEqual(len(created),9) # not merely the two returned jambs
        self.assertTrue(all(o.location==(7.,-19.,12.) for o in created))
        self.assertTrue(all(o.rotation_euler==(0.,0.,math.pi/2) for o in created))
        self.assertTrue(any('reveal-arch' in o.name for o in created))

    def test_compound_offsets_and_heading_round_trip(self):
        source={'id':'tower','class':'tower','material':'m','sector':'s','at':[48,12,-48],'params':{'height':40,'radius':4}}
        shaft=next(o for o in expand.expand_kit([source],{'m'}) if o['name']=='tower.shaft')
        self.assertEqual(shaft['at'],[48,48,32])
        source.update({'class':'scientific_room','rot':math.pi/2,'params':{'racks':2,'spacing':4}})
        rack=next(o for o in expand.expand_kit([source],{'m'}) if o['name']=='tower.rack0')
        self.assertAlmostEqual(rack['at'][0],48)
        self.assertAlmostEqual(rack['at'][1],46)
        self.assertAlmostEqual(rack['at'][2],12.9)

    def test_every_candidate_op_satisfies_real_kit_methods(self):
        for name,arena,binding in candidates():
            kit=CaptureKit()
            ops=expand.expand_kit(arena['art']['kit'],set(binding['materials']))+expand.infrastructure_plan(arena)
            for op in ops:
                with self.subTest(map=name,op=op['name']):
                    self.assertIn(op['material'],binding['materials'])
                    if op['op']=='pipe':_pipe_rings(op['points'],op['radius'],op['sides'])
                    kit_build.create_assembly(kit,op)

    def test_authority_chunking_preserves_all_faces(self):
        for name,a,_ in candidates():
            shell=expand.shell_plan(a)
            for bucket in list(shell['surfaces'].values())+list(shell['walls'].values()):
                chunks=list(expand.mesh_chunks(bucket))
                self.assertEqual(sum(len(c['faces']) for c in chunks),len(bucket['faces']))
                self.assertTrue(all(expand._triangles(c['vertices'],c['faces'])<=24000 for c in chunks))
            if name=='helix-conservatory':self.assertGreater(len(list(expand.mesh_chunks(shell['surfaces']['verdigris']))),1)

    def test_box_exact_authority_vertical_interval(self):
        plan=expand.structure_plan({'blocks':[{'x':48,'z':-48,'w':7,'d':7,'baseY':12,'h':34,'material':'m'}], 'overhead':[{'x':0,'z':0,'w':64,'d':10,'minY':15.2,'maxY':15.7,'material':'roof'}]})
        for name,lo,hi in [('m',12,34),('roof',15.2,15.7)]:
            heights=[v[2] for v in plan['buckets'][name]['vertices']]
            self.assertAlmostEqual(min(heights),lo);self.assertAlmostEqual(max(heights),hi)

    def test_complete_decorative_lineage_and_infrastructure(self):
        for name,a,_ in candidates():
            plan=expand.decorative_plan(a)
            expected=[m['id'] for m in a['art'].get('meshes',[]) if m['collision']=='none']
            self.assertEqual(plan['lineage'],expected)
            if name=='helix-conservatory':
                self.assertEqual(len(expected),5240)
                self.assertIn('grotto-pool',expected)
            if name=='vesper-viaduct':
                names=[o['name'] for o in expand.infrastructure_plan(a)]
                self.assertIn('civic-clock-dial',names);self.assertEqual(sum(n.startswith('tram-rail') for n in names),2)

    def test_closed_rib_normals_and_open_sheet_preservation(self):
        kit=CaptureKit();obj=kit.curved_rib('rib',(0,0,0),1,2,1,0,math.pi,'m')
        self.assertGreater(expand.signed_volume(obj.vertices,obj.faces),4.6)
        sheet=[(0,1,2)];self.assertEqual(expand.outward_faces([(0,0,0),(1,0,0),(0,1,0)],sheet),sheet)

    def test_all_candidates_restore_valid_cameras(self):
        for _,a,_ in candidates():
            for c in kit_build.camera_specs(a):
                eye,target=expand.to_blender(c['eye']),expand.to_blender(c['target'])
                self.assertGreater(math.dist(eye,target),1)
                self.assertTrue(all(math.isfinite(v) for v in (*eye,*target)))

    def test_linear_source_is_not_valid_srgb_export(self):
        source=png((32,128,224))
        with self.assertRaisesRegex(ValueError,'not derived sRGB'):verify_albedo(source,source)
        evidence=verify_albedo(source,png(tuple(srgb_byte(x) for x in (32,128,224))))
        self.assertEqual(evidence['maxByteError'],0)
        self.assertNotEqual(evidence['sourceLinearSha256'],evidence['exportSrgbSha256'])

    def test_unknown_material_roles_fail_closed(self):
        with self.assertRaisesRegex(ValueError,'Unknown binding role'):
            validate_bindings({'schema':'map-variety-bindings/v1','materials':{'m':{'role':'guess'}}})
        for _,_,binding in candidates():validate_bindings(binding)

    def test_solid_kit_collision_is_captured_from_exact_render_operations(self):
        for name,a,_ in candidates():
            capture=solid_geometry(a)
            self.assertEqual(capture['walls'],[w for w in a['terrain']['walls'] if w.get('renderSource')=='kit'],name)
            self.assertEqual(capture['surfaces'],[s for s in a['terrain']['surfaces'] if s.get('renderSource')=='kit' and not s['walkable']],name)

    def test_glb_triangle_overage_is_advisory_but_primitive_and_count_validation_remain_strict(self):
        def fixture(primitives,count):
            document,binary=geometry_fixture(count if type(count) is int and count>=3 else 3,primitives)
            document['accessors'][-1]['count']=count
            blob=encode_glb(document,binary)
            return SimpleNamespace(read_bytes=lambda:blob)
        bindings=preserved_bindings()
        with self.assertRaisesRegex(ValueError,'64 primitives'):audit_glb(fixture(65,3),ROOT,bindings)
        report=audit_glb(fixture(1,480003),ROOT,bindings)
        self.assertEqual(report['triangles'],160001)
        self.assertEqual(report['triangleAdvisory'],triangle_advisory(160001,'exported-glb'))
        self.assertEqual(report['triangleAdvisory']['overageTriangles'],10001)
        for count in (None,-3,3.5,True):
            with self.subTest(count=count),self.assertRaisesRegex(ValueError,'element count'):
                audit_glb(fixture(1,count),ROOT,bindings)
        with self.assertRaisesRegex(ValueError,'Incomplete triangle'):
            audit_glb(fixture(1,480004),ROOT,bindings)

    def test_triangle_advisory_never_claims_acceptance_from_an_estimate_or_measurement(self):
        for measurement in ('source-estimate','evaluated-scene','exported-glb'):
            for total in (149999,150000,150001,200000):
                report=triangle_advisory(total,measurement)
                self.assertEqual(report['totalTriangles'],total)
                self.assertEqual(report['targetTriangles'],150000)
                self.assertEqual(report['policy'],'advisory')
                self.assertEqual(report['overTarget'],total>150000)
                self.assertEqual(report['overageTriangles'],max(0,total-150000))
                self.assertEqual(report['status'],'pending-performance-visual-review')
        for total in (None,-1,float('nan'),150000.0,True):
            with self.assertRaises(ValueError):triangle_advisory(total,'exported-glb')
        with self.assertRaises(ValueError):triangle_advisory(1,'unknown')

    def test_greenhouse_world_path_is_converted_once(self):
        _,arena,binding=next(candidates())
        op=next(o for o in expand.expand_kit(arena['art']['kit'],set(binding['materials'])) if o['name']=='greenhouse-ridge')
        # Test control points (not tube extrema), including source Z sign.
        obj=SimpleNamespace(vertices=op['points'],location=op['at'],rotation_euler=(0,0,op['rot']))
        expected=[[-11,30.2,84],[0,30.6,87],[11,30.2,84]]
        for a,b in zip(world_vertices(obj),expected):
            for x,y in zip(a,b):self.assertAlmostEqual(x,y)

    def test_canonical_adapter_receives_only_normalized_pbr_and_master_images_pack(self):
        class Image:
            def __init__(self):self.name='derived.png';self.filepath='/external/derived.png';self.packed_file=None
            def pack(self):self.packed_file=object()
        class Nodes(list):
            def get(self,name):return self[0] if name=='Principled BSDF' else None
        def node(kind):return SimpleNamespace(type=kind,inputs=defaultdict(lambda:SimpleNamespace(default_value=None)))
        def material(name):return SimpleNamespace(name=name,use_nodes=True,node_tree=SimpleNamespace(nodes=Nodes([node('BSDF_PRINCIPLED')])))
        image=Image()
        bindings={'schema':'map-variety-bindings/v1','mapId':'vesper-viaduct','materials':{
            'brick':{'role':'surface','resource':'terracotta','tilesPerMeter':.25,'normalStrength':.35},
            'glass':{'role':'preserve','tilesPerMeter':1},'letter':{'role':'preserve','tilesPerMeter':1}}}
        def canonical(root,pbr,*,output_dir=None,with_report=False):
            self.assertEqual(pbr,{'brick':{'material':'terracotta','role':'surface','normal':True}})
            self.assertTrue(with_report)
            mat=material('brick');mat.node_tree.nodes.extend([node('NORMAL_MAP'),SimpleNamespace(type='TEX_IMAGE',image=image)])
            return {'brick':mat},{'brick':.5},{'pack':{'baseSha256':'base','overlaySha256':'overlay'},'materials':{'brick':{'tilesPerMeter':.5}}}
        fake_bpy=SimpleNamespace(data=SimpleNamespace(materials=SimpleNamespace(new=material)))
        with patch.dict(sys.modules,{'bpy':fake_bpy}):
            materials,density,receipt=load_reviewed_materials(SimpleNamespace(load_materials=canonical),ROOT,bindings,ROOT/'unused')
        self.assertEqual(set(materials),{'brick','glass','letter'})
        self.assertEqual(density['brick'],.25)
        self.assertEqual(receipt['materials']['brick']['tilesPerMeter'],.5)
        self.assertEqual(materials['brick'].node_tree.nodes[1].inputs['Strength'].default_value,.35)
        self.assertEqual(receipt['packedImages'],1)
        self.assertEqual(image.filepath,'//packed/derived.png')
        self.assertEqual(materials['glass'].node_tree.nodes[0].inputs['Alpha'].default_value,1)
        assert_packed_materials(materials.values())
        image.packed_file=None
        with self.assertRaisesRegex(ValueError,'unpacked'):assert_packed_materials(materials.values())

    def test_explicit_preserved_palettes_fail_unknown_names(self):
        self.assertEqual(PRESERVED['helix-conservatory']['glass']['alpha'],.08)
        self.assertEqual(PRESERVED['vesper-viaduct']['water']['roughness'],.36)
        with self.assertRaisesRegex(ValueError,'Unreviewed preserved'):
            adapter_bindings({'schema':'map-variety-bindings/v1','mapId':'helix-conservatory','materials':{'invented':{'role':'preserve','tilesPerMeter':1}}})

    def test_accepted_procedural_craft_is_preserved_not_coarse_landmark_substitutes(self):
        for name,a,binding in candidates():
            craft=base_craft_plan(a,ROOT)
            self.assertTrue(set(craft['buckets'])<=set(binding['materials']))
            names=[p['name'] for p in craft['lineage']]
            self.assertFalse(any(n.startswith('SOURCE.') for n in names))
            if name=='parallax-observatory':
                for prefix in ['tilting-primary-dish.mirror-petal.','arrival-dome.shell.','polar-armillary.orbital-','ephemeris.vault-roof-rib.','moonlit-tidal-chasm']:
                    self.assertTrue(any(n.startswith(prefix) for n in names),prefix)
                self.assertEqual(len(craft['labels']),8)
                self.assertTrue(craft['candidateCutLineage'])
            if name=='vesper-viaduct':
                for label in ['window-reveal','rear-window','roof-principal-rafter','clock-belt-course','stair-handrail']:
                    self.assertIn(label,names)
            summary=expand.scene_summary(a,set(binding['materials']))
            self.assertEqual(summary['triangleAdvisory'],triangle_advisory(summary['sourceSceneTriangles'],'source-estimate'))


if __name__=='__main__':unittest.main()
