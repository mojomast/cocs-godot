"""Exercise verifier failure reports without starting an engine or game server."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class VerifierReportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="native-report-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        tools = self.root / "tools/godot-dev"
        tools.mkdir(parents=True)
        for name in ("verify.py", "gate_runner.py"):
            shutil.copyfile(Path(__file__).with_name(name), tools / name)
        contracts = self.root / "port/contracts"
        contracts.mkdir(parents=True)
        self.lock = {"source_commit": "1" * 40, "godot_version": "fixture-engine-version"}
        (contracts / "source-lock.json").write_text(json.dumps(self.lock))
        (self.root / ".gitignore").write_text("__pycache__/\n")
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.root)}
        for name in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            self.env[name] = str(self.root / name)
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Verifier Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-qm", "fixture")
        self.commit = self.git("rev-parse", "HEAD").stdout.strip()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, env=self.env,
                              capture_output=True, text=True, check=True)

    def run_verifier(self):
        result = subprocess.run([sys.executable, "tools/godot-dev/verify.py"],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        report = json.loads((self.root / "port/reports/verification.json").read_text())
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["source_commit"], self.lock["source_commit"])
        self.assertEqual(report["port_commit"], self.commit)
        self.assertEqual(report["execution"]["executed"], len(report["gates"]))
        self.assertEqual(report["execution"]["planned"], len(report["planned_gate_names"]))
        self.assertEqual(report["execution"]["unrun"],
                         len(report["unrun_gate_names"]))
        executed = {item["gate"] for item in report["gates"]}
        self.assertFalse(executed.intersection(report["unrun_gate_names"]))
        self.assertEqual(executed.union(report["unrun_gate_names"]),
                         set(report["planned_gate_names"]))
        return report

    def fake_version_probe(self, version):
        # This fixture only answers --version; the verifier never reaches engine work.
        binary = self.root / "version-probe"
        binary.write_text(f"#!{sys.executable}\nprint({version!r})\n")
        binary.chmod(0o755)
        self.env["GODOT_BIN"] = str(binary)

    def test_missing_engine_records_every_gate_as_unrun(self):
        report = self.run_verifier()
        self.assertFalse(report["port_worktree_dirty"])
        self.assertEqual(report["gates"], [])
        self.assertEqual(report["source_derivative"], {"selection": "none"})
        self.assertEqual(report["unrun_gate_names"], report["planned_gate_names"])

    def test_invalid_explicit_derivative_is_a_preflight_failure(self):
        path = self.root / "invalid-derivative.json"
        path.write_text("{invalid")
        self.env["COCS_SOURCE_DERIVATIVE"] = str(path)
        report = self.run_verifier()
        self.assertIn("Invalid explicit COCS_SOURCE_DERIVATIVE", report["failure_reason"])
        self.assertEqual(report["execution"]["executed"], 0)

    def test_wrong_engine_version_does_not_claim_remaining_gates(self):
        self.fake_version_probe("wrong-version")
        report = self.run_verifier()
        self.assertEqual(report["execution"]["executed"], 1)
        self.assertEqual(report["gates"][0]["failure_reason"], "version-mismatch")
        self.assertFalse(report["gates"][0]["passed"])

    def test_first_gate_failure_preserves_explicit_identity_and_unrun_tail(self):
        self.fake_version_probe(self.lock["godot_version"])
        path = self.root / "derivative.json"
        path.write_text(json.dumps({"source_commit": self.lock["source_commit"],
                                    "derivative_commit": "2" * 40}))
        self.env["COCS_SOURCE_DERIVATIVE"] = str(path)
        # test_gate_runner.py is deliberately absent from the isolated fixture.
        report = self.run_verifier()
        self.assertEqual(report["execution"]["executed"], 2)
        self.assertTrue(report["gates"][0]["passed"])
        self.assertFalse(report["gates"][1]["passed"])
        self.assertEqual(report["gates"][1]["gate"], "gate-runner-tests")
        self.assertEqual(report["source_derivative"]["selection"], "explicit")
        self.assertEqual(report["source_derivative"]["derivative_commit"], "2" * 40)
        self.assertEqual(report["source_derivative"]["sha256"],
                         hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    unittest.main()
