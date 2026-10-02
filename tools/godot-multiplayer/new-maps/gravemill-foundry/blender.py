"""Current author entry point. Requires an explicit exclusive heavy-slot grant.

Writes isolated revision-three assets; promote.mjs performs verified promotion.
The original functional-checkpoint author is retained in checkpoint-blender.py.
"""
import pathlib
import runpy

runpy.run_path(str(pathlib.Path(__file__).parent / 'revision3' / 'author.py'), run_name='__main__')
