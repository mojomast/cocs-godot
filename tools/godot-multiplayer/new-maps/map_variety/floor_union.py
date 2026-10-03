"""Ordered coplanar floor subtraction, equivalent to accepted first-floor wins.

Authority remains unchanged. Render triangles are clipped, not hash-deduped:
earlier terrain.surfaces entries own every coplanar overlap, including material
priority. Distinct heights/planes do not occlude one another. A spatial index
only narrows candidates; clipping is performed against their actual triangles.
"""
import math
import struct

EPS = 1e-9
AREA_EPS = 1e-8


def area(poly):
    return abs(sum(a[0]*poly[(i+1)%len(poly)][2]-poly[(i+1)%len(poly)][0]*a[2]
                   for i,a in enumerate(poly)))/2 if len(poly)>2 else 0


def plane(triangle):
    a,b,c=triangle
    dx,dz,dy=b[0]-a[0],b[2]-a[2],b[1]-a[1]
    ex,ez,ey=c[0]-a[0],c[2]-a[2],c[1]-a[1]
    det=dx*ez-ex*dz
    if abs(det)<EPS:return None
    sx,sz=(dy*ez-ey*dz)/det,(dx*ey-ex*dy)/det
    return tuple(round(v,7) for v in (sx,sz,a[1]-sx*a[0]-sz*a[2]))


def clip(poly,a,b,inside=True):
    if not poly:return []
    sign=1 if inside else -1
    def distance(p):return sign*((b[0]-a[0])*(p[2]-a[2])-(b[2]-a[2])*(p[0]-a[0]))
    result=[]
    for i,p in enumerate(poly):
        q=poly[(i+1)%len(poly)];dp,dq=distance(p),distance(q)
        if dp>=-EPS:result.append(p)
        if (dp>EPS and dq<-EPS) or (dp<-EPS and dq>EPS):
            t=dp/(dp-dq);result.append(tuple(p[k]+(q[k]-p[k])*t for k in range(3)))
    clean=[]
    for p in result:
        if not clean or max(abs(p[k]-clean[-1][k]) for k in range(3))>EPS:clean.append(p)
    if len(clean)>1 and max(abs(clean[0][k]-clean[-1][k]) for k in range(3))<=EPS:clean.pop()
    return clean


def intersection(poly,cutter):
    for i,a in enumerate(cutter):poly=clip(poly,a,cutter[(i+1)%len(cutter)])
    return poly


def ccw(poly):
    signed=sum(a[0]*poly[(i+1)%len(poly)][2]-poly[(i+1)%len(poly)][0]*a[2] for i,a in enumerate(poly))
    return list(reversed(poly)) if signed<0 else poly


def subtract(poly,cutter):
    cutter=ccw(cutter)
    if area(intersection(poly,cutter))<=AREA_EPS:return [poly]
    out=[];remainder=poly
    for i,a in enumerate(cutter):
        b=cutter[(i+1)%len(cutter)]
        outside=clip(remainder,a,b,False)
        if area(outside)>AREA_EPS:out.append(outside)
        remainder=clip(remainder,a,b)
        if len(remainder)<3:break
    return out


def cells(poly):
    for x in range(math.floor(min(p[0] for p in poly)/8),math.floor(max(p[0] for p in poly)/8)+1):
        for z in range(math.floor(min(p[2] for p in poly)/8),math.floor(max(p[2] for p in poly)/8)+1):yield x,z


def float32_area(triangle):
    points=[struct.unpack('<fff',struct.pack('<fff',*p)) for p in triangle]
    a,b,c=points;u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
    return math.sqrt(sum((u[(i+1)%3]*v[(i+2)%3]-u[(i+2)%3]*v[(i+1)%3])**2 for i in range(3)))/2


def union_floors(surfaces):
    index={};covered=[];output=[];lineage=[]
    input_area=render_area=discarded_area=0
    for priority,surface in enumerate(surfaces):
        record={'sourceId':surface['id'],'material':surface['material'],'priority':priority,
                'inputTriangles':len(surface['triangles']),'renderTriangles':0,
                'inputProjectedArea':0.,'renderProjectedArea':0.}
        for indices in surface['triangles']:
            triangle=[surface['vertices'][i] for i in indices]
            key=plane(triangle)
            if key is None:raise ValueError('Playable floor has no projected area: '+surface['id'])
            initial=area(triangle);record['inputProjectedArea']+=initial;input_area+=initial
            candidates=set()
            for cell in cells(triangle):candidates.update(index.get((key,cell),()))
            pieces=[triangle]
            for old in sorted(candidates):
                pieces=[remainder for piece in pieces for remainder in subtract(piece,covered[old])]
                if not pieces:break
            # Prior input coverage equals the union of previously emitted pieces;
            # indexing the original triangle avoids multiplying index fragments.
            if pieces:
                old=len(covered);covered.append(triangle)
                for cell in cells(triangle):index.setdefault((key,cell),[]).append(old)
            for piece in pieces:
                for i in range(1,len(piece)-1):
                    tri=[piece[0],piece[i],piece[i+1]];projected=area(tri)
                    if projected<=AREA_EPS or float32_area(tri)<AREA_EPS:
                        discarded_area+=projected;continue
                    output.append({'sourceId':surface['id'],'material':surface['material'],'vertices':tri})
                    record['renderTriangles']+=1;record['renderProjectedArea']+=projected;render_area+=projected
        lineage.append(record)
    return output,{'policy':'coplanar-first-authored-surface-wins',
                   'materialPriority':'terrain.surfaces order, preserving accepted author order before candidate additions',
                   'inputTriangles':sum(r['inputTriangles'] for r in lineage),'renderTriangles':len(output),
                   'inputProjectedArea':input_area,'renderProjectedArea':render_area,
                   'overlapRemovedProjectedArea':input_area-render_area-discarded_area,
                   'discardedSubprecisionProjectedArea':discarded_area,'lineage':lineage}
