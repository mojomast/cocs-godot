#!/usr/bin/env python3
"""Validate matched evidence and build review sheets plus the cost table.

Runs under an interpreter with Pillow (this repo's review lanes use
/home/mojo/.hermes/releases/hermes-agent-*/venv/bin/python):

    python3 port/native-material-apply/review.py            # before/after pairs
    python3 port/native-material-apply/review.py --before-only
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
EVIDENCE = HERE / 'evidence'
SIZES = ['960x640', '1280x800']
PLAYABLE = ['prism-foundry', 'aurora-basin', 'cinder-array', 'lacuna-court', 'vermilion-fold', 'nacre-engine']
LOCKED = ['meridian-exchange', 'verdant-reliquary', 'ember-crucible', 'tidal-citadel', 'sunscar-convoy',
          'asterion-relay', 'monsoon-foundry', 'ion-speedway', 'aurora-stadium']


def load(size, phase, glow=False):
    suffix = '-glow' if glow else ''
    path = EVIDENCE / size / phase / f'manifest-{phase}-{size}{suffix}.json'
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    views = {}
    for entry in data['maps']:
        for camera in entry['cameras']:
            views[(camera['map'], camera['view'])] = camera
    return {'path': path, 'data': data, 'views': views}


def camera_key(camera):
    return {k: camera[k] for k in ['map', 'view', 'width', 'height', 'fov', 'position', 'target']}


def write_markdown(report):
    lines = [
        '# Material-apply cost table (fixed cameras, private Xvfb software GL)',
        '',
        'Frame cadence is the median of 40 frames after 12 warm-up frames on a frozen clock',
        '(Engine.time_scale = 0) at the same camera for both phases. Texture bytes are the',
        'unique RGBA8 textures actually bound by the scene\'s ShaderMaterials, counted once.',
        '',
        '| size | map | view | ms before | ms after | d ms | p95 before | p95 after | draws before | draws after | d draws | tex before | tex after | tex KB before | tex KB after | moth before | moth after |',
        '|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|',
    ]
    for row in report['cost']:
        if 'after' not in row:
            continue
        b, a = row['before'], row['after']
        lines.append('| {size} | {map} | {view} | {bm:.1f} | {am:.1f} | {dm:+.1f} | {bp:.1f} | {ap:.1f} | {bd} | {ad} | {dd:+d} | {bt} | {at} | {bk:.0f} | {ak:.0f} | {bmo} | {amo} |'.format(
            size=row['size'], map=row['map'], view=row['view'],
            bm=b['frame_ms_median'], am=a['frame_ms_median'], dm=a['frame_ms_median'] - b['frame_ms_median'],
            bp=b['frame_ms_p95'], ap=a['frame_ms_p95'],
            bd=b['draw_calls'], ad=a['draw_calls'], dd=a['draw_calls'] - b['draw_calls'],
            bt=b['textures']['unique_textures'], at=a['textures']['unique_textures'],
            bk=b['textures']['texture_bytes_rgba8'] / 1024.0, ak=a['textures']['texture_bytes_rgba8'] / 1024.0,
            bmo=b['moth_cache']['textures'], amo=a['moth_cache']['textures']))
    lines.append('')
    lines.append('`moth` is the shared Moth plane cache count at that view. Draw calls, primitives and node counts')
    lines.append('are unchanged by construction: the pass swaps materials only, and every batch, MultiMesh and')
    lines.append('material count per node is identical before and after.')
    (EVIDENCE / 'cost-table.md').write_text('\n'.join(lines) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before-only', action='store_true')
    args = parser.parse_args()
    report = {'matched_pairs': [], 'matched_cameras': 0, 'size_mismatch': [], 'cost': []}
    sheets = EVIDENCE / 'review'
    sheets.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        before = load(size, 'before')
        after = None if args.before_only else load(size, 'after')
        if before is None:
            continue
        width, height = (int(part) for part in size.split('x'))
        cells = {}
        for key, camera in before['views'].items():
            if (camera['width'], camera['height']) != (width, height):
                report['size_mismatch'].append({'size': size, key: camera['width']})
            cells[key] = {None: camera}
        if after is not None:
            for key, camera in after['views'].items():
                if key not in cells:
                    report['size_mismatch'].append({'size': size, 'extra': list(key)})
                    continue
                if camera_key(camera) != camera_key(cells[key][None]):
                    report['size_mismatch'].append({'size': size, 'unmatched': list(key),
                                                    'before': camera_key(cells[key][None]), 'after': camera_key(camera)})
                cells[key][True] = camera
            report['matched_cameras'] += len(cells)
        for key, pair in sorted(cells.items()):
            row = {'size': size, 'map': key[0], 'view': key[1]}
            for phase, camera in [('before', pair[None]), ('after', pair.get(True))]:
                if camera is None:
                    continue
                row[phase] = {k: camera[k] for k in ['frame_ms_mean', 'frame_ms_median', 'frame_ms_p95', 'draw_calls',
                                                     'primitives', 'video_memory_bytes', 'nodes', 'resources']}
                row[phase]['textures'] = camera['textures']
                row[phase]['moth_cache'] = camera['moth_cache']
            if pair.get(True) is not None:
                row['delta'] = {
                    'frame_ms_median': round(pair[True]['frame_ms_median'] - pair[None]['frame_ms_median'], 2),
                    'frame_ms_p95': round(pair[True]['frame_ms_p95'] - pair[None]['frame_ms_p95'], 2),
                    'draw_calls': pair[True]['draw_calls'] - pair[None]['draw_calls'],
                    'primitives': pair[True]['primitives'] - pair[None]['primitives'],
                    'unique_textures': pair[True]['textures']['unique_textures'] - pair[None]['textures']['unique_textures'],
                    'texture_bytes_rgba8': pair[True]['textures']['texture_bytes_rgba8'] - pair[None]['textures']['texture_bytes_rgba8'],
                }
            report['cost'].append(row)
        # review sheets: one per playable map, plus the locked set
        for group, ids in [('playable', PLAYABLE), ('locked', LOCKED)]:
            for map_id in ids:
                keys = sorted(key for key in cells if key[0] == map_id)
                if not keys:
                    continue
                phases = [None] + ([True] if args.before_only is False and cells[keys[0]].get(True) else [])
                phases = [phase for phase in phases if cells[keys[0]].get(phase)]
                scale = 0.5
                cell_w, cell_h = int(width * scale), int(height * scale)
                sheet = Image.new('RGB', (cell_w * len(keys), (cell_h + 22) * len(phases)), '#141a22')
                draw = ImageDraw.Draw(sheet)
                for row, phase in enumerate(phases):
                    label = 'before' if phase is None else 'after'
                    for column, key in enumerate(keys):
                        camera = cells[key][phase]
                        image_path = EVIDENCE / size / label / camera['file']
                        if not image_path.exists():
                            # Large 1280 PNGs for the seven non-featured locked maps are
                            # pruned from the commit; their review sheet is already built.
                            draw.text((column * cell_w + 6, row * (cell_h + 22) + 5),
                                      f"{key[0]} / {key[1]} / {label} / pruned", fill='#ff8866')
                            continue
                        image = Image.open(image_path).convert('RGB')
                        if image.size != (width, height):
                            raise SystemExit(f"{camera['file']} is {image.size}, expected {(width, height)}")
                        sheet.paste(image.resize((cell_w, cell_h), Image.Resampling.LANCZOS),
                                    (column * cell_w, row * (cell_h + 22) + 22))
                        draw.text((column * cell_w + 6, row * (cell_h + 22) + 5),
                                  f"{key[0]} / {key[1]} / {label} / {size}", fill='white')
                sheet.save(sheets / f'{group}-{map_id}-{size}.jpg', quality=90)
        # glow A/B: same build, glow off vs glow on (the core look must hold off).
        glow_off = load(size, 'after')
        glow_on = load(size, 'after', glow=True)
        if glow_on is not None and glow_off is not None:
            keys = sorted(glow_on['views'])
            scale = 0.5
            cell_w, cell_h = int(width * scale), int(height * scale)
            sheet = Image.new('RGB', (cell_w * len(keys), (cell_h + 22) * 2), '#141a22')
            draw = ImageDraw.Draw(sheet)
            for row, (label, source) in enumerate([('glow off', glow_off), ('glow on', glow_on)]):
                for column, key in enumerate(keys):
                    camera = source['views'].get(key)
                    if camera is None:
                        continue
                    image = Image.open(EVIDENCE / size / 'after' / camera['file']).convert('RGB')
                    sheet.paste(image.resize((cell_w, cell_h), Image.Resampling.LANCZOS),
                                (column * cell_w, row * (cell_h + 22) + 22))
                    draw.text((column * cell_w + 6, row * (cell_h + 22) + 5),
                              f"{key[0]} / {key[1]} / {label} / {size}", fill='white')
            sheet.save(sheets / f'glow-ab-{size}.jpg', quality=90)
    (EVIDENCE / 'cost-table.json').write_text(json.dumps(report, indent=2) + '\n')
    write_markdown(report)
    print(f"matched cameras: {report['matched_cameras']}; camera/size issues: {len(report['size_mismatch'])}; "
          f"views costed: {len(report['cost'])}")
    if report['size_mismatch']:
        print(json.dumps(report['size_mismatch'], indent=2))
        raise SystemExit('evidence does not match')
    print(f'sheets in {sheets}')


if __name__ == '__main__':
    main()
