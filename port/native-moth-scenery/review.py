#!/usr/bin/env python3
"""Assert matched cameras/dimensions, measure changed scene pixels, make sheets.

Requires Pillow (the existing Hermes Python environment supplies it here).
No exposure, gamma, contrast or saturation manipulation is applied to images.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    args = parser.parse_args()
    out = args.evidence
    headless = json.loads((out / 'geometry.json').read_text())
    graphical = json.loads((out / 'geometry-graphical.json').read_text())
    assert headless['failures'] == graphical['failures'] == 0
    assert len(headless['maps']) == len(graphical['maps']) == 9
    assert headless['maps'] == graphical['maps'], 'source/geometry/counts differ between headless and Compatibility'
    measurements = []
    maps = ['meridian-exchange', 'ember-crucible', 'asterion-relay']
    for size in ['960x640', '1280x800']:
        directory = out / size
        width, height = map(int, size.split('x'))
        manifest = json.loads((directory / 'manifest.json').read_text())
        assert len(manifest) == 18, (size, 'actual nine-map capture set')
        rows = {(row['map'], row['view'], row['phase']): row for row in manifest}
        for row in manifest:
            image = Image.open(directory / row['file'])
            assert image.size == (width, height) == (row['width'], row['height'])
        for view in ['street', 'service']:
            sheet = Image.new('RGB', (960, 3 * (round(height * 480 / width) + 24)), '#141b22')
            draw = ImageDraw.Draw(sheet)
            for index, name in enumerate(maps):
                before = rows[(name, view, 'before')]
                after = rows[(name, view, 'after')]
                for key in ['position', 'target', 'fov', 'width', 'height', 'geometry_sha256', 'eye_height']:
                    assert before[key] == after[key], (name, size, view, key)
                assert before['eye_height'] == 1.8
                a = Image.open(directory / before['file']).convert('RGB')
                b = Image.open(directory / after['file']).convert('RGB')
                difference = ImageChops.difference(a, b)
                pixels = difference.get_flattened_data() if hasattr(difference, 'get_flattened_data') else difference.getdata()
                changed = sum(max(pixel) > 5 for pixel in pixels)
                substantial = sum(max(pixel) > 20 for pixel in pixels)
                assert changed >= 150, (name, size, view, 'scenery not visibly represented', changed)
                bbox = difference.getbbox()
                measurements.append({'map': name, 'view': view, 'size': size, 'camera_matched': True, 'pixels_delta_gt5': changed, 'pixels_delta_gt20': substantial, 'changed_fraction': round(changed / (width * height), 6), 'difference_bounds': bbox})
                if view == 'service' and (directory / (name + '-service-no-lut.png')).exists():
                    for probe, threshold in [('no-lut', 1), ('clock25', 1)]:
                        image = Image.open(directory / (name + '-service-' + probe + '.png')).convert('RGB')
                        delta = ImageChops.difference(b, image)
                        samples = delta.get_flattened_data() if hasattr(delta, 'get_flattened_data') else delta.getdata()
                        pixels = sum(max(pixel) > threshold for pixel in samples)
                        assert pixels >= 4, (name, size, probe, 'missing actual rendered contribution', pixels)
                        measurements[-1][probe + '_pixels_delta_gt1'] = pixels
                for column, image in enumerate([a, b]):
                    image.thumbnail((480, height * 480 // width), Image.Resampling.LANCZOS)
                    y = index * (round(height * 480 / width) + 24)
                    draw.text((column * 480 + 8, y + 5), name + (' / BEFORE' if column == 0 else ' / AFTER'), fill='white')
                    sheet.paste(image, (column * 480, y + 24))
            sheet.save(out / ('review-' + size + '-' + view + '.jpg'), quality=94)
        overview = [row for row in manifest if row['view'] == 'overview']
        sheet = Image.new('RGB', (960, 3 * (round(height * 480 / width) + 24)), '#141b22')
        draw = ImageDraw.Draw(sheet)
        for index, row in enumerate(overview):
            image = Image.open(directory / row['file']).convert('RGB')
            image.thumbnail((480, height * 480 // width), Image.Resampling.LANCZOS)
            x = index % 2 * 480
            y = index // 2 * (round(height * 480 / width) + 24)
            draw.text((x + 8, y + 5), row['map'] + ' / AFTER', fill='white')
            sheet.paste(image, (x, y + 24))
        sheet.save(out / ('review-' + size + '-other-six.jpg'), quality=94)
    (out / 'matched-pixels.json').write_text(json.dumps(measurements, indent=2) + '\n')
    (out / 'review-summary.json').write_text(json.dumps({'passed': True, 'maps': 9, 'identical_geometry_across_renderers': True, 'matched_camera_pairs': len(measurements), 'scene_images': 36, 'lut_and_clock_probe_images': 12 if all('no-lut_pixels_delta_gt1' in item for item in measurements if item['view'] == 'service') else 0, 'dimensions_asserted': ['960x640', '1280x800'], 'color_adjustment': 'none'}, indent=2) + '\n')
    print(json.dumps(measurements, indent=2))


if __name__ == '__main__':
    main()
