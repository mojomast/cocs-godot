#!/usr/bin/env python3
"""Bounded, reproducible FFmpeg edit. Default writes a command plan, never encodes.

Full execution requires --execute --slot-granted. Keep evidence outside checkout.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name('trailer.json')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--stems', type=Path, required=True)
    p.add_argument('--sfx', type=Path, help='JSON cues: [{path, at, gainDB}], actual game SFX only')
    p.add_argument('--font', type=Path, default=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))
    p.add_argument('--execute', action='store_true')
    p.add_argument('--slot-granted', action='store_true')
    p.add_argument('--reuse-picture', action='store_true', help='Reuse already-reviewed picture intermediates for audio-only remaster')
    p.add_argument('--name', default='quiet-relay-trailer', help='Output basename, without extension')
    args = p.parse_args()
    if not args.name or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_' for c in args.name):
        p.error('--name must be an alphanumeric basename')
    if args.execute and not args.slot_granted:
        p.error('Encoding requires exclusive heavy-slot grant')
    out = args.evidence.resolve()
    if out == ROOT or ROOT in out.parents:
        p.error('Evidence must be outside checkout')
    out.mkdir(parents=True, exist_ok=True)
    work = out / 'edit'
    work.mkdir(exist_ok=True)
    m = json.loads(MANIFEST.read_text())
    if args.execute:
        for path in [args.font] + [args.stems / (n + '.wav') for n in ('strings', 'motion', 'brass', 'warden')]:
            if not path.is_file():
                raise FileNotFoundError(path)
    fps, total = m['fps'], sum(s['seconds'] for s in m['shots'])
    assert fps == 24 and total * fps <= 1440
    assert all(s['seconds'] % m['barSeconds'] == 0 for s in m['shots'])
    commands, clips, clean, timeline = [], [], [], []
    t = 0

    def run(arguments, log=None):
        arguments = list(map(str, arguments))
        target = Path(arguments[-1])
        if args.reuse_picture and target.parent == work and target.suffix == '.mp4' and target.is_file():
            commands.append('# Reusing reviewed picture: ' + str(target))
            return ''
        cmd = ['ffmpeg', '-hide_banner', '-nostdin', '-y', '-threads', '2',
               '-filter_threads', '1', '-filter_complex_threads', '1'] + arguments[:-1] + ['-threads', '2', arguments[-1]]
        commands.append(shlex.join(cmd))
        if args.execute:
            result = subprocess.run(cmd, capture_output=True, text=True)
            (work / f'ffmpeg-{len(commands):03}.log').write_text(result.stderr)
            (out / 'edit-commands-in-progress.sh').write_text('\n'.join(commands) + '\n')
            if log:
                log.write_text(result.stderr)
            result.check_returncode()
            return result.stderr
        return ''

    def escaped(path):
        # FFmpeg filter value quoting (shell quoting is handled independently).
        return str(path).replace('\\', '\\\\').replace(':', '\\:').replace("'", "'\\''")

    for shot in m['shots']:
        directory = out / shot['id']
        raw = work / (shot['id'] + '-clean.mp4')
        decorated = work / (shot['id'] + '-trailer.mp4')
        if args.execute:
            frames = sorted((directory / 'frames').glob('*.png'))
            expected = shot['seconds'] * fps
            if len(frames) != expected or any(f.name != f'{i:06}.png' for i, f in enumerate(frames)):
                raise RuntimeError(f'{shot["id"]}: expected contiguous {expected} frames, got {len(frames)}')
        run(['-framerate', fps, '-start_number', 0, '-i', directory / 'frames/%06d.png',
             '-frames:v', shot['seconds'] * fps, '-an', '-c:v', 'libx264', '-preset', 'fast',
             '-crf', 16, '-pix_fmt', 'yuv420p', raw])
        filters = ['drawbox=x=0:y=0:w=iw:h=22:color=black:t=fill',
                   'drawbox=x=0:y=ih-22:w=iw:h=22:color=black:t=fill']
        texts = shot['text'].split('|') if shot['text'] else []
        for i, text in enumerate(texts):
            textfile = work / f'{shot["id"]}-{i}.txt'
            textfile.write_text(text)
            title = shot['id'] == 'title'
            y, size = (195 + i * 56, 42 if i == 0 else 19) if title else (42, 22)
            filters.append(f"drawtext=fontfile='{escaped(args.font)}':textfile='{escaped(textfile)}':"
                           f'fontsize={size}:fontcolor=white:shadowcolor=black@0.8:shadowx=2:shadowy=2:'
                           f'x=(w-tw)/2:y={y}:alpha=min(1\\,t*3)')
        credit = work / 'credit.txt'
        credit.write_text(m['credit'])
        filters.append(f"drawtext=fontfile='{escaped(args.font)}':textfile='{escaped(credit)}':"
                       'fontsize=12:fontcolor=white@0.8:x=18:y=h-17')
        # Brief dip at story/act boundaries, not around combat or at the loop seam.
        if shot['id'] in ('mara', 'robots', 'title'):
            filters.append('fade=t=in:st=0:d=0.125')
        run(['-i', raw, '-vf', ','.join(filters), '-an', '-c:v', 'libx264', '-preset', 'fast',
             '-crf', 18, '-pix_fmt', 'yuv420p', decorated])
        clips.append(decorated)
        if shot['menu']:
            clean.append((raw, shot['seconds']))
        timeline.append(dict(shot=shot['id'], start=t, end=t + shot['seconds'],
                             sourceIn=0, sourceOut=shot['seconds'], text=texts,
                             transition='dip 3 frames' if shot['id'] in ('mara', 'robots', 'title') else 'bar cut'))
        t += shot['seconds']

    concat = work / 'trailer-concat.txt'
    concat.write_text(''.join("file '" + str(c).replace("'", "'\\''") + "'\n" for c in clips))
    silent = work / 'trailer-silent.mp4'
    run(['-f', 'concat', '-safe', 0, '-i', concat, '-c', 'copy', silent])

    # Four phase-locked stems, gain changes on bar boundaries; no music time stretch.
    inputs, afilters = [], []
    gains = ['0.70', '0.08+0.36*clip((t-18)/0.75,0,1)',
             '0.08+0.30*clip((t-24)/0.75,0,1)', '0.42*clip((t-36)/0.75,0,1)']
    for i, name in enumerate(['strings', 'motion', 'brass', 'warden']):
        inputs += ['-i', args.stems / (name + '.wav')]
        afilters.append(f"[{i}:a]atrim=duration={total},asetpts=PTS-STARTPTS,"
                        f"volume='{gains[i]}':eval=frame[a{i}]")
    cues = json.loads(args.sfx.read_text()) if args.sfx else []
    for i, cue in enumerate(cues, 4):
        path = Path(cue['path']).resolve()
        if ROOT not in path.parents and (out / 'sfx') not in path.parents:
            raise ValueError('SFX must be game assets or production-synth exports in evidence/sfx')
        if not 0 <= cue['at'] < total or cue['gainDB'] > -6:
            raise ValueError('SFX cues need an in-range time and gain <= -6 dB')
        inputs += ['-i', path]
        afilters.append(f"[{i}:a]volume={cue['gainDB']}dB,adelay={round(cue['at']*1000)}:all=1[a{i}]")
    afilters.append(''.join(f'[a{i}]' for i in range(4 + len(cues))) +
                    f'amix=inputs={4 + len(cues)}:normalize=0:duration=longest,atrim=duration={total},'
                    f'afade=t=in:d=0.25,afade=t=out:st={total-2.25}:d=2.25[mix]')
    mix = work / 'score-mix.wav'
    run(inputs + ['-filter_complex', ';'.join(afilters), '-map', '[mix]', '-ar', 48000, '-c:a', 'pcm_s24le', mix])
    loud = m['loudness']
    norm = f"loudnorm=I={loud['integratedLUFS']}:TP={loud.get('encodeTruePeakDBTP', loud['truePeakDBTP'])}:LRA={loud['rangeLU']}"
    report = work / 'loudness-pass1.log'
    measured = run(['-i', mix, '-af', norm + ':print_format=json', '-f', 'null', '-'], report)
    if args.execute:
        values = json.loads(measured[measured.rfind('{'):measured.rfind('}') + 1])
        for key, field in [('measured_I', 'input_i'), ('measured_TP', 'input_tp'),
                           ('measured_LRA', 'input_lra'), ('measured_thresh', 'input_thresh'), ('offset', 'target_offset')]:
            norm += f':{key}={values[field]}'
        norm += ':linear=true'
        (work / 'loudness-measured.json').write_text(json.dumps(values, indent=2))
    else:
        commands.append('# Execution inserts measured two-pass loudnorm values from loudness-pass1.log')
    public = out / (args.name + '.mp4')
    run(['-i', silent, '-i', mix, '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy',
         '-af', norm, '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-t', total, '-movflags', '+faststart', public])

    # Menu is a live Godot replay now: trailer-demo.mjs exports its JSON data.
    # No menu movie is produced or installed.
    if args.execute:
        for path in (public,):
            probe = subprocess.check_output(['ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(path)], text=True)
            (out / (path.name + '.probe.json')).write_text(probe)
            data = json.loads(probe)
            video = next(s for s in data['streams'] if s['codec_type'] == 'video')
            if video['codec_name'] != 'h264' or video['width'] != 960 or video['height'] != 540:
                raise RuntimeError(f'Unexpected video format: {path}')
            expected_duration = total
            if abs(float(data['format']['duration']) - expected_duration) > 0.15:
                raise RuntimeError(f'Unexpected duration: {path}')
            (out / (path.name + '.sha256')).write_text(hashlib.sha256(path.read_bytes()).hexdigest() + '\n')
    (out / 'edit-commands.sh').write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + '\n'.join(commands) + '\n')
    (out / 'edit-timeline.json').write_text(json.dumps(dict(timeline=timeline, fps=fps,
        duration=total, menuAsset='live engine demo.json; no video', loudnessTarget=loud,
        sfx=cues, executed=args.execute, credit=m['credit']), indent=2))
    print('TRAILER_EDIT', 'encoded; visual/audio approval still required' if args.execute else 'plan only', out)


if __name__ == '__main__':
    main()
