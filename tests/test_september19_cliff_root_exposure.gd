extends GutTest
const ROCKS = preload("res://scripts/terrain/field/CliffRockDressing.gd")
var sources: Array
var hidden: Dictionary
var exposed: Dictionary

func before_all() -> void:
	ROCKS.prepare()
	sources = FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
	var plants: Array = FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/source-plants.bin",FileAccess.READ).get_var()
	for plant: Dictionary in plants:
		if plant.support_point.distance_to(Vector3(-443.2065,14.1,366.625))<.001: hidden = plant
	var visible: Array = FileAccess.open("res://docs/qa/2026-09-19-manual/132-bank-source-shapes/plants.bin",FileAccess.READ).get_var()
	for plant: Dictionary in visible:
		if plant.support_point.distance_to(hidden.support_point)>5:
			exposed = plant
			break
	assert(not hidden.is_empty() and not exposed.is_empty())

func test_root_hidden_by_adjacent_native_rock_is_not_published() -> void:
	assert_true(reconsider(hidden).is_empty(),"The original fern root is 6.5 cm behind the neighboring wall, even though its 10 cm probe escapes it")

func test_an_exposed_native_root_retains_its_pose_and_identity() -> void:
	var retained := reconsider(exposed)
	assert_eq(retained.size(),1)
	if retained.size()==1:
		assert_eq(retained[0].transform,exposed.transform)
		assert_eq(retained[0].id,exposed.id)

func reconsider(plant: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = [{"point":plant.support_point,"normal":plant.support_normal,"kind":plant.attachment}]
	return ROCKS._plant_anchors(candidates,plant.support_id,null,2697992464,null,null,sources,1)
