"""Isolated package loader and explicit, single-operation future CLI."""
import hashlib,importlib,importlib.util,sys
from pathlib import Path
def package():
    here=Path(__file__).resolve().parent
    name='_calibrated_admission_'+hashlib.sha256(str(here).encode()).hexdigest()[:16]
    if name not in sys.modules:
        spec=importlib.util.spec_from_file_location(name,here/'__init__.py',submodule_search_locations=[str(here)])
        module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module)
    return name
def module(name):return importlib.import_module(package()+'.'+name)
if __name__=='__main__':
    if len(sys.argv)<2 or sys.argv[1] not in ['prepare','supervisor','verify_preservation']:raise SystemExit('prepare|supervisor|verify_preservation; no multi-group runner')
    name=sys.argv.pop(1);raise SystemExit(module(name).cli())
