"""Read-only frozen U inputs, pinned from 243223d3 artifact-inventory.json.

COCS_BOTANICAL_U_FIXTURE_ROOT must name a worktree/repository root containing
the exact repository-relative paths below. No artifact-directory shorthand,
ambient repository fallback, search, download, or skipped missing fixture.
"""
import hashlib
import json
import os
from pathlib import Path

PINS={
 'godot/tests/new_maps/botanical_stage/artifacts/helix-conservatory/probes.json':'a61b35fb633166bd4dbed2930a61bc039c6eddc746388d7f8815a8fcba7cc41f',
 'port/new-maps/helix-conservatory/variety/revision-3/helix-conservatory.glb':'fe3a6912a1c6c1eafdb6266df6f9256d64129bc81637bced2e76c3262cd284dd',
 'port/new-maps/parallax-observatory/variety/districts-v3/parallax-observatory.glb':'d9e9109f8ea0e4cfc2da48dcc7f8ef8ee43fe5947ae8a4f8784a2f7bc7f818a7',
 'port/new-maps/vesper-viaduct/variety/urban-v2/vesper-viaduct.glb':'7aa4ce7cbd46a599e28c70ab86acf1c7ae5e12d5dea6074c5e953e073b95ddbd',
 'tools/godot-multiplayer/new-maps/botanical-stage/evidence/helix-conservatory/evaluated.json':'7a942d809d9e18dac93f8a0f00660b2fabdfc75cd66cce68286324975da2afa8',
}
PROBES='godot/tests/new_maps/botanical_stage/artifacts/helix-conservatory/probes.json'
EVALUATED='tools/godot-multiplayer/new-maps/botanical-stage/evidence/helix-conservatory/evaluated.json'

def archive_bytes(relative):
    if relative not in PINS:raise ValueError('Unpinned U fixture path: '+relative)
    configured=os.environ.get('COCS_BOTANICAL_U_FIXTURE_ROOT')
    if not configured:raise ValueError('Set COCS_BOTANICAL_U_FIXTURE_ROOT to the frozen U repository/worktree root')
    root=Path(configured).expanduser().resolve(strict=True)
    if not root.is_dir():raise ValueError('U fixture root must be a directory')
    path=(root/relative).resolve(strict=True)
    if not path.is_relative_to(root):raise ValueError('U fixture path escapes explicit root')
    data=path.read_bytes()
    if hashlib.sha256(data).hexdigest()!=PINS[relative]:raise ValueError('Frozen U fixture SHA256 mismatch: '+relative)
    return data # Hash the exact bytes returned to the parser; no second read.

def archive_json(relative):return json.loads(archive_bytes(relative))
