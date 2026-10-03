"""Supplemental L polish gates, reusing K's serial bounded ownership policies."""
from pathlib import Path
import sys
import native_queue as queue

CASES = [
    ('explosion','edge_effects/weapons.gd','EDGE_WEAPONS',False),
    ('identity','identity_maps/environment_parity.gd','IDENTITY_ENVIRONMENT_PARITY_OK',False),
    ('variants','graphics_depth/variants.gd','MOTH_DEPTH_VARIANTS',False),
    ('moth','moth/validate.gd','MOTH_VALIDATION',False),
    ('weather','world_weather/spatial.gd','WORLD_WEATHER_SPATIAL_OK',True),
    ('depth','graphics_depth/capture.gd','DEPTH_GRAPHICAL failures=0',True),
    ('muzzle','weapon_effects/moth_coverage.gd','WEAPON_EFFECTS_MOTH_COVERAGE',True),
    ('support','combat_integration/support_cues.gd','COMBAT_SUPPORT_CUES',False),
    ('lobby','protocol/lobby_qol.gd','PORT_LOBBY_QOL_OK',True),
    ('lobby-flow','protocol/lobby_flow.gd','PORT_LOBBY_FLOW_OK',False),
    ('popup-focus','protocol/lobby_popup_free.gd','LOBBY_POPUP_FREE',True),
    ('setup','loadouts/setup_menu.gd','PORT_LOADOUT_SETUP_OK',True),
    ('lobby-existing','loadouts/lobby_menu.gd','PORT_LOADOUT_LOBBY_OK',True),
    ('weather-unit','world_weather/unit.gd','WORLD_WEATHER_NATIVE_OK',False),
    ('weapon-lifecycle','weapon_effects/lifecycle.gd','WEAPON_EFFECTS_LIFECYCLE',False),
    ('weapon-rig','weapon_effects/rig_integration.gd','WEAPON_EFFECTS_REAL_RIG',False),
    ('identity-composition','identity_maps/polish_capture.gd','IDENTITY_CAPTURE',True),
    ('identity-inspection','identity_maps/polish_capture.gd','IDENTITY_CAPTURE',True),
    ('effect-captures','combat_integration/polish_capture.gd','POLISH_EFFECT_CAPTURE_OK',True),
    ('lobby-captures','protocol/lobby_polish_capture.gd','LOBBY_POLISH_CAPTURE',True),
]


def plan(root=queue.ROOT, godot=queue.GODOT, output=Path('/tmp/opencode/polish-native'), scope='contracts', grant='NEW-GRANT'):
    output=output.resolve()
    jobs=[]
    def add(name,args,timeout,marker,sources):
        jobs.append({'id':name,'argv':args,'timeout':timeout,'marker':marker,
                     'requires':sources+['tools/motion-review/polish_queue.py'], 'lock_owner':'queue'})
    add('native-import',[godot,'--headless','--path','godot','--editor','--import','--quit'],600,None,['godot/project.godot'])
    for name,script,marker,graphical in CASES:
        add('typecheck-'+name,[godot,'--headless','--path','godot','--script','res://tests/'+script,'--check-only'],60,None,['godot/tests/'+script])
    for name,script,marker,graphical in CASES:
        args=[godot,'--headless','--path','godot','--script','res://tests/'+script]
        if graphical:
            args=[sys.executable,'tools/godot-dev/xvfb_run.py',godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/'+script]
        if name=='depth': args+=['--',str(output/name/'images'),'after-L']
        if name=='popup-focus': args+=['--','--lobby-menu']
        if name in ['muzzle','effect-captures','lobby-captures']: args+=['--','--evidence-out='+str(output/name/'images')]
        if name.startswith('identity-'):
            args+=['--','--output='+str(output/name/'images'),'--size=960x640']
            if name=='identity-composition': args+=['--composition']
        add(name,args,120,marker,['godot/tests/'+script])
    return jobs


if __name__=='__main__':
    queue.plan=plan
    raise SystemExit(queue.main())
