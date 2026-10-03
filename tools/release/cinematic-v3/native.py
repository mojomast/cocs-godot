"""Thin cinematic adapter: existing Xvfb TCP helper and bounded subreaper owner."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/godot-dev'))
from xvfb_run import start_server
from finish_runner import run_bounded, descendants


def display_child(command):
    # Explicit TCP is the K-proven workaround; do not try a broken Unix listener,
    # allocate a guessed display number, or borrow another session's display.
    server, display, env = start_server(False)
    if server is None:
        raise RuntimeError('Owned TCP X11 unavailable: ' + str(display))
    child = None
    def interrupted(signum, _frame):
        raise InterruptedError('signal ' + str(signum))
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, interrupted)
    try:
        print('CINEMATIC_DISPLAY ' + json.dumps({'transport': 'tcp', 'display': display,
              'pid': server.pid, 'argv': server.args}), flush=True)
        child = subprocess.Popen(command, env=env)
        return child.wait()
    finally:
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, signal.SIG_IGN)
        for process in (child, server):
            if process is None:
                continue
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if args and args[0] == '--display-child':
        return display_child(args[1:])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--timeout', type=float, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    options = parser.parse_args(args)
    command = options.command[1:] if options.command[:1] == ['--'] else options.command
    if not command or not 0 < options.timeout <= 28800:
        parser.error('Bounded native command required')
    log = options.report.with_suffix('.native.log')
    result = run_bounded([sys.executable, '-B', str(Path(__file__).resolve()),
                          '--display-child', *command], ROOT,
                         {**os.environ, 'LP_NUM_THREADS': '1'}, log, options.timeout)
    audits = []
    for index in range(3):
        audits.append({'at': datetime.now(timezone.utc).isoformat(),
                       'remaining': sorted(descendants())})
        if index < 2:
            time.sleep(.1)
    result['zero_audits'] = audits
    if any(a['remaining'] for a in audits):
        result.update(status='failed', failure_reason='nonempty-post-exit-audit')
    with options.report.open('x') as stream:
        json.dump(result, stream, indent=2)
    print(log.read_text(), end='', flush=True)
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
