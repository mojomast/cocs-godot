"""Read only the explicitly selected X/U roots; verify every frozen inventory byte."""
import argparse
import json
import os
from pathlib import Path
from fixture_inputs import sha,write
INVENTORIES={
 'X':('COCS_BOTANICAL_X_FIXTURE_ROOT','tools/godot-multiplayer/new-maps/botanical-correction/x-evidence/artifact-inventory.json','440a1291201eaa3ee55f9c0218503ac4588028bfae7fee5c46364673bf94bd78',600),
 'U':('COCS_BOTANICAL_U_FIXTURE_ROOT','tools/godot-multiplayer/new-maps/botanical-stage/evidence/artifact-inventory.json','ce0dd0ec8a87340cc31bfcb88cdfc7b11fb5aad1ce6efd317b9bb43ec22289ef',264),
}
def verify():
    result={}
    for label,(env,path,digest,count) in INVENTORIES.items():
        if not os.environ.get(env):raise ValueError('Explicit '+env+' required')
        root=Path(os.environ[env]).resolve(strict=True);raw=(root/path).read_bytes()
        if sha(raw)!=digest:raise ValueError('Frozen inventory changed')
        files=json.loads(raw)['files']
        if len(files)!=count:raise ValueError('Frozen inventory count drift')
        for relative,record in files.items():
            p=(root/relative).resolve(strict=True)
            if not p.is_relative_to(root):raise ValueError('Inventory path escapes root')
            data=p.read_bytes()
            if sha(data)!=record['sha256'] or len(data)!=record['bytes']:raise ValueError('Frozen artifact changed '+relative)
        result[label]={'root':str(root),'inventorySha256':digest,'verifiedFiles':count,'mismatches':0}
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('output');a=p.parse_args()
    result=verify();write(a.output,result);print(json.dumps(result,indent=2))
