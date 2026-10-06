extends RefCounted
## StreetHouse_8c's inhabited arcade and stepped rear facade remain together.
## The closed upper course at y=9 has the same wall boundary as the course below;
## its removal moves the complete crown, including eaves and dormer, down 3 m.
## Two upper storeys reproduce the original prefab exactly. Town admission must
## reserve the complete arcade/roof envelope and prove both entrance approaches.
const DATA := "res://terrain/environment/grammar/streethouse8c.json"
const OPTIONAL_COURSE := 9.0
const CROWN := 12.0
const COURSE_HEIGHT := 3.0


static func sample(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var storeys := rng.randi_range(1, 2)
	# Keep the exact source prefab in the sampling distribution, alongside
	# the measured window alternatives and shortened course variant.
	var window := "Window_1_2"
	if storeys == 2:
		window = ["", "Window_1_2", "Window_5_2"][rng.randi_range(0, 2)]
	return {"upper_storeys": storeys, "upper_side_window": window}


static func derive(upper_storeys: int = 2, upper_side_window: String = "") -> Array[Dictionary]:
	assert(upper_storeys in [1, 2], "Only the measured upper-course interface is admitted")
	assert(upper_side_window in ["", "Window_1_2", "Window_5_2"])
	assert(
		upper_storeys == 2 or upper_side_window != "Window_5_2",
		"Projecting hoods need an inhabited course below the eave"
	)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(source.complete)
	var out: Array[Dictionary] = []
	for value: Dictionary in source.parts:
		var m: Array = value.matrix
		var pose := Transform3D(
			Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])),
			Vector3(m[12], m[13], m[14])
		)
		if is_equal_approx(pose.origin.y, OPTIONAL_COURSE):
			assert(
				(
					String(value.module).begins_with("Wall_")
					or String(value.module).begins_with("Window_")
				)
			)
			if upper_storeys == 1:
				continue
		elif pose.origin.y >= CROWN - .0001:
			pose.origin.y -= (2 - upper_storeys) * COURSE_HEIGHT
		var replacement := ""
		if (
			upper_storeys == 1
			and value.module == "Window_19_2"
			and is_equal_approx(pose.origin.y, 6.0)
		):
			replacement = "Window_1_2"
		if value.module == "Wall_Middle1_30x30_1" and pose.origin.is_equal_approx(Vector3(3, 6, 0)):
			replacement = upper_side_window
		# The two middle front bays share the native 3 m wall interface. Use
		# complete flush window panels beneath the arcade floor, where a hood
		# would compete with the curved side brackets. The unmodified source
		# remains available when no facade variation is requested.
		if (
			not upper_side_window.is_empty()
			and value.module == "Wall_Middle1_30x30_1"
			and absf(pose.origin.y - 3.0) < .0001
			and absf(pose.origin.z - 1.375) < .0001
			and absf(absf(pose.origin.x) - 1.5) < .0001
		):
			replacement = "Window_1_2"
		var selected: Dictionary = (
			value if replacement.is_empty() else source.facade_variants[replacement]
		)
		out.append(
			{
				"module": String(value.module) if replacement.is_empty() else replacement,
				"module_source": String(selected.module_source),
				"asset_id": StringName(selected.get("asset_id", "")),
				"transform": pose,
				"source_node": int(value.source_node),
				"materials": selected.materials
			}
		)
	return out
