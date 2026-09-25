"""Measure exported panel geometry at the unchanged native wall/corner sockets."""
import json
import struct
import unittest
import numpy as np
import build_siding as author


def read_faces(path):
    blob=path.read_bytes(); size=struct.unpack_from('<I',blob,12)[0]
    doc=json.loads(blob[20:20+size]); base=20+size+8
    triangles=[]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            accessor=doc['accessors'][primitive['attributes']['POSITION']]
            view=doc['bufferViews'][accessor['bufferView']]
            offset=base+view.get('byteOffset',0)+accessor.get('byteOffset',0)
            data=np.frombuffer(blob,dtype='<f4',count=accessor['count']*3,offset=offset).reshape(-1,3,3).astype(float)
            triangles.append(data)
    return np.concatenate(triangles)


class SidingContract(unittest.TestCase):
    def test_stones_remain_closed_after_native_socket_fitting(self):
        stock=np.array(json.loads(author.STOCK.read_text())['wall']['points']).reshape(-1,3,3)
        for width,height in [(3,4),(6,8),(12,12),(24,16)]:
            for index,(vertices,triangles) in enumerate(author.panel(width,height,stock)+author.volumetric_panel(width,height)):
                # Count edges after the same float32 conversion as the file.
                _,inverse=np.unique(vertices.astype('<f4'),axis=0,return_inverse=True)
                faces=inverse[triangles]
                edges=np.sort(np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1)
                _,counts=np.unique(edges,axis=0,return_counts=True)
                self.assertTrue((counts==2).all(),f'{width}x{height} stone {index}: open/nonmanifold edges')

    def test_native_corner_sockets_remain_continuous(self):
        stock=np.array(json.loads(author.STOCK.read_text())['wall']['points']).reshape(-1,3,3)
        for width,height in [(3,4),(6,8),(12,12),(24,16)]:
            faces=read_faces(author.OUT/f'wall_{width}x{height}.glb')
            ys=np.arange(-.295,height-.3,.031)
            for side in [-1,1]:
                points=np.column_stack([np.full(len(ys),side*(width/2-.00001)),ys])
                old_points=points.copy();old_points[:,0]=side*(1.5-.00001);old_points[:,1]=(ys+.3)%4-.3
                actual=author.native_depth(points,faces)
                expected=author.native_depth(old_points,stock)
                error=np.abs(actual-expected).max()
                self.assertLess(error,.005,f'{width}x{height} side {side}: socket error {error}')

    def test_finite_triangles_and_declared_grid_envelope(self):
        for width in author.WIDTHS:
            for height in author.HEIGHTS:
                faces=read_faces(author.OUT/f'wall_{width}x{height}.glb')
                self.assertTrue(np.isfinite(faces).all())
                area=np.linalg.norm(np.cross(faces[:,1]-faces[:,0],faces[:,2]-faces[:,0]),axis=1)
                self.assertGreater(area.min(),1e-9,f'{width}x{height}')
                points=faces.reshape(-1,3)
                np.testing.assert_allclose(points[:,:2].min(axis=0),[-width/2,-.3],atol=.00001)
                np.testing.assert_allclose(points[:,:2].max(axis=0),[width/2,height-.3],atol=.00001)
                self.assertGreaterEqual(points[:,2].min(),.19999)
                self.assertLessEqual(points[:,2].max(),2.831)

if __name__=='__main__':unittest.main()
