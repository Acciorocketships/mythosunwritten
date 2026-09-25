extends GutTest
const SIDING := preload("res://scripts/terrain/field/CliffSiding.gd")

func _coverage(panels: Dictionary) -> Dictionary:
	var out := {}
	for asset: String in panels:
		var size := asset.trim_prefix("wall_").split("x")
		var width := int(size[0])/3
		var height := int(size[1])/4
		for pose: Transform3D in panels[asset]:
			for y in height:
				for x in width:
					var point := pose*Vector3((float(x)-float(width-1)*.5)*3.0,float(y)*4.0,0)
					var key := str(point.snapped(Vector3.ONE*.001))+str(pose.basis.z.round())
					out[key]=int(out.get(key,0))+1
	return out

func _single(transforms: Array) -> Dictionary:
	return _coverage({"wall_3x4":transforms})

func test_contiguous_faces_merge_without_filling_the_missing_step_slots() -> void:
	for turn in 4:
		var poses := []
		var basis := Basis(Vector3.UP,PI*.5*turn)
		for x in range(-16,16):
			for y in range(0,4 if x<0 else (2 if x<7 else 1)):
				# Preserve nonzero native level phase too.
				var point := basis*Vector3(float(x)*3.0+1.5,1.0+float(y)*4.0,10.5)
				poses.append(Transform3D(basis,point))
		var panels := SIDING.panels(poses)
		assert_eq(_coverage(panels),_single(poses),"Exact original occupied slots, no overlaps or invented rock across a lower step")
		var count := 0
		for rows: Array in panels.values(): count+=rows.size()
		assert_lt(count,poses.size()/3,"Long faces use larger panels")
		poses.reverse()
		assert_eq(SIDING.panels(poses),panels,"Input order cannot change native art ownership")

func test_chunk_partition_does_not_change_panel_ownership() -> void:
	for turn in 4:
		var left := [];var right := [];var all := []
		var basis := Basis(Vector3.UP,PI*.5*turn)
		for x in range(-64,64):
			for y in 3:
				var pose := Transform3D(basis,basis*Vector3(float(x)*3.0+1.5,float(y)*4.0,10.5))
				all.append(pose)
				if x<4: left.append(pose)
				else: right.append(pose)
		var combined := SIDING.panels(left)
		for key: String in SIDING.panels(right):
			if not combined.has(key): combined[key]=[]
			combined[key].append_array(SIDING.panels(right)[key])
		assert_eq(_coverage(combined),_coverage(SIDING.panels(all)),"No missing or duplicate chunk seam")
		var actual := []
		var expected := []
		for key: String in combined:
			for pose: Transform3D in combined[key]: actual.append(key+str(pose))
		for key: String in SIDING.panels(all):
			for pose: Transform3D in SIDING.panels(all)[key]: expected.append(key+str(pose))
		actual.sort();expected.sort()
		assert_eq(actual,expected,"Both chunks choose identical complete panel transforms")
