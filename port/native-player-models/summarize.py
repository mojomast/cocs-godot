"""Summarize actual retained measurements without inventing GPU timings."""
import json
from pathlib import Path
import statistics
ROOT=Path(__file__).resolve().parent

def main():
    render=ROOT/'evidence/render-1790052439614620418/render-metrics.json'
    rows=[]
    for r in json.loads(render.read_text()):
        values=sorted(r['frame_usec'])
        rows.append({'resolution':r['size'],'baseline':r['baseline'],'actors':r['count'],
                     'samples':len(values),'median_frame_ms':statistics.median(values)/1000,
                     'p95_frame_ms':values[int(.95*(len(values)-1))]/1000,
                     'median_draw_calls':statistics.median(r['draw_calls']),
                     'renderer':r['renderer'],'method':r['method']})
    baseline=json.loads((ROOT/'baseline.log').read_text().split('PLAYER_MODEL_BASELINE ')[1])
    runs=sorted((ROOT/'evidence').glob('*/result.json'),key=lambda p:p.stat().st_mtime)
    geometry=next(json.loads(p.read_text())['geometry'][0] for p in reversed(runs) if 'geometry' in json.loads(p.read_text()))
    populations=[]
    for before,after in zip(baseline['synthetic_cpu_construction_only'],geometry['synthetic_cpu_construction_only']):
        old=statistics.median(before['construction_usec']);new=statistics.median(after['construction_usec'])
        populations.append({'actors':before['count'],'baseline_median_usec':old,'candidate_median_usec':new,'ratio':new/old})
    model=geometry['variants'][0]
    result={'note':'Synthetic software-rendered frame intervals, not GPU hardware timings. Shared host is not a controlled benchmark machine. No inferential confidence claim.',
            'render_source':str(render.relative_to(ROOT)), 'construction':populations,
            'geometry':{'baseline_triangles':312,'candidate_triangles':model['triangles'],'triangle_ratio':model['triangles']/312,'baseline_meshes':26,'candidate_meshes':model['meshes'],'baseline_nodes':27,'candidate_nodes':model['nodes'],'materials_per_actor':4,'texture_bytes':0},'render':rows}
    (ROOT/'METRICS.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__': main()
