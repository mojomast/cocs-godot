"""Serial-grant Blender reopen check for the portable coastal editable master.

Run only after a native build, under its owner's Blender slot:
blender -b -t 1 --python-exit-code 1 --python tools/map-variety-support/verify_master.py -- --blend <revision2.blend> --report <material-report.json>

All file-backed image datablocks must be packed after reopening; absolute
source/converted paths are never required to load or render the saved master.
"""
import argparse
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_entry import packed_image_count


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blend', type=pathlib.Path, required=True)
    parser.add_argument('--report', type=pathlib.Path, required=True)
    args = parser.parse_args(argv)
    report = json.loads(args.report.read_text())
    master_bytes = args.blend.read_bytes()
    if (len(master_bytes) != report['masterBytes'] or
            hashlib.sha256(master_bytes).hexdigest() != report['masterSha256']):
        raise ValueError('Reopen master bytes differ from material report')
    import bpy
    bpy.ops.wm.open_mainfile(filepath=str(args.blend.resolve()))
    packed = packed_image_count(bpy.data.images)
    if packed != report['packedImages']:
        raise ValueError('Reopened master image inventory changed')
    print(json.dumps({'status': 'packed-master-reopened', 'masterSha256': report['masterSha256'],
                      'packedImages': packed}))


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []))
