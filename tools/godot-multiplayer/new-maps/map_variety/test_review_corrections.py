"""Regressions for floor ownership and actual embedded scene acceptance."""
import copy
import hashlib
import json
import math
import struct
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

import floor_union as union
import kit_expander
from export_audit import audit_glb, srgb_byte
from glb_geometry import EmbeddedGlb
from glb_test_fixtures import geometry_fixture,encode_glb,preserved_bindings
from test_repair import ROOT,png


def authority(name,revision):
    return json.loads((ROOT/f'port/new-maps/{name}/variety/{revision}/authority.json').read_text())['arena']


def rectangle(name,material,x0,x1,z0,z1,height):
    return {'id':name,'material':material,'walkable':True,
            'vertices':[[x,height(x,z),z] for x,z in [(x0,z0),(x0,z1),(x1,z1),(x1,z0)]],
            'triangles':[[0,1,2],[0,2,3]]}


def indexed(triangles):
    grid={}
    for triangle in triangles:
        for cell in union.cells(triangle['vertices']):grid.setdefault(cell,[]).append(triangle)
    return grid


def hits(grid,x,z):
    result=[]
    for triangle in grid.get((math.floor(x/8),math.floor(z/8)),[]):
        a,b,c=triangle['vertices'];den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
        if abs(den)<1e-9:continue
        u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den
        v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den
        if min(u,v,1-u-v)>=-1e-8:result.append((u*a[1]+v*b[1]+(1-u-v)*c[1],triangle['material']))
    return result


def source_triangles(surfaces):
    return [{'vertices':[s['vertices'][i] for i in face],'material':s['material']} for s in surfaces for face in s['triangles']]


def rendered_triangles(shell):
    return [{'vertices':[[bucket['vertices'][i][0],bucket['vertices'][i][2],-bucket['vertices'][i][1]] for i in face],
             'material':material} for material,bucket in shell['surfaces'].items() for face in bucket['faces']]


class FloorOwnershipTests(unittest.TestCase):
    def assert_disjoint(self,triangles):
        grid={};checked=set()
        for index,t in enumerate(triangles):
            points=t['vertices'];key=union.plane(points)
            for cell in union.cells(points):
                for previous in grid.get((key,cell),[]):
                    pair=(previous,index)
                    if pair in checked:continue
                    checked.add(pair)
                    overlap=union.area(union.intersection(points,union.ccw(triangles[previous]['vertices'])))
                    self.assertLessEqual(overlap,2e-7,(previous,index,overlap))
                grid.setdefault((key,cell),[]).append(index)

    def test_exact_partial_and_sloped_overlaps_preserve_area_and_first_material(self):
        for height in (lambda x,z:12,lambda x,z:12+.25*x-.125*z):
            a=rectangle('accepted','saltstone',0,2,0,2,height)
            b=rectangle('later','cistern',1,3,0,2,height)
            duplicate=dict(a,id='duplicate',material='other')
            elevated=rectangle('upper','upper',0,2,0,2,lambda x,z:height(x,z)+4)
            rendered,report=union.union_floors([a,b,duplicate,elevated])
            self.assertAlmostEqual(report['inputProjectedArea'],16)
            self.assertAlmostEqual(report['renderProjectedArea'],10)
            self.assertEqual([r['renderProjectedArea'] for r in report['lineage']],[4,2,0,4])
            self.assert_disjoint(rendered)
            grid=indexed(rendered)
            self.assertIn((height(1.5,.37),'saltstone'),hits(grid,1.5,.37))
            self.assertNotIn((height(1.5,.37),'cistern'),hits(grid,1.5,.37))
            self.assertTrue(any(m=='cistern' for _,m in hits(grid,2.5,.37)))

    def test_parallax_actual_union_is_disjoint_support_preserving_and_keeps_well_open(self):
        arena=authority('parallax-observatory','districts-v3')
        floors=[s for s in arena['terrain']['surfaces'] if s.get('walkable',True) and s.get('renderSource')!='kit']
        rendered,report=union.union_floors(floors)
        self.assert_disjoint(rendered)
        self.assertTrue(all(union.float32_area(t['vertices'])>=1e-8 for t in rendered))
        self.assertGreater(report['overlapRemovedProjectedArea'],0)
        records={r['sourceId']:r for r in report['lineage']}
        for name in ('tidal-cistern-joint-0--12','tidal-cistern-joint-8--12'):
            self.assertEqual(records[name]['inputTriangles'],10)
            self.assertEqual(records[name]['renderTriangles'],0)
        before=indexed(source_triangles(floors));after=indexed(rendered)
        actual=indexed(rendered_triangles(kit_expander.shell_plan(arena)))
        for triangle in source_triangles(floors):
            x=sum(v[0] for v in triangle['vertices'])/3;z=sum(v[2] for v in triangle['vertices'])/3
            expected=max(y for y,_ in hits(before,x,z))
            self.assertAlmostEqual(max(y for y,_ in hits(after,x,z)),expected,places=5)
        for x,y in [(32,8),(34,8),(40,10),(43.5,11.75)]:
            self.assertAlmostEqual(max(h for h,_ in hits(actual,x,-34.13)),y,places=6)
        for x in (-108.13,108.13):
            prior=hits(before,x,.17);selected=hits(actual,x,.17)
            top=max(y for y,_ in prior)
            expected=next(m for y,m in prior if abs(y-top)<1e-7)
            self.assertEqual([m for y,m in selected if abs(y-top)<1e-7],[expected])

    def test_vesper_actual_shell_has_one_slate_terrace(self):
        arena=authority('vesper-viaduct','urban-v2')
        faces=[]
        for t in rendered_triangles(kit_expander.shell_plan(arena)):
            if all(abs(v[1]-22)<1e-8 and 7-1e-8<=v[0]<=29+1e-8 and 37-1e-8<=v[2]<=53+1e-8 for v in t['vertices']):faces.append(t)
        self.assertEqual(len(faces),2)
        self.assertEqual({t['material'] for t in faces},{'slate'})
        self.assertAlmostEqual(sum(union.area(t['vertices']) for t in faces),22*16)
        self.assert_disjoint(faces)
        self.assertEqual(len([s for s in arena['terrain']['surfaces'] if s['id']=='roof-terrace-deck']),1)
        self.assertFalse(any(s['id']=='roof-terrace-block-cap' for s in arena['terrain']['surfaces']))


class GlbAcceptanceTests(unittest.TestCase):
    def audit(self,document,binary,bindings=None,root=ROOT,**kwargs):
        raw=encode_glb(document,binary)
        return audit_glb(SimpleNamespace(read_bytes=lambda:raw),root,bindings or preserved_bindings(),**kwargs)

    def test_valid_real_geometry_and_strided_accessor(self):
        for stride,prefix in [(12,0),(16,8)]:
            doc,binary=geometry_fixture(position_stride=stride,position_prefix=prefix)
            report=self.audit(doc,binary,expected_materials={'glass'},expected_triangles=1)
            self.assertEqual(report['triangles'],1)
            self.assertEqual(report['usedMaterials'],['glass'])
            self.assertEqual(report['materialEvidence']['glass']['role'],'preserve')
            self.assertEqual(report['evaluatedTriangleDelta'],0)
            with self.assertRaisesRegex(ValueError,'build selection'):self.audit(doc,binary,expected_materials={'missing'})
            with self.assertRaisesRegex(ValueError,'build selection'):self.audit(doc,binary,expected_triangles=2)

    def test_empty_json_only_and_scene_position_material_absence_reject(self):
        for field in ('scene','scenes','nodes','buffers','materials'):
            doc,binary=geometry_fixture();doc.pop(field)
            with self.subTest(field=field),self.assertRaises(ValueError):self.audit(doc,binary)
        doc,binary=geometry_fixture();doc['meshes']=[];doc['nodes']=[{}]
        with self.assertRaisesRegex(ValueError,'no candidate geometry'):self.audit(doc,binary)
        doc,binary=geometry_fixture();doc['meshes'][0]['primitives'][0]['attributes'].pop('POSITION')
        with self.assertRaisesRegex(ValueError,'Missing POSITION'):self.audit(doc,binary)
        doc,binary=geometry_fixture();doc['meshes'][0]['primitives'][0].pop('material')
        with self.assertRaisesRegex(ValueError,'material index'):self.audit(doc,binary)
        for document in ({'meshes':[]},{'meshes':[{'primitives':[{'indices':0}]}],'accessors':[{'count':3}]}):
            data=json.dumps(document).encode();data+=b' '*((-len(data))%4)
            raw=struct.pack('<III',0x46546c67,2,20+len(data))+struct.pack('<II',len(data),0x4e4f534a)+data
            with self.assertRaises(ValueError):audit_glb(SimpleNamespace(read_bytes=lambda:raw),ROOT,preserved_bindings())

    def test_actual_scene_graph_rejects_orphans_cycles_and_instancing(self):
        for mode in ('orphan','cycle','instance','gpu-instance','node-index'):
            doc,binary=geometry_fixture()
            if mode=='orphan':doc['meshes'].append(copy.deepcopy(doc['meshes'][0]))
            elif mode=='cycle':doc['nodes'][0]['children']=[0]
            elif mode=='instance':doc['nodes'].append({'mesh':0});doc['scenes'][0]['nodes'].append(1)
            elif mode=='gpu-instance':doc['nodes'][0]['extensions']={'EXT_mesh_gpu_instancing':{'attributes':{'TRANSLATION':0}}}
            else:doc['scenes'][0]['nodes']=[5]
            with self.subTest(mode=mode),self.assertRaises(ValueError):self.audit(doc,binary)

    def test_accessor_bytes_indices_ranges_types_and_finiteness(self):
        for mode in ('index-value','index-count','index-component','index-type','index-offset','position-count','component','type','stride','offset','nonfinite','range'):
            doc,binary=geometry_fixture();accessor=doc['accessors'][0]
            if mode=='index-value':
                view=doc['bufferViews'][doc['accessors'][-1]['bufferView']];struct.pack_into('<H',binary,view['byteOffset'],3)
            elif mode=='index-count':doc['accessors'][-1]['count']=10**30
            elif mode=='index-component':doc['accessors'][-1]['componentType']=5126
            elif mode=='index-type':doc['accessors'][-1]['type']='VEC3'
            elif mode=='index-offset':doc['accessors'][-1]['byteOffset']=2
            elif mode=='position-count':accessor['count']=10**30
            elif mode=='component':accessor['componentType']=5123
            elif mode=='type':accessor['type']='VEC2'
            elif mode=='stride':doc['bufferViews'][0]['byteStride']=8
            elif mode=='offset':accessor['byteOffset']=4
            elif mode=='nonfinite':struct.pack_into('<f',binary,0,float('nan'))
            else:accessor['max']=[.5,.5,0]
            with self.subTest(mode=mode),self.assertRaises(ValueError):self.audit(doc,binary)

    def test_container_bounds_and_external_resources_reject(self):
        doc,binary=geometry_fixture();raw=encode_glb(doc,binary)
        malformed=[raw[:-1],raw+b'\0',raw[:4]+struct.pack('<I',1)+raw[8:],
                   raw[:12]+struct.pack('<I',len(raw)+4)+raw[16:]]
        for blob in malformed:
            with self.assertRaises(ValueError):EmbeddedGlb(blob)
        for mode in ('buffer-uri','image-uri','view-bounds','buffer-length'):
            d=copy.deepcopy(doc)
            if mode=='buffer-uri':d['buffers'][0]['uri']='external.bin'
            elif mode=='image-uri':d['images']=[{'uri':'external.png','mimeType':'image/png'}]
            elif mode=='view-bounds':d['bufferViews'][0]['byteLength']=len(binary)+1
            else:d['buffers'][0]['byteLength']=len(binary)+4
            with self.subTest(mode=mode),self.assertRaises(ValueError):self.audit(d,binary)

    def test_used_material_must_be_bound(self):
        doc,binary=geometry_fixture();doc['materials'][0]['name']='unbound'
        with self.assertRaisesRegex(ValueError,'Unbound used material'):self.audit(doc,binary)

    def test_scene_used_pbr_requires_real_verified_images(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as directory:
            root=Path(directory);channels={};textures={}
            colors={'albedo':(32,128,224),'normal':(128,128,255),'roughness':(89,89,89)}
            for name,color in colors.items():
                data=png(color);(root/(name+'.png')).write_bytes(data);channels[name]=name
                textures[name]={'path':name+'.png','sha256':hashlib.sha256(data).hexdigest()}
            (root/'base.json').write_text(json.dumps({'materials':[{'id':'fixture','channels':channels}],'textures':textures}))
            (root/'overlay.json').write_text(json.dumps({'materials':[],'textures':{}}))
            bindings={'schema':'map-variety-bindings/v1','pack':{'base':'base.json','overlay':'overlay.json'},
                      'materials':{'surface':{'role':'surface','resource':'fixture','tilesPerMeter':1},'unused':{'role':'preserve'}}}
            doc,binary=geometry_fixture();doc['materials']=[{'name':'surface','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2}},'normalTexture':{'index':1}}]
            doc['textures']=[];doc['images']=[]
            for color in [tuple(srgb_byte(v) for v in colors['albedo']),colors['normal'],(255,89,0)]:
                binary.extend(b'\0'*((-len(binary))%4));start=len(binary);image=png(color);binary.extend(image)
                view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(image)})
                doc['textures'].append({'source':len(doc['images'])});doc['images'].append({'mimeType':'image/png','bufferView':view})
            doc['buffers'][0]['byteLength']=len(binary)
            report=self.audit(doc,binary,bindings,root)
            self.assertTrue(report['materialEvidence']['surface']['pixelsVerified'])
            self.assertEqual(set(report['albedo']),{'surface'})
            # Font meshes can retain an earlier UV layer; validate the actual
            # selected stream rather than assuming MothLocal always exports as 0.
            secondary=copy.deepcopy(doc)
            attrs=secondary['meshes'][0]['primitives'][0]['attributes']
            attrs['TEXCOORD_1']=attrs.pop('TEXCOORD_0')
            mat=secondary['materials'][0]
            for texture in (mat['pbrMetallicRoughness']['baseColorTexture'],mat['pbrMetallicRoughness']['metallicRoughnessTexture'],mat['normalTexture']):texture['texCoord']=1
            self.assertTrue(self.audit(secondary,binary,bindings,root)['materialEvidence']['surface']['pixelsVerified'])
            attrs['TEXCOORD_0']=attrs.pop('TEXCOORD_1')
            with self.assertRaisesRegex(ValueError,'selected UV'):self.audit(secondary,binary,bindings,root)
            for mode in ('missing-image','missing-albedo','missing-normal','missing-roughness','missing-tangent','missing-uv','bad-image-bounds'):
                bad=copy.deepcopy(doc)
                if mode=='missing-image':bad['images']=[]
                elif mode=='missing-albedo':bad['materials'][0]['pbrMetallicRoughness'].pop('baseColorTexture')
                elif mode=='missing-normal':bad['materials'][0].pop('normalTexture')
                elif mode=='missing-roughness':bad['materials'][0]['pbrMetallicRoughness'].pop('metallicRoughnessTexture')
                elif mode=='missing-tangent':bad['meshes'][0]['primitives'][0]['attributes'].pop('TANGENT')
                elif mode=='missing-uv':bad['meshes'][0]['primitives'][0]['attributes'].pop('TEXCOORD_0')
                else:bad['bufferViews'][-1]['byteLength']=len(binary)
                with self.subTest(mode=mode),self.assertRaises(ValueError):self.audit(bad,binary,bindings,root)


if __name__=='__main__':unittest.main()
