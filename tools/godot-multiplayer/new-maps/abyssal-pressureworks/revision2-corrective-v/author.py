"""Abyssal corrective composition entry (future granted heavy owner only).

Builds the *complete* revised authority (all retained decks, ramps, ceilings,
walls, equipment, glazing and the six removed-roof substitutes) plus the authored
classes, then exports the material-batched GLB. Requires Sol's injected adapter:
see tools/map-variety-support/build_entry.py.

blender -b -t 1 --python-exit-code 1 --python <this> -- --root <repo>
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[4] / 'tools' / 'map-variety-support'))
import layout  # noqa: E402
import build_entry  # noqa: E402

CONFIG = {'id': 'abyssal-pressureworks', 'directory': HERE, 'layout': layout,
          'description': 'Abyssal revision-2 complete composition builder'}

if __name__ == '__main__':
    build_entry.run(CONFIG)
