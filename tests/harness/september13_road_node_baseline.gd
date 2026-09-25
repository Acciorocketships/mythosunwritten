extends SceneTree
const Before = preload("res://tests/fixtures/september13/WorldPathsBefore.gd")
const Nodes = preload("res://tests/test_path_plan_nodes.gd")
func _init() -> void:
	var water := Nodes.DryPlanningWater.new(4242)
	var heights := HeightfieldPlan.new(4242,1,1,"mean",1)
	heights.set_raw_height_override(func(_x:int,_z:int)->float:return 0.0)
	var fields := WorldFieldBlockCache.new(heights,water,28,0,256)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var paths := Before.new(4242,water,fields,program,program.query_margin,SettlementPlan.new(4242,water))
	for x in range(-4,5): paths.node_for(Vector2i(x,0))
	print("BASELINE water_build_count=",fields.water_build_count," expected<=9")
	quit(0 if fields.water_build_count<=9 else 1)
