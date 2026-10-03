"""W renderer descendant receipts using the reviewed owned-only cleanup logic."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'revision5'))
import grant
grant.HERE=HERE
code=(HERE.parent/'revision5/owned_capture.py').read_text().replace("HERE/'evidence/attempts'","HERE/'evidence/W/attempts'")
exec(compile(code,__file__,'exec'))
