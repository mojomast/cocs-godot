"""Editable, small modular architectural kit for Blender 4.5 source builders.

No import-time scene mutation. Materials are passed by exact reviewed name; this
module neither selects Moth resources nor exports a scene. All dimensions use
Blender metres/Z-up. Callers place parts inside their revised authority envelope.
"""
import hashlib
import math


def _phase(identity):
    raw = hashlib.sha256(identity.encode('utf-8')).digest()
    return (int.from_bytes(raw[:4], 'big') / 2**32,
            int.from_bytes(raw[4:8], 'big') / 2**32)


class Kit:
    def __init__(self, source, export, materials, density):
        """Collections, exact Blender materials and reviewed tiles/metre table.

        `source` and `export` must be distinct collections in the same scene.
        No fallback material or global palette changes are permitted.
        """
        if source == export or not materials or set(materials) != set(density):
            raise ValueError('Distinct collections and complete reviewed material densities required')
        if any(not math.isfinite(v) or v <= 0 or v > 16 for v in density.values()):
            raise ValueError('Invalid UV repeat density')
        self.source, self.export = source, export
        self.materials, self.density = materials, density

    def mesh(self, name, vertices, faces, material, *, sector='default', bevel=0.035, smooth=True):
        import bpy
        if material not in self.materials or not name or not faces:
            raise ValueError('Unreviewed or empty kit mesh')
        data = bpy.data.meshes.new(name)
        data.from_pydata(vertices, [], faces)
        data.update(calc_edges=True)
        if any(p.area < 1e-8 for p in data.polygons):
            bpy.data.meshes.remove(data)
            raise ValueError('Degenerate kit face: ' + name)
        obj = bpy.data.objects.new(name, data)
        self.source.objects.link(obj)
        data.materials.append(self.materials[material])
        obj['kit_sector'] = sector
        obj['kit_material'] = material
        obj['kit_source'] = name
        # Fixed part-local planar UVs with stable phase; never use world/object
        # position. Linked copies retain identical non-swimming Moth UVs.
        uv = data.uv_layers.new(name='MothLocal')
        uv.active_render = True
        offset = _phase(name)
        for face in data.polygons:
            axis = max(range(3), key=lambda i: abs(face.normal[i]))
            axes = ((1, 2), (0, 2), (0, 1))[axis]
            for loop in face.loop_indices:
                point = data.vertices[data.loops[loop].vertex_index].co
                uv.data[loop].uv = tuple(point[i] * self.density[material] + offset[k]
                                         for k, i in enumerate(axes))
            face.use_smooth = smooth
        if bevel:
            modifier = obj.modifiers.new('Real edge highlight · 2 segments', 'BEVEL')
            modifier.width = bevel
            modifier.segments = 2
            modifier.affect = 'EDGES'
            modifier.loop_slide = True
        if smooth:
            modifier = obj.modifiers.new('Weighted face-area normals', 'WEIGHTED_NORMAL')
            modifier.keep_sharp = True
            modifier.weight = 50
        return obj

    def prism(self, name, center, size, material, **kwargs):
        x, y, z = center
        w, d, h = size
        if min(size) <= 0:
            raise ValueError('Prism size must be positive')
        vertices = [(x+sx*w/2, y+sy*d/2, z+sz*h/2)
                    for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
        faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
                 (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
        return self.mesh(name, vertices, faces, material, **kwargs)

    def instance(self, master, name, location, *, sector=None, rotation_z=0, scale=(1, 1, 1)):
        import bpy
        if master not in self.source.objects[:] or min(scale) <= 0:
            raise ValueError('Only positive-scale linked source instances are supported')
        obj = bpy.data.objects.new(name, master.data)
        self.source.objects.link(obj)
        obj.location = location
        obj.rotation_euler.z = rotation_z
        obj.scale = scale
        # Modifiers live on objects, not on the shared mesh datablock. A bare
        # linked-data copy would silently lose bevels and weighted normals.
        for source_modifier in master.modifiers:
            modifier = obj.modifiers.new(source_modifier.name, source_modifier.type)
            if modifier.type == 'BEVEL':
                modifier.width = source_modifier.width
                modifier.segments = source_modifier.segments
                modifier.affect = source_modifier.affect
                modifier.loop_slide = source_modifier.loop_slide
            elif modifier.type == 'WEIGHTED_NORMAL':
                modifier.keep_sharp = source_modifier.keep_sharp
                modifier.weight = source_modifier.weight
            else:
                raise ValueError('Unreviewed linked instance modifier: ' + modifier.type)
        obj['kit_sector'] = sector if sector is not None else master['kit_sector']
        obj['kit_material'] = master['kit_material']
        obj['kit_source'] = master['kit_source']
        return obj

    def framed_bay(self, label, origin, width, height, depth, *, frame, trim, sector='default', arch=False):
        """Three-dimensional portal bay: jambs, lintel, recessed reveal and sill.

        The opening remains empty; calling builder owns the actual wall/collider.
        Optional arch uses a curved multi-ring extruded span, not a flat decal.
        """
        if min(width, height, depth) <= 0 or width < 1.2 or height < 1.8:
            raise ValueError('Invalid portal dimensions')
        x, y, z = origin
        rail = min(.22, width * .09)
        columns = []
        for side in (-1, 1):
            columns.append(self.prism(f'{label}.jamb.{side}',
                (x+side*(width/2-rail/2), y, z+height/2),
                (rail, depth, height), frame, sector=sector, bevel=.045))
            self.prism(f'{label}.pilaster.{side}',
                (x+side*(width/2-rail*.5), y-depth*.55, z+height*.53),
                (rail*.7, depth*.22, height*.73), trim, sector=sector, bevel=.025)
        if arch:
            self.curved_rib(f'{label}.arched-lintel', (x, y, z+height*.76),
                            width*.46, width*.46+rail, depth, 0, math.pi,
                            frame, sector=sector, segments=20)
        else:
            self.prism(f'{label}.lintel', (x, y, z+height-rail/2),
                       (width, depth, rail), frame, sector=sector, bevel=.045)
        self.prism(f'{label}.reveal', (x, y+depth*.42, z+height*.55),
                   (width-2*rail, depth*.13, height*.7), trim, sector=sector, bevel=.025)
        self.prism(f'{label}.stepped-sill', (x, y-depth*.12, z+rail*.44),
                   (width+rail*.5, depth*1.28, rail*.55), trim, sector=sector, bevel=.035)
        return columns

    def curved_rib(self, name, center, inner, outer, depth, start, stop, material,
                   *, sector='default', segments=24):
        """Extruded annular rib in XZ, e.g. greenhouse hoop or vaulted pipe roof."""
        if not 0 < inner < outer or depth <= 0 or not 0 < stop-start <= 2*math.pi or not 6 <= segments <= 96:
            raise ValueError('Invalid curved rib')
        cx, cy, cz = center
        vertices = []
        for iy in (-1, 1):
            for radius in (inner, outer):
                for i in range(segments+1):
                    angle = start+(stop-start)*i/segments
                    vertices.append((cx+radius*math.cos(angle), cy+iy*depth/2,
                                     cz+radius*math.sin(angle)))
        n = segments+1
        faces = []
        for i in range(segments):
            faces += [(i, i+1, n+i+1, n+i),
                      (2*n+i, 3*n+i, 3*n+i+1, 2*n+i+1),
                      (i, 2*n+i, 2*n+i+1, i+1),
                      (n+i, n+i+1, 3*n+i+1, 3*n+i)]
        faces += [(0,n,3*n,2*n), (segments,2*n+segments,3*n+segments,n+segments)]
        return self.mesh(name, vertices, faces, material, sector=sector, bevel=.018)

    def pipe(self, name, points, radius, material, *, sector='default', sides=12):
        """Closed faceted manifold through 3D control points, parallel-transport rings."""
        from mathutils import Vector
        if len(points) < 2 or radius <= 0 or not 8 <= sides <= 24:
            raise ValueError('Invalid manifold profile')
        path = [Vector(p) for p in points]
        if any((b-a).length < .01 for a,b in zip(path, path[1:])):
            raise ValueError('Coincident manifold control points')
        rings = []
        previous = None
        for i, point in enumerate(path):
            tangent = ((path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized())
            normal = (Vector((0,0,1)) if abs(tangent.z) < .9 else Vector((1,0,0)))
            normal = (normal-tangent*normal.dot(tangent)).normalized() if previous is None else previous
            normal = (normal-tangent*normal.dot(tangent)).normalized()
            across = tangent.cross(normal).normalized()
            rings.extend([tuple(point+radius*(normal*math.cos(j*math.tau/sides)+across*math.sin(j*math.tau/sides)))
                          for j in range(sides)])
            previous = normal
        faces = [tuple(reversed(range(sides)))]
        for i in range(len(path)-1):
            for j in range(sides):
                nxt = (j+1)%sides
                faces.append((i*sides+j,i*sides+nxt,(i+1)*sides+nxt,(i+1)*sides+j))
        faces.append(tuple((len(path)-1)*sides+j for j in range(sides)))
        return self.mesh(name, rings, faces, material, sector=sector, bevel=.012)

    def build_export_batches(self, *, max_triangles=24000):
        """Apply bevel/normals to copies; join by sector/material for bounded art.

        Run after scene geometry is final and BEFORE saving the editable master.
        This only touches objects in the export collection, leaving linked source
        meshes/modifiers intact. The later material adapter/exporter owns Moth
        textures, glTF tangent settings, and production acceptance.
        """
        import bpy
        if self.export.objects[:] or not isinstance(max_triangles, int) or max_triangles < 1:
            raise ValueError('Fresh export collection and positive triangle cap required')
        groups = {}
        graph = bpy.context.evaluated_depsgraph_get()
        for obj in sorted(self.source.objects, key=lambda o: o.name):
            if obj.type != 'MESH' or obj.matrix_world.determinant() <= 0:
                raise ValueError('Source must be positive-handed mesh: ' + obj.name)
            material = obj['kit_material']
            if material not in self.materials:
                raise ValueError('Missing reviewed material: ' + obj.name)
            evaluated = obj.evaluated_get(graph)
            data = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                                   depsgraph=graph)
            if not data.uv_layers.get('MothLocal'):
                bpy.data.meshes.remove(data)
                raise ValueError('Lost repeat UVs after modifiers: ' + obj.name)
            data.transform(obj.matrix_world)
            if len(data.materials) != 1 or data.materials[0] != self.materials[material]:
                bpy.data.meshes.remove(data)
                raise ValueError('Unreviewed evaluated material slots: ' + obj.name)
            triangles = sum(max(0, len(poly.vertices)-2) for poly in data.polygons)
            key = (obj['kit_sector'], material)
            bins = groups.setdefault(key, [])
            if not bins or bins[-1][1] + triangles > max_triangles:
                bins.append(([], 0))
            items, count = bins[-1]
            if triangles > max_triangles:
                bpy.data.meshes.remove(data)
                raise ValueError('Single source mesh exceeds export triangle cap: ' + obj.name)
            copy = bpy.data.objects.new('export-part.'+obj.name, data)
            self.export.objects.link(copy)
            items.append(copy)
            bins[-1] = (items, count+triangles)
        results = []
        for (sector, material), bins in sorted(groups.items()):
            for index, (parts, _) in enumerate(bins):
                bpy.ops.object.select_all(action='DESELECT')
                for part in parts:
                    part.select_set(True)
                bpy.context.view_layer.objects.active = parts[0]
                # Joined mesh keeps explicit UV loops and the modifier-evaluated
                # bevel surfaces; it is never joined with a different material.
                if len(parts) > 1:
                    bpy.ops.object.join()
                batch = parts[0]
                batch.name = f'kit.{sector}.{material}.{index:02d}'
                batch['kit_sector'] = sector
                batch['kit_material'] = material
                batch['kit_export_only'] = True
                results.append(batch)
        bpy.ops.object.select_all(action='DESELECT')
        return results
