extends GutTest

func test_false_certificate_contains_no_path_for_transformed_primitives_and_lattice() -> void:
	var shapes: Array[FeatureGroundShape] = [
		FeatureGroundShape.circle(Vector2(-24,0),2.3,1),
		FeatureGroundShape.capsule(Vector2(-9,-19),Vector2(29,31),0.08,1),
		FeatureGroundShape.oriented_rect(Vector2(23.9,-24.1),Vector2(6,0.13),0.72,1),
		FeatureGroundShape.axis_rect(Rect2(2,2,20,20),0,200)]
	var field := FeatureGroundField.new(shapes,[],0,{Vector2i(-2,-2):5},{Vector2i(2,2):true})
	var checked := 0
	var rejected := 0
	for z in range(-72,73,2):
		for x in range(-72,73,2):
			var area := Rect2(Vector2(x,z),Vector2.ONE*2)
			if field.may_have_path_in(area): continue
			rejected += 1
			for iz in 9:
				for ix in 9:
					var point := area.position + Vector2(ix,iz)*0.25
					if field.surface_at(point)==FeatureGroundField.WORN_PATH:
						fail_test("False rejection at %s in %s" % [point,area])
						return
					checked += 1
	assert_gt(rejected,4000)
	assert_gt(checked,300000)

func test_closed_boundary_and_narrow_path_are_not_rejected() -> void:
	var field := FeatureGroundField.new([
		FeatureGroundShape.axis_rect(Rect2(24,24,0.01,0.01),1)],[],0)
	assert_true(field.may_have_path_in(Rect2(22,22,2,2)))
	assert_true(field.may_have_path_in(Rect2(24,24,2,2)))
	assert_false(field.may_have_path_in(Rect2(30,30,2,2)))

func test_scoped_sampler_preserves_lattice_overrides_and_subpixel_boundaries() -> void:
	var shapes: Array[FeatureGroundShape] = [
		FeatureGroundShape.capsule(Vector2(-19,-17),Vector2(27,28),0.08,1,100),
		FeatureGroundShape.oriented_rect(Vector2(23.9,-24.1),Vector2(6,0.13),0.72,1,100),
		FeatureGroundShape.axis_rect(Rect2(-3,-3,6,6),0,200)]
	var field := FeatureGroundField.new(shapes,[],0,{Vector2i.ZERO:5},{Vector2i(-1,-1):true})
	for z in range(-30,31,2):
		for x in range(-30,31,2):
			var area := Rect2(Vector2(x,z),Vector2.ONE*2)
			var sample := field.surface_sampler_in(area)
			for iz in 9:
				for ix in 9:
					var point := area.position+Vector2(ix,iz)*0.25
					if int(sample.call(point)) != field.surface_at(point):
						fail_test("Scoped mismatch at %s" % point)
						return
	pass_test("All 77,841 sampled classifications preserved")
