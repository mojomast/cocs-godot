"""Static AA readback census. Writes JSON diagnostics only, never art or engine data."""
import collections as C
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'parallax-observatory/revisions/districts-v4-tangent'))
from contract import EmbeddedGlb,stream,SOURCE,SOURCE_SHA
AA=Path('/home/mojo/.tmp-on-disk/cocs-parallax-tangent-native-AA-20261003')
NATIVE=AA/'godot/tests/new_maps/parallax_tangent'
AA_DIR=AA/'tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v4-tangent'
ART_SHA='95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5'
def sha(b):return hashlib.sha256(b).hexdigest()
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):return math.sqrt(dot(a,a))
def unit(a):return tuple(x/norm(a) for x in a) if norm(a) else (0.,0.,0.)
def angle(a,b):return math.degrees(math.acos(max(-1.,min(1.,dot(unit(a),unit(b)))))) if norm(a)*norm(b)>1e-20 else None
def orient(corners):
    return min((corners[i:]+corners[:i] for i in range(3)),key=lambda cs:tuple((c['P'],c['UV']) for c in cs))
def key(cs):return tuple((c['P'],c['UV']) for c in cs)
def attributes(cs):return tuple((c['N'],c['T']) for c in cs)
def errors(a,b):return [max(abs(x-y) for c,d in zip(a,b) for x,y in zip(c[k],d[k])) for k in ('P','N','UV','T')]
def strict(a,b):
    e=errors(a,b);return e[0]<=1e-5 and e[1]<=.0002 and e[2]==0 and e[3]<=.0002
def compact_source_report(report):
    # Keep the comprehensive vertex census reviewable: one record per line.
    sections=[]
    for label,inventory in report.items():
        fields=[]
        for name,value in inventory.items():
            text=('[\n'+',\n'.join(json.dumps(r,separators=(',',':')) for r in value)+'\n]') if name=='badVertexRecords' else json.dumps(value,indent=2)
            fields.append(json.dumps(name)+': '+text)
        sections.append(json.dumps(label)+': {\n'+',\n'.join(fields)+'\n}')
    return '{\n'+',\n'.join(sections)+'\n}\n'
def maximum_matching(a,b,predicate):
    """Bipartite multiset equality, not greedy choice of whichever sign passes."""
    owner={}
    def augment(i,seen):
        for j in range(len(b)):
            if j in seen or not predicate(a[i],b[j]):continue
            seen.add(j)
            if j not in owner or augment(owner[j],seen):owner[j]=i;return True
        return False
    for i in range(len(a)):augment(i,set())
    return sorted((i,j) for j,i in owner.items())

def derivative(cs):
    e1=sub(cs[1]['P'],cs[0]['P']);e2=sub(cs[2]['P'],cs[0]['P'])
    u1=sub(cs[1]['UV'],cs[0]['UV']);u2=sub(cs[2]['UV'],cs[0]['UV'])
    det=u1[0]*u2[1]-u1[1]*u2[0];area=norm(cross(e1,e2))/2
    if abs(det)<=1e-15 or area<=1e-12:return {'area':area,'uvJacobian':det,'defined':False}
    du=tuple((e1[k]*u2[1]-e2[k]*u1[1])/det for k in range(3))
    dv=tuple((e2[k]*u1[0]-e1[k]*u2[0])/det for k in range(3))
    signs=[]
    for c in cs:
        hand=dot(cross(c['N'],du),dv);signs.append(1 if hand>0 else -1 if hand<0 else 0)
    return {'area':area,'uvJacobian':det,'defined':True,'du':du,'dv':dv,'wFromUV':signs}

def source_faces(g):
    groups=C.defaultdict(list);inventory=C.Counter({k:0 for k in ('zeroT','nonunitT','nonorthogonalNT','parallelNT','nonunitN')});bad=[];allfaces=[];transforms=[]
    g.geometry()
    native_names=[n['name'].replace('.','_') for n in g.doc['nodes'] if 'mesh' in n]
    assert len(native_names)==len(set(native_names)), 'Node-name sanitization collision'
    for ni,node in enumerate(g.doc['nodes']):
        if 'mesh' not in node:continue
        assert 'matrix' not in node
        transforms.append({'nodeIndex':ni,'node':node['name'],'scaleDeterminant':math.prod(node.get('scale',[1,1,1])),**{k:node[k] for k in ('matrix','rotation','translation','scale') if k in node}})
        for pi,p in enumerate(g.doc['meshes'][node['mesh']]['primitives']):
            names=(('P','POSITION','VEC3'),('N','NORMAL','VEC3'),('UV','TEXCOORD_0','VEC2'),('T','TANGENT','VEC4'))
            s={k:stream(g,p['attributes'][field],shape) for k,field,shape in names}
            ix=[v[0] for v in stream(g,p['indices'],'SCALAR',(5121,5123,5125))]
            role=g.doc['materials'][p['material']]['name'];normal_map='normalTexture' in g.doc['materials'][p['material']]
            for vertex,t in enumerate(s['T']):
                flags=[]
                if norm(t[:3])==0:flags.append('zeroT')
                if abs(norm(t[:3])-1)>.001:flags.append('nonunitT')
                if abs(dot(s['N'][vertex],t[:3]))>.001:flags.append('nonorthogonalNT')
                if norm(cross(s['N'][vertex],t[:3]))<1e-12:flags.append('parallelNT')
                if abs(norm(s['N'][vertex])-1)>.001:flags.append('nonunitN')
                inventory.update(flags)
                if flags:bad.append({'node':node['name'],'nodeIndex':ni,'mesh':node['mesh'],'primitive':pi,'accessor':p['attributes']['TANGENT'],'vertex':vertex,'flags':flags,'N':s['N'][vertex],'T':t})
            for fi in range(len(ix)//3):
                cs=[{**{k:s[k][v] for k in s},'vertex':v,'corner':ci} for ci,v in enumerate(ix[fi*3:fi*3+3])]
                uv=derivative(cs);inventory['faces']+=1
                inventory['definedUVFaces' if uv['defined'] else 'undefinedUVFaces']+=1
                if uv['defined']:
                    inventory['UVHandDisagreeCorners']+=sum(c['T'][3]!=w for c,w in zip(cs,uv['wFromUV']))
                    inventory['storedTangentOpposesDU']+=sum(dot(c['T'][:3],uv['du'])<0 for c in cs)
                    inventory['storedBinormalOpposesDV']+=sum(dot(cross(c['N'],c['T'][:3]),uv['dv'])*c['T'][3]<0 for c in cs)
                row={'node':node['name'],'nodeIndex':ni,'mesh':node['mesh'],'primitive':pi,'face':fi,'accessor':p['attributes']['TANGENT'],'material':role,'normalMap':normal_map,'corners':orient(list(reversed(cs))),'derivative':uv}
                groups[node['name'].replace('.','_'),role,key(row['corners'])].append(row);allfaces.append(row)
    return groups,{'uniqueVertexRecords':dict(inventory),'badVertexRecords':bad,'nodeTransforms':transforms},allfaces

def native_faces(report,raw):
    groups=C.defaultdict(list);offset=0;counts=C.Counter()
    for si,s in enumerate(report['surfaces']):
        assert s['offset']==offset;n=s['vertices'];arrays={}
        for k,w in (('P',3),('N',3),('UV',2),('T',4)):
            arrays[k]=[struct.unpack_from('<'+'f'*w,raw,offset+i*w*4) for i in range(n)];offset+=n*w*4
        ix=struct.unpack_from('<'+'I'*s['indices'],raw,offset);offset+=s['indices']*4
        assert len(ix)%3==0 and all(0<=v<n for v in ix)
        for t in arrays['T']:
            counts['zeroT']+=norm(t[:3])==0;counts['nonunitT']+=abs(norm(t[:3])-1)>.001
        for fi in range(len(ix)//3):
            cs=orient([{**{k:arrays[k][v] for k in arrays},'vertex':v,'corner':ci} for ci,v in enumerate(ix[fi*3:fi*3+3])])
            assert all(math.isfinite(v) for c in cs for k in arrays for v in c[k])
            groups[s['node'],s['material'],key(cs)].append({'node':s['node'],'surfaceRecord':si,'surface':s['surface'],'face':fi,'material':s['material'],'corners':cs})
            counts['faces']+=1
    assert offset==len(raw)
    return groups,dict(counts)

def compare(source,native):
    counts=C.Counter();mismatches=[];ambiguous=[];missing=[];maximum=[0.]*4
    for k in sorted(source.keys()|native.keys()):
        aa=source.get(k,[]);bb=native.get(k,[])
        if not aa or not bb or len(aa)!=len(bb):missing.append({'node':k[0],'material':k[1],'sourceFaces':[r['face'] for r in aa],'nativeFaces':[r['face'] for r in bb],'sourceCount':len(aa),'nativeCount':len(bb)});continue
        counts['matchedGeometryFaces']+=len(aa);counts['duplicateGroups']+=len(aa)>1
        # Retain full multiset multiplicity. Matching never chooses source identity:
        # it tests whether the whole group admits a bijection at strict tolerances.
        pairs=maximum_matching(aa,bb,lambda a,b:strict(a['corners'],b['corners']))
        counts['strictEquivalentFaces']+=len(pairs)
        for i,j in pairs:maximum=[max(x,y) for x,y in zip(maximum,errors(aa[i]['corners'],bb[j]['corners']))]
        if len(pairs)==len(aa):continue
        # Without tangent-based disambiguation, only identical source basis classes
        # permit per-corner attribution. Otherwise report the entire unmatched multiset.
        classes={attributes(r['corners']) for r in aa}
        if len(classes)>1:
            ambiguous.append({'sources':aa,'natives':bb,'strictMatchingCardinality':len(pairs)});continue
        a=aa[0]
        for b in bb:
            if strict(a['corners'],b['corners']):continue
            corners=[]
            for ca,cb in zip(a['corners'],b['corners']):
                flags=[]
                for field,tol in (('P',1e-5),('N',.0002),('UV',0)):
                    if max(abs(x-y) for x,y in zip(ca[field],cb[field]))>tol:flags.append(field)
                if max(abs(x-y) for x,y in zip(ca['T'][:3],cb['T'][:3]))>.0002:flags.append('Tdirection')
                if ca['T'][3]!=cb['T'][3]:flags.append('w')
                if not flags:continue
                counts.update(flags);counts['mismatchedCorners']+=1
                sb=tuple(x*ca['T'][3] for x in cross(ca['N'],ca['T'][:3]));nb=tuple(x*cb['T'][3] for x in cross(cb['N'],cb['T'][:3]))
                corners.append({'source':ca,'native':cb,'flags':flags,'normalTangentDot':dot(ca['N'],ca['T'][:3]),'sourceBinormalLength':norm(sb),'nativeBinormalLength':norm(nb),'binormalAngleDegrees':angle(sb,nb),'tangentAngleDegrees':angle(ca['T'][:3],cb['T'][:3])})
            mismatches.append({'sourceCandidates':[{'nodeIndex':r['nodeIndex'],'node':r['node'],'mesh':r['mesh'],'primitive':r['primitive'],'face':r['face'],'accessor':r['accessor']} for r in aa],
                'native':{k:v for k,v in b.items() if k!='corners'},'material':a['material'],'normalMap':a['normalMap'],'sourceDerivative':a['derivative'],'corners':corners})
    counts['mismatchedFaces']=len(mismatches);counts['ambiguousBasisGroups']=len(ambiguous);counts['missingGeometryGroups']=len(missing)
    return {'counts':dict(counts),'maxStrictMatchedErrorsPNUVT':maximum,'mismatches':mismatches,'ambiguousGroups':ambiguous,'missingGeometryGroups':missing}

def main():
    raw=(NATIVE/'candidate.glb').read_bytes();assert sha(raw)==ART_SHA
    x=SOURCE.read_bytes();assert sha(x)==SOURCE_SHA
    sg,source,faces=source_faces(EmbeddedGlb(raw));_,baseline,_=source_faces(EmbeddedGlb(x))
    outputs={};inputs={str(SOURCE.relative_to(ROOT)):sha(x),str(NATIVE/'candidate.glb'):sha(raw)}
    for label,directory in [('AA03',NATIVE/'evidence'),('AA04',AA_DIR/'native/AA04')]:
        p=directory/'native-import.json';b=directory/'native-streams.bin'
        report=json.loads(p.read_text());assert report['artHash']==ART_SHA
        data=b.read_bytes();ng,ni=native_faces(report,data);result=compare(sg,ng);result['nativeInventory']=ni
        outputs[label]=result;inputs[str(p)]=sha(p.read_bytes());inputs[str(b)]=sha(data)
        (HERE/(label+'-census.json')).write_text(json.dumps(result,indent=2)+'\n')
    (HERE/'source-census.json').write_text(compact_source_report({'AA':source,'X':baseline}))
    summary={'artifactSha256':ART_SHA,'sourceX':SOURCE_SHA,'inputs':inputs,'scope':'Static original AA mesh-local arrays; native node transforms absent, no world-transform claim',
        'AA03':outputs['AA03']['counts'],'AA04':outputs['AA04']['counts'],'sourceAA':source['uniqueVertexRecords'],'sourceXInventory':baseline['uniqueVertexRecords'],
        'sameCensus':outputs['AA03']==outputs['AA04'],'sourceBasisOnly':'Derivative disagreements counted only for nonzero area/Jacobian; no arbitrary UV basis assigned to degenerate UV faces'}
    (HERE/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
