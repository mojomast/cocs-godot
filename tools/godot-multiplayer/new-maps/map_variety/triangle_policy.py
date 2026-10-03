"""Total triangle counts inform review; they are not an acceptance ceiling."""
TARGET_TRIANGLES = 150000


def triangle_advisory(total, measurement):
    if type(total) is not int or total < 0:
        raise ValueError('Triangle total must be a known nonnegative integer')
    if measurement not in ('source-estimate', 'evaluated-scene', 'exported-glb'):
        raise ValueError('Unknown triangle measurement provenance')
    return {'policy': 'advisory', 'measurement': measurement,
            'totalTriangles': total, 'targetTriangles': TARGET_TRIANGLES,
            'overTarget': total > TARGET_TRIANGLES,
            'overageTriangles': max(0, total-TARGET_TRIANGLES),
            'status': 'pending-performance-visual-review'}
