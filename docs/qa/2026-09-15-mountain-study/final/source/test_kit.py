"""Physical/source contract for the original mountain kit, independent of rendering."""
import unittest
from collections import Counter
import numpy as np
import build_kit


class MountainMeshContract(unittest.TestCase):
    def test_closed_outward_non_degenerate_solids(self):
        for name, parts in build_kit.kit().items():
            for vertices, triangles in parts:
                v = np.asarray(vertices, dtype=np.float64)
                t = np.asarray(triangles)
                edges = Counter(tuple(sorted(e)) for f in t for e in
                                [(f[0], f[1]), (f[1], f[2]), (f[2], f[0])])
                self.assertTrue(all(n == 2 for n in edges.values()), name)
                a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
                self.assertTrue(np.isfinite(v).all(), name)
                self.assertGreater(np.linalg.norm(np.cross(b-a, c-a), axis=1).min(), 1e-5, name)
                self.assertGreater(np.einsum('ij,ij->i', a, np.cross(b, c)).sum()/6, 1, name)
                directed = Counter((int(f[j]), int(f[(j+1)%3])) for f in t for j in range(3))
                self.assertTrue(all(directed[(b,a)] == n for (a,b),n in directed.items()), name)

    def test_determinism_and_bounded_native_scale(self):
        first, second = build_kit.kit(), build_kit.kit()
        self.assertEqual(first.keys(), second.keys())
        for name, parts in first.items():
            for (v,t), (v2,t2) in zip(parts, second[name]):
                np.testing.assert_array_equal(v,v2)
                np.testing.assert_array_equal(t,t2)
            points = np.concatenate([p[0] for p in parts])
            self.assertGreaterEqual(points[:,1].min(), -1e-6, name)
            self.assertLess(points[:,1].max(), 80, name)
            self.assertLess(sum(len(p[1]) for p in parts), 15000, name)


if __name__ == '__main__':
    unittest.main()
