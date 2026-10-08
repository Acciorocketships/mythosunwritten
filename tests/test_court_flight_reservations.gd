extends GutTest

func test_climbing_stride_cannot_excavate_reserved_bearing_above_its_lower_tread() -> void:
 var massif := WarrenMassif.new(43)
 for z in range(-2,6):
  for x in range(-2,6): massif.columns[Vector2i(x,z)]={"base":0,"top":12}
 var excavation := WarrenExcavation.new(43)
 var start := Vector3i(0,4,0)
 var ordinary := WarrenPassageLatticeRules.stride_cells(massif,excavation,{},start,Vector2i.DOWN,1,3)
 assert_eq(ordinary.size(),3,"unreserved flight remains available")
 # At the first intermediate column the rounded tread is band 4, but the
 # compiler reserves the entire flight through band 6 for its upper headroom.
 excavation.construction_reservations[Vector3i(0,6,1)]=true
 var refused := WarrenPassageLatticeRules.stride_cells(massif,excavation,{},start,Vector2i.DOWN,1,3)
 assert_true(refused.is_empty(),"honour the full flight envelope before sacrificing a court house")
 excavation.construction_reservations.clear()
 excavation.construction_reservations[Vector3i(0,7,1)]=true
 assert_eq(WarrenPassageLatticeRules.stride_cells(massif,excavation,{},start,Vector2i.DOWN,1,3).size(),3,"a complete bearing course above headroom remains legal")

func test_reserved_bridge_end_houses_count_as_court_frontages_at_their_room_height() -> void:
 var massif := WarrenMassif.new(43)
 var columns: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)]
 for z in range(-2,3):
  for x in range(-2,5): massif.columns[Vector2i(x,z)]={"base":0,"top":12}
 var excavation := WarrenExcavation.new(43)
 var fronts := [Vector2i(0,-1),Vector2i(1,-1),Vector2i(2,-1)]
 excavation.bridge_span_audit["seeded"]=[{"floor":8,"top":10,"endpoint_foundation_floor":2,"endpoint_foundation_groups":[fronts],"endpoint_groups":[[Vector2i(0,-1)]]}]
 var plan := WarrenMazeSourcePlan.new(43,WarrenVillageScaleProfile.for_id(&"grand"),massif,excavation)
 var blocked := {}
 for c in massif.columns: blocked[c]=true
 assert_eq(WarrenPlotReservations.plaza_buildable_frontages(plan,columns,4,{},blocked),1,"committed lower bridge houses form a real continuous court edge")
 assert_eq(WarrenPlotReservations.plaza_buildable_frontages(plan,columns,8,{},blocked),0,"narrow upper room cannot imply a full-width upper facade")
 assert_eq(WarrenPlotReservations.plaza_buildable_frontages(plan,columns,11,{},blocked),0,"no imagined rooms above their roof")
