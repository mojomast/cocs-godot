#!/usr/bin/env python3
"""Original 'Relay / Warden' score. Offline: numpy + ffmpeg, no downloads.
--check is structural and light; default renders phase-locked native stems.
All pitched sound comes from existing CC0 VSCO/VCSL recordings, never GM.
"""
import argparse
import hashlib
import json
import math
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RATE = 32000
BPM = 80
BEAT = 60 / BPM
BARS = 16
FRAMES = round(BARS * 4 * BEAT * RATE)
LAYERS = ('strings', 'motion', 'brass', 'warden')
# Independent voice-leading. A major contains C#, resolving to D.
CHORDS = (
    (38, 53, 57, 62), (34, 53, 58, 62), (41, 53, 57, 60), (36, 52, 55, 60),
    (43, 55, 58, 62), (38, 53, 57, 62), (33, 52, 57, 61), (33, 52, 57, 61),
    (34, 53, 58, 62), (43, 55, 58, 62), (38, 53, 57, 62), (33, 52, 57, 61),
    (34, 53, 58, 62), (36, 52, 55, 60), (33, 52, 57, 61), (38, 53, 57, 62),
)
# (beat, MIDI, sounding beats). Rising fifth / falling third answered over Bb.
# Rests are real brass breaths. The melody is never transposed with the root.
MELODY = (
    ((0, 62, 1.4), (1.5, 69, .85), (2.5, 65, 1.1)),
    ((0, 65, 1.4), (1.5, 62, 2.0)),
    ((0, 60, 1.4), (1.5, 65, 1.0), (3, 69, .65)),
    ((0, 67, 2.5), (3, 64, .6)),
    ((0, 62, 1.4), (1.5, 67, .85), (2.5, 65, 1.0)),
    ((0, 65, 1.3), (1.5, 62, 2.0)),
    ((0, 61, 1.4), (1.5, 64, 1.0), (3, 69, .6)),
    ((0, 64, 2.1), (2.5, 61, .8)),
    ((0, 62, 1.4), (1.5, 65, .85), (2.5, 70, 1.1)),
    ((0, 69, .8), (1, 67, 2.4)),
    ((0, 65, 1.4), (1.5, 69, .85), (2.5, 74, 1.1)),
    ((0, 73, 2.2), (2.5, 69, .8)),
    ((0, 70, 1.4), (1.5, 65, 1.8)),
    ((0, 67, 1.4), (1.5, 64, 1.8)),
    ((0, 61, 1.4), (1.5, 64, .8), (2.5, 69, .8)),
    ((0, 65, 1.0), (1.25, 62, 2.2)),
)


def composition():
    events = []

    def note(layer, family, bar, beat, midi, beats, gain, pan=0, strong=False):
        events.append(dict(layer=layer, family=family, at=bar * 4 + beat,
                           midi=midi, beats=beats, gain=gain, pan=pan, strong=strong))

    for bar, (bass, viola, violin2, violin1) in enumerate(CHORDS):
        arch = (.78, .9, 1.0, .85)[bar // 4]
        # Actual sustained section voices; register-specific sample selection.
        for family, midi, gain, pan in (
            ('strings-pad-cello', bass + 12, .20, .25),
            ('strings-pad-viola', viola, .15, -.05),
            ('strings-pad-violin', violin2 + 12, .13, -.3),
            ('strings-pad-violin', violin1 + 12, .12, -.5),
        ):
            note('strings', family, bar, 0, midi, 4.12, gain * arch, pan)
        for beat, midi in ((0, viola + 12), (2.5, violin1 + 12)):
            note('strings', 'harp', bar, beat, midi, 1.4, .10, -.22)
        if bar < 4 or bar >= 12:
            for beat, midi, length in MELODY[bar]:
                note('strings', 'strings-pad-violin', bar, beat, midi + 12,
                     length, .18, -.36)
        # Measured eighths grouped 3+3+2, with phrase-end rests.
        ostinato = (bass, violin2, viola, bass, violin2, viola, violin2, viola)
        for i, midi in enumerate(ostinato):
            if bar % 4 == 3 and i >= 6:
                continue
            note('motion', 'low-strings-stacc-cello', bar, i / 2, midi,
                 .38, .25 if i in (0, 3, 6) else .17, .22, i in (0, 3, 6))
        note('motion', 'timpani-hit', bar, 0, bass + 12, 1.6, .27, .12)
        if bar % 2 == 0:
            note('motion', 'taiko-bassdrum', bar, 0, 36, 2, .24, .05, True)
        if bar % 4 == 3:
            note('motion', 'timpani-roll', bar, 2, 45, 1.8, .20, .12)
        for beat, midi, length in MELODY[bar]:
            note('brass', 'low-brass-fhorn', bar, beat, midi - (24 if bar in (10, 11) else 12),
                 length, .40, .18, True)
            if bar >= 8:
                note('brass', 'trumpet-pad', bar, beat, midi,
                     length, .22, -.12, True)
        note('brass', 'low-brass-trombone', bar, 0, viola, 3.25, .22, .2, True)
        note('brass', 'low-brass-tuba', bar, 0, bass, 3.35, .22, .35)
        # Warden: measured tremolo, ominous fifths, rolls into four-bar peaks.
        for i in range(16):
            note('warden', 'low-strings-stacc-violin', bar, i / 4,
                 (violin1 if i % 2 == 0 else violin2) + 12, .22,
                 .105 if i % 4 else .14, -.35, True)
        note('warden', 'low-brass-tuba', bar, 0, bass, 2.8, .23, .35, True)
        note('warden', 'brass-stacc-horn', bar, 2.5, bass + 7, .7, .19, .18, True)
        if bar % 4 == 3:
            note('warden', 'cymbal-swell', bar, 0, 60, 4, .25, -.1)
            note('warden', 'timpani-roll', bar, 1, bass + 12, 2.9, .30, .12)
        if bar % 4 == 0:
            note('warden', 'cymbal-crash', bar, 0, 60, 3.5, .21, -.1, True)
            note('warden', 'taiko-bassdrum', bar, 0, 36, 2.5, .32, .05, True)
        if bar == 15:
            note('warden', 'tubular-bells', bar, 0, 62, 3.8, .18, -.2, True)
    return events


def select(event, bank):
    choices = [s for s in bank if s['id'].startswith(event['family'] + '-')]
    if event['family'] == 'timpani-hit':
        choices = [s for s in bank if s['instrument'] == 'timpani']
    assert choices, event['family']
    def rank(s):
        return abs(s['midi'] - event['midi']) * 3 + (s['velocity'] != (2 if event['strong'] else 1))
    best = min(map(rank, choices))
    tied = sorted((s for s in choices if rank(s) == best), key=lambda s: s['id'])
    # Recorded round robins prevent identical repeated attacks. Deterministic
    # alternation changes articulation, never harmony or phrase timing.
    subdivision = 4 if event['layer'] == 'warden' else 2
    return tied[round(event['at'] * subdivision) % len(tied)]


def validate(events, bank):
    assert len(CHORDS) == len(MELODY) == BARS
    assert FRAMES == 1536000
    for index, chord in enumerate(CHORDS):
        following = CHORDS[(index + 1) % BARS]
        assert all(abs(a - b) <= 3 for a, b in zip(chord[1:], following[1:])), 'inner voices must connect smoothly'
    assert CHORDS[14][-1] == 61 and CHORDS[15][-1] == 62, 'dominant leading tone resolves to tonic'
    for bar, phrase in enumerate(MELODY):
        pcs = {n % 12 for n in CHORDS[bar]}
        for beat, pitch, duration in phrase:
            # G minor includes passing F in bar 5, A resolving to G in bar 10.
            assert pitch % 12 in pcs or (bar == 4 and pitch == 65) or (bar == 9 and beat == 0)
            assert 0 <= beat < beat + duration < 4, 'brass needs a breath'
    assert MELODY[0][:2] == ((0, 62, 1.4), (1.5, 69, .85))
    assert MELODY[10][0][1] == MELODY[0][2][1], 'develop the original motif'
    for e in events:
        s = select(e, bank)
        assert abs(s['midi'] - e['midi']) <= 12, (e, s['id'])
        assert s['license'] == 'CC0-1.0'
        assert 0 <= e['at'] < BARS * 4 and 0 < e['beats'] <= 4.2
        frame = e['at'] * BEAT * RATE
        assert frame == round(frame), 'all attacks share an exact PCM grid'
        assert 0 < e['gain'] <= .4 and abs(e['pan']) <= 1
        assert (ROOT / 'public/music' / s['file']).exists()
    return {'events': len(events), 'bars': BARS, 'bpm': BPM, 'frames': FRAMES,
            'seconds': FRAMES / RATE, 'layers': list(LAYERS)}


def render(events, bank, output):
    import numpy as np
    cache = {}
    used = {}

    def sample(e):
        s = select(e, bank)
        if s['id'] not in cache:
            path = ROOT / 'public/music' / s['file']
            data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
                                           '-f', 'f32le', '-ac', '1', '-ar', str(RATE), '-'])
            cache[s['id']] = np.frombuffer(data, dtype='<f4').copy()
            used[s['id']] = {k: s[k] for k in ('id', 'file', 'source', 'license', 'url')}
            used[s['id']]['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        raw = cache[s['id']]
        ratio = 2 ** ((e['midi'] - s['midi']) / 12)
        sustain = e['beats'] * BEAT
        looped = s.get('loopStart') is not None and s.get('loopEnd') is not None
        release = .38 if looped else .18
        size = round((sustain + release) * RATE)
        positions = np.arange(size, dtype=np.float64) * ratio
        if looped:
            lo, hi = s['loopStart'] * RATE, s['loopEnd'] * RATE
            assert 0 <= lo < hi <= len(raw)
            cross = min(.060 * RATE, (hi - lo) / 8)
            period = hi - lo - cross
            wrapped = positions >= hi - cross
            positions[wrapped] = lo + np.mod(positions[wrapped] - (hi - cross), period)
            audio = np.interp(positions, np.arange(len(raw)), raw, right=0)
            blend = wrapped & (positions < lo + cross)
            x = (positions[blend] - lo) / cross
            tail = np.interp(hi - cross + positions[blend] - lo, np.arange(len(raw)), raw)
            audio[blend] = audio[blend] * x + tail * (1 - x)
        else:
            audio = np.interp(positions, np.arange(len(raw)), raw, right=0)
        t = np.arange(size) / RATE
        attack = .12 if e['family'].startswith('strings-pad') else .035
        envelope = np.minimum(1, t / attack) * np.clip((sustain + release - t) / release, 0, 1)
        if looped:
            envelope *= .83 + .17 * np.sin(np.pi * np.minimum(t / sustain, 1))
        audio *= envelope * e['gain'] * s.get('gain', 1)
        pan = (e['pan'] + 1) * math.pi / 4
        return np.column_stack((audio * math.cos(pan), audio * math.sin(pan))).astype(np.float32)

    stems = {name: np.zeros((FRAMES, 2), dtype=np.float32) for name in LAYERS}

    def add_cyclic(dest, audio, start):
        start %= FRAMES
        n = min(len(audio), FRAMES - start)
        dest[start:start + n] += audio[:n]
        if n < len(audio):
            dest[:len(audio) - n] += audio[n:]

    for e in events:
        audio = sample(e)
        start = round(e['at'] * BEAT * RATE)
        dest = stems[e['layer']]
        add_cyclic(dest, audio, start)
        # Fixed stereo early reflections and late taps. Linear processing keeps
        # layer summation predictable; tails wrap through the 16-bar boundary.
        for delay, gain in ((.071, .10), (.113, .09), (.179, .075), (.293, .055),
                            (.431, .045), (.617, .035), (.857, .026), (1.139, .018)):
            add_cyclic(dest, audio[:, ::-1] * gain, start + round(delay * RATE))
    # Sum-of-absolute-stems bounds EVERY adaptive mix, not only an all-on mix.
    bound = max(float(np.max(sum(np.abs(s) for s in stems.values()))), 1e-9)
    scale = min(1, .70 / bound)
    output.mkdir(parents=True, exist_ok=True)
    entries = []
    for name, audio in stems.items():
        audio *= scale
        assert np.isfinite(audio).all()
        path = output / (name + '.wav')
        pcm = np.rint(np.clip(audio, -1, 1) * 32767).astype('<i2')
        with wave.open(str(path), 'wb') as wav:
            wav.setparams((2, 2, RATE, FRAMES, 'NONE', 'not compressed'))
            wav.writeframes(pcm.tobytes())
        entries.append(dict(id=name, file=path.name, frames=FRAMES,
                            peak=float(np.max(np.abs(audio))), bytes=path.stat().st_size,
                            sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    manifest = dict(schema=1, title='Relay / Warden', original_composition=True,
                    bpm=BPM, bars=BARS, sample_rate=RATE, frames=FRAMES,
                    composition_sha256=hashlib.sha256(json.dumps(events, sort_keys=True).encode()).hexdigest(),
                    max_adaptive_peak_bound=bound * scale + 4 / 32767,
                    normalization=scale, stems=entries, sources=list(used.values()))
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / 'godot/audio/music/orchestral')
    args = parser.parse_args()
    bank = json.loads((ROOT / 'public/music/manifest.json').read_text())['samples']
    events = composition()
    print(json.dumps(validate(events, bank), indent=2))
    if not args.check:
        print(json.dumps(render(events, bank, args.output), indent=2))
