"""Map-local material policy; canonical Sol adapter owns only Moth PBR.

Preserved constants are transcribed from accepted source authors, not inferred
from names. The new Helix pool has its own explicit candidate BRDF below.
"""
from export_audit import validate_bindings


def linear_hex(value):
    rgb=[int(value[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)


PRESERVED = {
    'helix-conservatory': {
        'glass': {'color':(.15,.36,.32,.08),'roughness':.72,'metallic':0,'alpha':.08,
                  'source':'helix-conservatory/blender_author.py:29-50'},
        'water': {'color':(.15,.36,.32,.65),'roughness':.18,'metallic':0,'alpha':.65,
                  'transmission':.25,'ior':1.333,
                  'source':'revision-3 new grotto pool; explicit Helix green palette / liquid BRDF'},
    },
    'parallax-observatory': {
        'sea': {'color':(*tuple((int('#242c49'[i:i+2],16)/255)**2.2 for i in (1,3,5)),1),
                'roughness':.78,'metallic':.05,'alpha':1,
                'source':'parallax-observatory/blender_author.py:38-46 / accepted palette sea'},
    },
    'vesper-viaduct': {
        'glass': {'color':(*linear_hex('#243c58'),1),'roughness':.83,'metallic':0,'alpha':1,
                  'source':'vesper-viaduct/author_blender.py:19-61'},
        'water': {'color':(*linear_hex('#224675'),1),'roughness':.36,'metallic':0,'alpha':1,
                  'source':'vesper-viaduct/author_blender.py:19-61'},
        'letter': {'color':(*linear_hex('#f1c27b'),1),'roughness':.83,'metallic':0,'alpha':1,
                   'source':'vesper-viaduct/author_blender.py:19-61; accepted lettering is not emissive'},
    },
}


def adapter_bindings(bindings):
    """Normalize candidate registry to Sol 6ff4079e's exact PBR-only interface."""
    validate_bindings(bindings)
    if bindings['mapId'] not in PRESERVED:
        raise ValueError('Unreviewed map palette: '+bindings['mapId'])
    pbr={}
    for name,binding in bindings['materials'].items():
        if binding['role']=='preserve':
            if name not in PRESERVED[bindings['mapId']]:
                raise ValueError('Unreviewed preserved material: '+name)
            continue
        pbr[name]={'material':binding['resource'],'role':'surface','normal':True}
        if 'metallic' in binding:pbr[name]['metallic']=binding['metallic']
    return pbr


def load_reviewed_materials(adapter, root, bindings, output_dir):
    import bpy
    pbr=adapter_bindings(bindings)
    materials,density,receipt=adapter.load_materials(root,pbr,output_dir=output_dir,with_report=True)
    if set(materials)!=set(pbr) or set(density)!=set(pbr):
        raise ValueError('Sol adapter returned incorrect PBR material keys')
    receipt['preserved']={}
    receipt['mapOverrides']={}
    for name,binding in bindings['materials'].items():
        if binding['role']=='preserve':
            spec=PRESERVED[bindings['mapId']][name]
            mat=bpy.data.materials.new(name)
            mat.use_nodes=True
            mat.diffuse_color=spec['color']
            bs=mat.node_tree.nodes.get('Principled BSDF')
            for socket,value in [('Base Color',spec['color']),('Roughness',spec['roughness']),
                                 ('Metallic',spec['metallic']),('Alpha',spec['alpha']),
                                 ('Transmission Weight',spec.get('transmission',0)),('IOR',spec.get('ior',1.5))]:
                bs.inputs[socket].default_value=value
            if spec['alpha']<1:mat.surface_render_method='DITHERED'
            materials[name]=mat
            receipt['preserved'][name]=spec
        else:
            normals=[n for n in materials[name].node_tree.nodes if n.type=='NORMAL_MAP']
            if len(normals)!=1:raise ValueError('Expected exactly one reviewed normal node: '+name)
            normals[0].inputs['Strength'].default_value=binding.get('normalStrength',1)
        # These are deliberately reviewed per-map repeat densities. Preserve the
        # adapter's pack density in its receipt and record the applied override.
        density[name]=binding['tilesPerMeter']
        receipt['mapOverrides'][name]={'tilesPerMeter':density[name],
                                      'normalStrength':binding.get('normalStrength')}
    packed=set()
    for mat in materials.values():
        for node in mat.node_tree.nodes:
            if node.type!='TEX_IMAGE':continue
            image=node.image
            if image is None:raise ValueError('Unbound material image')
            if image not in packed:
                image.pack()
                if not image.packed_file:raise ValueError('Image did not pack: '+image.name)
                image.filepath='//packed/'+image.name
                packed.add(image)
    receipt['packedImages']=len(packed)
    return materials,density,receipt


def assert_packed_materials(materials):
    for mat in materials:
        if not mat.use_nodes:continue
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and (node.image is None or not node.image.packed_file):
                raise ValueError('Master depends on an unpacked external image: '+mat.name)
