"""Visible, low-poly world architecture on source solids or beyond play bounds.

All positions are the recipe's Y-up metres. `emit` maintains an individually
editable master piece and contributes its faces to one material export batch.
This pass never creates gameplay collision. Anything projecting above ground
inside play either rests on existing source block/overhead collision, or is a
thin marking; cliffs/ships/shore rocks are beyond the source boundary.
"""
import math


def build(map_id, data, emit, box, tube):
    def beam(name, a, b, radius, material, sides=6):
        dx,dy,dz=(b[i]-a[i] for i in range(3))
        length=math.sqrt(dx*dx+dy*dy+dz*dz)
        if length<.001:return
        direction=(dx/length,dy/length,dz/length)
        axis=(0,0,1) if abs(direction[2])<.9 else (0,1,0)
        ux=direction[1]*axis[2]-direction[2]*axis[1]
        uy=direction[2]*axis[0]-direction[0]*axis[2]
        uz=direction[0]*axis[1]-direction[1]*axis[0]
        norm=math.sqrt(ux*ux+uy*uy+uz*uz)
        u=(ux/norm,uy/norm,uz/norm)
        v=(direction[1]*u[2]-direction[2]*u[1],direction[2]*u[0]-direction[0]*u[2],direction[0]*u[1]-direction[1]*u[0])
        vertices=[]
        for origin in (a,b):
            for j in range(sides):
                angle=math.tau*j/sides
                vertices.append(tuple(origin[k]+radius*(u[k]*math.cos(angle)+v[k]*math.sin(angle)) for k in range(3)))
        faces=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
        for j in range(sides):faces.append((j,(j+1)%sides,(j+1)%sides+sides,j+sides))
        emit(name,vertices,faces,material)

    def prism(name,outline,y0,y1,material):
        n=len(outline)
        vertices=[(x,y0,z) for x,z in outline]+[(x,y1,z) for x,z in outline]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
        emit(name,vertices,faces,material)

    def ridge(name,center,zbase,halfwidth,depth,height,material,phase=0,axis='z'):
        # Extruded, faceted skyline: even the face towards the arena has large
        # tilted triangles rather than a flat boundary wall. Entire footprint
        # stays outside the source collision bounds.
        n=12
        front=[];back=[]
        for i in range(n+1):
            x=center-halfwidth+2*halfwidth*i/n
            height_i=height*(.34+.66*abs(math.sin(i*1.89+phase)))
            front.append((x,-.30,zbase) if axis=='z' else (zbase,-.30,x))
            crest=zbase+depth*(.35+.5*abs(math.sin(i*.91+phase)))
            back.append((x,height_i,crest) if axis=='z' else (crest,height_i,x))
        vertices=front+back
        faces=[]
        for i in range(n):faces.extend(((i,i+1,n+2+i),(i,n+2+i,n+1+i)))
        faces.extend(tuple(reversed(face)) for face in list(faces))
        emit(name,vertices,faces,material)
        # Top edges catch sun and provide a distinct crest silhouette.
        for i in range(0,n,2):
            beam(name+'.ridge-seam',back[i],back[i+2],.13,'salt' if material!='sandstone' else 'red-earth')

    if map_id=='breakwater-exchange':
        # Ground view starts at (-78, -13), aimed toward the lockhouse. Dress
        # both faces of the very large lock-bulkhead which filled that frame.
        for wall_x,zspan in ((-47,(-40,-4)),(47,(-4,34))):
            for face in (-1,1):
                x=wall_x+face*1.52
                box('bulkhead.oxidized-foot',x,.46,sum(zspan)/2,.09,.90,zspan[1]-zspan[0],'charcoal')
                box('bulkhead.safety-cap',x,6.82,sum(zspan)/2,.12,.20,zspan[1]-zspan[0],'glow-amber')
                for j,z in enumerate(range(int(zspan[0]+3),int(zspan[1]-2),6)):
                    box('bulkhead.steel-pier',x,3.5,z,.16,6.5,.48,'iron')
                    box('bulkhead.warning-panel',x+face*.012,3.1,z+2,.045,1.4,2.8,'safety-yellow' if j%2 else 'rust')
                    beam('bulkhead.cable', (x,5.9,zspan[0]),(x,5.9,zspan[1]),.10,'charcoal')
                for z in range(int(zspan[0]+2),int(zspan[1]-6),7):
                    beam('bulkhead.yellow-chevron',(x+face*.05,1.2,z),(x+face*.05,5.4,z+3.2),.15,'safety-yellow')
                    beam('bulkhead.yellow-chevron',(x+face*.05,5.4,z+3.2),(x+face*.05,1.2,z+6.4),.15,'safety-yellow')
        # Wall-mounted jib cranes appear ahead of the actual freight/gallery
        # approach view. Their bases stand on the source-solid 7m bulkheads;
        # hook ends remain >8m above walk and Puma height.
        for x,z in ((-47,-7),(47,27)):
            tube('jib.turntable',x,7.45,z,1.38,.8,'bronze',14)
            beam('jib.vertical',(x,7.7,z),(x,19,z),.42,'charcoal')
            beam('jib.main-derrick',(x,18.8,z),(x,16.2,z+24),.34,'safety-yellow')
            beam('jib.counterweight',(x,17.8,z),(x,13.2,z-9),.28,'bronze')
            for n in range(1,5):
                p=z+n*5
                beam('jib.truss-web',(x,18.8-(n-1)*.55,p-5),(x,16.5-n*.46,p),.16,'iron')
            beam('jib.hoist-wire',(x,16.2,z+24),(x,8.4,z+24),.07,'charcoal')
            box('jib.load-hook',x,8.2,z+24,.7,.48,.7,'glow-amber')
        for sign in (-1,1):
            x=sign*31
            for bx,bz in ((sign*65,8),(sign*37,-31)):
                for xx in (bx-1.65,bx-.85,bx, bx+.85,bx+1.65):
                    for face in (-1,1):
                        box('container.end-corrugation',xx,1.5,bz+face*(4.5+.035),.105,2.65,.06,'charcoal')
                for zface in (-1,1):
                    box('container.end-number',bx,2.5,bz+zface*4.57,2.7,.24,.045,'glow-amber')
            # Warehouse roofs are source overhead slabs; these substantial
            # pitched monitor bays, ducts and trusses are unreachable from play.
            for dx in (-6,0,6):
                beam('warehouse.sawtooth-rise',(x+dx,7.92,35),(x+dx+2,10.8,35),.19,'bronze')
                beam('warehouse.sawtooth-fall',(x+dx+2,10.8,35),(x+dx+4,7.92,35),.19,'iron')
                beam('warehouse.roof-spine',(x+dx+2,10.8,35),(x+dx+2,10.8,47),.18,'charcoal')
            for z in (37,41,45):
                box('warehouse.skylight',x,8.0,z,13,.075,1.1,'ice-blue')
            for px in (x-7.4,x+7.4):
                for z in (36.5,41,45.5):
                    box('warehouse.door-pier',px,3,z,.10,5.8,.42,'bronze')
            for bx in (sign*70,sign*79):
                for y in (1.2,2.8,4.7):
                    beam('pump.cistern-piping',(bx,y,56.2),(bx,y,60.0),.16,'bronze')
            # The existing gantry collision provides four 13m legs and a 26m
            # beam. Upper truss and suspended signage sit over that actual deck.
            for z in (-60,-52):
                for j in range(6):
                    a=x-12+j*4
                    beam('crane.portal-diagonal',(a,13.65,z),(a+2,17.1,z),.23,'safety-yellow')
                    beam('crane.portal-counter',(a+2,17.1,z),(a+4,13.65,z),.23,'iron')
                beam('crane.high-chord',(x-12,17.1,z),(x+12,17.1,z),.29,'bronze')
            for xx in (x-8,x+8):
                beam('crane.hoist-cable',(xx,13.5,-56),(xx,8.5,-56),.075,'charcoal')
                box('crane.hoist-hook',xx,8.3,-56,.95,.42,1.0,'glow-amber')
        # Docked freight silhouettes are fully beyond the southern source
        # boundary z=-72. They add a shipyard skyline but no ghost collision.
        for i,(cx,length) in enumerate(((-58,37),(44,46))):
            outline=[(cx-length/2,-78),(cx+length/2,-78),(cx+length/2-3,-86),(cx+length/2-8,-90),(cx-length/2+8,-90),(cx-length/2+3,-86)]
            prism('ferry.hull.%d'%i,outline,-2.7,3.2,'charcoal')
            box('ferry.gunwale',cx,3.35,-82,length-5,.32,7,'bronze')
            box('ferry.pilot-house',cx-5,7,-83,11,7,5,'teal')
            for xx in (cx-13,cx-7,cx+1,cx+8):
                box('ferry.container-bay',xx,4.8,-86,4.8,3,4,'coral' if xx<cx else 'ice-blue')
            for xx in (cx-16,cx+16):
                beam('ferry.mast',(xx,3.6,-83),(xx,15,-83),.30,'iron')
                beam('ferry.rigging',(xx,13,-83),(xx+5,3.5,-84),.08,'safety-yellow')
        # Road surface divisions are shallow paint over the same source floor.
        for z in (-47,18,41):
            box('dock.route-inlay',0,.041,z,165,.022,.18,'bronze')
        for bx in range(-90,91,15):
            for z in (-39,-32,31,50):
                # Shore road/warehouse concrete has readable loading bays and
                # transverse dark expansion joints at eye height (no step).
                box('freight.loading-bay',bx,.034,z,9,.022,2.8,'sediment')
                for xx in (bx-4,bx+4):
                    box('freight.stop-bar',xx,.049,z,.20,.023,3.2,'safety-yellow')
        for x in (-67,-36,-2,36,67):
            box('freight.crossing-stripe',x,.036,5,3.6,.02,.32,'hazard-white')
        # Wide bolted quay plates read from player eye level. They are only
        # color/normal changes (~2 cm), not new traversability or obstacles.
        for row,z in enumerate((-22,-14,-6,2,10,18,26)):
            for column,x in enumerate(range(-99,100,9)):
                if (row+column)%3==0:continue
                box('quay.riveted-panel',x,.002,z,6.8,.012,5.2,
                    'sediment' if (row+column)%2 else 'iron')
                for bolt_x in (x-3.2,x+3.2):
                    box('quay.rivet',bolt_x,.012,z, .11,.006,.11,'bronze')

    elif map_id=='thermal-divide':
        # Actual sources end at z=68 and x=+/-92. A jagged alpine skyline and
        # layered retaining terraces begin OUTSIDE the boundary collision.
        ridge('north.rock-wall',-45,69.1,55,17,24,'basalt',.3)
        ridge('north.snowline',50,69.3,55,20,33,'sediment',1.2)
        for x in (-48,48):
            ridge('south.rock-wall',x,-69.1,52,-17,19,'basalt',x*.03)
        for side in (-1,1):
            x=side*49
            # Rotor houses on the inaccessible source turbine roof (y 7.9).
            for n,dx in enumerate((-5.5,5.5)):
                cx=x+dx
                tube('station.heat-stack',cx,12,14.5,1.35,8,'charcoal',16)
                for y in (9.1,11.1,14.8):
                    tube('station.heat-collar',cx,y,14.5,1.48,.27,'bronze',16)
                for blade in range(8):
                    theta=math.tau*blade/8
                    beam('station.impeller', (cx,16,14.5),(cx+math.cos(theta)*3.4,16,14.5+math.sin(theta)*3.4),.24,'ice-blue')
                tube('station.impeller-hub',cx,16.2,14.5,.65,.45,'safety-yellow')
            for z in (11,15,19):
                beam('station.hot-pipe',(x-9,8.65,z),(x+9,8.65,z),.28,'bronze')
            for dx in (-8,0,8):
                tube('station.ground-vent',x+dx,8.75,19.8,.82,1.4,'charcoal')
            # Doorway on each east/west opening remains wide open. Side walls
            # receive large vertical channels and insulated face conduits.
            for facex in (x-10.42,x+10.42):
                for z in (10.8,19.2):
                    box('station.facade-flange',facex,3.4,z,.10,6.1,.34,'charcoal')
                    beam('station.steam-return',(facex,1.2,z),(facex,6.4,z),.17,'bronze')
                box('station.gable-badge',facex,5.2,15,.13,1.1,3.6,'glow-amber')
            # Rocks below exist on source abutments x=+/-16,44,72 z=57.
            for bx in (side*16,side*44,side*72):
                for z in (56.05,57.3,58.3):
                    beam('abutment.ice-ledger',(bx-3.1,8.15,z),(bx+3.1,8.15,z),.16,'salt')
            ridge('side.escarpment.%s'%side,24,side*93.5,49,side*19,19,'basalt',side*.8,'x')
        # A bridge with real source support, not an unconnected slab.
        for z in (34.8,43.2):
            for x in range(-42,43,7):
                y=max(0,min(4,(44-abs(x))/4))
                beam('span.balustrade', (x,y+.25,z),(x,y+1.25,z),.12,'iron')
            beam('span.top-rail',(-44,.95,z),(-28,4.95,z),.15,'glow-amber')
            beam('span.top-rail',(-28,4.95,z),(28,4.95,z),.15,'glow-amber')
            beam('span.top-rail',(28,4.95,z),(44,.95,z),.15,'glow-amber')
        for x in (-42,-26,0,26,42):
            box('spillway.longitudinal-grate',x,.055,-35,1.3,.045,13,'charcoal')
        for z in (-56,-48,-27,2,30):
            box('permafrost.terrain-joint',0,.028,z,128,.02,.20,'sediment')
        for side in (-1,1):
            # Ground slabs and insulated lines link the source turbine halls to
            # the source spillway. They lie only 3–9 cm above the same floor.
            for i in range(6):
                x=side*(23+i*11)
                for z in (-38,-24,-11,4,29):
                    box('geothermal.deck-segment',x,.038,z,7.2,.025,3.9,'sediment' if (i+int(z))%2 else 'basalt')
                for z in (-39,29):
                    box('geothermal.pressure-arrow',x,.065,z,2.8,.018,.22,'ice-blue')
            for z in (-22,-17):
                beam('geothermal.buried-pipe',(side*22,.105,z),(side*77,.105,z),.075,'bronze')
            for x in (side*26,side*47,side*70):
                tube('geothermal.manifold-cap',x,.075,-20,.48,.10,'charcoal',10)

    elif map_id=='sirocco-circuit':
        # The old isolated cones inside the racing loop had no collision and
        # looked like misplaced props. Skyline now starts past the ±132/103
        # authoritative edge, behind the existing race barrier.
        for i,x in enumerate((-105,-35,35,105)):
            ridge('canyon.north.%d'%i,x,104.5,32,21,22+(i%3)*7,'sandstone',i*.7)
            ridge('canyon.south.%d'%i,x,-104.5,32,-21,16+(i%2)*8,'red-earth',i*.4)
        for side in (-1,1):
            # Jagged side skyline, never the blocky monoliths of a flat prism.
            for z in (-69,0,69):
                ridge('canyon.side-rock',z,side*133.5,37,side*24,22+abs(z)/12,'red-earth',z*.04,'x')
        # Pit buildings are behind the race's outer collision rail, facing the
        # normal start straight camera at (-58,-66), toward +X.
        for i,x in enumerate((-54,-38,-22,-6,10,26)):
            box('pit.garage-roof',x,7.7,-95,15,.55,10,'charcoal')
            box('pit.team-panel',x,4.8,-89.8,13,1.9,.12,'coral' if i%2 else 'ice-blue')
            for px in (x-6.7,x+6.7):
                box('pit.vertical-frame',px,3.8,-89.7,.28,7.2,.18,'bronze')
            for offset in (-4,0,4):
                box('pit.vent',x+offset,7.42,-93,.7,.17,5.2,'safety-yellow')
        # Existing collision piers and overhead x=4,z=±25 form the real span.
        for z in (-23,23):
            for y in (6.1,8.6):
                box('overpass.pier-cladding',4,y,z,2.08,.30,2.08,'bronze')
        for z in range(-24,25,6):
            beam('overpass.side-truss',(2.3,12,z),(2.3,15,z+3),.18,'safety-yellow')
            beam('overpass.side-truss',(5.7,12,z),(5.7,15,z+3),.18,'safety-yellow')
        beam('overpass.top-chord',(2.3,15,-24),(2.3,15,24),.26,'charcoal')
        beam('overpass.top-chord',(5.7,15,-24),(5.7,15,24),.26,'charcoal')
        for i,g in enumerate(data['race']['gates']):
            # Suspended gate signals with a 9 m minimum clear height, no new
            # columns or obstruction within any 32 m vehicle road ribbon.
            beam('sector.signal-yoke.%02d'%i,(g['x']-5,9,g['z']),(g['x']+5,9,g['z']),.16,'glow-amber')
            box('sector.panel.%02d'%i,g['x'],9.2,g['z'],2.4,.33,.72,'charcoal')

    elif map_id=='copper-bowl':
        # Goal camera at (40,3,0)->(52,1,0): the first thing in its view must
        # be an open frame at source scoring X=47, not a solid proxy at X=52.
        for side in (-1,1):
            mouth=side*47.05;back=side*51.36
            for z in (-8,8):
                beam('goal.front-post',(mouth,0,z),(mouth,5.05,z),.23,'hazard-white')
                beam('goal.side-roof',(mouth,5.05,z),(back,4.95,z),.17,'hazard-white')
                for xx in (mouth+side*1.6,mouth+side*3.2):
                    beam('goal.side-net',(xx,.35,z),(xx,4.9,z),.038,'salt')
            beam('goal.front-crossbar',(mouth,5.05,-8),(mouth,5.05,8),.24,'hazard-white')
            beam('goal.back-crossbar',(back,4.95,-8),(back,4.95,8),.16,'bronze')
            for z in range(-8,9,1):
                beam('goal.back-net',(back,.35,z),(back,4.94,z),.045,'salt')
            for y in (1,2,3,4):
                beam('goal.back-net-strand',(back,y,-8),(back,y,8),.042,'salt')
            # Visual slats on the inaccessible source-solid backboard face,
            # leaving real collision x=52 even without its opaque art cube.
            for z in range(-7,8,2):
                box('goal.backboard-strut',side*51.45,2.5,z,.09,4.7,.13,'bronze')
            # Sideline stands already have broad, high source-solid tiers.
            for tier in range(4):
                z=side*(34+4*tier)
                h=2.5+1.7*tier
                box('terrace.dark-step',0,h+.09,z,106,.16,2.7,'charcoal' if tier%2 else 'bronze')
                for x in range(-48,49,8):
                    box('terrace.seat',x,h+.22,z,6.6,.16,.56,'copper' if (x//8+tier)%2 else 'safety-yellow')
                box('terrace.riser-face',0,h-.7,z-side*1.92,106,1.1,.09,'red-earth')
            # Roof canopy supported visually by existing 15m light mast solids
            # at x=±62,z=±43, over seats with top height <8.
            outline=[(-63,side*36),(63,side*36),(66,side*53),(-66,side*53)]
            top=[(x,15.1,z) for x,z in outline]
            emit('grandstand.arched-canopy',top,[(0,1,2),(0,2,3)],'charcoal')
            for x in range(-60,61,12):
                beam('grandstand.rib',(x,15.25,side*37),(x,15.25,side*52),.29,'bronze')
                beam('grandstand.column',(x,7.7,side*46),(x,15.05,side*46),.18,'bronze')
            for x in (-62,62):
                beam('grandstand.mast-truss',(x,14.7,side*43),(x*.75,15.1,side*37),.31,'bronze')
            # Face-mounted digital scoreboard above the back pockets; no new
            # mass at player height or over the source scoring plane.
            box('scoreboard.body',0,12.0,side*50,22,4.5,.40,'charcoal')
            for x in (-7,-4,4,7):
                box('scoreboard.digit',x,12.2,side*49.74,.92,2.2,.08,'glow-amber')
            box('scoreboard.copper-wordmark',0,15.0,side*49.72,20,.33,.08,'bronze')
        for x in (-47,47):
            for z in (-27,27):
                tube('pitch.corner-marker',x,.055,z,.38,.08,'hazard-white',12)

    elif map_id=='tern-archipelago':
        # Seven source nodes are already enclosed by narrow, low bastion
        # collision. Roofline crenellations/signal masts rest on those walls.
        for p in data['art']['pieces']:
            if p['kind']!='box' or p['material']!='limestone' or p['h']!=5:continue
            x,z=p['x'],p['z']
            if p['w']<p['d']:
                for face in (-1,1):
                    for y in (1.35,3.75):
                        box('bastion.raised-stone-band',x+face*(p['w']/2+.02),y,z,.06,.25,p['d']-.12,'cedar')
            else:
                for face in (-1,1):
                    for y in (1.35,3.75):
                        box('bastion.raised-stone-band',x,y,z+face*(p['d']/2+.02),p['w']-.12,.25,.06,'cedar')
        for node in data['nodes']:
            x,z=node['x'],node['z'];w=23 if node['archetype']=='hq' else 18
            accent='coral' if node['id']=='hq-0' else 'ice-blue' if node['id']=='hq-1' else 'safety-yellow'
            for side in (-1,1):
                for dz in (-5,5):
                    box('bastion.watch-cap',x+side*w/2,5.8,z+dz,1.25,1.55,1.4,'charcoal')
                    box('bastion.signal-inset',x+side*w/2,5.8,z+dz,.08,.8,.85,accent)
            for dz in (-6,6):
                beam('bastion.safety-rail',(x-7,5.3,z+dz),(x+7,5.3,z+dz),.13,'bronze')
            if node['archetype'] in ('hq','relay'):
                mastx=x+w/2-1.5
                beam('bastion.aerial',(mastx,5.2,z),(mastx,13.5,z),.21,'charcoal')
                for y in (8,11.5):
                    beam('bastion.radio-dipole',(mastx-2.3,y,z),(mastx+2.3,y,z),.11,accent)
                tube('bastion.dish-head',mastx,13.7,z,.8,.26,'glow-amber',10)
        # Several nonwalkable shoals are OUTSIDE z=±80 or x=±120; the seven
        # authored island decks remain level, collision-aligned and reachable.
        for x in (-101,-55,-10,36,90):
            for side in (-1,1):
                z=side*84
                prism('outer.offshore-reef',[(x-8,z),(x-3,z+side*7),(x+6,z+side*9),(x+9,z+side*2)],-2,2.2,'limestone')
                beam('outer.windbreak',(x-3,2.2,z+side*6),(x+3,6.5,z+side*6),.25,'cedar')
        # Deposits on existing source-solid outer rocks only.
        for x in (-92,-68,-28,28,68,92):
            for z in (-72,69):
                prism('shore.eroded-crown',[(x-2,z-2),(x+2,z-2),(x+1.6,z+2),(x-2,z+2)],3,4.3,'sediment')
        for lane in data['lanes']:
            points=lane['waypoints']
            for i in range(len(points)-1):
                a,b=points[i],points[i+1]
                dx=b[0]-a[0];dz=b[1]-a[1];length=math.hypot(dx,dz)
                if length<.1:continue
                # Planar lane paint, not a physical false railing on the wide
                # low-tide navigation. Reflective causeway edge delineation.
                nx=-dz/length*lane['width']*.51;nz=dx/length*lane['width']*.51
                for side in (-1,1):
                    beam('causeway.edge-inlay',(a[0]+side*nx,.058,a[1]+side*nz),(b[0]+side*nx,.058,b[1]+side*nz),.055,'bronze')
        for depot in data['depots']:
            x,z=depot['x'],depot['z']
            for dx in (-4,4):
                box('depot.deck-slot',x+dx,.07,z,.8,.08,8,'charcoal')
            box('depot.identity',x,.08,z-5,7,.03,.2,'glow-amber')
