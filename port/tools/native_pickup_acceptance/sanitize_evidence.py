"""Derive sanitized evidence from original Git bytes without writing raw credentials.

Only non-null welcome token/progressToken/profile.ownerToken values change; unchanged archive
members retain exact bytes. Values are never logged, hashed individually, or
included in the redaction manifest. The original commit/branch is untouched.
"""
import copy
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ORIGINAL = '2d4e60a66761d79f79ef274cf6ba20d663ede968'
ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / 'port/native-pickup-acceptance'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def original_file(path):
    return subprocess.check_output(['git', 'show', f'{ORIGINAL}:{path}'], cwd=ROOT)


def main():
    archive_path = DEST / 'evidence.tar.gz'
    index_path = DEST / 'evidence-index.json'
    provenance_path = DEST / 'SANITIZATION.json'
    assert not any(p.exists() for p in (archive_path, index_path, provenance_path)), 'Never overwrite a delivery'
    original_archive = original_file('port/native-pickup-acceptance/evidence.tar.gz')
    original_index_bytes = original_file('port/native-pickup-acceptance/evidence-index.json')
    original_index = json.loads(original_index_bytes)
    assert sha(original_archive) == original_index['archive_sha256'], 'Original archive index mismatch'
    original_members = {}
    with tarfile.open(fileobj=io.BytesIO(original_archive), mode='r:gz') as archive:
        for info in archive.getmembers():
            assert info.isfile() and info.name.startswith('evidence/') and '..' not in Path(info.name).parts
            original_members[info.name] = archive.extractfile(info).read()
    assert set(original_members) == {m['path'] for m in original_index['members']}
    for entry in original_index['members']:
        data = original_members[entry['path']]
        assert sha(data) == entry['sha256'] and len(data) == entry['bytes'], 'Original member index mismatch'

    derived_members = dict(original_members)
    changes = []
    secrets = []
    for name, data in original_members.items():
        if not name.endswith('/wire.jsonl.gz'):
            continue
        original_plain = gzip.decompress(data)
        lines = original_plain.decode().splitlines(keepends=True)
        fields = []
        for number, line in enumerate(lines, 1):
            if not line.strip():
                continue
            record = json.loads(line)
            frame = record['frame']
            if frame.get('type') != 'welcome':
                continue
            expected = copy.deepcopy(record)
            for path in (('token',), ('progressToken',), ('profile', 'ownerToken')):
                source_parent = frame if len(path) == 1 else (frame.get(path[0]) or {})
                key = path[-1]
                value = source_parent.get(key)
                if value is None:
                    continue
                target_parent = expected['frame'] if len(path) == 1 else expected['frame'][path[0]]
                assert isinstance(value, str) and value, 'Unexpected welcome credential shape'
                secrets.append(value.encode())
                # Replace only this exact string value; leave other JSON bytes untouched.
                encoded = json.dumps(value, ensure_ascii=False, separators=(',', ':'))
                old = json.dumps(key) + ':' + encoded
                new = json.dumps(key) + ':null'
                assert line.count(old) == 1, 'Expected one exact field value'
                line = line.replace(old, new, 1)
                target_parent[key] = None
                fields.append({'line': number, 'jsonPointer': '/frame/' + '/'.join(path), 'replacement': None})
            assert json.loads(line) == expected, 'Noncredential semantic change'
            lines[number - 1] = line
        if fields:
            derived_plain = ''.join(lines).encode()
            derived_members[name] = gzip.compress(derived_plain, compresslevel=9, mtime=0)
            changes.append({'path': name, 'redactedFields': fields, 'count': len(fields),
                            'original_sha256': sha(data), 'derived_sha256': sha(derived_members[name]),
                            'original_uncompressed_sha256': sha(original_plain),
                            'derived_uncompressed_sha256': sha(derived_plain)})
    assert len(changes) == 2 and sum(c['count'] for c in changes) == 6, 'Unexpected original redaction count'
    assert len(original_members) == 36
    # Scan all retained bytes, including decompressed logs, against every removed
    # value in memory. No value or value-specific digest is written to provenance.
    for name, data in derived_members.items():
        decoded = gzip.decompress(data) if name.endswith('.gz') else data
        assert all(secret not in decoded for secret in secrets), 'Credential survived derivation'
        if name.endswith('/wire.jsonl.gz'):
            for line in decoded.decode().splitlines():
                if not line:
                    continue
                frame = json.loads(line)['frame']
                if frame.get('type') == 'welcome':
                    assert all(frame.get(k) is None for k in ('token', 'progressToken'))
                    assert (frame.get('profile') or {}).get('ownerToken') is None
    changed_names = {c['path'] for c in changes}
    assert all(derived_members[name] == data for name, data in original_members.items() if name not in changed_names)

    payload = io.BytesIO()
    members = []
    with tarfile.open(fileobj=payload, mode='w', format=tarfile.USTAR_FORMAT) as archive:
        for name, data in sorted(derived_members.items()):
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o600
            archive.addfile(info, io.BytesIO(data))
            members.append({'path': name, 'bytes': len(data), 'sha256': sha(data),
                            'original_sha256': sha(original_members[name]), 'redacted': name in changed_names})
    derived_archive = gzip.compress(payload.getvalue(), compresslevel=9, mtime=0)
    with tarfile.open(fileobj=io.BytesIO(derived_archive), mode='r:gz') as archive:
        for entry, info in zip(members, archive.getmembers(), strict=True):
            data = archive.extractfile(info).read()
            assert info.name == entry['path'] and len(data) == entry['bytes'] and sha(data) == entry['sha256']
    index = {'schema': 2, 'archive': archive_path.name, 'archive_bytes': len(derived_archive),
             'archive_sha256': sha(derived_archive), 'provenance': provenance_path.name,
             'method': 'Sanitized derivative: only six welcome token/progressToken/profile.ownerToken values become null in two wire logs. All 36 members and all three attempts retained; 34 members byte-identical.',
             'members': members}
    provenance = {'schema': 1, 'original_commit': ORIGINAL,
                  'original_branch_preserved': 'port/native-pickup-acceptance',
                  'original_archive_path': 'port/native-pickup-acceptance/evidence.tar.gz',
                  'original_archive_sha256': sha(original_archive),
                  'original_index_sha256': sha(original_index_bytes),
                  'derived_archive_sha256': sha(derived_archive),
                  'derivation_source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  'derivation_script_sha256': sha(Path(__file__).read_bytes()),
                  'execution_provenance': 'Original summaries, execution source hashes and gameplay observations are unchanged. This is offline sanitization, not a new live execution.',
                  'credential_scan': {'removed_values_absent_from_all_decompressed_members': True,
                                      'all_retained_welcome_credentials_null': True},
                  'members_retained': len(members), 'members_byte_identical': len(members)-len(changes),
                  'redacted_field_count': sum(c['count'] for c in changes), 'changes': changes}
    DEST.mkdir(parents=True, exist_ok=True)
    archive_path.write_bytes(derived_archive)
    index_path.write_text(json.dumps(index, indent=2) + '\n')
    provenance_path.write_text(json.dumps(provenance, indent=2) + '\n')
    for name, data in derived_members.items():
        if name.endswith('/summary.json') or name.endswith('.png'):
            path = DEST / name
            path.parent.mkdir(parents=True, exist_ok=True)
            assert not path.exists(), 'Never overwrite retained evidence'
            path.write_bytes(data)
    print(json.dumps({'status': 'PASS', 'archive_bytes': len(derived_archive),
                      'original_archive_sha256': sha(original_archive), 'derived_archive_sha256': sha(derived_archive),
                      'members_retained': len(members), 'redacted_fields': provenance['redacted_field_count'],
                      'changes': [{'path': c['path'], 'count': c['count'], 'fields': c['redactedFields']} for c in changes]}, indent=2))


if __name__ == '__main__':
    main()
