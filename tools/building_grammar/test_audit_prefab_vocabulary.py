import struct
import unittest
from audit_prefab_vocabulary import accessor_bytes, mesh_signature


class VocabularyIdentityTests(unittest.TestCase):
    def triangle(self, indices=(0, 1, 2), interleaved=False):
        points = [(0., 0., 0.), (1., 0., 0.), (0., 1., 0.)]
        positions = b''.join(struct.pack('<3f', *p) + (b'pad!' if interleaved else b'') for p in points)
        binary = positions + struct.pack('<3H', *indices)
        doc = {'bufferViews': [{'byteOffset': 0, 'byteStride': 16 if interleaved else 12},
                               {'byteOffset': len(positions)}],
               'accessors': [{'bufferView': 0, 'componentType': 5126, 'type': 'VEC3', 'count': 3},
                             {'bufferView': 1, 'componentType': 5123, 'type': 'SCALAR', 'count': 3}]}
        return doc, binary, {'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1}]}

    def test_storage_padding_does_not_change_geometry_identity(self):
        self.assertEqual(mesh_signature(*self.triangle()), mesh_signature(*self.triangle(interleaved=True)))

    def test_same_bounds_with_reversed_winding_is_not_a_match(self):
        self.assertNotEqual(mesh_signature(*self.triangle()), mesh_signature(*self.triangle((0, 2, 1))))

    def test_different_surface_attributes_are_not_a_match(self):
        doc, binary, mesh = self.triangle()
        before = mesh_signature(doc, binary, mesh)
        mesh['primitives'][0]['attributes']['NORMAL'] = 0
        self.assertNotEqual(before, mesh_signature(doc, binary, mesh))

    def test_unsupported_sparse_data_fails_explicitly(self):
        doc, binary, mesh = self.triangle()
        doc['accessors'][0]['sparse'] = {}
        with self.assertRaises(ValueError):
            accessor_bytes(doc, binary, 0)


if __name__ == '__main__':
    unittest.main()
