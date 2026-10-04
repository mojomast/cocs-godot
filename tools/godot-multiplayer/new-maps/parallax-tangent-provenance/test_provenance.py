"""Source-only regression for PNG address, supplied TBN and exported-UV derivative.

This deliberately tests a non-symmetric image, not an engine or renderer.
"""
import math
import unittest


# Top-down PNG order: each row and column differs; green straddles neutral 128.
PNG_ROWS = (
    ((201, 210, 246), (172, 193, 239), (189, 181, 242)),
    ((162, 64, 247), (212, 75, 239), (175, 83, 250)),
    ((188, 218, 248), (159, 204, 244), (207, 197, 236)),
    ((208, 88, 246), (168, 96, 251), (193, 72, 242)),
)


def sample_top_down(u, v):
    return PNG_ROWS[math.floor(v * len(PNG_ROWS))][math.floor(u * len(PNG_ROWS[0]))]


def sample_blender_bottom_up(u, v):
    # Blender's OIIO negative row stride loads the first PNG row into the last
    # ImBuf row. Blender's UV v=0 addresses the bottom internal row.
    return PNG_ROWS[len(PNG_ROWS) - 1 - math.floor(v * len(PNG_ROWS))][math.floor(u * len(PNG_ROWS[0]))]


def normal(pixel, *, w=1, invert_green=False):
    # Plane P(u,v)=(u,v,0): N=+Z, T=+X, B=cross(N,T)*w=+Y*w.
    x, y, z = (2 * channel / 255 - 1 for channel in pixel)
    if invert_green:
        y = -y
    result = (x, y * w, z)
    length = math.sqrt(sum(a*a for a in result))
    return tuple(a / length for a in result)


class ImageAddressAndSuppliedBasis(unittest.TestCase):
    def test_asymmetric_png_preserves_location_and_authored_world_normal(self):
        height, width = len(PNG_ROWS), len(PNG_ROWS[0])
        for row in range(height):
            for column in range(width):
                with self.subTest(row=row, column=column):
                    u = (column + 0.5) / width
                    v_blender = (height - row - 0.5) / height
                    v_gltf = 1 - v_blender
                    authored = sample_blender_bottom_up(u, v_blender)
                    exported = sample_top_down(u, v_gltf)
                    self.assertEqual(exported, authored)
                    self.assertNotEqual(sample_top_down(u, v_blender), authored)
                    self.assertNotEqual(authored[1], 128)
                    # glTF exported-coordinate derivative dP/dv'=-Y on this
                    # plane; its derived sign is -1, but Blender supplied +1.
                    # Both render equations still perturb in the same direction.
                    self.assertEqual(normal(exported, w=1), normal(authored, w=1))
                    self.assertNotEqual(normal(exported, w=-1), normal(authored, w=1))
                    self.assertNotEqual(normal(exported, w=1, invert_green=True), normal(authored, w=1))
                    # Two simultaneous inversions can cancel in this fixture;
                    # this is not a recommendation to alter immutable pixels.
                    self.assertEqual(normal(exported, w=-1, invert_green=True), normal(authored, w=1))


if __name__ == '__main__':
    unittest.main()
