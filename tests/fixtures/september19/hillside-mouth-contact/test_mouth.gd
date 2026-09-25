extends GutTest
const STUDY=preload("res://tests/fixtures/september19/hillside-mouth-contact/profile_grade.gd")
func points()->PackedVector2Array:
	return PackedVector2Array([Vector2(0,0),Vector2(6,0),Vector2(12,0),Vector2(18,0),Vector2(24,0),Vector2(30,0),Vector2(30,6)])
func receivers()->Array[Dictionary]:
	return [{"index":5,"a":Vector2(30,0),"b":Vector2(30,6),"wa":8.0,"wb":8.0,"head":2.0}]
func test_tributary_meets_receiving_water_before_its_centreline()->void:
	var h:=PackedFloat32Array([10,9,8,7,5,2,2]);var g:=PackedFloat32Array([0,0,0,0,0,0,0])
	var result:=STUDY.receiver_caps(points(),h,g,receivers())
	assert_eq(result[4],2.0,"The last tributary station is already inside receiving water")
	assert_eq(result[3],7.0,"The receiving footprint cannot flatten unrelated upstream water")
	assert_eq(result[6],2.0,"Retain the supplied downstream reach")
	assert_eq(h,PackedFloat32Array([10,9,8,7,5,2,2]))
func test_real_bank_and_unsupplied_channels_do_not_receive_lower_heads()->void:
	var h:=PackedFloat32Array([10,9,8,7,5,2,2]);var g:=PackedFloat32Array([0,0,0,0,4,0,0])
	assert_eq(STUDY.receiver_caps(points(),h,g,receivers()),h,"A ground barrier blocks receiver contact")
	assert_eq(STUDY.receiver_caps(points(),h,g,[]),h,"No declared confluence means no hydraulic head transfer")
func test_contact_and_upstream_grade_keep_sill_clearance()->void:
	var h:=PackedFloat32Array([10,9,8,7,5,2,2]);var g:=PackedFloat32Array([0,0,6,0,0,0,0])
	var capped:=STUDY.receiver_caps(points(),h,g,receivers())
	var result:=STUDY.constrain(points(),capped,g,.22)
	assert_eq(result[4],2.0)
	assert_gte(result[2],6.09999)
	for i in result.size()-1:assert_gte(result[i],result[i+1])
func test_receiver_cannot_reach_across_a_dry_gap_in_the_upstream_trace()->void:
	var p:=points();p[4]=Vector2(15,0);p[3]=Vector2(27,0)
	var h:=PackedFloat32Array([10,9,8,7,5,2,2]);var g:=PackedFloat32Array([0,0,0,0,0,0,0])
	assert_eq(STUDY.receiver_caps(p,h,g,receivers()),h,"Contact stops at first departure; a nearby disconnected turn is not the mouth")
func test_confluence_inside_a_dense_descent_uses_its_own_span()->void:
	var plan:=HeightfieldPlan.new(2697992464,128,32)
	plan.set_raw_height_override(func(_x,_z):return 0.0)
	var region:=plan.compute_region(0,0,4)
	var trace:=RiverTrace.new()
	trace.points=PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(24,0)])
	trace.widths=PackedFloat32Array([8,8,8]);trace.beds=PackedFloat32Array([8,2,0])
	trace.set_meta("receiver_stations",PackedInt32Array([1]))
	var d:Dictionary={"lo":0,"hi":2,"pos":PackedVector2Array([Vector2(0,0),Vector2(6,0),Vector2(12,0),Vector2(18,0),Vector2(24,0)]),"w":PackedFloat32Array([8,8,8,8,8]),"lvl":PackedFloat32Array([10,7,4,3,2])}
	var shaped:=STUDY.shape(trace,region,PackedFloat32Array([10,4,2]),[d])
	assert_eq(shaped.descents[0].lvl[1],4.0,"A receiver inside a dense span still owns its submerged approach")
	assert_eq(shaped.descents[0].bank_sources,PackedInt32Array([-1,-1,-1,-1]))
