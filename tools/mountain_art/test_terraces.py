"""Measure real ledge triangles and basal width, not generator metadata."""
import unittest
import numpy as np
import build_kit


class TerraceContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets = build_kit.kit()

    def test_intermediate_plantable_shoulders(self):
        for name, parts in self.assets.items():
            if name.startswith('shelf'): continue
            with self.subTest(asset=name):
                points = np.concatenate([v[t] for v, t in parts])
                normal = np.cross(points[:, 1]-points[:, 0], points[:, 2]-points[:, 0])
                area = np.linalg.norm(normal, axis=1)*.5
                up = normal[:, 1]/(area*2)
                y = points.mean(axis=1)[:, 1]
                height = points[:, :, 1].max()
                # Ignore buried fracture faces. An intermediate ledge must be
                # visible from above the assembled asset, not inside a crack.
                exposed = np.zeros(len(points), dtype=bool)
                a, b, c = points[:, 0], points[:, 1], points[:, 2]
                e, f = b-a, c-a
                det = e[:, 0]*f[:, 2]-e[:, 2]*f[:, 0]
                usable = abs(det) > 1e-8
                safe = np.where(usable, det, 1)
                for i in np.flatnonzero((up > .82) & (area > .05) & (y < height*.83)):
                    p = points[i].mean(axis=0)
                    d = p-a
                    u = (d[:, 0]*f[:, 2]-d[:, 2]*f[:, 0])/safe
                    v = (e[:, 0]*d[:, 2]-e[:, 2]*d[:, 0])/safe
                    hits = usable & (u >= 0) & (v >= 0) & (u+v <= 1)
                    heights = a[:, 1] + u*e[:, 1] + v*f[:, 1]
                    exposed[i] = not np.any(hits & (heights > p[1]+.015))
                # Three separated intermediate elevations must offer actual upward
                # surfaces; vertical moss or a planted crown alone cannot pass.
                bands = []
                for low, high in [(0.15, .38), (.38, .60), (.60, .83)]:
                    bands.append(area[exposed & (y > height*low) & (y < height*high)].sum())
                self.assertGreater(min(bands), 3.0, (name, bands))

    def test_lower_half_broadens_the_grounded_form(self):
        for name, parts in self.assets.items():
            if name.startswith('shelf'): continue
            with self.subTest(asset=name):
                v = np.concatenate([p[0] for p in parts])
                height = v[:, 1].max()
                # Depth is independent of the existing side-by-side crown columns.
                base = np.ptp(v[v[:, 1] < height*.12, 2])
                upper = np.ptp(v[v[:, 1] > height*.78, 2])
                self.assertGreater(base/upper, 1.4, name)


if __name__ == '__main__': unittest.main()
