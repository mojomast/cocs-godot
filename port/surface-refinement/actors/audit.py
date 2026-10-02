#!/usr/bin/env python3
"""Reproducible pixel review only: Pillow/NumPy, no native capture or bpy."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'tools/asset-production'))
from moth_finish import FAMILIES, MATERIAL_ROLES, checked_source, derive_pixels

BASE = '068e3ce2'
OUT = Path(__file__).resolve().parent
EVIDENCE = Path('/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002')
IDS = ['chatgpt', 'claude', 'grok', 'meta', 'gemini', 'deepseek', 'mistral', 'kimi', 'qwen']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    manifest = json.loads((ROOT/'godot/moth/generated/manifest.json').read_text())
    report = {'scope': 'source-only; revised native acceptance pending',
              'base': BASE, 'materials': MATERIAL_ROLES, 'operators': {}, 'queue_grain': {},
              'helper_sha256': digest(ROOT/'tools/asset-production/moth_finish.py'),
              'moth_manifest_sha256': digest(ROOT/'godot/moth/generated/manifest.json'),
              'moth_baked_master_sha256': digest(ROOT/manifest['provenance']['source'])}
    capture = EVIDENCE/'operator-captures-refined'
    report['native_evidence'] = {
        'root': str(capture), 'capture_receipt_sha256': digest(capture/'capture-receipt.json'),
        'fixture_sha256': digest(EVIDENCE/'operator-capture.gd'),
        'row_order': ['original SVG red', 'original SVG blue', 'rejected Moth red', 'rejected Moth blue'],
        'receipt': json.loads((capture/'capture-receipt.json').read_text()),
    }
    native = Image.new('RGB', (1200, len(IDS)*255), '#202630')
    nd = ImageDraw.Draw(native)
    sheet = Image.new('RGB', (900, len(IDS)*155), '#202630')
    sd = ImageDraw.Draw(sheet)
    for row, operator in enumerate(IDS):
        native_path = capture/f'closeup-{operator}.png'
        nd.text((8, row*255+4), operator+' | original SVG red / blue | rejected Moth red / blue (existing native pixels)', fill='white')
        # Same crop for all identities; no recoloring/sharpening or invented views.
        im = Image.open(native_path).crop((215, 450, 1395, 915)).resize((600, 236))
        native.paste(im, (300, row*255+19))
        rec = {'native_png_sha256': digest(native_path), 'channels': {}}
        sd.text((8, row*155+3), operator+' shared shell: rejected -> quiet candidate (2D raw data, NOT a native after)', fill='white')
        for col, channel in enumerate(('albedo', 'roughness', 'normal')):
            relative = f'godot/source_operators/moth_finish/assets/{operator}-shell-{channel}.png'
            before = Image.open(io.BytesIO(subprocess.check_output(['git', 'show', BASE+':'+relative], cwd=ROOT)))
            after = Image.open(ROOT/relative)
            b, a = np.asarray(before), np.asarray(after)
            rec['channels'][channel] = {'before_range': [int(b.min()), int(b.max())],
                                        'after_range': [int(a.min()), int(a.max())],
                                        'before_mean': round(float(b.mean()), 5), 'after_mean': round(float(a.mean()), 5),
                                        'new_png_sha256': digest(ROOT/relative)}
            for which, image in enumerate((before, after)):
                x = col*300+which*145
                sd.text((x+4, row*155+18), channel+(' before' if which == 0 else ' after'), fill='white')
                sheet.paste(image.convert('RGB').resize((128, 118)), (x+4, row*155+34))
        report['operators'][operator] = rec
    native.save(OUT/'native-reviewed-crops.png')
    sheet.save(OUT/'shell-pixel-comparison.png')
    samples = Image.new('RGB', (800, len(FAMILIES)*155), '#202630')
    draw = ImageDraw.Draw(samples)
    for row, (role, (key, contrast, normal, density)) in enumerate(FAMILIES.items()):
        path, source_hash = checked_source(ROOT, manifest['textures'][key])
        im = Image.open(path).convert('RGBA')
        a = np.asarray(im).astype(float)/255
        if manifest['textures'][key]['color_space'] == 'srgb':
            a[:, :, :3] = np.where(a[:, :, :3] <= .04045, a[:, :, :3]/12.92,
                                   ((a[:, :, :3]+.055)/1.055)**2.4)
        colors, normals = derive_pixels(a.reshape(-1).tolist(), *im.size, role)
        rgb = np.asarray(colors).reshape(im.height, im.width, 4)[:, :, :3]
        report['queue_grain'][role] = {'source': key, 'source_png_sha256': source_hash,
                                      'linear_multiplier_range': [float(rgb.min()), float(rgb.max())],
                                      'normal_strength': normal, 'tiles_per_metre': density,
                                      'derived_float_sha256': hashlib.sha256(np.asarray(colors, dtype='<f8').tobytes()).hexdigest()}
        draw.text((8, row*155+3), f'{role}: {key}; contrast {contrast}; normal {normal}; {density} tiles/m', fill='white')
        for col, (label, image) in enumerate((('raw Moth albedo/data', im),
                                             ('neutral coating x grain', Image.fromarray(np.uint8(np.clip(rgb*.65, 0, 1)*255))),
                                             ('normal DATA' if normal else 'normal OMITTED', Image.fromarray(np.uint8(np.asarray(normals).reshape(im.height, im.width, 4)*255))))):
            draw.text((col*260+8, row*155+18), label, fill='white')
            samples.paste(image.convert('RGB').resize((244, 115)), (col*260+8, row*155+35))
    samples.save(OUT/'queued-grain-pixels.png')
    (OUT/'pixel-audit.json').write_text(json.dumps(report, indent=2, sort_keys=True)+'\n')
    print('Source pixel/capture provenance audit written; no new native run.')


if __name__ == '__main__':
    run()
