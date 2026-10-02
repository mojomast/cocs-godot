"""Switchyard workshop, seed 31027. Pure source recipe; no bpy dependency.

Coordinates are joint-local Godot metres. Rigid weights deliberately avoid
rubbery armour. Runtime joints and contact solver remain RobotVisual-owned.
"""
import json
import math

SEED = 31027
SKINS = {'needle_surveyor': 'skirmisher', 'caisson_guard': 'bulwark',
         'kiln_tender': 'mortar'}
PALETTE = {'armor': [0.21, 0.37, 0.36, 1], 'dark': [0.035, 0.052, 0.065, 1],
           'steel': [0.43, 0.51, 0.53, 1], 'ceramic': [0.73, 0.67, 0.49, 1],
           'optic': [1, 0.31, 0.09, 1], 'coolant': [0.1, 0.65, 0.73, 1]}


def robot(skin, lod=0):
    role = SKINS[skin]
    biped = role != 'mortar'
    width = .38 if role == 'skirmisher' else .72
    height = 1.12 if biped else .72
    joints = {'Chassis': {'parent': None, 'at': [0, height, 0]},
              'Turret': {'parent': 'Chassis', 'at': [0, .3 if biped else .22, -.12]},
              'Optics': {'parent': 'Turret', 'at': [0, 0, 0]},
              'Weapon': {'parent': 'Turret', 'at': [.3 if biped else 0, -.12, -.2]}}
    pieces = []

    def box(j, name, p, s, mat='armor', bevel=.015):
        shape = 'plate' if name in ['split_breastplate','armored_crossbeam','split_saddle','sensor_cowl','overlapping_scute','contact_sole'] else 'box'
        pieces.append(dict(joint=j, name=name, shape=shape, p=list(p), size=list(s),
                           material=mat, bevel=bevel))

    def rod(j, name, a, b, radius, mat='steel'):
        pieces.append(dict(joint=j, name=name, shape='tube' if name in ['barrel','tube'] else 'rod', a=list(a), b=list(b),
                           radius=radius, material=mat, bevel=min(.008, radius/4)))

    # Three separate load-bearing architectures; rear and belly are authored too.
    if role == 'skirmisher':
        box('Chassis', 'narrow_keel', [0, -.02, 0], [.28, .46, .43], 'dark', .035)
        for side in [-1, 1]:
            box('Chassis', 'split_breastplate', [side*.105, .055, -.13], [.12, .36, .18], bevel=.035)
        box('Chassis', 'survey_counterweight', [-.27, .09, 0], [.24, .22, .35], 'ceramic', .035)
        rod('Chassis', 'counterweight_strut', [-.27, .03, 0], [-.29, -.37, -.1], .034)
        box('Chassis', 'rear_spine', [0, -.02, .22], [.11, .35, .06], 'steel')
    elif role == 'bulwark':
        box('Chassis', 'armored_crossbeam', [0, .05, 0], [.71, .37, .46], bevel=.045)
        box('Chassis', 'suspended_belly', [0, -.17, .02], [.5, .12, .43], 'dark')
        for side in [-1, 1]:
            box('Chassis', 'shoulder_laminate', [side*.28, .11, -.12], [.16, .26, .23], 'ceramic', .035)
        joints['Shield'] = {'parent': 'Chassis', 'at': [-.46, .04, -.27]}
        box('Shield', 'backing', [0, -.05, -.15], [.6, 1.06, .2], 'dark', .035)
        for y in [-.37, -.06, .25]:
            box('Shield', 'overlapping_scute', [0, y, -.26], [.53, .29, .07], bevel=.023)
        rod('Shield', 'rear_grip', [-.16, -.2, -.08], [.16, .12, -.08], .035)
    else:
        box('Chassis', 'low_pressure_hull', [0, .02, 0], [.69, .3, .77], 'dark', .05)
        for side in [-1, 1]:
            box('Chassis', 'split_saddle', [side*.24, .11, 0], [.2, .22, .69], bevel=.04)
        box('Chassis', 'underside_service_hatch', [0, -.16, 0], [.4, .08, .52], 'steel')
    # Functional rear radiator and protected coolant cells, distinct from status optics.
    if lod < 2:
        for x in [-width*.25, width*.25]:
            rod('Chassis', 'coolant_cell', [x, -.09, .17], [x, .13, .17], .035, 'coolant')
        for y in [-.06, .01, .08]:
            box('Chassis', 'rear_radiator', [0, y, .25 if biped else .39], [width*.65, .025, .025], 'steel', .003)
    for i in range(2 if biped else 4):
        side = -1 if i % 2 == 0 else 1
        tip = [side*width*.45, .09, 0] if biped else [side*(width*.5+.38), .09, -.5 if i < 2 else .5]
        origin = [side*width*.4, height-.12, tip[2]*.5]
        knee = [tip[0]-origin[0], (tip[1]-origin[1])*.48,
                (tip[2]-origin[2])*.6 + (.16 if biped else 0)]
        end = [tip[n]-origin[n]-knee[n] for n in range(3)]
        hip, shin = f'Hip{i}', f'Shin{i}'
        joints[hip] = {'parent': None, 'at': origin}
        joints[shin] = {'parent': hip, 'at': knee}
        rod(hip, 'upper_load_link', [0, 0, 0], knee, .055 if role == 'skirmisher' else .095, 'dark')
        rod(hip, 'armor_sleeve', [v*.18 for v in knee], [v*.72 for v in knee], .075 if role == 'skirmisher' else .12, 'armor')
        target = hip if lod == 2 else shin
        start, stop = (knee, [knee[n]+end[n] for n in range(3)]) if lod == 2 else ([0, 0, 0], end)
        rod(target, 'shin_ram', start, stop, .06 if role == 'skirmisher' else .09)
        box(target, 'contact_sole', stop, [.18 if role == 'skirmisher' else .25, .18, .38 if biped else .23], 'dark')
        if lod == 0:
            for tread in [-.06, .04]:
                box(target, 'toe_cleat', [stop[0],stop[1]+.082,stop[2]+tread],
                    [.16 if role == 'skirmisher' else .23,.024,.034], 'steel', .005)
        if lod < 2:
            rod(hip, 'axle', [-.1, 0, 0], [.1, 0, 0], .1, 'steel')
            rod(shin, 'knee_axle', [-.09, 0, 0], [.09, 0, 0], .095, 'ceramic')
            a = [knee[0]+.055, knee[1]*.15, knee[2]*.15]
            b = [knee[0]+.055, knee[1]*.78, knee[2]*.78]
            rod(hip, 'piston_parallel', a, b, .022)
    rod('Turret', 'turntable_bearing', [0, -.06, 0], [0, .09, 0], width*.28, 'dark')
    box('Turret', 'sensor_cowl', [0, .12, 0], [width*.84, .21, .39], 'armor', .035)
    box('Optics', 'status_slit', [0, .12, -max(width*.399,.215)], [width*.42, .045, .018], 'optic', .004)
    if lod < 2:
        box('Turret', 'sensor_brow', [0,.21,-.16], [width*.76,.06,.13], 'ceramic', .012)
    if lod == 0:
        for side in [-1, 1]:
            rod('Turret', 'azimuth_spindle', [side*width*.4,.09,-.04], [side*width*.4,.09,.12], .043, 'steel')
    if role == 'mortar':
        # A service-tool cradle around the existing artillery tube; no new ability.
        box('Weapon', 'pressure_breech', [0, .24, -.14], [.4, .29, .68], 'ceramic', .04)
        rod('Weapon', 'tube', [0, .28, -.26], [0, .57, -.36], .16, 'dark')
        for side in [-1, 1]:
            rod('Weapon', 'fork_tool', [side*.2, .12, .03], [side*.2, .43, -.29], .04)
    else:
        box('Weapon', 'receiver', [0, 0, -.2], [.16 if role == 'skirmisher' else .27, .19, .5], 'dark')
        rod('Weapon', 'barrel', [0, 0, -.4], [0, 0, -.605], .078 if role == 'skirmisher' else .12)
    if lod == 0:
        for side in [-1, 1]:
            for y in [-.09, .17]:
                rod('Chassis', 'captive_fastener', [side*width*.33, y, -.235], [side*width*.33, y, -.25], .016)
            # Segmented flexible harness remains wholly on the chassis rigid weight.
            for n in range(6):
                a = [side*width*.32, -.13+n*.04, .2]
                b = [side*width*.32, -.09+n*.04, .2]
                rod('Chassis', 'harness', a, b, .017, 'dark')
    return dict(id=skin, role=role, lod=lod, joints=joints, pieces=pieces,
                sockets={'forward': [0, 0, -1], 'feetOrigin': [0, -.9, 0]},
                collision='none; authority source unchanged', rigidWeight=1)


def props():
    """Open frames have no blocker, collider, or installation side effect."""
    out = {}
    def add(name, parts):
        out[name] = [dict(joint='Root', name=f'{name}_{i}', shape='box', p=p,
                          size=s, material=m, bevel=.025) for i, (p, s, m) in enumerate(parts)]
    add('relay_console', [([0,.45,0],[.55,.9,.35],'dark'), ([0,.95,-.05],[.8,.24,.48],'armor'), ([0,1.08,-.06],[.55,.025,.3],'coolant')])
    add('repair_dock', [([0,.06,0],[1.5,.12,1.2],'dark'), ([-.65,.65,.4],[.16,1.2,.2],'armor'), ([.65,.65,.4],[.16,1.2,.2],'armor'), ([0,1.25,.4],[1.4,.16,.2],'ceramic')])
    add('battery_rack', [([0,.08,0],[1.2,.16,.5],'dark')] + [([x,.5,0],[.23,.75,.35],'armor') for x in [-.4,0,.4]] + [([0,.92,0],[1.2,.1,.5],'steel')])
    add('blast_shutter_frame', [([-1.1,1.2,0],[.2,2.4,.35],'armor'), ([1.1,1.2,0],[.2,2.4,.35],'armor'), ([0,2.4,0],[2.4,.2,.35],'ceramic')])
    add('cargo_stack', [([-.32,.3,0],[.6,.6,.6],'armor'), ([.32,.3,0],[.6,.6,.6],'ceramic'), ([0,.9,0],[.6,.6,.6],'dark')])
    add('cable_junction', [([0,.25,0],[.65,.5,.3],'armor')] + [([x,.1,.28],[.08,.12,.5],'dark') for x in [-.2,0,.2]])
    # Common recessed service strip and four visible retaining studs.
    for name, pieces in out.items():
        p = pieces[0]['p']; s = pieces[0]['size']
        for side in [-1, 1]:
            for level in [-1, 1]:
                pieces.append(dict(joint='Root', name='retainer', shape='rod',
                    a=[p[0]+side*s[0]*.35,p[1]+level*s[1]*.35,p[2]-s[2]/2],
                    b=[p[0]+side*s[0]*.35,p[1]+level*s[1]*.35,p[2]-s[2]/2-.02],
                    radius=.02, material='steel', bevel=.003))
        # Recessed, legible service panels on each assembly, using the same kit
        # rather than leaving the support props as anonymous uninterrupted boxes.
        width = min(.46, s[0]*.68)
        for n in range(3):
            pieces.append(dict(joint='Root',name='service_vent',shape='box',
                p=[p[0],p[1]+(n-1)*.075,p[2]-s[2]/2-.01],
                size=[width,.028,.022],material='dark',bevel=.004))
        pieces.append(dict(joint='Root',name='service_indicator',shape='box',
            p=[p[0],p[1]+s[1]*.35,p[2]-s[2]/2-.018],
            size=[width*.45,.035,.025],material='coolant',bevel=.004))
    # Dock actuators and rack cell caps create functional negative space/detail.
    for side in [-1,1]:
        out['repair_dock'].append(dict(joint='Root',name='dock_actuator',shape='rod',
            a=[side*.56,.25,.23],b=[side*.56,.95,.23],radius=.042,material='steel',bevel=.008))
    for x in [-.4,0,.4]:
        out['battery_rack'].append(dict(joint='Root',name='cell_cap',shape='box',
            p=[x,.82,-.19],size=[.16,.08,.05],material='ceramic',bevel=.008))
    return out


def manifest():
    return dict(seed=SEED, palette=PALETTE, robots=[robot(s, l) for s in SKINS for l in range(3)], props=props())


if __name__ == '__main__':
    print(json.dumps(manifest(), sort_keys=True, separators=(',', ':')))
