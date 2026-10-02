"""Serial bounded Blender master/reopen exports. Meta must be first initially."""
import argparse
from pathlib import Path
import subprocess
import sys

p=argparse.ArgumentParser()
p.add_argument('--operators',required=True)
p.add_argument('--evidence',required=True,type=Path)
p.add_argument('--tag',required=True)
p.add_argument('--blender',default='/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender')
a=p.parse_args()
here=Path(__file__).resolve().parent
for operator in a.operators.split(','):
    for mode in ('build','reopen-export'):
        subprocess.run([sys.executable,str(here/'run_owned.py'),'--log',str(a.evidence/f'{operator}-{mode}-{a.tag}.log'),
            '--',a.blender,'-b','--factory-startup','--python-exit-code','1','--python',str(here/'blender_pipeline.py'),
            '--',mode,'--operator',operator,'--evidence',str(a.evidence)],check=True)
