"""Explicit-X source integration check. No engines; removes only its own scratch copy."""
import contextlib
import io
import json
import shutil
import uuid
from prepare_native import setup,validate_prepared,pin_import

def main():
    attempt='binding-test-'+uuid.uuid4().hex;dest=None
    try:
        with contextlib.redirect_stdout(io.StringIO()):dest=setup(attempt)
        config=validate_prepared(dest)
        assert config['variants']['candidate']['triangles']==64311
        assert config['variants']['accepted']['triangles']==54804
        assert sum(len(g['trials']) for g in config['groups'].values())==60
        assert not list(dest.glob('*journey.json'))
        try:setup(attempt)
        except FileExistsError:pass
        else:raise AssertionError('Attempt overwrite accepted')
        try:pin_import(attempt)
        except FileNotFoundError:pass
        else:raise AssertionError('Unimported fixture accepted')
        # Mutate only this test's new copies; original X bytes remain read-only.
        candidate=dest/'candidate.glb';original=candidate.read_bytes()
        try:
            candidate.unlink()
            try:validate_prepared(dest)
            except FileNotFoundError:pass
            else:raise AssertionError('Missing candidate accepted')
            candidate.write_bytes((dest/'accepted.glb').read_bytes())
            manifest=dest/'source.json';old=manifest.read_bytes();changed=json.loads(old)
            changed['variants']['candidate']['artSha256']=changed['variants']['accepted']['artSha256']
            from fixture_inputs import sha
            changed['files'][changed['variants']['candidate']['artPath']]=sha(candidate.read_bytes())
            manifest.write_text(json.dumps(changed))
            try:
                try:validate_prepared(dest)
                except ValueError:pass
                else:raise AssertionError('Accepted substitution plus edited manifest accepted')
            finally:manifest.write_bytes(old)
            candidate.write_bytes(original[:-1]+bytes([original[-1]^1]))
            try:validate_prepared(dest)
            except ValueError:pass
            else:raise AssertionError('Tampered art accepted')
        finally:candidate.write_bytes(original)
        validate_prepared(dest)
        print('Actual accepted/X pairs, both full GLB inventories, 60 source cases, immutable attempt, missing import/art, tamper and accepted fallback checks PASS; native unparsed')
        return {v:config['variants'][v] for v in ['accepted','candidate']}
    finally:
        if dest is not None:shutil.rmtree(dest)
if __name__=='__main__':main()
