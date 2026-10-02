"""Contact sheets and wall-clock-cadence native clip from actual capture receipts."""
import json
import os
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw

source = Path(os.environ['ROBOT_INSPECTION'])
production = Path(os.environ['ROBOT_PRODUCTION'])
out = Path(os.environ['ASSET_STAGE_EVIDENCE'])
receipt = json.loads((source/'inspection.json').read_text())


def sheet(name, paths, columns=3):
    width, height = 480, 322
    canvas = Image.new('RGB', (width*columns, height*((len(paths)+columns-1)//columns)), '#111b25')
    draw = ImageDraw.Draw(canvas)
    for index, path in enumerate(paths):
        im = Image.open(path).convert('RGB'); im.thumbnail((width,height-22))
        x,y = index % columns*width,index//columns*height
        canvas.paste(im,(x,y)); draw.text((x+5,y+height-18),path.stem,fill='white')
    canvas.save(out/(name+'.png'))


sheet('robot-anatomy', [source/f'close-{role}-{side}.png' for role in ['skirmisher','bulwark','mortar'] for side in ['front','rear','underside']])
sheet('lod-distance', [source/f'lod-{i}.png' for i in range(3)]+[source/f'distance-{i}.png' for i in [12,22,48]])
sheet('props', [source/f'prop-{i}.png' for i in range(6)])
sheet('production-mounts', sorted(source.glob('production-*.png')))
sheet('animation-contact', [source/f'animation-{i:03}.png' for i in [0,22,42,62,82,85,89,94,105]])
sheet('campaign-source-events', [production/role/f'frame-{i:03}.png' for role in ['skirmisher','bulwark','mortar'] for i in [0,24,48]])
frames=[f for f in receipt['frames'] if f['name'].startswith('animation-')]
durations=[(frames[i+1]['ticksUsec']-f['ticksUsec'])/1e6 for i,f in enumerate(frames[:-1])]
assert len(frames)==120 and all(d>0 for d in durations)
lines=[]
for i,f in enumerate(frames):
    lines += ["file '"+f['path']+"'", 'duration '+str(durations[i] if i<len(durations) else durations[-1])]
lines += ["file '"+frames[-1]['path']+"'"]
concat=out/'cadence.ffconcat';concat.write_text('\n'.join(lines)+'\n')
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-threads','1','-f','concat','-safe','0','-i',str(concat),
                '-fps_mode','vfr','-c:v','libx264','-threads','1','-pix_fmt','yuv420p','-crf','19',str(out/'native-animation-captured-cadence.mp4')],check=True,timeout=90)
summary={'source':str(source),'production':str(production),'frames':len(frames),'capturedSeconds':sum(durations),
         'intervalMin':min(durations),'intervalMax':max(durations),'meanCapturedFPS':len(durations)/sum(durations),
         'renderer':receipt['renderer'],'timing':'PNG capture-completion timestamps; variable-frame-rate encode; not hardware performance',
         'sheets':[p.name for p in out.glob('*.png')]}
(out/'review.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))
