"""Lossless PNG pixel comparison for paired staged scenery views (stdlib only)."""
import json
import struct
import sys
import zlib
from pathlib import Path

def pixels(path):
    data = path.read_bytes()
    offset, chunks = 8, []
    while offset < len(data):
        size = struct.unpack_from('>I', data, offset)[0]
        kind, block = data[offset+4:offset+8], data[offset+8:offset+8+size]
        offset += size + 12
        if kind == b'IHDR':
            width, height, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', block)
            assert depth == 8 and color in (2, 6) and interlace == 0
        if kind == b'IDAT': chunks.append(block)
    bpp = 3 if color == 2 else 4
    stride = width*bpp
    raw = zlib.decompress(b''.join(chunks))
    previous = bytearray(stride)
    rows = []
    for y in range(height):
        kind = raw[y*(stride+1)]
        row = bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
        for i in range(stride):
            left = row[i-bpp] if i >= bpp else 0
            up = previous[i]
            corner = previous[i-bpp] if i >= bpp else 0
            estimate = left+up-corner
            distances = [abs(estimate-left),abs(estimate-up),abs(estimate-corner)]
            predictor = [left,up,corner][distances.index(min(distances))]
            row[i] = (row[i] + [0,left,up,(left+up)//2,predictor][kind]) % 256
        rows.append(row)
        previous = row
    return width, height, bpp, rows

root = Path(sys.argv[1])
report = []
for before in sorted(root.glob('**/*-before.png')):
    after = before.with_name(before.name.replace('-before.png','-after.png'))
    w,h,bpp,a = pixels(before)
    ww,hh,bb,b = pixels(after)
    assert (w,h,bpp)==(ww,hh,bb)
    changed, maximum = 0, 0
    for y in range(h):
        for x in range(w):
            delta=max(abs(a[y][x*bpp+k]-b[y][x*bpp+k]) for k in range(3))
            maximum=max(maximum,delta)
            if delta>2: changed+=1
    report.append({'before':str(before),'after':str(after),'changedPixelsOver2':changed,'pixelCount':w*h,'maxChannelDelta':maximum})
print(json.dumps(report,indent=2))
