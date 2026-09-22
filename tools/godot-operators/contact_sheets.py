#!/usr/bin/env python3
"""Label evidence without touching either renderer's model pixels."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[2] / 'port/native-source-operators/evidence'
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
for size, height in [(1280, 800), (1920, 1080)]:
    sheet = Image.new('RGB', (1560, 1170), '#17212b')
    draw = ImageDraw.Draw(sheet)
    for row, character in enumerate(['claude', 'grok', 'meta']):
        for view_index, view in enumerate(['front', 'side', 'back']):
            for engine_index, engine in enumerate(['source', 'native']):
                image = Image.open(OUT / f'{engine}-{character}-{view}-{size}.png').convert('RGB')
                image = image.crop((int(size*.28), int(height*.07), int(size*.72), int(height*.94)))
                image.thumbnail((260, 355), Image.Resampling.LANCZOS)
                x, y = (view_index*2+engine_index)*260, row*390
                sheet.paste(image, (x+(260-image.width)//2, y+30))
                draw.text((x+8, y+7), f'{character} / {view} / {engine}', font=FONT, fill='white')
    sheet.save(OUT / f'comparison-{size}.png')
    sheet = Image.new('RGB', (1536, 804), '#17212b')
    draw = ImageDraw.Draw(sheet)
    for row, character in enumerate(['claude', 'grok', 'meta']):
        for distance_index, distance in enumerate(['10m', '25m']):
            for engine_index, engine in enumerate(['source', 'native']):
                image = Image.open(OUT / f'{engine}-{character}-{distance}-{size}.png').convert('RGB')
                image.thumbnail((384, 240), Image.Resampling.LANCZOS)
                x, y = (distance_index*2+engine_index)*384, row*268
                sheet.paste(image, (x, y+28))
                draw.text((x+8, y+6), f'{character} / {distance} / {engine}', font=FONT, fill='white')
    sheet.save(OUT / f'distance-comparison-{size}.png')
frames = []
for frame in range(12):
    image = Image.new('RGB', (1024, 542), '#17212b')
    draw = ImageDraw.Draw(image)
    for index, engine in enumerate(['source', 'native']):
        image.paste(Image.open(OUT / f'{engine}-walk-{frame:02}.png').convert('RGB'), (index*512, 30))
        draw.text((index*512+12, 7), f'{engine}: actual CharacterRig gait / phase {frame}/12', font=FONT, fill='white')
    frames.append(image)
frames[0].save(OUT / 'walk-source-native.gif', save_all=True, append_images=frames[1:], duration=90, loop=0, optimize=True)
print('Created labeled camera/identity and animated source/native comparison sheets.')
