#!/usr/bin/env python3
"""Source-only deterministic finish authoring. No engine, baking, or GLB writes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
DEST = Path('godot/source_operators/moth_finish')
NOTES = Path('port/operator-finish/content')
IDS = ['chatgpt', 'claude', 'grok', 'meta', 'gemini', 'deepseek', 'mistral', 'kimi', 'qwen']
MOTH = json.loads((ROOT / 'godot/moth/generated/manifest.json').read_text())
CAT = json.loads((ROOT / 'godot/source_operators/generated/manifest.json').read_text())
DESIGNS = [
    'split-cage survey instrument: calibration brackets and split service rails',
    'ceramic warding chassis: broad shield enamel with protected inspection slots',
    'asymmetric industrial outrider: offset patch plate and exposed brushed strip',
    'twin-turbine heavy chassis: thick bolted bays, paired load rails, corner impacts',
    'bifurcated ceramic anatomy: paired petal seams and separated passive buses',
    'pressure-vessel salvage frame: pressure collar, drain recess and repair strip',
    'swept aerofoil interceptor: diagonal leading-edge scuffs and longitudinal brushing',
    'orbital gimbal reactor: concentric service collars and sparse radial ticks',
    'lamellar mechanical sentinel: three overlapping courses and keyed service tabs',
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, sort_keys=True) + '\n')


def glb(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary = raw[28 + length:]
    def accessor(index):
        a = doc['accessors'][index]
        v = doc['bufferViews'][a['bufferView']]
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5121: 'u1'}[a['componentType']]
        size = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = v.get('byteStride', np.dtype(dtype).itemsize * size)
        return np.ndarray((a['count'], size), dtype=dtype, buffer=binary,
                          offset=start, strides=(stride, np.dtype(dtype).itemsize)).copy()
    return raw, doc, accessor


def audit(operator):
    raw, g, get = glb(ROOT / f'godot/source_operators/generated/{operator}.glb')
    parents = {c: i for i, n in enumerate(g['nodes']) for c in n.get('children', [])}
    def ancestry(i):
        names = []
        while True:
            names.append(g['nodes'][i].get('name', ''))
            if i not in parents:
                return names
            i = parents[i]
    materials = {}
    primitives = []
    for ni, node in enumerate(g['nodes']):
        if 'mesh' not in node:
            continue
        for pi, p in enumerate(g['meshes'][node['mesh']]['primitives']):
            m = g['materials'][p['material']]
            name = m['name']
            entry = materials.setdefault(name, {'material_indices': [], 'material': m, 'nodes': [], 'ancestors': []})
            entry['material_indices'] = sorted(set(entry['material_indices'] + [p['material']]))
            entry['nodes'].append(node['name'])
            entry['ancestors'] += ancestry(ni)
            attrs = p['attributes']
            uv = get(attrs['TEXCOORD_0']) if 'TEXCOORD_0' in attrs else None
            pos = get(attrs['POSITION'])
            ix = get(p['indices']).reshape(-1, 3)
            rec = {'node': node['name'], 'material': name, 'primitive': pi,
                   'vertices': len(pos), 'triangles': len(ix), 'uv1': uv is not None,
                   'attributes': sorted(attrs), 'position_bounds': [pos.min(0).tolist(), pos.max(0).tolist()]}
            if uv is not None:
                utri = uv[ix]
                d1, d2 = utri[:, 1] - utri[:, 0], utri[:, 2] - utri[:, 0]
                det = d1[:, 0]*d2[:, 1] - d1[:, 1]*d2[:, 0]
                rounded = np.round(pos, 5)
                groups = {}
                for xyz, tex in zip(rounded, uv):
                    groups.setdefault(tuple(xyz), set()).add(tuple(np.round(tex, 5)))
                rec.update(uv_bounds=[uv.min(0).tolist(), uv.max(0).tolist()],
                           uv_signed_triangles={'positive': int((det > 1e-9).sum()),
                                                'negative': int((det < -1e-9).sum()),
                                                'degenerate': int((abs(det) <= 1e-9).sum())},
                           seam_positions=sum(len(v) > 1 for v in groups.values()),
                           uv_edge_angles_histogram=np.histogram(np.arctan2(d1[:, 1], d1[:, 0]), bins=8,
                                                               range=(-np.pi, np.pi))[0].tolist())
            primitives.append(rec)
    for e in materials.values():
        e['ancestors'] = sorted(set(e['ancestors']))
    cat = next(o for o in CAT['operators'] if o['id'] == operator)
    assert sha(raw) == cat['sha256'], 'Frozen GLB differs from catalog'
    return {'glb_sha256': sha(raw), 'team_armor_material': cat['teamArmorMaterial'],
            'materials': materials, 'primitives': primitives}


SOURCES = {}


def moth(key, size=256):
    record = MOTH['textures'][key]
    path = ROOT / 'godot' / record['path'].removeprefix('res://')
    raw = path.read_bytes()
    assert sha(raw) == record['png_sha256']
    im = Image.open(path).convert('RGBA')
    assert sha(im.tobytes()) == record['pixel_sha256']
    SOURCES[key] = {'registry_key': 'textures/' + key, 'path': record['path'],
                    'png_sha256': sha(raw), 'rgba_pixel_sha256': sha(im.tobytes()),
                    'dimensions': list(im.size), 'registry_color_space': record['color_space']}
    # One enlarged sample, never tiny repeated labels across an entire actor.
    return np.asarray(im.convert('L').resize((size, size), Image.Resampling.BILINEAR), dtype=float) / 255


def masks(index, style):
    """Authored layouts in the existing fitted UV1 square; safe border at .015."""
    n = 256
    seam = Image.new('L', (n, n)); ds = ImageDraw.Draw(seam)
    wear = Image.new('L', (n, n)); dw = ImageDraw.Draw(wear)
    mark = Image.new('L', (n, n)); dm = ImageDraw.Draw(mark)
    # Source primitives overlap their normalized local UVs. Keep markings on
    # native fitted overlays; source maps have seam-safe, quiet macro treatments.
    if style in ('shell', 'trim', 'rubber', 'precision'):
        if style == 'shell':
            # Shared local UV islands prevent identifying one chest face from
            # material alone. Borrow the identity architecture at low contrast,
            # without its pictograms, and fade away from the periodic seam.
            s, w, _ = masks(index, 'panel')
            yy, xx = np.mgrid[:256, :256]
            safe = np.clip(np.minimum.reduce([xx, yy, 255-xx, 255-yy])/32, 0, 1)
            return s*.32*safe, w*.60*safe, np.zeros_like(s)
        elif style == 'trim':
            ds.line([(55, 62), (55, 198)], fill=45, width=2)
            dw.line([(66, 72), (105, 76)], fill=65, width=2)
        # Rubber and vertex-colored precision assemblies rely on real geometry
        # for seams: no painted panel/labels over cable runs or bolts.
    else:
        outlines = [
            [(38,38),(101,38),(101,68),(155,68),(155,38),(218,38),(218,218),(38,218)],
            [(55,36),(201,36),(220,96),(192,216),(128,229),(64,216),(36,96)],
            [(42,42),(143,42),(143,90),(215,90),(215,216),(42,216)],
            [(32,42),(224,42),(224,214),(32,214)],
            [(40,57),(105,35),(126,77),(151,35),(218,57),(198,210),(128,225),(58,210)],
            [(51,42),(205,42),(222,77),(222,190),(197,219),(59,219),(34,190),(34,77)],
            [(36,42),(101,33),(222,186),(195,221),(47,166)],
            [(49,49),(207,49),(221,128),(207,207),(49,207),(35,128)],
            [(38,42),(218,42),(218,208),(128,230),(38,208)],
        ]
        pts = outlines[index]
        ds.line(pts + [pts[0]], fill=180, width=3)
        if index == 0:
            for x in (83,173): ds.line([(x,88),(x,192)],fill=100,width=3)
            for y in (99,126,153): dm.line([(109,y),(119,y)],fill=105,width=2)
        elif index == 1:
            ds.line([(72,91),(128,181),(184,91)],fill=135,width=3)
            dm.rectangle((97,61,157,70),fill=90)
        elif index == 2:
            ds.rectangle((64,112,133,190),outline=145,width=3)
            dm.line([(161,121),(191,153),(161,185)],fill=110,width=4)
        elif index == 3:
            for x in (85,171): ds.line([(x,61),(x,197)],fill=140,width=5)
            for x in (45,211):
                for y in (56,200): ds.ellipse((x-5,y-5,x+5,y+5),fill=180)
            dm.rectangle((104,77,152,91),outline=100,width=3)
        elif index == 4:
            ds.line([(128,85),(128,199)],fill=160,width=3)
            for x in (82,174): dm.arc((x-17,105,x+17,139),15,320,fill=100,width=3)
        elif index == 5:
            ds.ellipse((66,64,190,188),outline=155,width=4)
            ds.rectangle((102,190,154,204),fill=120)
            dm.line([(102,91),(128,80),(154,91)],fill=100,width=3)
        elif index == 6:
            for off in (0,23): ds.line([(74+off,83),(174+off,188)],fill=125,width=2)
            dm.line([(128,140),(142,143),(143,157)],fill=105,width=3)
        elif index == 7:
            for r in (44,69): ds.ellipse((128-r,128-r,128+r,128+r),outline=115,width=2)
            for y in (66,190): dm.line([(120,y),(136,y)],fill=95,width=2)
        else:
            for y in (94,145,191): ds.line([(51,y),(128,y+14),(205,y)],fill=155,width=4)
            for x,y in ((67,66),(154,117),(89,165)): dm.rectangle((x,y,x+23,y+5),fill=110)
        # Chips at three selected exposed corners; no uniform noise scatter.
        for j in (0,2,len(pts)-2):
            x,y = pts[j]; dw.line([(x+4,y+4),(x+12+index%3*3,y+5)],fill=170,width=3)
            dw.line([(x+6,y+9),(x+11,y+10)],fill=95,width=2)
        if style == 'board':
            # Passive, sparse readable traces. Unique bus direction & terminal
            # placement per identity; actual baked circuit pixels sit below.
            for k in range(3):
                x=77+k*36; y=88+(index%3)*12
                ds.line([(x,193),(x,y+18),(x+18,y),(x+30,y)],fill=155,width=2)
                dm.ellipse((x+26,y-4,x+34,y+4),outline=135,width=2)
        elif style == 'vent':
            for k in range(4 + index%3):
                y=87+k*17
                ds.line([(76,y),(183,y+(-6 if index==6 else 0))],fill=190,width=5)
        # One service pictogram; no full-body text or fictional lore label.
        dm.line([(174,193),(181,184),(188,193)],fill=110,width=2)
    return tuple(np.asarray(im, dtype=float)/255 for im in (seam, wear, mark))


def pixels(index, style):
    key = ('circuit_board-etch' if style == 'board' else 'metal_grating' if style == 'vent'
           else 'carbon_fiber' if style == 'rubber' else 'brushed_metal' if style in ('trim','precision')
           or index in (2,5,6,8) else 'riveted_armor' if index == 3 else 'hex_paneling')
    base = moth(key)
    if index == 6 and style in ('shell', 'panel'):
        # Aerofoil grain follows the swept layout rather than horizontal bands.
        base = np.asarray(Image.fromarray(base.astype('float32')).rotate(-38, resample=Image.Resampling.BILINEAR),dtype=float)
        base[base == 0] = float(base.mean())
    # Baked microstructure contributes gently; authored macro layout dominates.
    micro = base - base.mean()
    seam, wear, mark = masks(index, style)
    dark = np.asarray(Image.fromarray((seam*255).astype('uint8')).filter(ImageFilter.GaussianBlur(2)),dtype=float)/255
    # A dark undercoat chip adjacent to the brighter polished scuff, kept local
    # to the selected exposed corners instead of randomized across the face.
    chip = np.roll(wear, 2, axis=0)*.55
    lum = .965 + micro*.065 - seam*.23 - dark*.09 + wear*.055 - chip*.13 - mark*.16
    lum = np.clip(lum, .66, 1)
    rgb = np.repeat((lum*255).astype('uint8')[:,:,None],3,axis=2)
    # Strict neutral modulation: source palette, vertex colors and team tint own hue.
    rough = {'shell':.57,'trim':.37,'rubber':.88,'precision':.49,'panel':.60,'board':.68,'vent':.72}[style]
    if index == 6 and style in ('shell','panel'): rough = .43
    if index == 3 and style in ('shell','panel'): rough = .67
    micro_roughness = .40 if style == 'rubber' else .28 if style == 'precision' else .08
    r = np.clip(rough + micro*micro_roughness + seam*.17 + dark*.08 - wear*.17 + mark*.04,.18,.98)
    # Authored height + real Moth luminance-derived fine relief, not a copied
    # albedo masquerading as a normal. UV V follows image row / glTF fitted UV.
    h = micro*.08 - seam*.55 - dark*.12 - wear*.13 - chip*.16 + mark*.04
    dy, dx = np.gradient(h)
    normal = np.stack((-dx*2, -dy*2, np.ones_like(dx)),axis=2)
    normal /= np.linalg.norm(normal,axis=2,keepdims=True)
    norm = np.round((normal*.5+.5)*255).astype('uint8')
    return {'albedo':Image.fromarray(rgb), 'roughness':Image.fromarray(np.round(r*255).astype('uint8')),
            'normal':Image.fromarray(norm)}, key


def generate(out):
    SOURCES.clear()
    finishes = {}; textures = {}; coverage = {}; previews = []
    for index, operator in enumerate(IDS):
        a = audit(operator); coverage[operator] = a
        assert all(p['uv1'] for p in a['primitives'])
        bindings=[]; preserve=[]
        for name,e in sorted(a['materials'].items()):
            mat=e['material']; pbr=mat.get('pbrMetallicRoughness',{})
            reasons=[]
            if name=='sourceTeamIvory': reasons.append('team identification / unlit markers')
            if any(mat.get('emissiveFactor',[0,0,0])): reasons.append('existing emissive optics / wing identity')
            if mat.get('alphaMode','OPAQUE')!='OPAQUE': reasons.append('source transparency')
            if 'weapon' in e['ancestors'] or 'gunAnchor' in e['ancestors']: reasons.append('material shared with held weapon')
            if name=='sourceMaterial2': reasons.append('dark chassis material shared with visor lens; retain optical surface')
            if reasons:
                preserve.append({'source_material':name,'reason':'; '.join(reasons)})
                continue
            if name==a['team_armor_material']: role='armor'; style='shell'
            elif pbr.get('metallicFactor')==0: role='rubber'; style='rubber'
            elif 'baseColorFactor' not in pbr: role='precision'; style='precision'
            else: role='metal'; style='trim'
            bindings.append({'source_material':name,'role':role,'finish':operator+'-'+style})
        a['bound_materials']=[b['source_material'] for b in bindings]
        a['preserved_materials']=preserve
        a['bound_primitive_count']=sum(p['material'] in a['bound_materials'] for p in a['primitives'])
        styles=sorted(set(b['finish'].split('-')[-1] for b in bindings)|{'panel','board','vent'})
        for style in styles:
            images,key=pixels(index,style); fid=operator+'-'+style
            if style == 'rubber':
                # Actual hand geometry has collapsed UV side triangles and a
                # small central UV domain. Do not request uncertain tangents.
                del images['normal']
            f={'albedo_mode':'modulate','metallic':{'shell':.08 if index not in (2,3,5,6,8) else .52,
                  'trim':.78,'rubber':0,'precision':.62,'panel':.12 if index not in (2,3,5,6,8) else .52,
                  'board':.12,'vent':.72}[style], 'roughness_gain':1.0,
               'normal_strength':0 if style == 'rubber' else .32 if style == 'precision' else .55}
            for channel,im in images.items():
                asset_id='shared-'+style if style in ('trim','rubber','precision') else fid
                rel=DEST/'assets'/f'{asset_id}-{channel}.png'; path=out/rel
                path.parent.mkdir(parents=True,exist_ok=True);im.save(path,optimize=False,compress_level=9)
                resource='res://'+str(rel.relative_to('godot')); f[channel]=resource
                arr=np.asarray(im)
                textures[resource]={'dimensions':list(im.size),'channels':len(im.getbands()),
                    'png_sha256':sha(path.read_bytes()),'pixel_sha256':sha(im.tobytes()),
                    'color_space':'srgb' if channel=='albedo' else 'linear',
                    'meaning':{'albedo':'neutral RGB multiplier; opaque; no tint or emission',
                               'roughness':'R luminance = physical perceptual roughness; gain 1',
                               'normal':'RGB tangent normal +Y in UV V direction; unit-length after derivation'}[channel],
                    'range':[int(arr.min()),int(arr.max())],'moth_keys':['textures/'+key],
                    'derivation':{'operator_index':0 if style in ('trim','rubber','precision') else index,
                                  'layout':style,'function':'pixels(index, style)','resolution':256}}
            finishes[fid]=f
        write_json(out/DEST/'profiles'/f'{operator}.json',{'version':1,'operator_id':operator,
                   'bindings':bindings,'overlay_finishes':{s:operator+'-'+s for s in ('panel','board','vent')},
                   'preserve_materials':preserve})
        previews.append((operator, index))
    provenance={'generator':'tools/operator-finish/content/build.py','generator_sha256':sha(Path(__file__).read_bytes()),
                'moth_manifest_sha256':sha((ROOT/'godot/moth/generated/manifest.json').read_bytes()),
                'moth_baked_source':{'path':MOTH['provenance']['source'],
                                     'sha256':sha((ROOT/MOTH['provenance']['source']).read_bytes())},
                'operator_catalog_manifest_sha256':sha((ROOT/'godot/source_operators/generated/manifest.json').read_bytes()),
                'art_reference_sources':{p:sha((ROOT/p).read_bytes()) for p in
                    ('game/operator-anatomy.mjs','game/operator-detail.mjs','game/data.mjs','game/view.mjs')},
                'moth_sources':SOURCES,'source_glbs':{o:a['glb_sha256'] for o,a in coverage.items()},
                'recipe':'Moth luminance centered + authored UV1 seam/wear/mark masks; restrained neutral modulation; height gradient normal renormalized before RGB8 quantization',
                'normal_convention':'N=normalize(-2*dH/dU,-2*dH/dV,1); image rows are +V. Native moving-light orientation verification pending.',
                'dependencies':{'pillow':'12.3.0','numpy':'2.5.3'},'verification_scope':'source-only; native gallery and motion pending'}
    assert provenance['moth_baked_source']['sha256']==MOTH['provenance']['source_sha256']
    write_json(out/DEST/'manifest.json',{'version':1,'finishes':finishes,'provenance':provenance,'textures':textures})
    write_json(out/NOTES/'coverage.json',coverage)
    # Source geometry comparison: representative bound articulation per role,
    # actual triangle UV wireframes beside local XY projections. Every primitive
    # is measured above; this selected contact sheet is inspectable 2D evidence.
    uv_sheet=Image.new('RGB',(1100,9*200),(26,31,37));ud=ImageDraw.Draw(uv_sheet)
    for row,operator in enumerate(IDS):
        y=row*200;ud.text((8,y+8),operator,fill='white')
        _,g,get=glb(ROOT/f'godot/source_operators/generated/{operator}.glb')
        profile=json.loads((out/DEST/'profiles'/f'{operator}.json').read_text())
        for col,binding in enumerate(profile['bindings']):
            name=binding['source_material'];x=112+col*245
            candidates=[(node,p) for node in g['nodes'] if 'mesh' in node
                        for p in g['meshes'][node['mesh']]['primitives']
                        if g['materials'][p['material']]['name']==name]
            node,p=next(((n,p) for n,p in candidates if 'Batch' in n.get('name','')),candidates[0])
            uv=get(p['attributes']['TEXCOORD_0']);pos=get(p['attributes']['POSITION']);ix=get(p['indices']).reshape(-1,3)
            ud.text((x,y+8),binding['role']+' '+name.removeprefix('sourceMaterial'),fill='white')
            ud.text((x,y+22),node['name'],fill=(159,182,191))
            xy=pos[:,:2];span=np.maximum(xy.max(0)-xy.min(0),1e-7)
            xy=(xy-xy.min(0))/max(span)*108
            for triangle in ix:
                points=[(x+float(uv[i,0])*108,y+50+float(uv[i,1])*108) for i in triangle]
                ud.line(points+[points[0]],fill=(96,135,142),width=1)
                points=[(x+124+float(xy[i,0]),y+158-float(xy[i,1])) for i in triangle]
                ud.line(points+[points[0]],fill=(121,124,146),width=1)
            ud.text((x,y+172),'UV1 / local XY (not native)',fill=(172,172,172))
    uv_sheet.save(out/NOTES/'uv-geometry-2d.png')
    # Review sheet is explicitly 2D flat palette multiplication, no native claims.
    sheet=Image.new('RGB',(1056,9*160),(28,33,39));draw=ImageDraw.Draw(sheet)
    for operator,index in previews:
        y=index*160;draw.text((8,y+8),operator,fill='white')
        color=next(o for o in CAT['operators'] if o['id']==operator)
        _,g,_=glb(ROOT/f'godot/source_operators/generated/{operator}.glb')
        mat=next(m for m in g['materials'] if m['name']==color['teamArmorMaterial'])
        linear=np.array(mat['pbrMetallicRoughness']['baseColorFactor'][:3])
        palette=np.where(linear<=.0031308,12.92*linear,1.055*linear**(1/2.4)-.055)
        for column,style in enumerate(('before','shell','panel','board','vent','normal','roughness')):
            if style=='before': im=Image.new('RGB',(128,128),tuple((palette*255).astype(int)))
            else:
                kind='normal' if style=='normal' else 'roughness' if style=='roughness' else 'albedo'
                fid='panel' if style in ('normal','roughness') else style
                im=Image.open(out/DEST/'assets'/f'{operator}-{fid}-{kind}.png').convert('RGB')
                if kind=='albedo': im=Image.fromarray((np.asarray(im)*palette).astype('uint8'))
                im=im.resize((128,128),Image.Resampling.LANCZOS)
            x=145+column*130;sheet.paste(im,(x,y+24));draw.text((x,y+8),style,fill='white')
    path=out/NOTES/'review-2d.png';path.parent.mkdir(parents=True,exist_ok=True);sheet.save(path)
    return finishes,textures,coverage


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        with tempfile.TemporaryDirectory(prefix='operator-finish-',dir='/tmp/opencode') as temp:
            out=Path(temp);f,t,c=generate(out)
            changed=[str(p.relative_to(out)) for p in out.rglob('*') if p.is_file()
                     and (not (ROOT/p.relative_to(out)).exists() or p.read_bytes()!=(ROOT/p.relative_to(out)).read_bytes())]
            assert not changed, 'Nonreproducible outputs: '+str(changed)
            print(f'Reproduction PASS: {len(c)} operators, {len(f)} finishes, {len(t)} texture maps; frozen GLB and Moth hashes verified')
    else:
        f,t,c=generate(ROOT);print(f'Generated {len(c)} profiles, {len(f)} finishes, {len(t)} maps')


if __name__=='__main__':
    main()
