"""Losslessly package reviewed evidence; never remove or rewrite the originals.

Usage: python3 port/tools/package_evidence.py EVIDENCE_DIRECTORY SOURCE_COMMIT
Writes sibling evidence.tar.gz and evidence-index.json exclusively. The caller
reviews/removes loose tracked files in a separate packaging commit afterward.
"""
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def package(directory, commit):
    directory = Path(directory).resolve()
    root = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip())
    commit = subprocess.check_output(['git', 'rev-parse', '--verify', commit + '^{commit}'], text=True).strip()
    members = []
    payload = io.BytesIO()
    runs = []
    with tarfile.open(fileobj=payload, mode='w', format=tarfile.USTAR_FORMAT) as archive:
        for path in sorted(directory.rglob('*')):
            if path.is_symlink():
                raise ValueError(f'Symlink is not evidence: {path}')
            if not path.is_file():
                continue
            data = path.read_bytes()
            relative = path.relative_to(directory).as_posix()
            # Packaging must retain exact committed bytes and provenance.
            original = subprocess.check_output(['git', 'show', f'{commit}:{path.relative_to(root)}'])
            if data != original:
                raise ValueError(f'Uncommitted or changed evidence: {relative}')
            member = tarfile.TarInfo('evidence/' + relative)
            member.size = len(data)
            member.mode = 0o600
            archive.addfile(member, io.BytesIO(data))
            members.append({'path': member.name, 'bytes': len(data), 'sha256': digest(data)})
            if path.name == 'summary.json':
                report = json.loads(data)
                runs.append({'run': path.parent.name, 'reported_status': report.get('status'),
                             'cases': [{'name': c['name'], 'reported_status': c['status'],
                                        'error': c.get('error'), 'cleanup': c.get('cleanup')}
                                       for c in report['cases']],
                             'cleanup': report.get('cleanup')})
    compressed = gzip.compress(payload.getvalue(), compresslevel=9, mtime=0)
    # Verify every reconstructed byte, not just that tar can list the archive.
    with tarfile.open(fileobj=io.BytesIO(compressed), mode='r:gz') as archive:
        for expected, actual in zip(members, archive.getmembers(), strict=True):
            data = archive.extractfile(actual).read()
            assert actual.name == expected['path'] and len(data) == expected['bytes']
            assert digest(data) == expected['sha256']
    index = {'schema': 1, 'source_commit': commit, 'source_directory': str(directory.relative_to(root)),
             'archive': 'evidence.tar.gz', 'archive_bytes': len(compressed), 'archive_sha256': digest(compressed),
             'uncompressed_file_bytes': sum(m['bytes'] for m in members),
             'method': 'Lossless deterministic tar/gzip; original bytes, including failed runs and duplicated summaries, retained.',
             'runs': runs, 'members': members}
    with directory.with_suffix('.tar.gz').open('xb') as out:
        out.write(compressed)
    with directory.with_name('evidence-index.json').open('x') as out:
        out.write(json.dumps(index, indent=2) + '\n')
    print(json.dumps({k: index[k] for k in ('archive_bytes', 'uncompressed_file_bytes', 'source_commit')}))


if __name__ == '__main__':
    package(*sys.argv[1:])
