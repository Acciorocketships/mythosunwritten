import unittest
import copy
from pathlib import Path
import numpy as np
from export_prefab_derivation import derive, material_bindings, matrix, stock_match, drawer_displacement, articulated_match
from audit_prefab_vocabulary import read_glb

class DerivationTests(unittest.TestCase):
    def test_drawer_slide_has_one_bounded_degree_of_freedom(self):
        original=matrix({'translation':[0,.481,.3322172165]})
        for z in [.493,.495,.507]:
            candidate=matrix({'translation':[0,.481,z]})
            self.assertAlmostEqual(drawer_displacement(original,candidate,.592047),z-.3322172165)
        for translation in [[.01,.481,.493],[0,.50,.493],[0,.481,.2],[0,.481,1.0]]:
            self.assertIsNone(drawer_displacement(original,matrix({'translation':translation}),.592047))
        for changed in [{'translation':[0,.481,.493],'rotation':[0,1,0,0]},
                        {'translation':[0,.481,.493],'scale':[1,1,1.1]}]:
            self.assertIsNone(drawer_displacement(original,matrix(changed),.592047))

    def test_drawer_rule_reconstructs_whole_stock_and_rejects_other_changes(self):
        path=Path(__file__).resolve().parents[2]/'tests/fixtures/suntail-cupboard-stock.glb.bin'
        stock,binary=read_glb(path)
        source=copy.deepcopy(stock)
        source['nodes'][1]['translation'][2]=.5070000290870667
        source['nodes'][0]['translation']=[3.975,4.12772,-2.593]
        result=articulated_match(source,binary,0,stock,binary)
        self.assertIsNotNone(result)
        self.assertEqual(len(result[0]),2)
        self.assertEqual(result[1]['node'],'Cupboard_1_Box')
        self.assertAlmostEqual(result[1]['displacement'],.17478281259536743)
        bad=copy.deepcopy(source)
        bad['meshes'][0]['primitives'][0]['mode']=1
        self.assertIsNone(articulated_match(bad,binary,0,stock,binary))
        bad=copy.deepcopy(source)
        bad['nodes'][1]['rotation']=[0,1,0,0]
        self.assertIsNone(articulated_match(bad,binary,0,stock,binary))
        bad=copy.deepcopy(source)
        bad['nodes'][0]['children']=[]
        self.assertIsNone(articulated_match(bad,binary,0,stock,binary))
        bad=copy.deepcopy(source)
        bad['nodes'][0]['children']=[1,1]
        self.assertIsNone(articulated_match(bad,binary,0,stock,binary))

    def test_authored_material_override_is_explicit(self):
        self.assertEqual(material_bindings([('mesh',('Wood','Planks'),np.eye(4))],
                                          [('mesh',('Wood','Plaster'),np.eye(4))]),
                         [['Wood','Planks']])

    def test_geometry_and_child_pose_mismatches_are_rejected(self):
        source=[('mesh',('Wood',),np.eye(4))]
        self.assertIsNone(material_bindings(source,[('other',('Wood',),np.eye(4))]))
        moved=np.eye(4);moved[0,3]=.01
        self.assertIsNone(material_bindings(source,[('mesh',('Wood',),moved)]))

    def test_repeated_meshes_are_consumed_once(self):
        source=[('mesh',('Wood',),np.eye(4))]
        self.assertIsNone(material_bindings(source,source+source))

    def test_nested_mirror_and_translation_preserve_full_affine_pose(self):
        parent=matrix({'translation':[2,3,4],'scale':[-1,2,1]})
        child=matrix({'translation':[1,1,1]})
        np.testing.assert_allclose((parent@child)[:3,3],[1,5,5])
        self.assertLess(np.linalg.det((parent@child)[:3,:3]),0)

    def test_renamed_stock_keeps_authored_pose_and_material_override(self):
        stock_pose=matrix({'translation':[1,2,3],'rotation':[0,1,0,0]})
        source_pose=matrix({'translation':[3,5,7],'scale':[-1,1,1]})
        result=stock_match([('finial',('DarkMetal',),source_pose)],
                           [('Finial',[('finial',('Metal',),stock_pose)])])
        self.assertEqual(result[0],'Finial')
        np.testing.assert_allclose(result[1]@stock_pose,source_pose)
        self.assertEqual(result[2],[['DarkMetal']])

    def test_renamed_door_leaf_cannot_import_an_extra_frame(self):
        leaf=('door',('Wood',),np.eye(4))
        frame=('frame',('Stone',),np.eye(4))
        self.assertIsNone(stock_match([leaf],[('DoorAndFrame',[leaf,frame])]))

    def test_one_alignment_must_fit_every_child(self):
        original=[('frame',('Wood',),np.eye(4)),
                  ('door',('Wood',),matrix({'translation':[1,0,0]}))]
        changed=[original[0],('door',('Wood',),matrix({'translation':[2,0,0]}))]
        self.assertIsNone(stock_match(original,[('ChangedDoor',changed)]))

    def test_modified_structure_is_rebuilt_from_verified_native_children(self):
        base=Path(__file__).resolve().parents[2]/'assets/PureVillage/Models'
        result=derive(base/'Houses/House_16c.glb',
                      [base/'Architecture',base/'Doors',base/'Structures'])
        self.assertTrue(result['complete'],result['unmatched'])
        modules=[p['module'] for p in result['parts']]
        self.assertNotIn('HouseStairs3',modules)
        self.assertIn('Stone_Stair_2',modules)
        self.assertIn('Stone_Block_9',modules)

    def test_glazed_storefront_uses_its_explicit_structure_stock(self):
        base=Path(__file__).resolve().parents[2]/'assets/PureVillage/Models'
        result=derive(base/'Houses/House_6b.glb',
                      [base/'Architecture',base/'Doors',base/'Structures'])
        self.assertTrue(result['complete'],result['unmatched'])
        facades=[p for p in result['parts'] if p['module']=='StoreFacade2']
        self.assertEqual(len(facades),2)
        for facade in facades:
            self.assertEqual(Path(facade['module_source']),base/'Structures/StoreFacade2.glb')
            self.assertGreater(len(facade['materials']),1)

if __name__=='__main__':unittest.main()
