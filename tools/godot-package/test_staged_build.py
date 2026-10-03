"""Exercise real builder staging/filter functions with tiny source fixtures only."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("package_build", Path(__file__).with_name("build.py"))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class StagedBuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.policy = json.loads(subprocess.check_output(["node", "tools/godot-package/staged_resources.mjs", ".", "HEAD"], cwd=build.ROOT))

    def test_actual_native_copy_omits_all_candidate_resources(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
            root, project = Path(tmp) / "source", Path(tmp) / "project"
            for p in [*self.policy["nativeFiles"], *self.policy["files"]]:
                f = root / p
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_bytes(b"tiny fixture")
            build.stage_native_project(root, project, self.policy)
            actual = sorted(p.relative_to(project).as_posix() for p in project.rglob("*") if p.is_file())
            self.assertEqual(actual, sorted(p.removeprefix("godot/") for p in self.policy["nativeFiles"]))
            for p in self.policy["excludePaths"]:
                self.assertFalse((project / p).exists())

    def test_real_all_resources_preset_gets_exact_exclusions(self):
        # Obtain the actual builder's literal preset, rather than a parallel
        # fixture list. No main(), toolchain acquisition, import or export runs.
        import ast
        tree = ast.parse(Path(build.__file__).read_text())
        preset = next(n.value.value for n in ast.walk(tree) if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "preset" for t in n.targets) and isinstance(n.value, ast.Constant))
        self.assertIn('export_filter="all_resources"', preset)
        result = build.exclude_staged_resources(preset, self.policy)
        excluded = next(line for line in result.splitlines() if line.startswith("exclude_filter=")).split('"')[1].split(",")
        self.assertTrue(set(self.policy["excludePaths"]).issubset(excluded))
        self.assertIn("tests/*", excluded)
        self.assertNotIn("multiplayer_worlds/art/worlds/gravemill-foundry.glb", excluded)

    def test_raw_json_import_and_copy_list_bypass_reject(self):
        for p in self.policy["files"]:
            with self.assertRaisesRegex(RuntimeError, "Staged resource"):
                build.reject_staged_inputs([p], self.policy)
        forged = {**self.policy, "nativeFiles": [next(iter(self.policy["files"]))]}
        with self.assertRaisesRegex(RuntimeError, "Staged resource"):
            build.stage_native_project(Path("unused"), Path("unused"), forged)


if __name__ == "__main__":
    unittest.main()
