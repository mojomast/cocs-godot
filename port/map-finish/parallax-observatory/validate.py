"""Source-only resource, selector, GLB face and collision-envelope audit."""
import hashlib
import json
import math
import re
import struct
from collections import Counter
from author import ROOT, HERE, PROFILE, HASH, build


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gd_table(path, name):
    text = path.read_text().split('const '+name+' := ',1)[1]
    # These tables are literal dictionaries with strings, numbers and Colors.
    level = 0
    for i, char in enumerate(text):
        level += (char == '{') - (char == '}')
        if level == 0:
            text = text[:i+1]
            break
    text = re.sub(r'Color\("([0-9a-f]+)"\)',r'"\1"',text)
    text = re.sub(r',\s*([}\]])',r'\1',text)
    return json.loads(text)


def glb_data(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF'
    length, kind = struct.unpack_from('<II',raw,12)
    assert kind == 0x4e4f534a
    doc = json.loads(raw[20:20+length])
    start = 20+length
    binary = raw[start+8:]

    def accessor(i):
        a = doc['accessors'][i]
        v = doc['bufferViews'][a['bufferView']]
        fmt = {5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
        dims = {'VEC3':3,'SCALAR':1}[a['type']]
        size = struct.calcsize('<'+fmt*dims)
        offset = v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*dims,binary,offset+j*v.get('byteStride',size))
                for j in range(a['count'])]

    # Accepted production exports have identity transforms. Refuse silently
    # invalid support proof if a later import changes this assumption.
    assert all(not any(k in n for k in ('matrix','translation','rotation','scale')) for n in doc['nodes'])
    faces = {0:[],2:[]}
    primitives = Counter()
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            name = doc['materials'][primitive['material']]['name']
            primitives[name] += 1
            verts = accessor(primitive['attributes']['POSITION'])
            normals = accessor(primitive['attributes']['NORMAL'])
            ids = [i[0] for i in accessor(primitive['indices'])]
            for j in range(0,len(ids),3):
                tri = [verts[i] for i in ids[j:j+3]]
                for axis in faces:
                    if max(v[axis] for v in tri)-min(v[axis] for v in tri) < 1e-5:
                        plane = sum(v[axis] for v in tri)/3
                        other = 2 if axis == 0 else 0
                        uv = [(v[other],v[1]) for v in tri]
                        normal_axis = sum(normals[i][axis] for i in ids[j:j+3])/3
                        faces[axis].append((plane, uv, name, normal_axis))
    return doc, faces, primitives


def contains(tri, point):
    a,b,c = tri
    def cross(u,v): return u[0]*v[1]-u[1]*v[0]
    def minus(u,v): return (u[0]-v[0],u[1]-v[1])
    det = cross(minus(b,a),minus(c,a))
    if abs(det) < 1e-9: return False
    u = cross(minus(point,a),minus(c,a))/det
    v = cross(minus(b,a),minus(point,a))/det
    return u >= -1e-5 and v >= -1e-5 and u+v <= 1+1e-5


def validate():
    profile = json.loads(PROFILE.read_text())
    expected, hosts = build()
    assert profile == expected, 'Profile drift: regenerate author.py --write'
    assert json.loads((HERE/'mounts.json').read_text()) == hosts
    source = json.loads((ROOT/'godot/multiplayer_worlds/generated/parallax-observatory.json').read_text())
    assert source['geometryHash'] == HASH == profile['geometry_hash']
    glb = ROOT/'godot/multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb'
    assert digest(glb) == 'b3ea4ec57f57f6db83e1acab40dc95135562347ef884cc8f33ba067af8521bb1'
    master = ROOT/'tools/godot-multiplayer/new-maps/parallax-observatory/parallax-observatory.blend'
    asset = json.loads((glb.parent/'asset-manifest.json').read_text())
    assert digest(master) == asset['blendSha256']
    doc, faces, primitive_counts = glb_data(glb)
    assert not doc.get('images') and not doc.get('textures')
    names = {m['name'] for m in doc['materials']}
    selectors = [m['source'] for m in profile['materials']]
    assert len(selectors) == len(set(selectors))
    assert set(selectors).isdisjoint(profile['preserve_materials'])
    assert set(selectors) | set(profile['preserve_materials']) == names
    assert len(profile['materials']) <= profile['budgets']['material_variants']
    families = gd_table(ROOT/'godot/material_language/families.gd','TABLE')
    bounds = gd_table(ROOT/'godot/material_language/library.gd','BOUNDS')
    baked = json.loads((ROOT/'godot/moth/generated/manifest.json').read_text())
    derived = json.loads((ROOT/'godot/moth/derived/manifest.json').read_text())
    resources = {}

    def resource(manifest, bucket, key):
        entry = manifest[bucket][key]
        path = ROOT/'godot'/entry['path'].removeprefix('res://')
        assert path.is_file(), path
        assert digest(path) == entry['png_sha256'], path
        resources[entry['path']] = dict(sha256=digest(path),width=entry['width'],height=entry['height'])
        return entry['path']

    bindings = []
    for item in profile['materials']:
        f = families[item['family']]
        opts = item['options']
        variant = opts['variant']
        assert variant == 'default' or variant in f['variants']
        entry = dict(f['default'],**f['variants'].get(variant,{}))
        for key,value in opts.items():
            if key in ('tint','variant'): continue
            assert key in bounds, key
            assert math.isfinite(value) and bounds[key][0] <= value <= bounds[key][1]
        assert re.fullmatch('[0-9a-f]{6}',opts['tint'])
        base = resource(baked,'textures',entry['base'])
        normal = resource(derived,'derived','normal--'+entry['normal']) if entry['normal_source'] == 'derived' else resource(baked,'normals',entry['normal'])
        data = resource(derived,'derived','data--'+entry['base'])
        lut = baked['materials'][f['accent']['lut']]
        # material LUT entries carry two plane records, unlike texture entries.
        for plane in ('r','t'):
            lutpath = ROOT/'godot'/lut[plane]['path'].removeprefix('res://')
            assert lutpath.is_file() and digest(lutpath) == lut[plane]['png_sha256']
            resources[lut[plane]['path']] = dict(sha256=digest(lutpath))
        bindings.append(dict(source=item['source'],family=item['family'],variant=variant,
                             base=base,normal=normal,packed_ao_roughness_detail=data,
                             tiles_per_metre=opts['tiles_per_metre']))

    mounts = {m['id']:m for m in hosts['mounts']}
    blocks = {b['id']:b for b in source['arena']['blocks']}
    ids = set()
    support = []
    rectangles = []
    for kind in ('panels','signs'):
        assert len(profile[kind]) <= profile['budgets'][kind]
        for item in profile[kind]:
            assert item['id'] not in ids
            ids.add(item['id'])
            if kind == 'panels': resource(baked,'textures',item['texture'])
            else:
                # Conservative readable plaque aspect ratio, not an engine text
                # layout/render claim. Native capture must still inspect glyphs.
                assert max(len(line) for line in item['text'].split('\n'))*.32*item['size'][1] <= item['size'][0]
            assert all(math.isfinite(n) for n in item['position']+item['size']+item['rotation_degrees'])
            assert all(0 < n <= 8 for n in item['size'])
            yaw = item['rotation_degrees'][1]
            assert item['rotation_degrees'][0] == item['rotation_degrees'][2] == 0
            axis = 0 if abs(yaw) == 90 else 2
            normal = 1 if yaw in (0,90) else -1
            other = 2 if axis == 0 else 0
            pos = item['position']
            block = blocks[mounts[item['id']]['host']]
            lo = [block['x']-block['w']/2,block.get('baseY',0),block['z']-block['d']/2]
            hi = [block['x']+block['w']/2,block['h'],block['z']+block['d']/2]
            assert lo[1] <= pos[1]-item['size'][1]/2 and pos[1]+item['size'][1]/2 <= hi[1]
            assert lo[other] <= pos[other]-item['size'][0]/2 and pos[other]+item['size'][0]/2 <= hi[other]
            # Mounts remain in the host's non-walkable silhouette, with a small
            # outward clearance. This forbids signs across real door apertures.
            face = hi[axis] if normal > 0 else lo[axis]
            assert 0.005 <= (pos[axis]-face)*normal <= .13, (item['id'],face,pos)
            candidates = [(plane,uv,name,normal_axis) for plane,uv,name,normal_axis in faces[axis]
                          if .004 <= (pos[axis]-plane)*normal <= .13 and abs(normal_axis) > .99]
            distances = []
            backing_normal_signs = set()
            for u in (-.5,-.25,0,.25,.5):
                for v in (-.5,-.25,0,.25,.5):
                    point = (pos[other]+u*item['size'][0],pos[1]+v*item['size'][1])
                    hits = [((pos[axis]-plane)*normal,name,normal_axis) for plane,uv,name,normal_axis in candidates if contains(uv,point)]
                    assert hits, ('unsupported GLB panel/sign',item['id'],point)
                    hit = min(hits)
                    distances.append(hit[0])
                    backing_normal_signs.add(1 if hit[2] > 0 else -1)
                    if hit[2]*normal < 0:
                        assert next(m for m in doc['materials'] if m['name'] == hit[1]).get('doubleSided') is True
            support.append(dict(id=item['id'],samples=25,normal_axis=axis,normal_sign=normal,
                                exported_backing_normal_signs=sorted(backing_normal_signs),
                                min_backing_distance=round(min(distances),5),
                                max_backing_distance=round(max(distances),5),host=block['id']))
            rectangles.append((item['id'],axis,pos[axis],pos[other],pos[1],*item['size']))
    for i,a in enumerate(rectangles):
        for b in rectangles[i+1:]:
            if a[1] == b[1] and abs(a[2]-b[2]) < .05:
                assert abs(a[3]-b[3]) >= (a[5]+b[5])/2-.001 or abs(a[4]-b[4]) >= (a[6]+b[6])/2-.001, ('overlapping plaques',a[0],b[0])

    motes = 0
    for pocket in profile['pockets']:
        assert pocket['id'] not in ids
        ids.add(pocket['id'])
        assert pocket['kind'] in ('dust','pollen','ash','mist','vent')
        assert 0 < pocket['count'] <= 12
        assert all(0 < s <= .6 for s in pocket['size'])
        # Every pocket lies in clear air near the equipment zone, with its entire
        # static spawn envelope checked against the accepted block volumes.
        for block in blocks.values():
            lo = [block['x']-block['w']/2,block.get('baseY',0),block['z']-block['d']/2]
            hi = [block['x']+block['w']/2,block['h'],block['z']+block['d']/2]
            assert any(pocket['position'][k]+pocket['size'][k]/2 <= lo[k] or
                       pocket['position'][k]-pocket['size'][k]/2 >= hi[k] for k in range(3)), ('pocket inside collision',pocket['id'],block['id'])
        motes += pocket['count']
    assert motes <= profile['budgets']['motes']
    return dict(status='source-ready; native pending',geometry_hash=HASH,
                accepted_glb_sha256=digest(glb),accepted_master_sha256=digest(master),
                profile_sha256=digest(PROFILE),coverage=dict(matched=selectors,preserved=profile['preserve_materials'],unmatched=[],primitive_counts=dict(primitive_counts)),
                counts=dict(materials=len(selectors),panels=len(profile['panels']),signs=len(profile['signs']),pockets=len(profile['pockets']),motes=motes,support_samples=len(support)*25),
                material_bindings=bindings,resources=resources,mount_checks=support,
                native=dict(parsed=False,rendered=False,visual_acceptance=False,low_full=False,teardown=False,frame_cadence=None))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-report',action='store_true')
    args = parser.parse_args()
    result = validate()
    if args.write_report:
        (HERE/'source-check.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['counts'],indent=2))
