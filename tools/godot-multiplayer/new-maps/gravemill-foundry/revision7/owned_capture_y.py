"""Y-only renderer child inventory and owned error cleanup."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'revision5'))
import grant
grant.HERE=HERE
code=(HERE.parent/'revision5/owned_capture.py').read_text().replace("HERE/'evidence/attempts'","HERE/'evidence/Y/attempts'")
exec(compile(code,__file__,'exec'))
