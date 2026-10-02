"""Contact solving for 25 shared choreographies on the verified common rig.

Only victim visual pelvis is corrected. Actor roots and damage stay in the sim.
The nine mesh silhouettes still require independent penetration/hand inspection.
No per-body rest normalization or procedural runtime combat clock.
"""
from kinematics import add, sub, mul, unit, solve, rotate
from recipes import sample


def grip(heads,tails):
    name = 'RightHand'
    return add(heads[name],mul(unit(sub(tails[name],heads[name])),.045))


def chest(heads,pose):
    # Visible front armor surface, not an internal pivot buried in the torso.
    return add(heads['Chest'],rotate([0,.16,0],pose['torso']))


def adapted_pose(operator,clip,t,rig,rigs,libraries,pairs):
    pose = sample(clip['keys'],t)
    if 'pair' not in clip: return pose
    pair = clip['pair']
    attacker,move = pair['attacker'],pair['move']
    ah,at,_ = solve(rigs[attacker],sample(libraries[attacker][move]['keys'],t))
    target = grip(ah,at)
    definition = pairs[(attacker,move)]
    # Opposite facing during hold: victim forward/lateral invert. Release and
    # side swap are simulation-owned and happen at the declared release frame.
    target = [-target[0],definition['victim_x']/1000-target[1],target[2]-definition['victim_y']/1000]
    vh,_,_ = solve(rig,pose)
    correction = sub(target,chest(vh,pose))
    blend = max(0,min(1,t/.28,(1-t)/.18))
    pose['hips'] = add(pose['hips'],[correction[1]*blend,correction[2]*blend,correction[0]*blend])
    # During the catch and carry the feet follow the victim pelvis, preserving
    # body lengths. No planted-foot claim during the shared hold window.
    for foot in ('lf','rf'):
        pose[foot] = add(pose[foot],[correction[1]*blend,correction[2]*blend,correction[0]*blend])
    return pose
