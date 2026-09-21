"""Bounded verification commands with durable, atomic progress evidence."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def save_report(path, report):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(report, indent=2) + '\n')
    temporary.replace(path)


def run_gate(name, command, log_path, timeout=180):
    start = time.monotonic()
    reason = None
    output = ''
    code = None
    try:
        process = subprocess.Popen(command, text=True, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            output, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            reason = 'timeout'
            # Launchers may own a server and native children: kill the group.
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
        code = process.returncode
    except OSError as error:
        reason = 'launch-error'
        output = str(error) + '\n'
    if reason is None:
        if code != 0:
            reason = 'nonzero-exit'
        elif 'SCRIPT ERROR:' in output or 'ERROR:' in output:
            reason = 'engine-error'
    Path(log_path).parent.mkdir(parents=True, exist_ok=True)
    Path(log_path).write_text(output)
    return {'gate': name, 'command': command, 'exit_code': code,
            'passed': reason is None, 'failure_reason': reason,
            'duration_seconds': round(time.monotonic() - start, 3)}, output
