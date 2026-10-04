extends GutTest

class FullMargin extends HeightfieldPlan:
	func storey_margin() -> int: return max_storeys

func test_cliff_step_limits_the_sampled_dependency_radius() -> void:
	var plan := TerrainWorldTuning.make_heightfield(17)
	plan.set_raw_height_override(func(_x: int,_z: int) -> float: return 128.0)
	plan.compute_region(0,0,4)
	# The clamp's influence reaches storey_margin() = ceil(max storeys / step)
	# cells (eleven at 32 storeys, when this bound was 2500; 22 at the 64-storey
	# range of 2026-10-03); the window adds the four owned cells and a fixed
	# level/cliff-search pad of ten.
	var reach := 4+plan.storey_margin()+10
	assert_lte(plan._samples.size(),(2*reach+1)*(2*reach+1),"A three-storey step cannot transmit a %d-storey influence beyond %d cells" % [TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS,plan.storey_margin()])

func test_reduced_domain_matches_full_domain_at_every_owned_sample() -> void:
	for step: int in [1,2,3,5]:
		var narrow := HeightfieldPlan.new(17,128,32,"mean",step)
		var wide := FullMargin.new(17,128,32,"mean",step)
		for offset: int in [0,9,10,11,12,31,32,33]:
			# A single zero amid maximum targets gives the longest possible
			# clamp influence. Move it across both the new and old boundaries.
			var source := func(x: int,z: int) -> float:
				return 0.0 if x==offset and z==0 else 131.0
			narrow.set_raw_height_override(source)
			wide.set_raw_height_override(source)
			var a := narrow.compute_region(0,0,4)
			var b := wide.compute_region(0,0,4)
			for z in range(-4,5):
				for x in range(-4,5):
					assert_eq(a.surface_height(x,z),b.surface_height(x,z),"step %d source %d cell %s" % [step,offset,Vector2i(x,z)])
