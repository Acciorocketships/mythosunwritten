extends SceneTree
## Feasibility probe only: never changes or replaces a sealed town reservation.
const Site = preload("res://scripts/terrain/features/villages/grammar/NativeHouseSite.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var results: Array[Dictionary] = []
	for case: Dictionary in [
		{"seed": 7, "profile": &"standard"},
		{"seed": 31, "profile": &"large"},
		{"seed": 13, "profile": &"large"},
		{"seed": 43, "profile": &"grand"}
	]:
		var spatial := WarrenVolumetricSolver.generate(
			case.seed, {}, program, WarrenVillageScaleProfile.for_id(case.profile)
		)
		assert(spatial != null)
		for feature: WarrenFeatureReservation in spatial.features:
			if feature.kind != &"prefab_landmark":
				continue
			var landing: Vector3i = feature.audit.landmark_public_landing_cell
			var entrance: Vector3i = feature.audit.landmark_entrance_cell
			var outward := Vector3(landing - entrance).normalized()
			# Arrival at the inner edge of the existing 4 m landing cell.
			var arrival := Vector3(landing) * Vector3(4, 3, 4) - outward * 2.0
			var row := {
				"seed": case.seed,
				"profile": String(case.profile),
				"feature": String(feature.stable_id),
				"attempts": [],
				"fit_count": 0
			}
			for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
				for variation in 8:
					var site := Site.cross(
						catalog, dimensions.x, dimensions.y, variation, 2.0, arrival, outward
					)
					assert(site.ok, site.reason)
					var failures := {}
					var first := ""
					for part: Dictionary in site.parts:
						var box: AABB = (
							site.pose
							* part.transform
							* catalog.descriptor(Compiler.asset_id(part.module)).measured_aabb
						)
						# Rough native footing bevels may enter the ground by centimetres.
						var end := box.end
						box.position.y = maxf(box.position.y, site.ground_y)
						box.size = end - box.position
						for cell in cells(box):
							if not spatial.grid.reservation_owned_by(
								cell,
								WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE,
								feature.stable_id
							):
								failures[cell] = true
								if first.is_empty():
									first = "%s at %s" % [part.module, cell]
					var bearing_failures := {}
					for contact: AABB in site.bearing_bounds:
						contact.size.y = .01
						for cell in cells(contact):
							if not spatial.grid.reservation_owned_by(
								cell,
								WarrenSpatialGrid.Reservation.TERRAIN_BEARING,
								feature.stable_id
							):
								bearing_failures[cell] = true
					var fits := failures.is_empty() and bearing_failures.is_empty()
					if fits:
						row.fit_count += 1
					row.attempts.append(
						{
							"dimensions": str(dimensions),
							"variation": variation,
							"unreserved_visual_cells": failures.size(),
							"unreserved_bearing_cells": bearing_failures.size(),
							"first": first,
							"fits": fits
						}
					)
			results.append(row)
			print(
				"NATIVE_LANDMARK_FIT ", case.seed, " ", feature.stable_id, " ", row.fit_count, "/24"
			)
	var args := OS.get_cmdline_user_args()
	var output := (
		args[args.find("--output") + 1] if args.has("--output") else "/tmp/native-landmark-fit.json"
	)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(results, "  "))
	quit()


static func cells(box: AABB) -> Array[Vector3i]:
	var pitch := Vector3(4, 3, 4)
	var half := Vector3(2, 0, 2)
	var low := Vector3i(((box.position + half) / pitch + Vector3.ONE * .00001).floor())
	var high := Vector3i(((box.end + half) / pitch - Vector3.ONE * .00001).ceil())
	var result: Array[Vector3i] = []
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z):
				result.append(Vector3i(x, y, z))
	return result
