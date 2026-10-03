"""Y-specific supplemental views/rays without changing the eleven-camera fixture."""
from tangents import *
stage=ROOT/'godot/tests/new_maps/gravemill_foundry/revision7'
rays=(stage.parent/'revision6/rays.gd').read_text().replace('/revision6/','/revision7/').replace('R6-stage','R7-stage').replace('R6_NATIVE_RAYS','R7_NATIVE_RAYS')
(stage/'rays.gd').write_text(rays)
capture=(stage/'capture.gd').read_text()
capture=capture.replace('revision7/evidence/native/','revision7/evidence/native-targeted/').replace('capture-report.json','targeted-capture-report.json').replace('revision7/capture.gd','revision7/targeted_capture.gd')
capture=capture.replace('var probes := Stage.read_json(Stage.DIR+"probes.json")','var probes := Stage.read_json(Stage.DIR+"targeted-probes.json")')
(stage/'targeted_capture.gd').write_text(capture)
views={'scope':'Supplemental paired views aimed at real repaired surfaces; unchanged camera/lighting for R6 and R7; thin ground triangle may be subpixel',
    'cameras':[{'id':'tangent-copper-high','eye':[0,37,-9],'target':[0,34.15,-4]},
        {'id':'tangent-ground-sliver','eye':[-188.25,14.3,-8.9],'target':[-188.388,10.423,-7.943]}]}
(stage/'targeted-probes.json').write_text(json.dumps(views,indent=2)+'\n')
