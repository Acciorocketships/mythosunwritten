extends RefCounted
## House_16c's continuous upper course is a measured repeat interface.
## The low side wing stays fixed; the main crown, dormers, brackets and turret
## cap move together. Zero extra courses is the exact authored derivation.
const DATA := "res://terrain/environment/grammar/house16c.json"
const UPPER_COURSE := 10.5
const CROWN_ATTACHMENTS := 12.875
const COURSE_HEIGHT := 3.0
const SHAFT_RADIUS := 1.71
const WINDOW_HALF_WIDTH := .6
const WINDOW_SIGHTLINE := 2.0


static func sample(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {"extra_upper_storeys": rng.randi_range(0, 1)}


static func derive(extra_upper_storeys: int = 0) -> Array[Dictionary]:
	assert(extra_upper_storeys in [0, 1], "Only measured course variations are admitted")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(document.complete)
	var out: Array[Dictionary] = []
	for value: Dictionary in document.parts:
		var m: Array = value.matrix
		var pose := Transform3D(
			Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])),
			Vector3(m[12], m[13], m[14])
		)
		var part := {
			"module": String(value.module),
			"asset_id": StringName(value.asset_id),
			"transform": pose,
			"source_node": int(value.source_node)
		}
		if pose.origin.y >= CROWN_ATTACHMENTS - .0001:
			part.transform.origin.y += extra_upper_storeys * COURSE_HEIGHT
		out.append(part)
		if is_equal_approx(pose.origin.y, UPPER_COURSE):
			assert(
				(
					String(value.module).begins_with("Wall_")
					or String(value.module).begins_with("Window_")
					or value.module == "StoneTower_Window_30x30"
				)
			)
			for course in extra_upper_storeys:
				var repeat := part.duplicate(true)
				repeat.transform.origin.y += (course + 1) * COURSE_HEIGHT
				repeat["repeated_course"] = course + 1
				out.append(repeat)
				if String(value.module) in ["Wall_Start_30x30_1", "Wall_End_30x30_1"]:
					out.append(
						{
							"module": "WindowSolo_6",
							"asset_id": &"pure_village.native.windowsolo_6",
							"transform":
							(
								repeat.transform
								* Transform3D(
									Basis.from_scale(Vector3.ONE * .77019), Vector3(0, .8, .25)
								)
							),
							"source_node": int(value.source_node),
							"role": &"course_window"
						}
					)
	return out.filter(
		func(part: Dictionary) -> bool:
			return part.get("role", &"") != &"course_window" or not _faces_shaft(part, out)
	)


static func _faces_shaft(window: Dictionary, parts: Array[Dictionary]) -> bool:
	# The corner cylinder owns the sightline of the immediately adjacent bay.
	# Keep its backing solid rather than burying glass behind the stone shaft.
	var pose: Transform3D = window.transform
	for part in parts:
		if part.module != "StoneTower_Window_30x30":
			continue
		var shaft: Vector3 = part.transform.origin
		if pose.origin.y < shaft.y or pose.origin.y >= shaft.y + COURSE_HEIGHT:
			continue
		var delta := shaft - pose.origin
		var forward := delta.dot(pose.basis.z.normalized())
		var across := absf(delta.dot(pose.basis.x.normalized()))
		if (
			forward > 0
			and forward < WINDOW_SIGHTLINE + SHAFT_RADIUS
			and across < SHAFT_RADIUS + WINDOW_HALF_WIDTH
		):
			return true
	return false
