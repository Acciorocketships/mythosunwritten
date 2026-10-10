extends GutTest
const ROCKS = preload("res://scripts/terrain/field/CliffSlopeRocks.gd")

func test_large_batches_keep_every_rock_and_pebble_fades_stay_local() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires real MultiMesh readback")
		return
	var entries := {}
	for name in ["angry_01","angry_06"]:
		entries[name] = []
		for x in [-60.0,-28.0,4.0,36.0]:
			entries[name].append({"transform":Transform3D(Basis(),Vector3(x,8,4)),
				"normal":Vector3.UP,"point":Vector3(x,7,4),"tint":Color(.2,.3,.4),"exposure":.5,"grade":.25})
	var root := ROCKS.build(entries,2697992464)
	var counts := {}
	var seen := {}
	for node: Node in root.get_children():
		if not node is MultiMeshInstance3D: continue
		var small: bool = node.visibility_range_end > 0
		var name := "angry_06" if small else "angry_01"
		counts[name] = int(counts.get(name,0)) + 1
		if small:
			assert_eq(node.visibility_range_end,70.0)
			assert_eq(node.visibility_range_end_margin,10.0)
			assert_eq(node.cast_shadow,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		else: assert_eq(node.cast_shadow,GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		for i in node.multimesh.instance_count:
			var pose: Transform3D = node.multimesh.get_instance_transform(i)
			var key := [name,pose]
			assert_false(seen.has(key),"no duplicated rock")
			seen[key] = true
	assert_eq(counts.get("angry_01"),2,"large rocks share 64 m cells")
	assert_eq(counts.get("angry_06"),4,"pebble fade cells remain 32 m")
	assert_eq(seen.size(),8)
	for name: String in entries:
		for rock: Dictionary in entries[name]:
			assert_true(seen.has([name,rock.transform * ROCKS._pieces[name][1]]),"exact rendered transform retained")
	assert_eq(root.get_node("CliffSlopeRockCollision").get_child_count(),8,"all original hulls retained")
	root.free()
	_ignore_catalog_uid_warnings()

func _ignore_catalog_uid_warnings() -> void:
	# Existing catalogue UID migrations fall back to valid paths. Keep all
	# assertions and every other engine/push error actionable.
	for error: GutTrackedError in gut.error_tracker.get_current_test_errors():
		if error.is_engine_error() and error.contains_text("invalid UID") and error.contains_text("using text path instead"):
			error.handled = true
