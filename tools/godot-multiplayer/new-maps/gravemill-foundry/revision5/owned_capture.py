"""Inventory every render-group child; terminate only owned Godot on script error."""
import os
import select
import signal
import subprocess
import sys
import time
from pathlib import Path
from grant import inventory,now,write,HERE
group=os.getpgrp();start=now();members={};failed=False
proc=subprocess.Popen(sys.argv[1:],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
assert proc.stdout is not None
while True:
    rows=[r for r in inventory() if r['pgid']==group]
    for row in rows:members[(row['pid'],row['startTicks'])]=row
    ready,_,_=select.select([proc.stdout],[],[],.1)
    if ready:
        line=proc.stdout.readline()
        if line:
            sys.stdout.buffer.write(line);sys.stdout.buffer.flush()
            if b'SCRIPT ERROR:' in line:
                failed=True
                for row in rows:
                    if row['comm'].startswith('Godot_'):
                        current=[r for r in inventory() if r['pid']==row['pid'] and r['startTicks']==row['startTicks'] and r['pgid']==group]
                        if current:os.kill(row['pid'],signal.SIGTERM)
        elif proc.poll() is not None:break
    if proc.poll() is not None and not ready:break
code=proc.wait()
write(HERE/'evidence/attempts'/('capture-group-'+str(group)+'.json'),{'start':start,'end':now(),'pgid':group,'members':list(members.values()),'scriptError':failed,'returncode':code})
sys.exit(1 if failed else code)
