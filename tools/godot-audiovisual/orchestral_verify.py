#!/usr/bin/env python3
"""Post-render integrity checks; signal measurements do NOT judge musical quality."""
import hashlib
import json
import wave
from pathlib import Path
import numpy as np
from orchestral_score import ROOT, RATE, FRAMES, LAYERS

folder = ROOT / 'godot/audio/music/orchestral'
manifest = json.loads((folder / 'manifest.json').read_text())
assert manifest['frames'] == FRAMES and manifest['sample_rate'] == RATE
assert [s['id'] for s in manifest['stems']] == list(LAYERS)
bound = np.zeros((FRAMES, 2), dtype=np.float32)
report = {'stems': [], 'purpose': 'integrity/headroom/phase, not perceptual quality'}
for entry in manifest['stems']:
    path = folder / entry['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256']
    with wave.open(str(path), 'rb') as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getnframes()) == (2, 2, RATE, FRAMES)
        pcm = np.frombuffer(wav.readframes(FRAMES), dtype='<i2').reshape(-1, 2).astype(np.float32) / 32768
    assert np.isfinite(pcm).all()
    assert np.mean(pcm * pcm) > 1e-7, 'empty or effectively silent layer'
    bound += np.abs(pcm)
    seam = float(np.max(np.abs(pcm[0] - pcm[-1])))
    assert seam < .04, 'loop boundary discontinuity needs review'
    report['stems'].append({'id': entry['id'], 'frames': FRAMES,
                            'peak': float(np.max(np.abs(pcm))), 'seam_step': seam})
assert float(np.max(bound)) <= .701, 'adaptive combinations can exceed headroom budget'
for source in manifest['sources']:
    path = ROOT / 'public/music' / source['file']
    assert source['license'] == 'CC0-1.0'
    assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256']
report['max_adaptive_peak_bound'] = float(np.max(bound))
report['pcm_bytes'] = FRAMES * 4 * 4
print(json.dumps(report, indent=2))
