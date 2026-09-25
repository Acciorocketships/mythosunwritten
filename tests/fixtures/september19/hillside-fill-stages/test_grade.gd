extends GutTest
const EIGHT = preload("res://tests/fixtures/september19/hillside-fill-stages/eight_field.gd")
func selected():
	return WaterField if OS.get_environment("GRADE_CONTROL")=="four" else EIGHT
func test_diagonal_descent_obeys_distance_in_world_metres() -> void:
	var h:=PackedFloat32Array([1,100,100,100])
	selected()._reconcile_connected_surface(h,PackedFloat32Array([0,0,0,0]),2,3.0)
	assert_lte(h[3],1.0+0.3*Vector2(3,3).length()+0.00001,"A diagonal must not inherit the longer stair-step distance")
func test_touching_corners_do_not_connect_separate_pools() -> void:
	for dry in [-INF,1.0]:
		var h:=PackedFloat32Array([1,dry,dry,10])
		selected()._reconcile_connected_surface(h,PackedFloat32Array([0,2,2,0]),2,3.0)
		assert_eq(h[3],10.0,"A dry ridge must block diagonal water exchange, including finite below-ground samples")
func test_native_bed_and_dry_mask_are_preserved() -> void:
	var h:=PackedFloat32Array([1,10,-INF,10,10,10])
	var ground:=PackedFloat32Array([0,8,0,0,0,0])
	selected()._reconcile_connected_surface(h,ground,3,3.0)
	assert_eq(h[2],-INF)
	assert_gte(h[1],8.09999)
	for i in [0,1,3,4,5]:assert_gt(h[i],ground[i])
func test_settled_lake_is_unchanged_and_reconciliation_is_idempotent() -> void:
	var h:=PackedFloat32Array([5,5,5,5,5,5])
	var g:=PackedFloat32Array([0,0,0,0,0,0])
	assert_eq(selected()._reconcile_connected_surface(h,g,3,3.0),0)
	assert_eq(h,PackedFloat32Array([5,5,5,5,5,5]))
	h[0]=1
	selected()._reconcile_connected_surface(h,g,3,3.0)
	var once:=h.duplicate()
	selected()._reconcile_connected_surface(h,g,3,3.0)
	assert_eq(h,once)
