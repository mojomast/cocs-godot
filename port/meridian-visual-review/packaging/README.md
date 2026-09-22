# Lossless native inventory packaging

This separate packaging change replaces only these three large, repeated JSON
inventories with gzip files:

- `../causal-run-2/baseline.json.gz`
- `../causal-run-2/source-cull-only.json.gz`
- `../causal-run-2/camera-inside.json.gz`

The original bytes remain in commit
`adb1a3bdde40494ede3d1bc5b4981e8cc612ef6f` and are reproduced exactly by gzip
decompression. `provenance.json` records original and archive paths, byte counts,
SHA256 hashes, source commit, and compression settings/tool versions. The three
files shrink from **366,898 bytes / 24,954 lines** to **40,623 bytes** (88.9%
smaller). Screenshots, logs, failed run, historical run metadata and original
analysis are unchanged. The cleanup follow-up is the preceding separate commit.

## Analyzer support and executed checks

`port/tools/meridian_visual_review/analyze.py` now transparently reads an existing
`.json` inventory, or its `.json.gz` counterpart when unpacked JSON is absent.
Fresh graphical runs still emit JSON. Both storage forms were executed against
the original GLB and screenshot and produced byte-identical analysis output:

```sh
python3 port/tools/meridian_visual_review/analyze.py \
  port/meridian-visual-review/causal-run-2 \
  --glb godot/content/probes/meridian-exchange/world.glb \
  --original-image port/reports/meridian-glb.png \
  > /tmp/opencode/meridian-analysis-gzip.json
cmp /tmp/opencode/meridian-analysis-gzip.json \
  /tmp/opencode/meridian-analysis-plain.json
cmp /tmp/opencode/meridian-analysis-gzip.json \
  port/meridian-visual-review/analysis.json
```

All commands exited **0**. The `plain.json` output was produced with the same
analyzer command before packaging. Separate verification compared every original
evidence file to `git show adb1a3b:<path>`, transparently decompressing these three
inventories, and checked archive and decompressed hashes. Results and exact
analyzer argv are recorded in `verification.json`. This is packaging validation,
not a new graphical acceptance run.

## Verify and extract without modifying historical reports

Run from the repository root. This checks both hashes and extracts original JSON
bytes into a fresh private directory, refusing to overwrite existing files:

```sh
python3 - <<'PY'
import gzip, hashlib, json
from pathlib import Path
root = Path('port/meridian-visual-review/packaging')
report = json.loads((root / 'provenance.json').read_text())
out = Path('/tmp/opencode/meridian-unpacked-inventories')
out.mkdir(exist_ok=False)
for entry in report['files']:
    packed = Path(entry['archive_path']).read_bytes()
    assert hashlib.sha256(packed).hexdigest() == entry['archive_sha256']
    raw = gzip.decompress(packed)
    assert len(raw) == entry['original_bytes']
    assert hashlib.sha256(raw).hexdigest() == entry['original_sha256']
    (out / Path(entry['original_path']).name).write_bytes(raw)
print('Verified and extracted', len(report['files']), 'original inventories')
PY
```

To reproduce archive creation, use
`gzip.compress(original_bytes, compresslevel=9, mtime=0)` with the Python/zlib
versions in `provenance.json`. Exact compressed hashes may depend on the
compression implementation; uncompressed SHA256 is the evidence identity.

The original top-level `../SHA256SUMS` and `causal-run-2/run.json` intentionally
retain historical original-file hashes and the old tool hashes. They are not a
claim that the current tools or compressed bytes have those old hashes.
`packaging/SHA256SUMS` covers the archives, updated analyzer and packaging records;
`cleanup-followup/SHA256SUMS` independently covers the cleanup implementation.
