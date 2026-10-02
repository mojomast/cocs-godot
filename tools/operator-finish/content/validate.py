#!/usr/bin/env python3
"""Contract/coverage/resource tests independent of generated expected bindings."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

from build import ROOT, DEST, IDS, MOTH, audit, sha


def validate():
    manifest=json.loads((ROOT/DEST/'manifest.json').read_text())
    assert manifest['version']==1
    assert manifest['provenance']['generator_sha256']==sha((ROOT/'tools/operator-finish/content/build.py').read_bytes())
    used=set();patterns=set();summaries={}
    for operator in IDS:
        profile=json.loads((ROOT/DEST/'profiles'/f'{operator}.json').read_text())
        assert profile['version']==1 and profile['operator_id']==operator
        actual=audit(operator)
        bound={b['source_material'] for b in profile['bindings']}
        preserve={p['source_material'] for p in profile['preserve_materials']}
        assert not bound & preserve
        assert bound | preserve == set(actual['materials']), 'Unclassified real material'
        assert actual['team_armor_material'] in bound
        assert 'sourceTeamIvory' in preserve and 'sourceMaterial2' in preserve
        for name,e in actual['materials'].items():
            m=e['material']
            protected=(any(m.get('emissiveFactor',[0,0,0])) or m.get('alphaMode','OPAQUE')!='OPAQUE'
                       or 'weapon' in e['ancestors'] or 'gunAnchor' in e['ancestors'])
            assert not protected or name in preserve, 'Protected optics/weapon material bound'
        assert all(p['uv1'] for p in actual['primitives'])
        for p in actual['primitives']:
            assert np.min(p['uv_bounds']) >= -1e-6 and np.max(p['uv_bounds']) <= 1+1e-6
        refs=[b['finish'] for b in profile['bindings']]+list(profile['overlay_finishes'].values())
        assert set(profile['overlay_finishes'])=={'panel','board','vent'}
        for fid in refs:
            finish=manifest['finishes'][fid]
            assert finish['albedo_mode']=='modulate'
            for scalar in ('metallic','roughness_gain','normal_strength'):
                assert 0 <= finish[scalar] <= 1
            for channel in ('albedo','roughness','normal'):
                if channel in finish:
                    used.add(finish[channel])
        panel=manifest['finishes'][profile['overlay_finishes']['panel']]['albedo']
        patterns.add(manifest['textures'][panel]['pixel_sha256'])
        summaries[operator]={'bindings':len(bound),'preserved_material_names':len(preserve),
                             'covered_primitives':sum(p['material'] in bound for p in actual['primitives']),
                             'all_primitives':len(actual['primitives'])}
    assert len(patterns)==9, 'Identical neutral identity patterns'
    assert used==set(manifest['textures']), 'Orphan/unrecorded texture resource'
    assert len(used)<=120
    for resource,rec in manifest['textures'].items():
        p=ROOT/'godot'/resource.removeprefix('res://')
        im=Image.open(p);a=np.asarray(im)
        assert sha(p.read_bytes())==rec['png_sha256'] and sha(im.tobytes())==rec['pixel_sha256']
        assert list(im.size)==rec['dimensions']==[256,256]
        if resource.endswith('-albedo.png'):
            assert im.mode=='RGB' and (a[:,:,0]==a[:,:,1]).all() and (a[:,:,1]==a[:,:,2]).all()
            assert a.min()>=168 and a.mean()>225, 'Palette crushed by modulation'
            assert (a[3,3]>=235).all(), 'Overlay bevel bare-paint sample darkened'
        elif resource.endswith('-normal.png'):
            n=a.astype(float)/255*2-1
            assert np.max(abs(np.linalg.norm(n,axis=2)-1)) < .012, 'Normal not renormalized'
            assert n[:,:,2].min()>.75
        else:
            assert im.mode=='L' and a.min()>=40 and a.max()<=250
            # Shared shell UVs intentionally carry only coating grain: forcing
            # overlay-level contrast here restores repeated anatomical panels.
            minimum = 2 if resource.endswith('-shell-roughness.png') else 8
            assert int(a.max())-int(a.min())>=minimum, 'Roughness carries no useful variation'
        for key in rec['moth_keys']:
            assert key.split('/')[1] in MOTH['textures']
    for key,source in manifest['provenance']['moth_sources'].items():
        record=MOTH['textures'][key];p=ROOT/'godot'/record['path'].removeprefix('res://')
        assert sha(p.read_bytes())==source['png_sha256']==record['png_sha256']
    actual_assets={str(p.relative_to(ROOT/'godot')) for p in (ROOT/DEST/'assets').glob('*.png')}
    assert actual_assets=={r.removeprefix('res://') for r in used}
    total=sum((ROOT/'godot'/r.removeprefix('res://')).stat().st_size for r in used)
    assert total<2_000_000
    return {'status':'PASS','scope':'source-only; native validation pending','operators':summaries,
            'finishes':len(manifest['finishes']),'unique_png_maps':len(used),'png_bytes':total,
            'tests':['exact real-material classification','protected material exclusion','frozen catalog GLB hashes',
                     'all primitive UV1 and ranges','neutral bounded albedo and bare bevel sample',
                     'roughness R variation','decoded normal unit length','nine unique untinted panel patterns',
                     'resource and pixel hashes','real Moth registry source hashes','bounded unique map budget']}


if __name__=='__main__':
    print(json.dumps(validate(),indent=2,sort_keys=True))
