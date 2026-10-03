"""Bounded semantic contract for Foundry's core metallic/roughness materials."""
from tangents import *
sys.path.insert(0,str(ROOT/'tools/map-variety-pipeline'))
from material_pack import linear_rgba
from functools import lru_cache

@lru_cache(maxsize=64)
def pixel_identity(raw,channels):
    w,h,pixels=linear_rgba(raw)
    return w,h,sha(bytes(v for i,v in enumerate(pixels) if i%4 in channels))

def fields(obj,allowed):
    if not isinstance(obj,dict) or set(obj)-set(allowed)-{'name','extras'}:
        raise ValueError('Unsupported material/texture semantics')

def binding(g,slot,kind):
    if slot is None:return None
    fields(slot,{'index','texCoord','scale' if kind=='normal' else 'strength' if kind=='occlusion' else ''})
    if type(slot.get('texCoord',0)) is not int or slot.get('texCoord',0)!=0:
        raise ValueError('Unsupported texture coordinate selection')
    texture=g.doc['textures'][slot['index']];fields(texture,{'source','sampler'})
    image=g.doc['images'][texture['source']];fields(image,{'bufferView','mimeType'})
    sampler={} if 'sampler' not in texture else g.doc['samplers'][texture['sampler']]
    fields(sampler,{'wrapS','wrapT','magFilter','minFilter'})
    state=[]
    for key,default,valid in [('wrapS',10497,{33071,33648,10497}),('wrapT',10497,{33071,33648,10497}),
            ('magFilter',None,{9728,9729}),('minFilter',None,{9728,9729,9984,9985,9986,9987})]:
        value=sampler.get(key,default)
        if key in sampler and (type(value) is not int or value not in valid):raise ValueError('Invalid sampler enum')
        state.append(value)  # Unspecified filter remains implementation-defined, never guessed.
    channels={'metallicRoughness':(1,2),'occlusion':(0,),'emissive':(0,1,2),'normal':(0,1,2)}.get(kind,(0,1,2,3))
    return (tuple(state),slot.get('texCoord',0),*pixel_identity(g.image_bytes(slot),channels))

def semantics(g,m):
    fields(m,{'pbrMetallicRoughness','normalTexture','occlusionTexture','emissiveTexture','emissiveFactor',
        'alphaMode','alphaCutoff','doubleSided','extensions'})
    p=m.get('pbrMetallicRoughness',{})
    fields(p,{'baseColorFactor','metallicFactor','roughnessFactor','baseColorTexture','metallicRoughnessTexture'})
    ext=m.get('extensions',{})
    if set(ext)-{'KHR_materials_emissive_strength'}:raise ValueError('Unsupported material extension')
    strength=ext.get('KHR_materials_emissive_strength',{});fields(strength,{'emissiveStrength'})
    alpha=m.get('alphaMode','OPAQUE')
    if alpha not in ('OPAQUE','MASK','BLEND') or type(m.get('doubleSided',False)) is not bool:raise ValueError('Invalid material rendering policy')
    slots=[('baseColor',p.get('baseColorTexture')),('metallicRoughness',p.get('metallicRoughnessTexture')),
        ('normal',m.get('normalTexture')),('occlusion',m.get('occlusionTexture')),('emissive',m.get('emissiveTexture'))]
    bindings={kind:binding(g,slot,kind) for kind,slot in slots}
    scalars=[*p.get('baseColorFactor',[1,1,1,1]),p.get('metallicFactor',1),p.get('roughnessFactor',1),
        *m.get('emissiveFactor',[0,0,0]),strength.get('emissiveStrength',1),
        m.get('normalTexture',{}).get('scale',1),m.get('occlusionTexture',{}).get('strength',1),m.get('alphaCutoff',.5)]
    if len(scalars)!=13 or any(type(v) not in (int,float) or not math.isfinite(v) for v in scalars):raise ValueError('Invalid material scalar')
    return bindings,(alpha,m.get('doubleSided',False)),scalars

def compare_materials(a,b):
    originals={m['name']:m for m in a.doc['materials']};new={m['name']:m for m in b.doc['materials']}
    if len(originals)!=len(a.doc['materials']) or len(new)!=len(b.doc['materials']) or set(originals)!=set(new):raise ValueError('Material inventory changed')
    for name,m in originals.items():
        old=semantics(a,m);actual=semantics(b,new[name])
        if old[:2]!=actual[:2]:raise ValueError('Material texture/render semantics changed: '+name)
        if any(abs(x-y)>1e-6 for x,y in zip(old[2],actual[2])):raise ValueError('Material PBR/emission fields changed: '+name)

def verify_native_materials(g,report):
    """Godot 4.5.2 probe: colors serialize as four-decimal sRGB Color strings.

    Energy is emission_energy_multiplier (not physical luminance); other scalars
    are float32. No historical native receipt is reclassified as an R7 run.
    """
    materials=report['materials']
    if set(materials)!={m['name'] for m in g.doc['materials']}:raise ValueError('Native material inventory changed')
    def srgb(x):return 12.92*x if x<=.0031308 else 1.055*x**(1/2.4)-.055
    for m in g.doc['materials']:
        semantics(g,m)
        p=m.get('pbrMetallicRoughness',{});row=materials[m['name']]
        base=p.get('baseColorFactor',[1,1,1,1]);em=m.get('emissiveFactor',[0,0,0])
        for key,want in [('albedo',[*(srgb(x) for x in base[:3]),base[3]]),('emission',[*(srgb(x) for x in em),1])]:
            value=row[key]
            if not isinstance(value,str) or not value.startswith('(') or not value.endswith(')'):raise ValueError('Native Color schema changed')
            actual=[float(x) for x in value[1:-1].split(',')]
            if len(actual)!=4 or any(not math.isfinite(x) or abs(x-y)>5.1e-5 for x,y in zip(actual,want)):raise ValueError('Native material '+key+' changed')
        for key,want in [('metallic',p.get('metallicFactor',1)),('roughness',p.get('roughnessFactor',1)),
                ('normalScale',m.get('normalTexture',{}).get('scale',1)),
                ('emissionEnergy',m.get('extensions',{}).get('KHR_materials_emissive_strength',{}).get('emissiveStrength',1))]:
            value=row[key]
            if type(value) not in (int,float) or not math.isfinite(value) or abs(value-want)>1e-6:raise ValueError('Native material '+key+' changed')
        enabled=any(x>0 for x in em) or 'emissiveTexture' in m
        if type(row['emissionEnabled']) is not bool or row['emissionEnabled']!=enabled:raise ValueError('Native emissionEnabled changed')
        channel=1 if 'metallicRoughnessTexture' in p else 0
        if type(row['roughnessChannel']) is not int or row['roughnessChannel']!=channel:raise ValueError('Native roughnessChannel changed')
    return len(materials)
