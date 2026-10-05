"""Write-once record, seal and path helpers.

Nothing here imports an engine, spawns a process, writes into the Godot project
or contacts a network. Records are created with exclusive-create semantics, so a
rerun of any helper raises instead of silently overwriting evidence. Every seal
binds a relative path to a byte count plus a SHA256 digest, and ``verify_seals``
re-checks those bytes against the files that are actually on disk.
"""
import datetime
import hashlib
import json
import re
from pathlib import Path

HEX64 = re.compile(r'[a-f0-9]{64}')
UTC = re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}\+00:00')


def _reject_constant(value):
    raise ValueError('non-finite JSON constant refused: ' + value)


def _unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key refused: ' + key)
        result[key] = value
    return result


def digest(data):
    if not isinstance(data, (bytes, bytearray)):
        raise ValueError('digest requires bytes')
    return hashlib.sha256(bytes(data)).hexdigest()


def sha(path):
    return digest(Path(path).read_bytes())


def load(path):
    """Fail-closed JSON: duplicate keys, NaN and Infinity are all refused."""
    return json.loads(
        Path(path).read_text(),
        object_pairs_hook=_unique,
        parse_constant=_reject_constant,
    )


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write_once(path, value):
    """Create ``path`` exclusively. An existing path is an error, never a rerun."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x') as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write('\n')
    return path


def relative(root, name):
    """Canonical, in-root, symlink-free relative path resolution."""
    if not isinstance(name, str) or not name or '\\' in name or name.startswith('/'):
        raise ValueError('invalid relative path')
    parts = Path(name).parts
    if Path(name).is_absolute() or any(part in ('.', '..') for part in parts) or str(Path(name)) != name:
        raise ValueError('noncanonical relative path')
    path = Path(root) / Path(name)
    if path.resolve() != path.absolute():
        raise ValueError('symlinked path refused')
    if not path.is_absolute() or not path.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError('path escape refused')
    return path


def seal(root, name, role):
    """Bind one file to its size and digest. The role is part of the seal."""
    path = relative(root, name)
    if path.is_symlink() or not path.is_file():
        raise ValueError('sealed path must be a regular file: ' + name)
    return {'path': name, 'role': role, 'sha256': sha(path), 'bytes': path.stat().st_size}


def seal_set(root, names, role='delivery'):
    if not isinstance(names, (list, tuple)) or not names or len(set(names)) != len(names):
        raise ValueError('nonempty unique seal list required')
    return [seal(root, name, role) for name in names]


def verify_seals(root, seals):
    """Re-check every seal against the bytes on disk. Raises on any divergence."""
    if not isinstance(seals, list) or not seals:
        raise ValueError('seal list required')
    root = Path(root)
    total = 0
    seen = set()
    for entry in seals:
        if not isinstance(entry, dict) or set(entry) != {'path', 'role', 'sha256', 'bytes'}:
            raise ValueError('exact seal schema required')
        if not isinstance(entry['path'], str) or entry['path'] in seen:
            raise ValueError('duplicate or non-string seal path')
        seen.add(entry['path'])
        if not HEX64.fullmatch(entry['sha256'] or ''):
            raise ValueError('seal digest must be lowercase hex sha256')
        if type(entry['bytes']) is not int or entry['bytes'] < 0:
            raise ValueError('seal byte count must be a nonnegative integer')
        path = relative(root, entry['path'])
        if path.is_symlink() or not path.is_file():
            raise ValueError('sealed file missing or replaced: ' + entry['path'])
        if path.stat().st_size != entry['bytes'] or sha(path) != entry['sha256']:
            raise ValueError('seal tampering: ' + entry['path'])
        total += entry['bytes']
    return {'sealsVerified': len(seals), 'sealedBytes': total}


def manifest(root, names, role='delivery'):
    """A self-describing seal manifest: the verified totals plus the seals."""
    sealed = seal_set(root, names, role)
    verified = verify_seals(root, sealed)
    return {'utc': utc(), 'root': str(Path(root).absolute()), 'role': role,
            'seals': sealed, **verified}
