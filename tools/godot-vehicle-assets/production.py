"""Vehicle-only additional commands, reusing the shared owned-process executor.

No plan/receipt/helper edits. Every execution takes the same nonwaiting lock.
"""
import argparse
import datetime
import fcntl
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('asset_runner', ROOT / 'tools/asset-production/run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['first-build', 'journey', 'parse', 'inspection', 'package-receipt'])
    parser.add_argument('--receipt')
    parser.add_argument('--granted', action='store_true')
    parser.add_argument('--compact', action='store_true')
    parser.add_argument('--kind', choices=['all', 'puma', 'titan', 'scout'], default='all')
    parser.add_argument('--evidence-root', required=True)
    args = parser.parse_args()
    if not args.granted:
        raise ValueError('Explicit grant E and --granted required')
    plan = runner.load_plan()
    output = Path(args.evidence_root) / datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    output.mkdir(parents=True)
    commands = {
        'first-build': (['{blender}', '-b', '-t', '1', '--python', 'tools/godot-vehicle-assets/build.py', '--', '{root}', '--kind=puma', '--lod=0'], 180),
        'parse': (['{godot}', '--headless', '--path', 'godot', '--check-only', '--script', 'res://tests/vehicle_assets/journey.gd'], 60),
        'journey': (['node', 'tools/godot-vehicle-assets/journey.mjs', '--granted', '--kind='+args.kind, '--output='+str(output/'connected')] + (['--compact'] if args.compact else []), 1200),
        'inspection': (['python3', 'tools/godot-dev/xvfb_run.py', '{godot}', '--path', 'godot', '--audio-driver', 'Dummy', '--script', 'res://tests/vehicle_assets/inspection.gd', '--', '--evidence='+str(output)], 180),
    }
    if args.stage == 'package-receipt':
        if not args.receipt:
            raise ValueError('--receipt must name the current real generic receipt')
        hooks = ['godot/vehicle_assets/attachment.gd', 'godot/vehicles/puma.gd', 'godot/vehicles/renderer.gd', 'godot/combined_arms/chassis.gd', 'godot/combined_arms/fleet.gd', 'godot/combined_arms/demo.gd']
        commands[args.stage] = (['node', 'tools/asset-production/package-receipt.mjs', 'vehicles', args.receipt] + ['--runtime-hook='+p for p in hooks], 60)
    argv, timeout = commands[args.stage]
    with open('/tmp/opencode/cocs-finish-acceptance.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        runner.execute({'id': args.stage, 'argv': argv, 'timeoutSeconds': timeout}, plan, output)
    print('VEHICLE_OWNED_STAGE', output)


if __name__ == '__main__':
    main()
