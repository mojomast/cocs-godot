"""AC lifetime owner using the frozen AA nonwaiting owned-PGID supervisor."""
from dependencies import ROOT, HERE, AA_DIR
source=(AA_DIR/'grant_AA.py').read_text()
source=source.replace('from contract import ROOT, HERE','from dependencies import ROOT, HERE')
source=source.replace('MOTH-BLENDER-20261003-AA','MOTH-BLENDER-20261004-AC')
source=source.replace('/tmp/opencode/parallax-tangent-AA','/tmp/opencode/parallax-glyph-AC')
source=source.replace('native/AA01/attempts','native/AC-control/attempts')
exec(compile(source,str(AA_DIR/'grant_AA.py'),'exec'))
