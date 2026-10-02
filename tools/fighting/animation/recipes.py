"""Authored task-space keys; stdlib only. Forward/up/lateral coordinates, metres.

Hands are shoulder-relative fractions of arm length. Feet are floor-relative
metres. Blender resolves these curves against each robot's measured anatomy.
These are production recipes, not claims of accepted exported animation.
"""
from copy import deepcopy
import hashlib
import json
import math

OPERATORS = ('chatgpt', 'claude', 'grok', 'meta', 'gemini', 'deepseek', 'mistral', 'kimi', 'qwen')
STATES = tuple('idle walk_f walk_b crouch jump_rise jump_apex jump_fall land dash_f dash_b guard_hi guard_lo hit_hi hit_lo hit_air block_hi block_lo knockdown wakeup throw_tech win lose'.split())
MOVES = tuple('stand_l stand_m stand_h crouch_l crouch_m crouch_h air_l air_m air_h throw_f throw_b special1 special2 special3 super'.split())
THROWS = ('throw_f', 'throw_b', 'special3')

# Each row is an independently composed guard: hands, hip compression, torso
# pitch/yaw/roll, stagger, gait order. Angles are degrees, not local bone Euler.
PROFILES = {
    'chatgpt': dict(lh=[.44,-.03,-.08], rh=[.30,-.10,.08], sink=.065, torso=[8,-12,0], stagger=.13, gait='survey', accent=[0,18,-8]),
    'claude': dict(lh=[.38,.15,.12], rh=[.22,-.08,-.12], sink=.09, torso=[4,18,-3], stagger=.10, gait='ward', accent=[-12,-8,6]),
    'grok': dict(lh=[.25,-.19,-.22], rh=[.48,.12,.02], sink=.08, torso=[17,-23,9], stagger=.18, gait='piston', accent=[22,29,-16]),
    'meta': dict(lh=[.48,-.22,-.20], rh=[.48,-.22,.20], sink=.16, torso=[19,0,0], stagger=.08, gait='brace', accent=[28,-12,3]),
    'gemini': dict(lh=[.51,.08,-.27], rh=[.15,.19,.20], sink=.075, torso=[-3,27,-7], stagger=.16, gait='petal', accent=[-15,-34,17]),
    'deepseek': dict(lh=[.29,-.12,.06], rh=[.32,-.16,-.06], sink=.12, torso=[13,8,2], stagger=.09, gait='pressure', accent=[31,7,-4]),
    'mistral': dict(lh=[.25,-.05,-.30], rh=[-.12,-.27,.25], sink=.11, torso=[26,-19,-11], stagger=.22, gait='sweep', accent=[-18,42,-24]),
    'kimi': dict(lh=[.35,.25,-.32], rh=[.19,-.28,.34], sink=.055, torso=[-8,-31,13], stagger=.15, gait='orbit', accent=[-22,58,26]),
    'qwen': dict(lh=[.53,-.17,.02], rh=[.12,-.02,.18], sink=.13, torso=[6,34,0], stagger=.19, gait='lamellar', accent=[9,-24,-9]),
}

# Per-fighter contact vocabulary: lead jab, medium, heavy; low and airborne
# actions have separately authored targets below rather than renamed stand clips.
# (limb, forward, up, lateral, wrist twist, torso pitch/yaw/roll)
CONTACTS = {
 'chatgpt': [('lh',.88,.02,0,0,[6,25,-4]),('rh',.75,.08,-.36,35,[12,-36,8]),('rh',.57,.65,0,-25,[-16,-23,-6]),('lh',.79,-.40,0,10,[25,18,0]),('rf',.57,.16,.12,0,[7,-18,4]),('rh',.62,.51,.08,-30,[-22,-30,0]),('lh',.77,-.12,0,10,[18,20,0]),('lf',.52,.63,-.15,0,[-12,35,12]),('rh',.55,-.64,.1,55,[35,-32,15])],
 'claude': [('lh',.72,.12,.10,35,[2,12,0]),('lh',.64,-.05,.32,80,[17,31,-6]),('rh',.91,.05,.04,-10,[-7,-16,0]),('lh',.66,-.38,.16,60,[18,22,-5]),('rh',.77,-.33,-.05,0,[12,-12,0]),('lh',.53,.61,.20,70,[-12,26,-4]),('lh',.60,.02,.25,60,[9,20,5]),('rf',.39,.50,.12,0,[-2,-15,-8]),('lh',.72,-.38,.20,85,[26,24,-7])],
 'grok': [('lh',.65,.08,.42,65,[11,44,-15]),('rh',.43,-.08,-.32,100,[28,-51,19]),('rh',.70,-.27,.12,135,[39,-33,12]),('lh',.55,-.45,.36,75,[35,46,-17]),('rf',.48,.13,.19,0,[21,-32,20]),('lh',.48,.64,.32,90,[-19,48,-12]),('rh',.54,.01,-.35,105,[28,-45,22]),('lf',.46,.52,-.21,0,[8,40,-20]),('rh',.57,-.62,.15,140,[43,-38,28])],
 'meta': [('lh',.72,-.11,-.03,15,[20,14,-4]),('rh',.35,-.05,-.28,90,[32,-35,12]),('both',.64,-.48,0,0,[44,0,0]),('lh',.63,-.48,-.13,25,[37,12,0]),('rf',.37,.10,.20,0,[19,-14,5]),('both',.46,.58,0,0,[-24,0,0]),('lh',.58,-.17,-.22,20,[30,18,-10]),('rf',.40,.33,.20,0,[17,-17,0]),('both',.53,-.66,0,0,[48,0,0])],
 'gemini': [('lh',.76,.20,-.27,-55,[-3,34,-15]),('rh',.68,.04,-.46,-80,[7,-47,13]),('lh',.71,.51,.20,30,[-19,38,-8]),('lh',.67,-.42,-.28,-65,[21,38,-16]),('lf',.51,.20,-.20,0,[-2,48,-12]),('rh',.58,.62,-.20,-40,[-25,-40,17]),('rh',.74,.15,.24,-75,[-9,-32,22]),('lf',.48,.61,-.19,0,[-15,52,-25]),('lh',.65,-.43,-.32,-70,[29,44,-19])],
 'deepseek': [('rh',.70,-.15,-.08,15,[22,-13,5]),('both',.72,-.06,0,0,[26,0,0]),('rh',.40,.36,-.29,110,[-10,-35,18]),('rh',.63,-.46,-.08,20,[35,-16,5]),('lf',.34,.15,-.17,0,[20,19,-5]),('rh',.44,.60,-.17,100,[-20,-29,15]),('lh',.62,-.22,-.08,25,[27,18,-4]),('both',.48,-.38,0,10,[35,0,0]),('rh',.38,-.65,-.26,115,[46,-32,23])],
 'mistral': [('lh',.80,-.09,-.20,-20,[26,22,-17]),('rf',.61,.53,.13,0,[-18,-54,24]),('lf',.47,.89,-.12,0,[-29,65,-28]),('lh',.67,-.51,-.19,-25,[39,26,-20]),('rf',.65,.10,.12,0,[18,-62,24]),('lf',.50,.73,-.14,0,[-23,62,-25]),('lf',.52,.51,-.18,0,[-12,42,-32]),('rf',.61,.73,.16,0,[-26,-61,31]),('lf',.57,.34,-.17,0,[34,74,-27])],
 'kimi': [('lh',.70,.23,.33,75,[-11,46,21]),('rh',.78,.12,-.30,-100,[-5,-65,-24]),('lh',.60,.63,-.25,105,[-24,51,18]),('lh',.57,-.43,.40,85,[19,54,24]),('lf',.50,.23,-.19,0,[-9,67,22]),('rh',.49,.65,-.35,-100,[-26,-59,-23]),('rh',.63,.24,-.40,-110,[-18,-58,-27]),('rf',.52,.66,.20,0,[-20,-72,-31]),('lh',.61,-.46,.35,115,[30,69,29])],
 'qwen': [('lh',.86,-.13,.02,0,[8,28,-2]),('rh',.80,-.04,.23,45,[14,-32,3]),('lh',.69,.48,-.03,-35,[-12,33,-5]),('lh',.79,-.46,.02,0,[27,32,0]),('rf',.49,.12,.18,0,[10,-26,0]),('rh',.62,.55,.20,40,[-18,-30,5]),('lh',.78,-.17,-.02,-10,[19,35,-3]),('rf',.46,.47,.18,0,[3,-31,5]),('rh',.71,-.44,.22,55,[32,-37,8])],
}

# Projectile, mobility and super are independently blocked out, including
# non-striking movement silhouettes. Each tuple has the same layout as CONTACTS.
SIGNATURES = {
 'chatgpt': [('lh',.83,.13,-.10,20,[4,18,-4]),('rh',.80,.37,.08,-30,[-12,-28,7]),('both',.83,.12,0,20,[8,0,0])],
 'claude': [('rh',.91,.14,0,0,[0,-13,0]),('both',.12,.26,.48,60,[-9,0,-6]),('lh',.73,.17,.32,95,[13,30,-7])],
 'grok': [('rh',.55,.62,.18,90,[-12,-44,20]),('both',-.12,.48,.30,20,[-26,12,14]),('rh',.57,-.32,-.31,120,[46,-58,23])],
 'meta': [('both',.73,-.13,0,0,[30,0,0]),('both',.48,-.66,0,15,[47,0,0]),('both',.70,-.55,0,35,[42,0,0])],
 'gemini': [('lh',.84,.22,-.20,-65,[-8,36,-16]),('both',.16,.53,.30,-50,[-21,-28,17]),('both',.66,.31,.30,-75,[-12,41,-21])],
 'deepseek': [('both',.78,-.10,0,0,[28,0,0]),('both',-.16,-.65,.22,0,[5,0,0]),('both',.62,-.31,0,80,[38,0,0])],
 'mistral': [('lh',.72,.03,-.28,-35,[28,32,-22]),('rf',.44,.38,.12,0,[39,-37,28]),('lf',.55,.92,-.10,0,[-32,83,-33])],
 'kimi': [('rh',.81,.20,-.25,-100,[-13,-61,-26]),('both',.03,.35,.41,110,[-16,87,24]),('lh',.64,.49,.38,140,[-20,103,32])],
 'qwen': [('rh',.85,-.08,.13,35,[10,-26,0]),('lh',.73,-.41,-.13,-30,[25,39,-5]),('both',.73,-.03,.12,65,[21,26,-3])],
}


def neutral(operator):
    p = PROFILES[operator]
    return dict(lh=p['lh'][:], rh=p['rh'][:], lf=[p['stagger'],0,-.15],
                rf=[-p['stagger'],0,.15], hips=[0,-p['sink'],0],
                torso=p['torso'][:], head=[0,0,0], wrist=[0,0])


def alter(pose, **changes):
    result = deepcopy(pose)
    result.update(deepcopy(changes))
    return result


def contact(base, spec):
    limb, f, u, s, wrist, torso = spec
    out = alter(base, torso=torso, hips=[.035,base['hips'][1]-.02,0])
    if limb == 'both':
        out['lh'], out['rh'] = [f,u,-abs(s)], [f,u,abs(s)]
        out['wrist'] = [wrist,-wrist]
    else:
        out[limb] = [f,u,s]
        if limb.endswith('h'):
            out['wrist'][0 if limb == 'lh' else 1] = wrist
            other = 'rh' if limb == 'lh' else 'lh'
            out[other] = [.12,.06,-.06 if other == 'lh' else .06]
        else:
            # Supporting hip moves over the planted leg; no leg stretch padding.
            out['hips'][0] = base['rf' if limb == 'lf' else 'lf'][0]
            out['hips'][1] += .055
    out['head'] = [-torso[0]*.3,-torso[1]*.55,-torso[2]*.3]
    return out


def attack(operator, move):
    base = neutral(operator)
    if move.startswith('crouch'):
        base['hips'][1] -= .16
    if move.startswith('air'):
        base['lf'][1], base['rf'][1] = .19,.29
    if move in MOVES[:9]:
        spec = CONTACTS[operator][MOVES.index(move)]
    else:
        spec = SIGNATURES[operator][{'special1':0,'special2':1,'super':2}[move]]
    impact = contact(base,spec)
    accent = PROFILES[operator]['accent']
    wind = alter(base, torso=[base['torso'][i]-accent[i]*.65 for i in range(3)],
                 hips=[-.035,base['hips'][1]-.035,0])
    limb = spec[0]
    for hand in ('lh','rh') if limb == 'both' else (limb,):
        if hand.endswith('h'):
            wind[hand] = [-.12, .35 if operator in ('grok','meta') and move.endswith('h') else -.12, base[hand][2]]
    follow = alter(impact, torso=[impact['torso'][i]+accent[i]*.22 for i in range(3)])
    for hand in ('lh','rh'):
        follow[hand][0] *= .83
        follow[hand][1] -= .09
    return [(0,base),(.22,wind),(.40,alter(wind, head=[-7,0,0])),(.5,impact),(.60,follow),(.82,alter(base,torso=follow['torso'])),(1,base)]


def state_keys(operator, name):
    b = neutral(operator)
    p = PROFILES[operator]
    a = p['accent']
    # Gaits have different foot order, lift, contact dwell and arm phrase. They
    # are explicit piecewise poses rather than a sine oscillator applied to jabs.
    gait = {
      'survey': (.18,.065,.24, [10,18,-3]), 'ward': (.12,.035,.34,[3,-7,6]),
      'piston': (.23,.11,.19,[23,-32,15]), 'brace': (.105,.045,.39,[26,8,-3]),
      'petal': (.20,.08,.22,[-7,36,-15]), 'pressure': (.11,.055,.37,[22,-9,4]),
      'sweep': (.29,.13,.17,[34,-36,-21]), 'orbit': (.22,.10,.28,[-14,48,23]),
      'lamellar': (.15,.025,.31,[8,25,-2]),
    }[p['gait']]
    stride,lift,dwell,turn = gait
    if name in ('walk_f','walk_b','dash_f','dash_b'):
        direction = -1 if name.endswith('_b') else 1
        dash = name.startswith('dash')
        step = stride*(1.3 if dash else 1)*direction
        left = alter(b,lf=[step,lift,-.15],torso=turn,lh=[.15,-.2,-.12])
        plant = alter(left,lf=[step,0,-.15],hips=[.035,b['hips'][1]-.03,0])
        right = alter(b,rf=[step,lift,.15],torso=[turn[0],-turn[1],-turn[2]],rh=[.1,-.24,.13])
        return [(0,b),(dwell,left),(.48,plant),(.5,alter(b,lf=[step,0,-.15])),(.5+dwell,right),(.96,alter(right,rf=[step,0,.15])),(1,b)]
    if name in ('guard_hi','guard_lo','block_hi','block_lo','crouch'):
        low = name.endswith('lo') or name == 'crouch'
        guarded = alter(b,hips=[-.025,b['hips'][1]-(.16 if low else .02),0],
                        lh=[p['lh'][0]*.7,p['lh'][1]+.15,p['lh'][2]],
                        rh=[p['rh'][0]*.8,p['rh'][1]+.17,p['rh'][2]])
        recoil = alter(guarded,torso=[p['torso'][0]-9,p['torso'][1]+a[1]*.2,p['torso'][2]+a[2]*.25])
        return [(0,guarded),(.22,recoil),(.65,guarded),(1,guarded)]
    if name in ('jump_rise','jump_apex','jump_fall','land'):
        fold = {'jump_rise':.23,'jump_apex':.35,'jump_fall':.10,'land':0}[name]
        mid = alter(b,lf=[stride,fold,-.15],rf=[-stride*.5,fold*.7,.15],
                    torso=[p['torso'][0]-a[0]*.6,p['torso'][1]+a[1]*.4,p['torso'][2]],
                    lh=[p['lh'][0],p['lh'][1]+.18,p['lh'][2]],
                    hips=[0,b['hips'][1]-(.10 if name=='land' else 0),0])
        return [(0,b),(.26,mid),(.7,alter(mid,head=[-8,0,0])),(1,b)]
    if name.startswith('hit') or name in ('knockdown','lose','wakeup'):
        low = name == 'hit_lo'
        down = name in ('knockdown','lose','wakeup')
        recoil = alter(b,torso=[-32 if not low else 35,a[1],a[2]],
                       lh=[-.18,.26,-.25],rh=[-.22,-.15,.28],
                       hips=[-.04,b['hips'][1]-(.29 if down else .06),0],head=[-18,12,7])
        if down:
            recoil = alter(recoil,torso=[64,a[1],a[2]],lf=[.27,0,-.15],rf=[-.22,0,.15])
        keys = [(0,b),(.19,recoil),(.56,alter(recoil,head=[15,-12,0])),(1,recoil if down else b)]
        return [(1-t,v) for t,v in reversed(keys)] if name == 'wakeup' else keys
    if name == 'throw_tech':
        return [(0,b),(.24,alter(b,lh=[.8,.05,-.1],rh=[.7,.0,.1],torso=[-8,a[1],a[2]])),(.6,alter(b,hips=[-.05,b['hips'][1]-.06,0])),(1,b)]
    if name == 'win':
        # Explicit signature salutes, including planted rooted vs open aerial arms.
        salute = contact(b,SIGNATURES[operator][2])
        return [(0,b),(.3,alter(b,head=[12,-15,0])),(.63,salute),(1,alter(salute,head=[-12,20,0]))]
    return [(0,b),(.31,alter(b,head=[a[0]*.13,a[1]*.16,a[2]*.12],rh=[b['rh'][0]+.035,b['rh'][1]+.025,b['rh'][2]])),(.73,alter(b,head=[-a[0]*.10,-a[1]*.1,0])),(1,b)]


def throw_keys(operator, move, victim=False):
    b = neutral(operator)
    p = PROFILES[operator]
    back = move == 'throw_b'
    special = move == 'special3'
    angle = p['accent'][1] + (-65 if back else 30)
    if victim:
        caught = alter(b,lh=[.25,.15,-.2],rh=[.25,.15,.2],torso=[25,angle*.3,p['accent'][2]])
        lifted = alter(caught,lf=[.17,.27,-.15],rf=[-.08,.32,.15],torso=[-30,angle,p['accent'][2]])
        landed = alter(b,hips=[0,-.38,0],torso=[65,-angle,15],lh=[.1,-.5,-.2],rh=[.1,-.5,.2])
        return [(0,b),(.28,caught),(.5,caught),(.68,lifted),(.82,landed),(1,landed)]
    grasp = alter(b,lh=[.67,-.05,.12],rh=[.64,-.12,-.12],hips=[.025,b['hips'][1]-.05,0])
    lift = alter(grasp,lh=[.49,.48,.1],rh=[.51,.42,-.1],torso=[-17,angle,p['accent'][2]])
    release = alter(grasp,lh=[.75,-.30,-.1],rh=[.71,-.35,.1],torso=[35 if special else 22,-angle,p['accent'][2]])
    return [(0,b),(.16,alter(b,hips=[-.03,b['hips'][1]-.06,0])),(.28,grasp),(.5,grasp),(.68,lift),(.82,release),(1,b)]


def sample(keys, t):
    t = max(0,min(1,t))
    for (ta,a),(tb,b) in zip(keys,keys[1:]):
        if t <= tb:
            v = (t-ta)/(tb-ta)
            v = v*v*(3-2*v)  # bounded Hermite; no Bezier overshoot through floor
            return {k:[x+(y-x)*v for x,y in zip(a[k],b[k])] for k in a}
    return deepcopy(keys[-1][1])


def library(operator):
    clips = {}
    for name in STATES + MOVES:
        keys = throw_keys(operator,name) if name in THROWS else attack(operator,name) if name in MOVES else state_keys(operator,name)
        clips[name] = dict(keys=keys,loop=name in ('idle','walk_f','walk_b','crouch','guard_hi','guard_lo'),
                           frames=60, phases={'start':0,'anticipation':.22,'preactive':.40,'impact':.50,'recovery':.60,'end':1})
    for attacker in OPERATORS:
        for move in THROWS:
            # Choreography belongs to attacker, posture/rest solve belongs to victim.
            keys = throw_keys(attacker,move,True)
            vb = neutral(operator)
            for _, pose in keys:
                pose['lh'][2] += (vb['lh'][2]-neutral(attacker)['lh'][2])*.3
                pose['rh'][2] += (vb['rh'][2]-neutral(attacker)['rh'][2])*.3
            clips[f'victim_{attacker}_{move}'] = dict(keys=keys,loop=False,frames=60,
                phases={'start':0,'contact':.28,'hold_end':.5,'lift':.68,'impact':.82,'end':1},
                pair={'attacker':attacker,'move':move,'position_owner':'simulation','contact_tolerance_m':.06})
    for name in THROWS:
        clips[name]['phases'] = {'start':0,'contact':.28,'hold_end':.5,'lift':.68,'impact':.82,'end':1}
    # Explicit second-band variants; content may select these, never silently alias.
    if operator == 'gemini':
        for name in ('idle','guard_hi','stand_l','stand_m','stand_h'):
            c = deepcopy(clips[name])
            for _,p in c['keys']:
                p['lh'],p['rh'] = p['rh'],p['lh']
                for h in ('lh','rh'): p[h][2] *= -1
                p['torso'][1] *= -1
                p['torso'][2] *= -1
                p['wrist'] = [-p['wrist'][1],-p['wrist'][0]]
            clips[name+'_band_b'] = c
    return clips


def curve_hash(clip):
    return hashlib.sha256(json.dumps(clip['keys'],sort_keys=True,separators=(',',':')).encode()).hexdigest()


def timing(clip, move=None):
    """Explicit piecewise mapping [simulation frame, authored seconds].

    Frame zero = first startup frame. Active starts at startup. Content's actual
    hitbox envelope is authoritative. Throws require explicit shared timeline.
    """
    if move is None:
        return [[0,0],[clip['frames'],clip['frames']/60]]
    if 'contact' in clip['phases']:
        pair = move.get('throw',{}).get('animation_timeline')
        if not pair:
            raise ValueError('throw.animation_timeline required: contact,hold_end,lift,impact,end')
        return [[0,0]] + [[int(pair[k]),float(v)] for k,v in clip['phases'].items() if k!='start']
    startup,active,recovery = (int(move[k]) for k in ('startup','active','recovery'))
    if min(startup,active,recovery) < 1:
        raise ValueError('positive move windows required')
    return [[0,0],[startup*.44,.22],[max(startup*.8,startup-1),.40],
            [startup,.50],[startup+active,.60],[startup+active+recovery,1.0]]
