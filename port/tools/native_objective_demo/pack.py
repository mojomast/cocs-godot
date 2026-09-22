"""Losslessly pack this task's diagnostic logs; retain per-file hashes."""
from pathlib import Path
import gzip
import hashlib
import json

root = Path('port/native-objective-gameplay/evidence')
for directory in sorted(root.iterdir()):
    if not directory.is_dir():
        continue
    manifest = directory / 'archive.json'
    records = json.loads(manifest.read_text()) if manifest.exists() else []
    for path in sorted(directory.iterdir()):
        if path.suffix not in ('.log', '.jsonl'):
            continue
        data = path.read_bytes()
        packed = gzip.compress(data, mtime=0)
        destination = path.with_name(path.name + '.gz')
        if destination.exists():
            raise RuntimeError(f'Refusing overwrite: {destination}')
        destination.write_bytes(packed)
        assert gzip.decompress(destination.read_bytes()) == data
        records.append({'original': path.name, 'archive': destination.name,
                        'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        path.unlink()
    for record in records:
        raw = gzip.decompress((directory / record['archive']).read_bytes())
        assert len(raw) == record['bytes']
        assert hashlib.sha256(raw).hexdigest() == record['sha256']
    manifest.write_text(json.dumps(records, indent=2) + '\n')
print('All diagnostic archives verified byte-for-byte')
