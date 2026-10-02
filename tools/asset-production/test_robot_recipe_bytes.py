"""Execute only the builder's serialization/archive statements, never bpy."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RobotRecipeBytes(unittest.TestCase):
    def test_build_archive_is_exact_declared_hash_input(self):
        source = ROOT/'tools/godot-robots/build.py'
        tree = ast.parse(source.read_text())
        main = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'main')
        spec = importlib.util.spec_from_file_location('robot_recipe', ROOT/'tools/godot-robots/recipe.py')
        recipe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(recipe)
        # Extract the actual production bytes, mkdir and write block. Do not
        # import the Blender builder or execute its asset loop/app references.
        start = next(i for i, n in enumerate(main.body) if isinstance(n, ast.Assign) and ast.unparse(n.targets[0]) == 'recipe_bytes')
        end = next(i for i, n in enumerate(main.body) if isinstance(n, ast.Assign) and ast.unparse(n.targets[0]) == 'receipt')
        block = ast.Module(body=main.body[start:end], type_ignores=[])
        receipt = main.body[end].value
        expression = next(v for k, v in zip(receipt.keys, receipt.values) if ast.literal_eval(k) == 'recipeSHA256')
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as directory:
            calls = []
            def manifest():
                calls.append(True)
                return recipe.manifest()
            env = {'HERE': Path(directory), 'json': json, 'manifest': manifest, 'hashlib': hashlib}
            exec(compile(block, str(source), 'exec'), env)
            digest = eval(compile(ast.Expression(expression), str(source), 'eval'), env)
            actual = (Path(directory)/'generated/recipe.json').read_bytes()
            self.assertEqual(actual, json.dumps(recipe.manifest(), sort_keys=True).encode('utf-8'))
            self.assertFalse(actual.endswith(b'\n'))
            self.assertEqual(digest, hashlib.sha256(actual).hexdigest())
            self.assertEqual(len(calls), 1)


if __name__ == '__main__': unittest.main()
