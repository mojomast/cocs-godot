"""Pinned AG file and corrected ownership helpers only; never call old launch/build.

Imports are isolated, restored and bytecode-free. review-pins binds all three files.
"""
import importlib.util,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent.parent/'walker-parity-response'
saved={key:sys.modules.get(key) for key in ['policy','prepare']}
old=sys.dont_write_bytecode
try:
    sys.dont_write_bytecode=True;loaded={}
    for name in ['policy','prepare','supervisor']:
        spec=importlib.util.spec_from_file_location('_baseline_frozen_'+name,BASE/(name+'.py'))
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);loaded[name]=module
        if name in saved:sys.modules[name]=module
finally:
    sys.dont_write_bytecode=old
    for key,value in saved.items():
        if value is None:sys.modules.pop(key,None)
        else:sys.modules[key]=value
files=loaded['prepare'];runtime=loaded['supervisor']
