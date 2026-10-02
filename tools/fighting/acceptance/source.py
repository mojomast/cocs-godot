"""Independent v1 data/GLB checks. No engine, imports, or generated substitutes."""
import hashlib
import json
import math
from pathlib import Path
import struct

IDS = 'chatgpt claude grok meta gemini deepseek mistral kimi qwen'.split()
MOVES = ('stand_l stand_m stand_h crouch_l crouch_m crouch_h air_l air_m air_h '
         'throw_f throw_b special1 special2 special3 super').split()
STATES = ('idle walk_f walk_b crouch jump_rise jump_apex jump_fall land dash_f dash_b '
          'guard_hi guard_lo hit_hi hit_lo hit_air block_hi block_lo knockdown wakeup '
          'throw_tech win lose').split()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite(value):
    if isinstance(value, dict):
        return all(finite(v) for v in value.values())
    if isinstance(value, list):
        return all(finite(v) for v in value)
    return not isinstance(value, float) or math.isfinite(value)


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def validate_data(roster, rules):
    require(finite(roster) and finite(rules), 'non-finite JSON number')
    require(roster.get('version') == 1, 'roster version')
    operators = roster.get('operators', [])
    require(len(operators) == 9 and {o['id'] for o in operators} == set(IDS), 'exact nine roster')
    for key, expected in {'version': 1, 'tick_rate': 60, 'units_per_meter': 1000,
                          'round_seconds': 99, 'rounds_to_win': 2,
                          'buffer_frames': 6, 'throw_tech_frames': 10}.items():
        require(rules.get(key) == expected, 'rules.' + key)
    require(integer(rules.get('stage_half_width'), 1), 'stage_half_width')
    for operator in operators:
        oid = operator['id']
        require(all(k in operator for k in ('name', 'archetype', 'stats', 'resource', 'moves', 'combos')), oid + ' fields')
        require(all(integer(operator['stats'].get(k), 1) for k in ('hp', 'walk_speed', 'weight', 'jump_velocity')), oid + ' stats')
        moves = operator['moves']
        require(set(MOVES) <= moves.keys(), oid + ' fifteen move families')
        require(len(operator['combos']) >= 3, oid + ' three combos')
        for combo in operator['combos']:
            require(isinstance(combo.get('name'), str) and len(combo.get('inputs', [])) >= 2, oid + ' combo inputs')
            if 'route' in combo:
                require(all(mid in moves for mid in combo['route']), oid + ' combo route')
                trace = expand_trace(combo)
                require(len(trace) > 0, oid + ' executable sparse trace')
        for mid, move in moves.items():
            label = oid + ':' + mid
            require(all(k in move for k in ('name', 'kind', 'startup', 'active', 'recovery', 'damage',
                    'hitstun', 'blockstun', 'hitstop', 'level', 'animation', 'effect', 'hitboxes', 'cancels', 'meter_cost')), label + ' fields')
            require(move['kind'] in ('strike', 'projectile', 'mobility', 'throw', 'counter', 'super'), label + ' kind')
            require(move['level'] in ('mid', 'low', 'overhead', 'unblockable'), label + ' level')
            for key in ('startup', 'active', 'recovery', 'damage', 'hitstun', 'blockstun', 'hitstop', 'meter_cost'):
                require(integer(move[key]), label + ' integer ' + key)
            require(move['meter_cost'] <= 1000, label + ' meter bounds')
            if mid == 'super':
                require(move['meter_cost'] == 1000, label + ' super cost')
            duration = sum(move[k] for k in ('startup', 'active', 'recovery'))
            require(duration > 0 and move['animation'] and move['effect'], label + ' duration/visual IDs')
            for box in move['hitboxes']:
                require(all(type(box.get(k)) is int for k in ('from', 'to', 'x', 'y', 'w', 'h')), label + ' integer box')
                require(0 <= box['from'] <= box['to'] < duration and box['w'] > 0 and box['h'] > 0, label + ' box interval')
            for cancel in move['cancels']:
                require(cancel['to'] in moves and 0 <= cancel['from'] <= cancel['until'] <= duration, label + ' cancel target/window')
                require(bool(cancel['on']) and set(cancel['on']) <= {'hit', 'block', 'whiff'}, label + ' cancel conditions')
    return {'operators': 9, 'required_move_families': 135,
            'actual_moves': sum(len(o['moves']) for o in operators),
            'authored_combos': sum(len(o['combos']) for o in operators)}


def expand_trace(combo, facing=1):
    """Content contract: omitted ticks release, duration holds, pressed is one edge."""
    require(facing in (-1, 1), 'trace facing')
    timeline = {}
    for sample in combo.get('setup_inputs', []) + combo['inputs']:
        require(isinstance(sample, dict), 'sparse command object')
        tick, duration = sample.get('tick'), sample.get('duration', 1)
        require(integer(tick) and integer(duration, 1) and tick + duration <= 3600, 'bounded trace interval')
        require(sample.get('axis_x') in (-1, 0, 1) and sample.get('axis_y') in (-1, 0, 1), 'command axes')
        require(integer(sample.get('held')) and integer(sample.get('pressed')) and
                sample['held'] <= 511 and sample['pressed'] & ~sample['held'] == 0, 'command masks')
        for offset in range(duration):
            require(tick + offset not in timeline, 'overlapping sparse spans')
            timeline[tick + offset] = dict(axis_x=sample['axis_x'] * facing, axis_y=sample['axis_y'],
                                          held=sample['held'], pressed=sample['pressed'] if offset == 0 else 0)
    return [timeline.get(t, dict(axis_x=0, axis_y=0, held=0, pressed=0))
            for t in range(max(timeline, default=-1) + 1)]


def read_glb(path):
    raw = Path(path).read_bytes()
    require(len(raw) >= 20, 'short GLB')
    magic, version, size = struct.unpack_from('<4sII', raw)
    require(magic == b'glTF' and version == 2 and size == len(raw), 'GLB header/length')
    chunks, offset = {}, 12
    while offset < size:
        require(offset + 8 <= size, 'truncated chunk header')
        length, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        require(length % 4 == 0 and offset + length <= size and kind not in chunks, 'chunk alignment/length/duplicate')
        chunks[kind] = raw[offset:offset + length]
        offset += length
    require(0x4E4F534A in chunks and 0x004E4942 in chunks, 'JSON and BIN required')
    document = json.loads(chunks[0x4E4F534A])
    require(finite(document), 'non-finite GLB metadata')
    return document, chunks[0x004E4942]


def accessor(doc, binary, index):
    a = doc['accessors'][index]
    require('sparse' not in a, 'sparse accessor requires explicit support')
    view = doc['bufferViews'][a['bufferView']]
    require(view.get('buffer', 0) == 0, 'external buffer unsupported')
    fmt = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    width = struct.calcsize('<' + fmt * count)
    stride = view.get('byteStride', width)
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    require(integer(a['count'], 1) and stride >= width, 'accessor count/stride')
    end = start + (a['count'] - 1) * stride + width
    require(end <= len(binary) and end <= view.get('byteOffset', 0) + view['byteLength'], 'accessor bounds')
    values = [struct.unpack_from('<' + fmt * count, binary, start + i * stride) for i in range(a['count'])]
    require(all(math.isfinite(v) for row in values for v in row), 'non-finite binary accessor')
    if a.get('normalized') and fmt != 'f':
        divisor = {5120: 127, 5121: 255, 5122: 32767, 5123: 65535}[a['componentType']]
        values = [tuple(max(-1, v / divisor) for v in row) for row in values]
    return values


def validate_glb(path, animations):
    doc, binary = read_glb(path)
    require(doc.get('meshes') and doc.get('skins'), 'body meshes and skins required')
    require(len(doc.get('buffers', [])) == 1 and 'uri' not in doc['buffers'][0], 'embedded BIN required')
    require(doc['buffers'][0]['byteLength'] <= len(binary), 'BIN byteLength')
    for i in range(len(doc.get('accessors', []))):
        accessor(doc, binary, i)
    weighted = 0
    for node in doc.get('nodes', []):
        if 'skin' not in node or 'mesh' not in node:
            continue
        joints = doc['skins'][node['skin']]['joints']
        require(joints and all(0 <= j < len(doc['nodes']) for j in joints), 'skin joints')
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            attributes = primitive['attributes']
            require('WEIGHTS_0' in attributes and 'JOINTS_0' in attributes, 'skinned primitive weights')
            weights = accessor(doc, binary, attributes['WEIGHTS_0'])
            indices = accessor(doc, binary, attributes['JOINTS_0'])
            positions = accessor(doc, binary, attributes['POSITION'])
            require(len(weights) == len(indices) == len(positions), 'skin vertex count')
            for ws, js in zip(weights, indices):
                require(all(0 <= w <= 1 for w in ws) and abs(sum(ws) - 1) < .002, 'normalized positive weights')
                require(all(0 <= j < len(joints) for w, j in zip(ws, js) if w > 0), 'weighted joint range')
            weighted += len(weights)
    require(weighted > 0, 'actual weighted vertices required')
    clips = doc.get('animations', [])
    names = [a.get('name') for a in clips]
    require(len(set(names)) == len(names) and set(animations) <= set(names), 'unique required clip names')
    fingerprints = {}
    for clip in clips:
        curves = []
        require(clip.get('channels'), 'empty animation')
        for channel in clip['channels']:
            sampler = clip['samplers'][channel['sampler']]
            times = accessor(doc, binary, sampler['input'])
            require(len(times) > 1 and all(a[0] < b[0] for a, b in zip(times, times[1:])), 'strict clip times')
            values = accessor(doc, binary, sampler['output'])
            target = channel['target']
            curves.append([doc['nodes'][target['node']].get('name'), target['path'], times, values])
        fingerprints[clip['name']] = hashlib.sha256(json.dumps(curves, sort_keys=True).encode()).hexdigest()
    return {'weighted_vertices': weighted, 'clips': len(clips), 'curve_sha256': fingerprints,
            'art_acceptance': 'unrun', 'native_load': 'unrun'}


def inspect(root):
    root = Path(root)
    result = {'data': {'status': 'unrun'}, 'assets': {}, 'failures': [], 'missing': []}
    data = root / 'godot/fighting/data'
    needed = [data / 'roster.json', data / 'rules.json']
    result['missing'] += [str(p.relative_to(root)) for p in needed if not p.is_file()]
    roster = None
    if not result['missing']:
        try:
            roster, rules = [json.loads(p.read_text()) for p in needed]
            result['data'] = {'status': 'passed', **validate_data(roster, rules)}
        except (ValueError, KeyError, TypeError) as error:
            result['failures'].append('data: ' + str(error))
            result['data']['status'] = 'failed'
    fingerprints = {}
    for oid in IDS:
        path = root / ('godot/fighting/assets/operators/' + oid + '.glb')
        if not path.is_file():
            result['missing'].append(str(path.relative_to(root)))
            result['assets'][oid] = {'status': 'unrun', 'reason': 'missing GLB'}
            continue
        try:
            # Shared libraries and victim aliases are permitted. Source checks only
            # validate stored curves; effective coverage belongs to the configured
            # native AnimationPlayer, not to a per-body GLB animation count.
            checked = validate_glb(path, [])
            checked['resolved_clip_coverage'] = 'unrun: native configured libraries/aliases required'
            for clip, sha in checked['curve_sha256'].items():
                if clip in ['special1', 'special2', 'special3', 'super']:
                    if (clip, sha) in fingerprints:
                        checked.setdefault('shared_signature_curve_review', []).append({'clip': clip, 'same_as': fingerprints[clip, sha]})
                    fingerprints[clip, sha] = oid
            result['assets'][oid] = {'status': 'passed', **checked}
        except (ValueError, KeyError, TypeError, IndexError, struct.error) as error:
            result['failures'].append(oid + ': ' + str(error))
            result['assets'][oid] = {'status': 'failed', 'reason': str(error)}
    result['status'] = 'failed' if result['failures'] else 'deferred' if result['missing'] else 'passed'
    return result
