#!/usr/bin/env python3
"""Validate matched evidence dimensions/cameras and make labeled review sheets."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).parent / 'evidence'
MAPS = ['meridian-exchange', 'ember-crucible', 'asterion-relay']
report = []
for size in ['960x640', '1280x800']:
    before = json.loads((OUT / size / 'before/manifest.json').read_text())
    after = json.loads((OUT / size / 'after/manifest.json').read_text())
    for a in before:
        b = next(item for item in after if (item['map'], item['view']) == (a['map'], a['view']))
        keys = ['map', 'view', 'position', 'target', 'fov', 'width', 'height']
        assert {k: a[k] for k in keys} == {k: b[k] for k in keys}
        expected = tuple(map(int, size.split('x')))
        assert (a['width'], a['height']) == expected
        report.append({k: a[k] for k in keys})
    for view in ['overview', 'street']:
        w, h = 640, 427 if size == '960x640' else 400
        sheet = Image.new('RGB', (w * 2, (h + 24) * 3), '#18202b')
        draw = ImageDraw.Draw(sheet)
        for row, name in enumerate(MAPS):
            for col, phase in enumerate(['before', 'after']):
                image = Image.open(OUT / size / phase / f'{name}-{view}.png').convert('RGB')
                assert image.size == tuple(map(int, size.split('x')))
                sheet.paste(image.resize((w, h), Image.Resampling.LANCZOS), (col * w, row * (h + 24) + 24))
                draw.text((col * w + 8, row * (h + 24) + 5), f'{name} / {view} / {phase} / original {size}', fill='white')
        sheet.save(OUT / f'review-{size}-{view}.jpg', quality=92)

after = json.loads((OUT / '1280x800/after/manifest.json').read_text())
overviews = [item for item in after if item['view'] == 'overview']
assert len(overviews) == 9
sheet = Image.new('RGB', (1440, 972), '#18202b')
draw = ImageDraw.Draw(sheet)
for index, item in enumerate(overviews):
    x, y = (index % 3) * 480, (index // 3) * 324
    image = Image.open(OUT / '1280x800/after' / (item['map'] + '-overview.png'))
    sheet.paste(image.resize((480, 300), Image.Resampling.LANCZOS), (x, y + 24))
    draw.text((x + 8, y + 5), item['map'], fill='white')
sheet.save(OUT / 'review-all-nine.jpg', quality=92)
(OUT / 'matched-cameras.json').write_text(json.dumps({'matched_pairs': len(report), 'all_nine_overviews': len(overviews), 'cameras': report}, indent=2) + '\n')
print(f'Matched {len(report)} exact camera/size pairs; all nine maps captured; review sheets written.')
