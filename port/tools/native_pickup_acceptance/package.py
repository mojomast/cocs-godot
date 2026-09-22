"""Archive owned live evidence losslessly; retain summaries and PNGs for direct review."""
# Restored from 2d4e60a. For original-to-sanitized derivation use sanitize_evidence.py.
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile

root = Path(__file__).resolve().parents[3]
directory = root / 'port/native-pickup-acceptance/evidence'
archive_path = directory.with_suffix('.tar.gz')
index_path = directory.with_name('evidence-index.json')
assert not archive_path.exists() and not index_path.exists(), 'Never replace a prior archive'
payload = io.BytesIO()
members = []
with tarfile.open(fileobj=payload, mode='w', format=tarfile.USTAR_FORMAT) as archive:
    for path in sorted(directory.rglob('*')):
        assert not path.is_symlink()
        if not path.is_file():
            continue
        data = path.read_bytes()
        if path.name == 'wire.jsonl.gz':
            for line in gzip.decompress(data).decode().splitlines():
                if not line:
                    continue
                frame = json.loads(line)['frame']
                if frame.get('type') == 'welcome':
                    assert all(frame.get(key) is None for key in ('token', 'progressToken')), 'Unredacted welcome credential'
        name = 'evidence/' + path.relative_to(directory).as_posix()
        member = tarfile.TarInfo(name)
        member.size = len(data)
        member.mode = 0o600
        archive.addfile(member, io.BytesIO(data))
        members.append({'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
compressed = gzip.compress(payload.getvalue(), compresslevel=9, mtime=0)
with tarfile.open(fileobj=io.BytesIO(compressed), mode='r:gz') as archive:
    for expected, member in zip(members, archive.getmembers(), strict=True):
        data = archive.extractfile(member).read()
        assert member.name == expected['path']
        assert len(data) == expected['bytes']
        assert hashlib.sha256(data).hexdigest() == expected['sha256']
archive_path.write_bytes(compressed)
index = {'schema': 1, 'archive': archive_path.name, 'archive_bytes': len(compressed),
         'archive_sha256': hashlib.sha256(compressed).hexdigest(),
         'method': 'Lossless deterministic tar/gzip. All three attempts retained, including setup failure and earlier cleanup-report race. Loose summaries/PNGs are convenience copies; extract archive for complete offline audit.',
         'members': members}
index_path.write_text(json.dumps(index, indent=2) + '\n')
# Only these just-archived, owned generated outputs are compacted.
for member in members:
    path = directory.parent / member['path']
    if path.name != 'summary.json' and path.suffix != '.png':
        path.unlink()
print(json.dumps({'archive_bytes': len(compressed), 'members': len(members), 'verified': True}))
