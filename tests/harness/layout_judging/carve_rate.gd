extends SceneTree
## Share of production-rolled towns whose source carves (massif + maze):
##   -- COUNT [FIRST]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var count := int(a[0]) if not a.is_empty() else 300
	var first := int(a[1]) if a.size() > 1 else 1
	var ok := 0
	var by_label: Dictionary = {}
	for i in range(first, first + count):
		var seed_value := Helper._mix64(i * 7919 + 17)
		var profile := WarrenVillageScaleProfile.select(seed_value)
		var massif := WarrenMassifBuilder.build(seed_value, {}, profile)
		var carved := massif != null and WarrenMazeCarver.carve(seed_value, massif, profile, false, false) != null
		ok += int(carved)
		if not carved:
			print("CARVE_FAIL i=%d seed=%d size=%.3f label=%s why=%s" % [i, seed_value, profile.size if "size" in profile else -1.0, profile.scale_id, WarrenMazeCarver.last_failure])
		var row: Array = by_label.get(profile.scale_id, [0, 0])
		row[0] += int(carved)
		row[1] += 1
		by_label[profile.scale_id] = row
	print("CARVE_RATE ok=%d/%d %s" % [ok, count, by_label])
	quit()
