"""Read-only evidence collection and write-once X inventory/gallery (no engines)."""
import datetime
import html
import json
import os
from pathlib import Path
from stage_config import ROOT,HERE,NATIVE,MAPS,read,write,sha
from stage_bridge import validate_setup
from source_scene import load
from export_audit import png_pixels

def main():
    evidence=HERE/'x-evidence';summary={};gallery=['<!doctype html><meta charset="utf-8"><title>Grant X corrective evidence</title>',
        '<h1>Grant X — original native PNG evidence</h1><p>Geometry corrections measured; Vesper physics blocked. Parallax has one inherited zero tangent. Human art/hosted/performance acceptance pending. Exterior details are not player cameras. Occluded attempts retained.</p>']
    for ident in MAPS:
        out,dest,_=validate_setup('x-03',ident);manifest=read(dest/'manifest.json')
        for path,digest in manifest['files'].items():
            if sha(ROOT/'godot'/path[6:])!=digest:raise ValueError('Staged bytes changed '+path)
        if sha(out/(ident+'.glb'))!=manifest['glbSha256'] or sha(out/'masters'/(ident+'.blend'))!=manifest['masterSha256']:raise ValueError('Actual artifact drift')
        physics=read(dest/'physics-report.json');imported=read(dest/'import-report.json');captures=[];image_rows=[]
        gallery.append('<h2>'+html.escape(ident)+'</h2>')
        for folder in [dest,dest/'detail-01',dest/'detail-02']:
            report=read(folder/'capture-report.json')
            if report['manifestSha256']!=sha(dest/'manifest.json'):raise ValueError('Capture receipt drift')
            probes=read(folder/('probes.json' if folder!=dest else 'source-probes.json'))
            if len(report['captures'])!=2*len(probes['cameras']):raise ValueError('Incomplete pairs')
            captures+=report['captures']
            for row in report['captures']:
                p=ROOT/'godot'/row['path'][6:]
                if sha(p)!=row['sha256']:raise ValueError('Original image drift')
                size,_=png_pixels(p.read_bytes())
                if size!=(1280,720):raise ValueError('Wrong native resolution')
                expected=manifest['geometryHash'] if row['variant']=='candidate-runtime-after' else manifest['source']['acceptedGeometryHash']
                if row['geometryHash']!=expected:raise ValueError('Image geometry identity mismatch')
                label=folder.name+'/'+row['view']+'/'+row['variant']
                image_rows.append({'path':str(p.relative_to(ROOT)),'sha256':sha(p),'view':row['view'],'variant':row['variant'],'comparison':row['comparison'],'inspectedOriginal':True})
                relative=os.path.relpath(p,evidence)
                gallery.append('<h3>'+html.escape(label)+'</h3><p>'+html.escape(row['comparison'])+'</p><a href="'+html.escape(relative)+'"><img loading="lazy" width="1280" height="720" src="'+html.escape(relative)+'"></a>')
        after=[r for r in captures if r['variant']=='candidate-runtime-after']
        performance={key:{'min':min(r[key] for r in after),'max':max(r[key] for r in after)} for key in ['drawCalls','staticViewMeanFrameMs','videoMemoryBytes','staticMemoryBytes']}
        performance.update(renderer=sorted(set(r['renderer'] for r in after)),scope='8-frame static llvmpipe cadence/memory/draw calls; not gameplay FPS or dedicated-GPU qualification')
        summary[ident]={'geometryHash':manifest['geometryHash'],'master':str((out/'masters'/(ident+'.blend')).relative_to(ROOT)),
            'glb':str((out/(ident+'.glb')).relative_to(ROOT)),'masterSha256':manifest['masterSha256'],'glbSha256':manifest['glbSha256'],
            'evaluatedExportTriangles':manifest['evaluatedExportTriangles'],'usedMaterials':manifest['usedMaterials'],
            'finiteCapsules':physics['finiteCapsules'],'finiteCapsuleErrors':physics['errors'],'nativeRays':len(physics['rays']),
            'nativeGroundSeams':len(physics['seamSupport']),'registeredModes':manifest['modes'],'materialInstancesRestored':imported['materialInstancesRestored'],
            'vectorCensus':read(out/'vector-census.json'),'actualReadbackSha256':sha(out/'x-readback-v2.json'),
            'nativePhysics':'blocked' if physics['errors'] else 'passed','fullHumanArtAcceptance':'pending; see X_HANDOFF.md view limitations',
            'hostedModes':'pending','images':image_rows,'staticPerformance':performance}
    write(evidence/'results.json',{'grant':'MOTH-BLENDER-20261003-X','time':datetime.datetime.now(datetime.timezone.utc).isoformat(),'maps':summary})
    with (evidence/'gallery.html').open('x') as f:f.write('\n'.join(gallery)+'\n')
    files={}
    for base in [HERE/'runs',NATIVE/'x-01',NATIVE/'x-02',NATIVE/'x-03',evidence]:
        for p in sorted(base.rglob('*')):
            if p.is_file():files[str(p.relative_to(ROOT))]={'sha256':sha(p),'bytes':p.stat().st_size}
    write(evidence/'artifact-inventory.json',{'scope':'X fresh and failed attempts, measured masters/exports, original captures, failure diagnostics and release; no acceptance or promotion claim','files':files})
    print('X retained files:',len(files),'original images:',sum(len(s['images']) for s in summary.values()))

if __name__=='__main__':main()
