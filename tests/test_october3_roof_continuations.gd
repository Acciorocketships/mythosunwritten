extends GutTest

func test_equal_width_gable_continuations_keep_the_host_ridge() -> void:
	for axis in 2:
		var main := Rect2i(-8,0,3,2) if axis==1 else Rect2i(0,-8,2,3)
		for sign_value in [-1,1]:
			var branch := main
			branch.position[axis]+=main.size[axis]*sign_value
			var chosen := BuildingDesigner._wing_axis(branch,1-axis,main,axis)
			assert_eq(chosen,axis,"An equal-profile continuation shares the host ridge")
			var mass := BuildingMass.new()
			mass.add_roof(main,axis,4,&"blue")
			mass.add_roof(branch,chosen,4,&"blue")
			var masses: Array[BuildingMass]=[mass]
			KitRoofJunctions.join(masses)
			assert_eq(mass.roofs.size(),1,"The continuation merges, leaving no exposed internal gable")
			assert_eq((mass.roofs[0].rect as Rect2i).get_area(),main.get_area()*2)

func test_wider_or_offset_wing_is_not_forced_into_host_profile() -> void:
	var main := Rect2i(-8,0,3,2)
	assert_eq(BuildingDesigner._wing_axis(Rect2i(-8,2,4,2),0,main,1),0)
	assert_eq(BuildingDesigner._wing_axis(Rect2i(-7,2,3,2),0,main,1),0)
