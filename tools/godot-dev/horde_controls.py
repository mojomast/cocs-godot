"""Generate actual-source input vectors inside the bounded native job scope."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix='horde-controls-') as directory:
    vectors = str(Path(directory) / 'vectors.json')
    subprocess.run(['node', 'port/native-horde/input-oracle.mjs', vectors], check=True, timeout=30)
    result = subprocess.run([os.environ['GODOT_BIN'], '--headless', '--path', 'godot',
                             '--script', 'res://tests/horde/controls_test.gd', '--',
                             '--vectors=' + vectors], timeout=45)
    sys.exit(result.returncode)
