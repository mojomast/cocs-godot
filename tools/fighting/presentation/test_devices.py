"""Execute the production's engine-free choice helper through a narrow syntax shim.

This is not Godot/OS input execution. The shim removes GDScript type declarations
and supplies its three Array methods; the actual helper algorithm/captions come
from device_choices.gd, not a second implementation of device selection.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]
HELPER = ROOT / 'godot/fighting/presentation/device_choices.gd'


class Array(list):
    def size(self): return len(self)
    def has(self, item): return item in self
    def find(self, item): return self.index(item) if item in self else -1
    def duplicate(self): return Array(self)


def load_helper():
    lines = []
    for line in HELPER.read_text().splitlines():
        if line.startswith('extends '): continue
        if line.startswith('static func '):
            line = re.sub(r' -> \w+:$', ':', line.replace('static func ', 'def ', 1))
            line = re.sub(r': (Array|Dictionary|int|String)(?=[,)])', '', line)
        line = re.sub(r'var (\w+): Array = (.+)', r'\1 = Array(\2)', line)
        line = re.sub(r'var (\w+): \w+ = ', r'\1 = ', line)
        line = re.sub(r'for (\w+): int in ', r'for \1 in ', line)
        lines.append(line)
    namespace = {'Array':Array}
    exec(compile('\n'.join(lines),str(HELPER),'exec'),namespace)
    return namespace['model'],namespace['caption']


MODEL, CAPTION = load_helper()


def model(assignments, player, connected):
    return MODEL(Array(assignments),player,Array(connected))


def method(source, name):
    return source.split(f'func {name}(',1)[1].split('\nfunc ',1)[0]


class DeviceChoiceProof(unittest.TestCase):
    def test_ordinary_p1_first_then_p2_second(self):
        assigned = [-1,-1]
        assigned[0] = model(assigned,0,[0,1])['next']
        self.assertEqual(assigned,[0,-1])
        assigned[1] = model(assigned,1,[0,1])['next']
        self.assertEqual(assigned,[0,1])
        self.assertEqual(model(assigned,1,[0,1])['choices'],[-1,1])

    def test_disconnected_caption_and_one_activation_keyboard_recovery(self):
        assigned = [4,9]
        missing = model(assigned,0,[9])
        self.assertEqual(missing['current'],4)
        self.assertTrue(missing['missing'])
        self.assertIn('disconnected',CAPTION(missing,0,{9:'P2 pad'}))
        self.assertFalse(CAPTION(missing,0,{}).startswith('Keyboard'))
        self.assertEqual(missing['next'],-1)
        self.assertEqual(assigned,[4,9]) # pure refresh did not silently reassign
        assigned[0] = missing['next']
        self.assertEqual(CAPTION(model(assigned,0,[9]),0,{}),'Keyboard 1')
        self.assertEqual(assigned[1],9)

    def test_reconnect_same_id_or_changed_id_never_transfers_assignment(self):
        assigned = [7,3]
        self.assertTrue(model(assigned,0,[3])['missing'])
        same = model(assigned,0,[3,7])
        self.assertFalse(same['missing'])
        self.assertEqual(CAPTION(same,0,{7:'Returned'}),'Pad 7 · Returned')
        changed = model(assigned,0,[3,12])
        self.assertTrue(changed['missing'])
        self.assertEqual(changed['next'],-1)
        assigned[0] = changed['next']
        self.assertEqual(model(assigned,0,[3,12])['next'],12)

    def test_exclusive_cycle_shared_keyboard_and_sparse_duplicate_ids(self):
        self.assertEqual(model([-1,-1],0,[])['next'],-1)
        self.assertEqual(model([-1,-1],1,[])['next'],-1)
        self.assertEqual(model([6,-1],1,[22,-2,6,22,10])['choices'],[-1,10,22])
        assigned = [6,-1]
        visited = []
        for _ in range(3):
            assigned[1] = model(assigned,1,[22,6,10])['next']
            visited.append(assigned[1])
        self.assertEqual(visited,[10,22,-1])
        self.assertEqual(model([6,6],1,[6])['next'],-1)
        self.assertIn('unavailable',CAPTION(model([6,6],1,[6]),1,{}))
        self.assertEqual(model([-1,-1],-1,[]),{})
        self.assertEqual(model([-1,-1],2,[]),{})
        self.assertEqual(model([-1],0,[]),{})

    def test_menu_settings_fullscreen_refresh_and_stale_choice_are_pure(self):
        assigned = [11,2]
        before = assigned[:]
        # Re-rendering screens/sizes changes neither IDs nor truth of the caption.
        for _screen in ['selection','settings','fullscreen','windowed','settings']:
            for p in [0,1]:
                current = model(assigned,p,[2])
                caption = CAPTION(current,p,{2:'Second'})
                self.assertEqual(caption.startswith('Keyboard'),assigned[p] == -1)
        self.assertEqual(assigned,before)
        old = model([-1,-1],0,[1,2])
        fresh = model([-1,-1],0,[2])
        self.assertEqual(old['next'],1)
        self.assertEqual(fresh['next'],2)
        main = (ROOT/'godot/fighting/main.gd').read_text()
        cycle = method(main,'_cycle_device')
        self.assertIn('Input.get_connected_joypads()',cycle)
        self.assertIn('DeviceChoices.model(router.devices,player',cycle)
        self.assertIn('router.assign(player,int(model.next))',cycle)
        self.assertNotIn('show_selection(',cycle)
        self.assertNotIn('show_settings(',cycle)
        self.assertIn('device_buttons.clear()',method(main,'_clear_ui'))
        self.assertIn('DeviceChoices.caption(model,p,names)',method(main,'_refresh_device_choices'))
        self.assertNotIn('maxi(0,devices.find',main)

    def test_release_pause_fresh_press_and_resume_wiring(self):
        main = (ROOT/'godot/fighting/main.gd').read_text()
        router = (ROOT/'godot/fighting/presentation/input_router.gd').read_text()
        changed = method(main,'_device_changed')
        self.assertIn('router.unplug(device)',changed)
        self.assertIn('if active: show_pause(',changed)
        self.assertIn('_refresh_device_choices()',changed)
        self.assertNotIn('router.assign(',changed)
        self.assertNotIn('resume_match(',changed)
        self.assertIn('router.set_modal(true)',method(main,'_panel'))
        unplug = method(router,'unplug')
        self.assertIn('if devices.has(device): release_all()',unplug)
        release = method(router,'release_all')
        for required in ['for p: int in 2:', 'blocked[', 'down[p].clear()', 'queued[p] = 0']:
            self.assertIn(required,release)
        assign = method(router,'assign')
        self.assertIn('devices[1-player] == device: return false',assign)
        self.assertLess(assign.index('release_all()'),assign.index('devices[player] = device'))
        self.assertIn('not blocked.has(token)',method(router,'_set_action'))
        resume = method(main,'resume_match')
        self.assertLess(resume.index('not Input.get_connected_joypads().has(device)'),resume.index('paused = false'))


if __name__ == '__main__': unittest.main()
