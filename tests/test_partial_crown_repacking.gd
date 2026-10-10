extends GutTest

func test_blocked_remainder_does_not_prevent_a_full_roof_on_clear_crown():
 var designer := BuildingDesigner.new(SuntailBuildingKit.create())
 designer.forbidden = func(cell:Vector2i, band:int): return cell.x < 0 and band >= 7
 var mass := BuildingMass.new()
 var exposed := BuildingMass.rect_cells(Rect2i(-2,0,4,1))
 exposed.merge(BuildingMass.rect_cells(Rect2i(0,1,2,1)))
 mass.add_storey(4,exposed,BuildingMass.MATERIAL_TIMBER)
 var original:Array[Rect2i]=[Rect2i(-2,0,4,1),Rect2i(0,1,2,1)]
 var result := designer._repack_slivers(mass,original,exposed,6)
 assert_has(result,Rect2i(0,0,2,2),'Clear half of the crown forms a full-width roof')
 var union := {}
 for rect:Rect2i in result:
  for cell:Vector2i in BuildingMass.rect_cells(rect):
   assert_false(union.has(cell),'Repacking never overlaps cells')
   union[cell]=true
 assert_eq(union.size(),exposed.size(),'Crown area remains exact')
 for cell:Vector2i in exposed:assert_has(union,cell)
