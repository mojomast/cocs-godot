"""Compose existing granted native captures; never launches engines or renderers."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("native", type=Path)
args = parser.parse_args()
manifest = json.loads((args.native / "manifest.json").read_text())
cases = ["normal", "projectile", "grapple", "release", "super"]
operators = sorted({c["operator"] for c in manifest["cases"]})
for operator in operators:
    sheet = Image.new("RGB", (1600, 840), "#121820")
    draw = ImageDraw.Draw(sheet)
    for row, (compact, reduced) in enumerate([(False, False), (True, False), (False, True), (True, True)]):
        for col, case in enumerate(cases):
            matches = [c for c in manifest["cases"] if c["operator"] == operator and c.get("case") == case
                       and c.get("compact") == compact and c.get("reduced") == reduced]
            label = f"{operator} {case} {'compact' if compact else 'wide'} {'reduced' if reduced else 'full'}"
            if matches:
                image = Image.open(args.native / matches[0]["file"]).convert("RGB")
                image.thumbnail((320, 180))
                sheet.paste(image, (col * 320, row * 210 + 24))
            else:
                label += " UNRUN"
            draw.text((col * 320 + 4, row * 210 + 4), label, fill="white")
    sheet.save(args.native / f"{operator}-contact-sheet.png")
