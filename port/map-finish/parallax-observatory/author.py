"""Deterministic profile-v1 authoring; no engine, import or asset rebuild."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PROFILE = ROOT / 'godot/multiplayer_worlds/dressing/profiles/parallax-observatory.json'
HERE = Path(__file__).resolve().parent
HASH = '906be2ae3df33f54f779df3963a5985376ac96bb75bda94578ca4d3deb6d4554'


def build():
    p = dict(version=1, map_id='parallax-observatory', geometry_hash=HASH,
             materials=[], panels=[], signs=[], pockets=[], preserve_materials=['sea'],
             budgets=dict(material_variants=6, panels=64, signs=24, motes=40))
    mounts = []

    def material(source, family, variant, tint, **options):
        manufactured=source in ['metal','mirror']
        p['materials'].append(dict(source=source, family=family,
                                    options=dict(variant=variant, tint=tint, lut_gain=0,
                                                 pulse_speed=0, pulse_depth=0,
                                                 detail_strength=.06,ao_strength=.14,
                                                 variation_mode='manufactured' if manufactured else 'organic',
                                                 variation_strength=.10 if manufactured else .32,
                                                 variation_scale=.07,variation_seed=610260+len(p['materials']), **options)))

    material('saltstone', 'pearl-ceramic', 'cast', 'bcb29d', tiles_per_metre=1.3,
             roughness=.88, roughness_variation=.10, normal_strength=.10,
             texture_strength=.32, texture_saturation=0, albedo_gain=1.35,metallic=0,specular_strength=.18)
    material('cistern', 'pearl-ceramic', 'cast', '808b88', tiles_per_metre=1.2,
             roughness=.76, roughness_variation=.10, normal_strength=.10,
             texture_strength=.28, texture_saturation=0, albedo_gain=1.3,metallic=0,specular_strength=.20)
    material('metal', 'brushed-alloy', 'default', '747873', tiles_per_metre=1.4,
             roughness=.70, roughness_variation=.08, normal_strength=.06,
             texture_strength=.20,texture_saturation=0,albedo_gain=1.3, metallic=.42, specular_strength=.18)
    # Accepted source mirror is opaque optical alloy, not glazing.
    material('mirror', 'brushed-alloy', 'default', 'afb2a9', tiles_per_metre=1.5,
             roughness=.40, roughness_variation=.06, normal_strength=.035,
             texture_strength=.12,texture_saturation=0,albedo_gain=1.2, metallic=.55, specular_strength=.2)
    material('paving', 'pearl-ceramic', 'worn', '999787', tiles_per_metre=1.25,
             roughness=.92, roughness_variation=.12, normal_strength=.12,
             texture_strength=.36, texture_saturation=0, albedo_gain=1.35,metallic=0,specular_strength=.18)
    # Same batch includes painted survey diamonds/ticks and cabinet faces as
    # well as metal ribs: quiet ochre coating, not all-over corroded stock.
    material('ochre', 'pearl-ceramic', 'cast', 'aa925f', tiles_per_metre=1.4,
             roughness=.68, roughness_variation=.10, normal_strength=.06,
             texture_strength=.18, texture_saturation=0,albedo_gain=1.3, metallic=.03,specular_strength=.20)

    def mount(kind, id, position, yaw, size, host, story, **fields):
        p[kind].append(dict(id=id, position=position, rotation_degrees=[0,yaw,0],
                            size=size, **fields))
        mounts.append(dict(id=id, host=host, story=story))

    def panel(id, texture, pos, yaw, size, host, story, tint='ffffff'):
        wear={}
        if id.startswith(('pump-mineral-','pump-oxide-','polar-frost-','coastal-salt-')):
            wear=dict(wear_mask='weathered_concrete',opacity=.18,feather=.4,seed=610280+len(p['panels']))
        mount('panels', id, pos, yaw, size, host, story, texture=texture,
              tint=tint, essential=False,**wear)

    def sign(id, text, pos, yaw, size, host, story, foreground='dce5e6', background='263239'):
        mount('signs', id, pos, yaw, size, host, story, text=text,
              foreground=foreground, background=background, essential=True)

    # Inserts occupy the blank outer edge of the existing plate cabinet faces;
    # the black instrument slots remain readable. No full-wall emissive overlay.
    for side in (-1,1):
        yaw = 0 if side == -1 else 180
        host = f'ephemeris-vault-wall-{side}'
        for j in range(9):
            x = -36 - 26*.44 + j*26*.11
            panel(f'archive-ceramic-{side}-{j}', 'weathered_concrete',
                  [round(x-.64,3),13.8,side*7.105], yaw, [.4,.64], host,
                  'Clean ceramic retrieval insert, beside the accepted cassette slots.', 'd8cfb9')
        for j, x in enumerate((-43.2,-28.8)):
            sign(f'archive-index-{side}-{j}', f'PLATES / {"A" if side == -1 else "B"}{j+1:02}',
                 [x,15.39,side*7.17], yaw, [3.7,.3], host,
                 'Disciplined storage-row index in the clear band above the top cabinet.',
                 'dbe7dd','334047')

    # Mineral films on the pump cabinet backs, plus narrow oxidised maintenance
    # bands between cabinets and wall dado. Avoid the accepted pressure risers.
    for side in (-1,1):
        yaw = 0 if side == -1 else 180
        host = f'tidal-pump-vault-wall-{side}'
        for j in (1,3,5,7):
            x = 24 - 26*.44 + j*26*.11
            panel(f'pump-mineral-{side}-{j}', 'weathered_concrete-worn',
                  [round(x-.16,3),.8,78+side*7.105], yaw, [1.35,.62], host,
                  'Damp salt/mineral deposit on a low pump instrument backing.', 'a6a18f')
        for j, x in enumerate((18.2,24.2,30.2)):
            panel(f'pump-oxide-{side}-{j}', 'metal-oxide',
                  [x,3.29,78+side*7.17], yaw, [1.25,.12], host,
                  'Oxidation at the upper service band, below the wall-bound header.', 'a39173')
        for j, x in enumerate((18.2,30.2)):
            sign(f'pump-service-{side}-{j}', f'{"SUPPLY" if side == -1 else "RETURN"} / P{j+1:02}',
                 [x,3.48,78+side*7.15], yaw, [3.5,.18], host,
                 'Supply/return identification above the pressure equipment.', 'd5ddbd','354239')

    # Frost is restricted to the cold exterior-side optical-wall upper band.
    # Four small instrument faces sit inside the existing spectrometer hubs.
    for side in (-1,1):
        yaw = 0 if side == -1 else 180
        for x in (-12,12):
            host = f'polar-hall-side-{side}-{-1 if x < 0 else 1}'
            panel(f'polar-frost-{side}-{x}', 'ice-cracked',
                  [x,31.25,-84+side*11.47], yaw, [4.2,.6], host,
                  'Localized frost above the spectrometer, away from the supported floor.', 'a6c1ca')
            panel(f'polar-optics-{side}-{x}', 'holographic_grid',
                  [x,28,-84+side*11.40], yaw, [.8,.8], host,
                  'Calibration readout inside the real radial spectrometer hub.', '8fbdc9')
    for x in (-12,12):
        sign(f'polar-sector-{x}', f'POLAR / S{1 if x < 0 else 2:02}',
             [x,24.92,-95.47], 0, [3.5,.36], f'polar-hall-side--1-{-1 if x < 0 else 1}',
             'Sector label below the data band, clear of the four actual portals.')

    # Real cover cabinets carry diagnostic electronics on their blank inward
    # faces. Mirror-petal landmarks and open apertures receive no panel geometry.
    for side in (-1,1):
        for x in (-78,-18,18,78):
            panel(f'calibrator-{side}-{x}', 'holographic_grid' if side == -1 else 'circuit_board-etch',
                  [x,13.1,side*5.475], 0 if side == -1 else 180, [1.8,.72],
                  f'meridian-calibrator-{side}-{x}',
                  'Mounted diagnostic panel on the actual source-solid calibration pedestal.',
                  '91b4bf' if side == -1 else '95a992')

    # Salt weathering belongs on the exposed plinth, not as interior fog.
    for x,z,w in ((-66,-10,10),(-18,-10,9),(84,-10,12),(82,10,10)):
        side = -1 if z < 0 else 1
        panel(f'coastal-salt-{x}', 'weathered_concrete-worn',
              [x,12.65,z-side*2.525], 0 if side == -1 else 180, [w*.65,.45],
              f'institute-wing-{x}-{z}', 'Salt-spray footing along the exposed institute facade.', 'a6b0a4')

    for x, yaw, name in ((-49.03,-90,'WEST'),(-22.97,90,'EAST')):
        sign(f'archive-entry-{name.lower()}', 'E1 / PLATE ARCHIVE', [x,14.5,-5.4], yaw, [3.8,.65],
             f'ephemeris-vault-jamb--1-{-1 if name == "WEST" else 1}',
             'Approach label mounted entirely on a source-solid jamb; axial opening remains clear.')
    for x, yaw, name in ((10.97,-90,'WEST'),(37.03,90,'EAST')):
        sign(f'pump-entry-{name.lower()}', 'T3 / TIDAL PUMP', [x,2.5,72.6], yaw, [3.4,.65],
             f'tidal-pump-vault-jamb--1-{-1 if name == "WEST" else 1}',
             'Lower-tier pump identification on the outer approach jamb.', 'e5dab5','354039')
    for x in (-114,114):
        sign(f'arrival-route-{x}', 'E1 ARCHIVE / MID +12' if x < 0 else 'O2 OPTICS / MID +12',
             [x,13.8,8.97], 180, [5.6,.65], f'district-baffle-{-1 if x < 0 else 1}',
             'Useful arrival route/altitude sign on the solid district baffle.')
    sign('north-wayfinding','POLAR / NORTH +24',[-66,13.8,-7.47],0,[5.2,.65],
         'institute-wing--66--10','Upper-tier wayfinding on the actual institute wing.')
    sign('south-wayfinding','TIDAL / SOUTH +0',[82,13.8,7.47],180,[5.2,.65],
         'institute-wing-82-10','Lower-tier wayfinding on the actual institute wing.')

    p['pockets'] = [
        dict(id='pump-header-vent',kind='vent',position=[20,4.1,71.08],size=[.5,.4,.35],color='a9c5bd',count=8),
        dict(id='pump-return-mist',kind='mist',position=[28,4.1,84.92],size=[.5,.4,.35],color='a9c5bd',count=8),
        dict(id='archive-shelf-dust',kind='dust',position=[-44,15.35,6.65],size=[.6,.3,.4],color='c5cbbb',count=4),
        dict(id='polar-cold-vent-west',kind='mist',position=[-12,31.15,-95.1],size=[.6,.4,.3],color='b6d1db',count=6),
        dict(id='polar-cold-vent-east',kind='mist',position=[12,31.15,-95.1],size=[.6,.4,.3],color='b6d1db',count=6),
    ]
    # Interiors v2 replaces the old flat panel backs with recessed machinery.
    # Retire those floating overlays; place labels and wear on the retained
    # continuous front cap/sill, leaving cassettes and hydraulic anatomy exposed.
    retired = {m['id'] for m in mounts if m['host'].startswith(('ephemeris-vault-wall-', 'tidal-pump-vault-wall-'))}
    for kind in ('panels', 'signs'):
        p[kind] = [item for item in p[kind] if item['id'] not in retired]
    mounts = [m for m in mounts if m['id'] not in retired]
    for side in (-1,1):
        yaw = 0 if side == -1 else 180
        # The 18 cm cap is too short for readable native text. Existing large
        # source-solid entry-jamb signs identify these rooms instead.
        for j,x in enumerate((15,23,32)):
            panel(f'pump-mineral-sill-{side}-{j}','weathered_concrete-worn',
                  [x,.09,78+side*7.17],yaw,[2,.12],f'tidal-pump-vault-wall-{side}',
                  'Localized mineral film on continuous source-solid pump sill.','a6a18f')
    return p, dict(version=1, geometry_hash=HASH, mounts=mounts)


if __name__ == '__main__':
    import argparse
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('--write',action='store_true')
    if args.parse_args().write:
        profile, mounts = build()
        PROFILE.parent.mkdir(parents=True,exist_ok=True)
        PROFILE.write_text(json.dumps(profile,indent=2)+'\n')
        (HERE/'mounts.json').write_text(json.dumps(mounts,indent=2)+'\n')
    else:
        print(json.dumps(build()[0],indent=2))
