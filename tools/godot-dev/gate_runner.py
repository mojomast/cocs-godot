"""Bounded verification commands with durable, atomic progress evidence."""
import json
import os
import re
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


def run_gate(name, command, log_path, timeout=180, success_marker=None, allowed_error_patterns=()):
    """Run one gate. Any SCRIPT ERROR or ERROR line fails it unless the gate both
    prints its declared success marker and exits 0, and the line matches one of the
    explicitly allowed engine-teardown patterns. That keeps error detection strict
    while permitting documented engine noise, e.g. the X11 cursor textures Godot's
    GLES3 reports as leaked when a display run captures the pointer and exits.
    """
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
        else:
            errors = [line for line in output.splitlines() if 'SCRIPT ERROR:' in line or 'ERROR:' in line]
            if success_marker and success_marker in output:
                errors = [line for line in errors
                          if not any(re.search(pattern, line.strip()) for pattern in allowed_error_patterns)]
            if errors:
                reason = 'engine-error'
    Path(log_path).parent.mkdir(parents=True, exist_ok=True)
    Path(log_path).write_text(output)
    return {'gate': name, 'command': command, 'exit_code': code,
            'passed': reason is None, 'failure_reason': reason,
            'duration_seconds': round(time.monotonic() - start, 3)}, output
