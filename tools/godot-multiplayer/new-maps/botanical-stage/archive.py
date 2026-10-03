"""Explicit candidate-local retry archive; accepted resources are never targets."""
import argparse
import datetime as dt
import shutil
import tarfile
from config import HERE, ROOT, DEST, MAPS, entry, write, sha

def archive(map_id,all_outputs=False):
    author,_,_,_,_=entry(map_id)
    paths=[DEST/'artifacts'/map_id]
    if all_outputs:paths += [author.MASTER.parent,author.EXPORT,author.REPORT,HERE/'evidence'/map_id]
    paths=[p for p in paths if p.exists()]
    if not paths:return
    name=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%f')+'-'+map_id
    dest=HERE/'evidence/attempts';dest.mkdir(parents=True,exist_ok=True)
    hashes={str(p.relative_to(ROOT)):sha(p) for path in paths for p in (path.rglob('*') if path.is_dir() else [path]) if p.is_file()}
    with tarfile.open(dest/(name+'.tar.gz'),'w:gz') as tar:
        for path in paths:tar.add(path,arcname=str(path.relative_to(ROOT)))
    write(dest/(name+'-archive.json'),{'files':hashes,'archiveSha256':sha(dest/(name+'.tar.gz'))})
    for path in paths:
        if path.is_dir():shutil.rmtree(path)
        else:path.unlink()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('map',choices=MAPS);parser.add_argument('--all-outputs',action='store_true')
    args=parser.parse_args();archive(args.map,args.all_outputs)
