"""Blender-authored scenic depth, entirely behind the frozen race barriers.

No added walkable road, collision, race markers or authority surfaces. The built
quays are inaccessible scenery: the existing 2.8 m barriers remain the boundary.
"""
import math

def author(data, emit):
    serial = 0
    def box(name, x, y, z, w, h, d, material, heading=0):
        nonlocal serial
        serial += 1
        sn, cs = math.sin(heading), math.cos(heading)
        vertices = [(x+sx*w/2*cs+sz*d/2*sn, y+sy*h/2, z-sx*w/2*sn+sz*d/2*cs)
                    for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1),(-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)]]
        quads = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        emit('detail-%04d-' % serial + name, vertices, [tri for a,b,c,d in quads for tri in [(a,b,c),(a,c,d)]], material)
    def cylinder(name,x,y,z,r,h,material,n=16):
        nonlocal serial
        serial += 1
        vertices=[(x+math.cos(i*math.tau/n)*r,y+dy*h/2,z+math.sin(i*math.tau/n)*r) for dy in [-1,1] for i in range(n)]
        faces=[]
        for i in range(n):
            j=(i+1)%n
            faces.extend([(i,j,j+n),(i,j+n,i+n)])
        for i in range(1,n-1): faces.extend([(0,i+1,i),(n,n+i,n+i+1)])
        emit('detail-%04d-' % serial+name,vertices,faces,material)
    points=data['race']['centerline']
    for i,a in enumerate(points):
        b=points[(i+1)%len(points)]
        dx,dz=b['x']-a['x'],b['z']-a['z']
        length=math.hypot(dx,dz)
        ux,uz=dx/length,dz/length
        heading=math.atan2(ux,uz)
        def at(t,side,y=0): return (a['x']+dx*t-uz*side,y,a['z']+dz*t+ux*side)
        for edge in data['race']['boundary'].values():
            p,q=edge[i],edge[(i+1)%len(points)]
            ex,ez=q['x']-p['x'],q['z']-p['z']
            el=math.hypot(ex,ez)
            # Solid-looking tide wall below the actual source road/edge.
            box('tidewall', (p['x']+q['x'])/2,-5,(p['z']+q['z'])/2,1.5,10,el,'concrete',math.atan2(ex,ez))
            box('salt-tidemark',(p['x']+q['x'])/2,-2.2,(p['z']+q['z'])/2,1.7,.55,el,'salt',math.atan2(ex,ez))
            for k in range(max(1,int(el/9))):
                t=(k+.5)/max(1,int(el/9))
                box('raking-buttress',p['x']+ex*t,-5.8,p['z']+ez*t,3,12,2.2,'concrete',math.atan2(ex,ez))
        # Edge maintenance ducts / lamps outside the player's swept body.
        for k in range(max(1,int(length/15))):
            t=(k+.5)/max(1,int(length/15))
            x,y,z=at(t,-15.7,4)
            box('light-mast',x,y,z,.35,8,.35,'steel',heading)
            box('luminaire',x,8,z,1.3,.3,2,'salt',heading)
        # Repeated facade layers augment the existing tested shell, never road space.
        for structure in data['structures']:
            if not structure['id'].startswith('district-%d-' % i): continue
            k=int(structure['id'].split('-')[-1]);t=(k+.5)/3;side=1 if i<4 or i>18 else -1
            h=structure['height']
            for story in range(int(h/4)):
                for bay in range(3):
                    u=t+(bay-1)*3/length
                    for offset in [-.85,0,.85]:
                        x,y,z=at(u+offset/length,side*17.65,2+story*4)
                        box('window-mullion',x,y,z,.2,2.1,.09,'steel',heading)
                x,y,z=at(t,side*17.7,3.25+story*4)
                box('facade-stringcourse',x,y,z,.3,.25,length/3-3,'concrete',heading)
            x,y,z=at(t,side*16.5,4.2)
            box('service-canopy',x,y,z,2.4,.25,length/3-4,'steel',heading)
            # Deep upper louvres and chimney bank break the repetitive flat roofs.
            for bay in range(4):
                x,y,z=at(t+(bay-1.5)*1.3/length,side*25,h+3)
                cylinder('exhaust-flue',x,y,z,.35,5+bay*.35,'steel',8)
        if i in [4,5,6]:
            # Longitudinal tunnel cable trays tucked above the source 7m spring.
            for side in [-11.5,11.5]:
                x,y,z=at(.5,side,7.5)
                box('tunnel-cable-tray',x,y,z,.65,.5,length,'amber',heading)
            for t in [.1,.3,.5,.7,.9]:
                x,y,z=at(t,0,15)
                box('vault-ceiling-light',x,y,z,2,.15,1,'salt',heading)
    # Infield pumpworks: intentionally unreachable dry-service island and halls.
    box('pump-island',-30,-3,52,104,5,65,'concrete')
    box('pump-hall',-35,9,49,62,18,28,'brick')
    box('pump-foundation',-35,1,49,66,2,32,'salt')
    for x in range(-62,-6,8):
        box('hall-buttress',x,10,33,1.4,20,2.3,'concrete')
        box('hall-glazing',x+3,11,34.8,4,10,.25,'glass')
        box('clerestory',x+3,21,49,6,5,17,'teal')
        box('clerestory-glass',x+3,21,40.4,5,3,.2,'glass')
    for x in [-62,-42,-22]:
        cylinder('surge-cistern',x,5,76,5,10,'teal',24)
        for y in [1,5,9]: cylinder('cistern-hoop',x,y,76,5.15,.25,'steel',24)
    for x in [-67,-60,-53,-46]:
        cylinder('discharge-stack',x,15,52,1,30,'steel')
        cylinder('stack-collar',x,24,52,1.5,2,'amber')
    # Glazed weather observatory, stepped plinth and elevated sensor crown.
    box('observatory-island',21,-3,3,47,5,49,'concrete')
    for y,w in [(2,34),(7,28),(15,19)]:
        box('observatory-plinth',20,y,0,w,4,w,'salt')
        box('observatory-glass',20,y+3,0,w-2,3,w-2,'glass')
    cylinder('observatory-crown',20,23,0,11,9,'teal',12)
    for i in range(12):
        theta=i*math.tau/12
        box('crown-fin',20+11*math.cos(theta),25,11*math.sin(theta),.8,12,2,'salt',-theta)
    cylinder('radar-mast',20,34,0,.7,17,'steel',12)
    box('radar-array',20,40,0,17,2,2,'amber',.4)
    box('radar-array-cross',20,37,0,12,1,1,'steel',1.9)
    # The original gates receive riveted panels and machinery, above road clearance.
    for i in [1,14,18]:
        a,b=points[i],points[(i+1)%len(points)]
        dx,dz=b['x']-a['x'],b['z']-a['z'];ln=math.hypot(dx,dz);ux,uz=dx/ln,dz/ln
        angle=math.atan2(ux,uz)
        for side in [-1,1]:
            x,z=(a['x']+b['x'])/2-uz*side*22,(a['z']+b['z'])/2+ux*side*22
            for y in [4,8,12,16,20]: box('gate-access-band',x,y,z,7,.45,12,'steel',angle)
        for lateral in range(-14,15,4):
            x,z=(a['x']+b['x'])/2-uz*lateral,(a['z']+b['z'])/2+ux*lateral
            box('gate-leaf-rib',x,12,z,1,5.6,3.4,'steel',angle)
