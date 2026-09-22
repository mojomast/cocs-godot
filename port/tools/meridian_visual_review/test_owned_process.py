#!/usr/bin/env python3
"""Real Linux/Xvfb descendant-timeout regression and bounded native smoke."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from owned_process import group_members, private_environment, run_owned

GODOT = "/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"
RECORDS = []


class OwnershipTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="meridian-cleanup-test-", dir="/tmp/opencode")
        self.addCleanup(self.temporary.cleanup)
        self.private = Path(self.temporary.name)
        self.env = private_environment(self.private / "environment")

    def assert_gone(self, record):
        self.assertTrue(record["cleanup_complete"], record)
        self.assertEqual(record["remaining_pids"], [])
        self.assertEqual(group_members(record["pgid"]), [])
        for pid in record["observed_pids"]:
            self.assertFalse(Path(f"/proc/{pid}").exists(), f"Owned PID {pid} still exists (including zombie)")

    def test_environment(self):
        keys = ["DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET",
                "DBUS_SESSION_BUS_ADDRESS", "SESSION_MANAGER"]
        env = private_environment(self.private / "environment", {key: "shared" for key in keys})
        self.assertTrue(all(key not in env for key in keys))
        for key in ["HOME", "TMPDIR", "TMP", "TEMP", "XDG_RUNTIME_DIR", "XDG_DATA_HOME",
                    "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            self.assertTrue(Path(env[key]).is_relative_to(self.private))
            self.assertEqual(Path(env[key]).stat().st_mode & 0o777, 0o700)

    def test_timeout_kills_and_reaps_real_xvfb_descendants(self):
        fixture = self.private / "descendants.py"
        fixture.write_text('''import os, signal, subprocess, sys, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
depth = int(sys.argv[1])
print("FIXTURE_PID=" + str(os.getpid()), flush=True)
if depth:
    subprocess.Popen([sys.executable, __file__, str(depth - 1)])
while True:
    time.sleep(1)
''')
        # A separately owned process proves cleanup does not target unrelated work.
        sentinel = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"], start_new_session=True)
        try:
            record = run_owned(["xvfb-run", "-a", sys.executable, str(fixture), "2"],
                               env=self.env, cwd=self.private, timeout=1.5, term_grace=0.2, kill_grace=3)
            RECORDS.append({"test": self._testMethodName, **record})
            self.assertTrue(record["timed_out"])
            self.assertIn("SIGKILL", record["signals"])
            fixture_pids = [int(line.split("=", 1)[1]) for line in record["stdout"].splitlines()
                            if line.startswith("FIXTURE_PID=")]
            self.assertEqual(len(fixture_pids), 3, record)
            self.assertTrue(set(fixture_pids).issubset(record["observed_pids"]))
            self.assert_gone(record)
            self.assertLess(record["duration_seconds"], 6)
            self.assertIsNone(sentinel.poll(), "Cleanup touched the unrelated session")
        finally:
            sentinel.terminate()
            sentinel.wait(timeout=3)

    def test_normal_leader_exit_cleans_orphan(self):
        record = run_owned([sys.executable, "-c",
                            "import subprocess,sys; p=subprocess.Popen([sys.executable,'-c',"
                            "'import time; time.sleep(30)']); print(p.pid,flush=True)"],
                           env=self.env, cwd=self.private, timeout=3, term_grace=0.2)
        RECORDS.append({"test": self._testMethodName, **record})
        self.assertFalse(record["timed_out"])
        self.assertEqual(record["returncode"], 0)
        self.assertIn(int(record["stdout"].strip()), record["observed_pids"])
        self.assert_gone(record)

    def test_representative_private_native_command(self):
        project = self.private / "project"
        project.mkdir()
        (project / "project.godot").write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        (project / "bounded.gd").write_text('extends SceneTree\nfunc _initialize() -> void:\n\tprint("BOUNDED_NATIVE_OK")\n\tquit(0)\n')
        record = run_owned(["xvfb-run", "-a", GODOT, "--audio-driver", "Dummy", "--path", str(project),
                            "--script", "res://bounded.gd"], env=self.env, cwd=self.private, timeout=20)
        RECORDS.append({"test": self._testMethodName, **record})
        self.assertFalse(record["timed_out"])
        self.assertEqual(record["returncode"], 0, record)
        self.assertIn("BOUNDED_NATIVE_OK", record["stdout"])
        self.assertNotIn("ERROR:", record["stdout"] + record["stderr"])
        self.assert_gone(record)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if args.evidence.exists():
        raise SystemExit("Refusing to replace test evidence")
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(OwnershipTests))
    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    args.evidence.write_text(json.dumps({"passed": result.wasSuccessful(), "tests_run": result.testsRun,
                                        "failures": result.failures, "errors": result.errors,
                                        "commands": RECORDS}, indent=2, default=str) + "\n")
    sys.exit(0 if result.wasSuccessful() else 1)
