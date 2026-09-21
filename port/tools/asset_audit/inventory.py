"""Offline, read-only source inventory. JSON to stdout; no JS execution or network.
Scope: assets/, public/, game/ (non-tests), godot/world/, exporter sources.
Missing optional generated Godot outputs are reported, not synthesized.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import wave
import zipfile

ROOTS = ('assets', 'public', 'game', 'godot/world', 'tools/godot-export')
REQUIRED = ('game/view.mjs', 'game/moth-baked.mjs', 'assets/moth/manifest.json',
            'public/music/manifest.json', 'public/audio/announcer/manifest.json')


def safe(root, relative):
    p = PurePosixPath(relative)
    if p.is_absolute() or '..' in p.parts or '\\' in relative:
        raise ValueError('unsafe repository path: ' + relative)
    result = root.joinpath(*p.parts)
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError('path escapes repository: ' + relative)
    # Do not follow even internal symlinks: keep provenance unambiguous.
    if any(x.is_symlink() for x in [result, *result.parents] if x != root.parent):
        raise ValueError('symlink not allowed: ' + relative)
    return result


def file_record(root, relative):
    p = safe(root, relative)
    data = p.read_bytes()
    result = {'path': relative, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        if len(data) < 33 or data[12:16] != b'IHDR':
            raise ValueError('malformed PNG: ' + relative)
        result['png'] = dict(zip(('width', 'height'), struct.unpack('>II', data[16:24])))
    elif data.startswith(b'RIFF') and data[8:12] == b'WAVE':
        with wave.open(io.BytesIO(data)) as w:
            result['wav'] = {'channels': w.getnchannels(), 'sample_rate': w.getframerate(),
                             'sample_width_bytes': w.getsampwidth(), 'frames': w.getnframes()}
    elif data.startswith(b'PK\x03\x04'):
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            result['archive_members'] = [
                {'name': i.filename, 'bytes': i.file_size} for i in sorted(z.infolist(), key=lambda i: i.filename)]
    if p.suffix in ('.mjs', '.gd', '.html'):
        text = data.decode('utf-8')
        result['symbols'] = [{'line': i, 'name': m.group(1)} for i, line in enumerate(text.splitlines(), 1)
                             if (m := re.search(r'(?:export (?:function|class)|func)\s+([\w]+)', line))]
    return result


def build(root):
    root = Path(root).resolve()
    for p in REQUIRED:
        if not safe(root, p).is_file():
            raise ValueError('missing required source: ' + p)
    paths = set()
    for folder in ROOTS:
        base = safe(root, folder)
        if not base.is_dir():
            raise ValueError('missing source directory: ' + folder)
        for p in base.rglob('*'):
            rel = p.relative_to(root).as_posix()
            if p.is_symlink():
                raise ValueError('symlink not allowed: ' + rel)
            if p.is_file() and '.test.' not in p.name:
                paths.add(rel)
    files = [file_record(root, p) for p in sorted(paths)]
    lookup = {f['path']: f for f in files}
    refs = []

    def reference(source, target, role, expected=None):
        target_path = safe(root, target)
        item = {'source': source, 'target': target, 'role': role, 'exists': target_path.is_file()}
        if expected:
            item['hash_matches_manifest'] = lookup.get(target, {}).get('sha256') == expected
        refs.append(item)

    music_path = 'public/music/manifest.json'
    music = json.loads(safe(root, music_path).read_text())
    for sample in music['samples']:
        for key in ('file', 'fallback'):
            reference(music_path, 'public/music/' + sample[key], sample['id'] + ':' + key)
    announcer_path = 'public/audio/announcer/manifest.json'
    announcer = json.loads(safe(root, announcer_path).read_text())
    for clip in announcer['clips']:
        reference(announcer_path, 'public/audio/announcer/' + clip['file'], clip['cue'], clip['sha256'])
    moth_path = 'assets/moth/manifest.json'
    moth = json.loads(safe(root, moth_path).read_text())
    jobs = []
    for job in moth['jobs']:
        jobs.append({k: job[k] for k in ('id', 'engine', 'enabled', 'raw', 'bake') if k in job})
        for value in job.get('input', {}).values():
            if isinstance(value, str) and value.startswith('sources/'):
                reference(moth_path, 'assets/moth/' + value, job['id'])
    baked_path = 'game/moth-baked.mjs'
    text = safe(root, baked_path).read_text()
    match = re.search(r'export const MOTH_BAKED\s*=\s*', text)
    if not match:
        raise ValueError('unsupported MOTH_BAKED declaration')
    baked, end = json.JSONDecoder().raw_decode(text[match.end():])
    if text[match.end() + end:].strip() != ';\n\nexport default MOTH_BAKED;':
        raise ValueError('unsupported MOTH_BAKED trailer (never executing JavaScript)')
    buckets = {}
    for key, value in baked.items():
        if not isinstance(value, dict):
            continue
        buckets[key] = []
        for name, record in sorted(value.items()):
            if not isinstance(record, dict):
                continue
            summary = {'name': name}
            for field in ('width', 'height', 'size', 'sampleRate', 'duration', 'bpm'):
                if field in record:
                    summary[field] = record[field]
            for field in ('frames', 'notes'):
                if isinstance(record.get(field), list):
                    summary[field + '_count'] = len(record[field])
            for field, v in record.items():
                if isinstance(v, str) and v.startswith('/moth/files/'):
                    reference(baked_path, 'public' + v, key + ':' + name + ':' + field)
            buckets[key].append(summary)
    return {'schema_version': 1, 'scope': list(ROOTS),
            'limitations': ['Static references are not proof of playback or visual parity.',
                            'No JS evaluation, image decoding, audio decoding except PCM WAV headers, or runtime execution.',
                            'File discovery excludes tests and audit outputs; generated Godot content is optional.'],
            'files': files, 'references': sorted(refs, key=lambda r: (r['source'], r['target'], r['role'])),
            'moth_jobs': sorted(jobs, key=lambda j: j['id']), 'baked_buckets': buckets,
            'music': {'samples': len(music['samples']), 'instruments': sorted({s['instrument'] for s in music['samples']}),
                      'declared_licenses': sorted({s.get('license', 'unknown') for s in music['samples']})},
            'announcer': {'clips': len(announcer['clips']), 'cues': sorted({c['cue'] for c in announcer['clips']})},
            'godot_optional_paths': [{'path': p, 'exists': safe(root, p).exists()} for p in
                                     ('godot/content/generated/manifest.json', 'godot/content/probes/meridian-exchange/world.glb')]}


def render(value):
    return json.dumps(value, sort_keys=True, indent=2, ensure_ascii=True) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    try:
        result = build(args.root)
    except (OSError, ValueError, KeyError, TypeError, wave.Error, zipfile.BadZipFile) as exc:
        print('asset-audit: ' + str(exc), file=sys.stderr)
        return 2
    print(render(result), end='')
    return 0


if __name__ == '__main__':
    sys.exit(main())
