#!/usr/bin/env python3
"""Original deterministic formant voices; stdlib only. No speech/model service.
Run from any directory. --check verifies committed assets without rewriting.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'godot/campaign/robot_voice_assets'
RATE = 22050
# Fundamental, vowel scale, breath/rasp, tremolo, syllable durations, vowels.
PROFILES = {
    'scrapper': (205, 1.28, .38, 43, [.085, .09, .14, .075], 'ieai'),
    'skirmisher': (157, 1.08, .10, 0, [.13, .07, .19], 'aia'),
    'sentinel': (132, .95, .025, 5, [.25, .32], 'uoi'),
    'mortar': (79, .72, .08, 2, [.20, .19, .27], 'ouu'),
    'bulwark': (66, .81, .48, 31, [.34, .12], 'ao'),
    'warden': (57, .85, .04, 7, [.28, .16, .35], 'oae'),
}
VOWELS = {'a': (730, 1090, 2440), 'e': (530, 1840, 2480),
          'i': (270, 2290, 3010), 'o': (570, 840, 2410), 'u': (300, 870, 2240)}
KINDS = ('encounter', 'attack', 'hurt', 'death')

def synth(name, kind, variant):
    base, scale, rasp, tremolo, lengths, vowels = PROFILES[name]
    rng = random.Random(f'{name}/{kind}/{variant}')
    lengths = list(lengths)
    if kind == 'hurt': lengths = [sum(lengths) * .48]
    if kind == 'death': lengths = [sum(lengths) * .85, .15]
    if variant: vowels = vowels[1:] + vowels[:1]
    data = []
    phase = 0.0
    for syllable, length in enumerate(lengths):
        if kind == 'attack': length *= .83
        length *= 1 + variant * .075
        filters = [[0., 0.] for _ in range(3)]
        count = int(RATE * length)
        for i in range(count):
            t = i / RATE
            u = i / count
            pitch = base * (1 + .12 * math.sin(u * math.pi) + variant * .035)
            pitch *= (1.16 - .36*u) if kind == 'death' else (1 + .045 * math.sin(t*31))
            phase += pitch / RATE
            # Glottal pulse and breath excite resonant vocal-tract filters.
            p = phase % 1
            source = (math.exp(-p*11) - .091) + rasp * rng.uniform(-.5, .5)
            if name == 'warden': source += .30 * math.sin(phase*math.pi) + .16*math.sin(phase*math.tau*1.007)
            formants = VOWELS[vowels[syllable % len(vowels)]]
            next_formants = VOWELS[vowels[(syllable+1) % len(vowels)]]
            value = 0.
            for k, (f, nf) in enumerate(zip(formants, next_formants)):
                freq = (f + (nf-f)*u*.32) * scale
                radius = math.exp(-math.pi*(90+k*65)/RATE)
                a = 2*radius*math.cos(math.tau*freq/RATE)
                y1, y2 = filters[k]
                y = source*(1-radius) + a*y1 - radius*radius*y2
                filters[k] = [y, y1]
                value += y * (1., .65, .28)[k]
            envelope = min(1., t/.013) * min(1., (length-t)/.035)
            envelope *= .80 + .20*math.cos(math.tau*t*tremolo)
            if name == 'skirmisher': envelope *= (1-u*.45)
            if kind == 'death': envelope *= (1-u*.8)
            data.append(math.tanh(value*2) * envelope)
        gap = .018 if name == 'scrapper' else (.09 if name == 'mortar' else .045)
        data.extend([0.] * int(RATE*gap))
    peak = max(map(abs, data))
    return [round(x / peak * .68 * 32767) for x in data]

def wav_bytes(samples):
    import io
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(struct.pack(f'<{len(samples)}h', *samples))
    return stream.getvalue()

def fingerprint(samples):
    """Normalized temporal envelope and coarse spectral energy, independent gain."""
    envelope = [0.] * 12
    for i, value in enumerate(samples):
        envelope[min(11, i*12//len(samples))] += value*value
    envelope = [x/sum(envelope) for x in envelope]
    spectrum = []
    for frequency in range(200, 4200, 200):
        coefficient = 2*math.cos(math.tau*frequency/RATE)
        power = 0.
        for fraction in (.15, .35, .55, .75):
            start = int(len(samples)*fraction)
            window = samples[start:start+882]
            s1 = s2 = 0.
            for i, value in enumerate(window):
                value *= .5-.5*math.cos(math.tau*i/max(1, len(window)-1))
                s0 = value+coefficient*s1-s2
                s2, s1 = s1, s0
            power += max(0., s1*s1+s2*s2-coefficient*s1*s2)
        spectrum.append(power)
    spectrum = [x/sum(spectrum) for x in spectrum]
    return {'envelope': envelope, 'spectrum': spectrum}

def main():
    check = argparse.ArgumentParser()
    check.add_argument('--check', action='store_true')
    args = check.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    reel, timeline, signatures, fingerprints = [], [], {}, {}
    def emit(path, payload):
        if args.check:
            assert path.read_bytes() == payload, f'Non-reproducible asset: {path}'
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
    for name in PROFILES:
        preview = []
        for kind in KINDS:
            for variant in range(2):
                samples = synth(name, kind, variant)
                if kind == 'encounter' and variant == 0:
                    fingerprints[name] = fingerprint(samples)
                assert max(map(abs, samples)) <= round(.68*32767)
                assert samples[0] == 0 and samples[-1] == 0
                payload = wav_bytes(samples)
                emit(OUT / f'{name}_{kind}_{variant}.wav', payload)
                signatures[f'{name}/{kind}/{variant}'] = hashlib.sha256(payload).hexdigest()
                timeline.append({'start': round(len(reel)/RATE, 3), 'label': f'{name} / {kind} / {variant+1}', 'duration': round(len(samples)/RATE, 3)})
                silence = [0]*int(RATE*.35)
                reel.extend(samples + silence)
                preview.extend(samples + silence)
        emit(OUT / 'audition' / f'{name}.wav', wav_bytes(preview))
    assert len(set(signatures.values())) == 48
    for index, name in enumerate(PROFILES):
        for other in list(PROFILES)[index+1:]:
            for field, threshold in (('envelope', .12), ('spectrum', .12)):
                distance = sum(abs(a-b) for a, b in zip(fingerprints[name][field], fingerprints[other][field]))
                assert distance > threshold, f'Similar {field}: {name}/{other}: {distance}'
    emit(OUT / 'audition' / 'all_robots.wav', wav_bytes(reel))
    emit(OUT / 'audition' / 'timeline.json', (json.dumps(timeline, indent=2)+'\n').encode())
    emit(OUT / 'signatures.json', (json.dumps(signatures, indent=2)+'\n').encode())
    emit(OUT / 'fingerprints.json', (json.dumps(fingerprints, indent=2)+'\n').encode())
    print('ROBOT_VOICE_ASSETS_OK: 48 deterministic peak-bounded clips, 6 previews + labelled reel')

if __name__ == '__main__': main()
