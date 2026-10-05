"""Isolated package loader with an explicit, single-operation CLI.

The hashed package name prevents this package's ``policy``, ``prepare``,
``supervisor`` and ``evidence`` modules from shadowing the same names in any
sibling walker package that a test run happens to import alongside it.
"""
import hashlib
import importlib
import importlib.util
import sys
from pathlib import Path


def package():
    here = Path(__file__).resolve().parent
    name = '_support_query_compare_' + hashlib.sha256(str(here).encode()).hexdigest()[:16]
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, here / '__init__.py',
                                                      submodule_search_locations=[str(here)])
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
    return name


def module(name):
    return importlib.import_module(package() + '.' + name)


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] not in ('prepare', 'supervisor'):
        raise SystemExit('prepare|supervisor; neither may stage GDScript, write a grant or launch')
    name = sys.argv.pop(1)
    raise SystemExit(module(name).cli())
