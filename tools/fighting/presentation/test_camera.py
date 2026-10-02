"""Independent projection/smoothing oracle, source-only, not Godot execution.

Loads tuning values from production camera.gd and real GLB skin vertices. Tests
containment invariants rather than snapshots of implementation output.
"""
import importlib.util
import json
import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]
SOURCE = (ROOT / "godot/fighting/presentation/camera.gd").read_text()
C = {k:float(v) for k,v in re.findall(r"const (\w+) := ([\d.]+)",SOURCE)}
spec = importlib.util.spec_from_file_location("read_only_glb",ROOT / "tools/fighting/animation/glb.py")
glb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(glb)


def fit(box, aspect, safe, cx=None):
    left,low,right,top = box
    cx = max(-C['CENTER_LIMIT'],min(C['CENTER_LIMIT'],(left+right)/2 if cx is None else cx))
    height = max((top-low)/(1-sum(safe)),2*max(cx-left,right-cx)/aspect)
    return [cx,low,height]


def advance(frame, target, actual, aspect, safe, hold=0, frozen=False):
    x,low,height = frame
    if not frozen:
        if target[2] > height+C['ZOOM_DEADBAND']:
            height += (target[2]-height)*C['GROW_RATE']
            hold = int(C['HOLD_TICKS'])
        elif hold > 0:
            hold -= 1
        elif target[2] < height-C['ZOOM_DEADBAND']:
            height += (target[2]-height)*C['SHRINK_RATE']
        if abs(target[0]-x) > .15:
            x += (target[0]-x)*C['PAN_RATE']
        low += (target[1]-low)*C['SHRINK_RATE']
    required = fit(actual,aspect,safe,x)
    low = min(low,required[1])
    height = max(height,required[2],(actual[3]-low)/(1-sum(safe)))
    return [x,low,height],hold


def apex(v,g):
    ticks = math.ceil(max(v,0)/max(g,1))
    return max(0,(ticks*v-g*ticks*(ticks-1)/2)/1000)


class CameraProof(unittest.TestCase):
    def contained(self, frame, box, aspect, safe):
        x,low,height = frame
        self.assertLessEqual(x-height*aspect/2,box[0]+1e-8)
        self.assertGreaterEqual(x+height*aspect/2,box[2]-1e-8)
        self.assertLessEqual(low,box[1]+1e-8)
        self.assertGreaterEqual(low+height*(1-sum(safe)),box[3]-1e-8)

    def test_all_spacing_height_and_ui_scales(self):
        for width,height in [(760,520),(1280,800),(1920,1080)]:
            for ui_scale in [1,1.5]:
                safe = [min(.48,(155*ui_scale+12)/height),min(.25,(78*ui_scale+8)/height)]
                for left in range(-8,9,2):
                    for right in range(left,9,2):
                        for y in [0,2,4,8,12]:
                            box = [left-1.6,-.3,right+1.6,y+2.8]
                            self.contained(fit(box,width/height,safe),box,width/height,safe)

    def test_grounded_readability_budget_and_displaced_pair(self):
        safe = [167/800,86/800]
        # Includes conservative animated limb room, not just collision hurtbox.
        for body_height in [1.8,2.1,2.5]:
            box = [-body_height*1.25,-.3,body_height*1.25,body_height+.63]
            frame = fit(box,1.6,safe)
            self.assertGreater(800*body_height/frame[2],250)
        for center in [-8,8]:
            # Off-centre paired throw extended limbs must survive x +/-4 clamp.
            box = [center-2,-.5,center+2,3.4]
            self.contained(fit(box,760/520,[.33,.17]),box,760/520,[.33,.17])

    def test_discrete_apex_covers_actual_launches_and_landing(self):
        roster = json.loads((ROOT/'godot/fighting/data/roster.json').read_text())
        rules = json.loads((ROOT/'godot/fighting/data/rules.json').read_text())
        g = rules['gravity']
        velocities = [p['stats']['jump_velocity'] for p in roster['operators']]
        velocities += [m['movement']['vy'] for p in roster['operators'] for m in p['moves'].values() if m.get('movement',{}).get('type') in ('super_jump','double_jump')]
        for velocity in velocities:
            y = 0
            for tick in range(math.ceil(velocity/g)+2):
                self.assertLessEqual(y/1000,apex(velocity,g)+1e-9)
                y += velocity-g*tick
        self.assertEqual(apex(-300,g),0)

    def test_smoothed_startup_ascent_hitstop_landing_and_projectiles(self):
        aspect,safe = 1.6,[167/800,86/800]
        ground = [-1.3,-.3,1.3,2.4]
        frame = fit([-2.7,-.3,2.7,3.0],aspect,safe)
        hold = 0
        frames = []
        v,g = 255,9
        y = 0
        # Four startup samples anticipate launch; positions always remain real.
        for tick in range(160):
            if tick >= 4:
                y = max(0,y+v/1000)
                v = v-g if y > 0 else 0
            actual = [-1.3,-.3,1.3,y+2.4]
            predicted = [-2.7,-.3,2.7,y+2.85+apex(255 if tick < 4 else v,g)]
            target = fit(predicted,aspect,safe)
            frame,hold = advance(frame,target,actual,aspect,safe,hold)
            self.contained(frame,actual,aspect,safe)
            frames.append(frame[:])
            if tick == 12:
                frozen = frame[:]
                for _ in range(18):
                    frame,hold = advance(frame,target,actual,aspect,safe,hold,True)
                self.assertEqual(frame,frozen)
        self.assertLess(frames[-1][2],6)
        # Immediate projectile presence and owner reflection cannot clip its box.
        for x,y in [(-9,1),(9,2),(-8,5),(0,10)]:
            actual = [min(-1.3,x-.4),-.3,max(1.3,x+.4),max(2.4,y+.4)]
            frame,hold = advance(frame,fit(actual,aspect,safe),actual,aspect,safe,hold)
            self.contained(frame,actual,aspect,safe)
        self.contained(fit(ground,aspect,safe),ground,aspect,safe)

    def test_real_nine_rigid_skin_envelopes(self):
        # The same bind-local AABB construction as the read-only runtime cache.
        # All weighted vertices are inside; any rigid pose transform preserves
        # containment. Positive blend weights stay in the union's convex AABB.
        totals = {}
        for path in sorted((ROOT/'godot/fighting/assets/operators').glob('*.glb')):
            asset = glb.GLB(path)
            boxes,points = {},[]
            for node_index,node in enumerate(asset.doc['nodes']):
                if 'skin' not in node or 'mesh' not in node: continue
                skin = asset.doc['skins'][node['skin']]
                inverse = asset.accessor(skin['inverseBindMatrices'])
                for primitive in asset.doc['meshes'][node['mesh']]['primitives']:
                    attrs = primitive['attributes']
                    positions = asset.accessor(attrs['POSITION'])
                    joints = asset.accessor(attrs['JOINTS_0'])
                    weights = asset.accessor(attrs['WEIGHTS_0'])
                    for vertex_index,(vertex,indices,masses) in enumerate(zip(positions,joints,weights)):
                        self.assertAlmostEqual(sum(masses),1,places=5)
                        for bind,weight in zip(indices,masses):
                            if weight <= 0: continue
                            point = glb.transform(inverse[bind],vertex)
                            key = skin['joints'][bind]
                            low,high = boxes.setdefault(key,[point[:],point[:]])
                            for i in range(3):
                                low[i] = min(low[i],point[i]); high[i] = max(high[i],point[i])
                            points.append((key,point))
                        if vertex_index%37 == 0:
                            recovered = [0.,0.,0.]
                            for bind,weight in zip(indices,masses):
                                if weight <= 0: continue
                                p = glb.transform(asset.world(skin['joints'][bind]),glb.transform(inverse[bind],vertex))
                                for axis in range(3): recovered[axis] += weight*p[axis]
                            expected = glb.transform(asset.world(node_index),vertex)
                            self.assertLess(math.dist(recovered,expected),1e-5,
                                            f'{path.stem}: skin bind coordinate mismatch')
            self.assertGreater(len(points),1000)
            for key,point in points:
                low,high = boxes[key]
                self.assertTrue(all(low[i] <= point[i] <= high[i] for i in range(3)))
            totals[path.stem] = len(points)
        self.assertEqual(len(totals),9)

    def test_integration_keeps_authority_and_animation_read_only(self):
        main = (ROOT/'godot/fighting/main.gd').read_text()
        bounds = (ROOT/'godot/fighting/presentation/pose_bounds.gd').read_text()
        self.assertIn('camera.configure(roster,rules,visuals)',main)
        self.assertIn('camera.present(state.fighters,get_viewport().get_visible_rect().size,state,',main)
        self.assertIn('camera.reset()',main)
        self.assertIn('tick == _last_tick',SOURCE)
        self.assertIn('elif not frozen:',SOURCE)
        for token in ['set_bone_', 'simulation.step', 'load_state', 'AnimationPlayer.new']:
            self.assertNotIn(token,SOURCE+bounds)


if __name__ == '__main__':
    unittest.main()
