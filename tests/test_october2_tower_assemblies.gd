extends GutTest
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")


func _host() -> BuildingMass:
	var host := BuildingMass.new()
	for band in [0, 2, 4]:
		host.add_storey(band, BuildingMass.rect_cells(Rect2i(0, -3, 4, 3)), BuildingMass.MATERIAL_TIMBER)
	return host


func test_attachment_requires_complete_host_and_never_covers_a_door() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var pose := Transform3D(Basis.IDENTITY, Vector3(4, 3, 0))
	var host := _host()
	assert_false(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.CORBELLED_HALF, Callable()).is_empty())
	host.storeys[0].cells.erase(Vector2i(1, -1))
	assert_true(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.CORBELLED_HALF, Callable()).is_empty(),
		"A missing host cell under the corbel cannot be hidden by the ornament.")
	host = _host()
	host.storeys[1].openings[Vector3i(1, -1, 1)] = BuildingMass.OPENING_DOOR
	assert_true(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.CORBELLED_HALF, Callable()).is_empty(),
		"Attachments cannot consume a host doorway.")
	host = _host()
	host.storeys[1].inset = true
	assert_true(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.CORBELLED_HALF, Callable()).is_empty(),
		"An inset wall leaves the half tower's rear unsupported.")


func test_complete_tower_roof_and_corbel_obey_public_or_neighbor_clearance() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var pose := Transform3D(Basis.IDENTITY, Vector3(4, 3, 0))
	var host := _host()
	for obstruction_band in [1, 3, 9]:
		var blocked := func(cell: Vector2i, band: int) -> bool:
			return cell.y >= 0 and band == obstruction_band
		assert_true(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.CORBELLED_HALF, blocked).is_empty(),
			"Whole-tower checks include its lower support and highest roof tip.")
	var eave_only := func(cell: Vector2i, band: int) -> bool:
		return cell.x == 0 and cell.y >= 0 and band == 6
	assert_true(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.CORBELLED_HALF, eave_only).is_empty(),
		"The roof is wider than its shaft and reserves the neighbouring column too.")


func test_grounded_towers_require_real_bearing_under_every_base_column() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var pose := Transform3D(Basis.IDENTITY, Vector3(4, 0, 0))
	var host := _host()
	assert_true(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.GROUNDED_HALF, Callable()).is_empty())
	var bearing := func(_cell: Vector2i, band: int) -> bool: return band == 0
	assert_false(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.GROUNDED_HALF, Callable(), bearing).is_empty())
	var partial := func(cell: Vector2i, _band: int) -> bool: return cell.x != 1
	assert_true(TOWER.fit(host, kit, catalog, pose, 2, TOWER.Form.GROUNDED_HALF, Callable(), partial).is_empty())


func test_attachment_admission_is_consistent_on_all_four_facades() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	for quarter_turn in 4:
		var rotation := Basis(Vector3.UP, quarter_turn * PI * 0.5)
		var host := BuildingMass.new()
		for floor: Dictionary in _host().storeys:
			var cells := {}
			for cell: Vector2i in floor.cells:
				var centre := rotation * Vector3(cell.x * 2.0 + 1.0, 0, cell.y * 2.0 + 1.0)
				cells[Vector2i(floori(centre.x / 2.0), floori(centre.z / 2.0))] = true
			host.add_storey(floor.floor_band, cells, BuildingMass.MATERIAL_TIMBER)
		var pose := Transform3D(rotation, rotation * Vector3(4, 3, 0))
		assert_false(TOWER.fit(host, kit, catalog, pose, 3, TOWER.Form.CORBELLED_HALF, Callable()).is_empty())
		var blocked := func(_cell: Vector2i, band: int) -> bool: return band == 11
		assert_true(TOWER.fit(host, kit, catalog, pose, 3, TOWER.Form.CORBELLED_HALF, blocked).is_empty())


func test_native_towers_join_courses_and_keep_the_complete_roof_envelope() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for storeys in range(2, 5):
		for form: int in [TOWER.Form.ROUND, TOWER.Form.GROUNDED_HALF, TOWER.Form.CORBELLED_HALF]:
			var parts := TOWER.parts(storeys, form)
			var envelope := TOWER.bounds(parts, catalog)
			assert_gt(envelope.size.x, 4.0, "The roof overhang exceeds two kit modules.")
			assert_gt(envelope.size.z, 4.0)
			if form == TOWER.Form.CORBELLED_HALF:
				assert_lt(envelope.position.y, -1.0, "The corbel needs host support below its first floor.")
			else:
				assert_almost_eq(envelope.position.y, 0.0, 0.001, "The grounded base must touch its bearing.")
			assert_almost_eq(envelope.end.y, float(storeys) * 3.0 + 5.205632, 0.001)
			var prior := AABB()
			for i in parts.size():
				var part: Dictionary = parts[i]
				var asset := catalog.descriptor(part.asset_id)
				assert_not_null(asset)
				var box: AABB = part.transform * asset.measured_aabb
				if i > 0:
					assert_lte(box.position.y, prior.end.y, "No open horizontal seam between native courses.")
				prior = box
			assert_eq(parts, TOWER.parts(storeys, form), "Assembly is reproducible.")


func test_half_towers_publish_the_host_height_for_the_open_rear() -> void:
	for storeys in range(2, 5):
		assert_eq(TOWER.host_height(storeys, TOWER.Form.ROUND), 0.0)
		for form: int in [TOWER.Form.GROUNDED_HALF, TOWER.Form.CORBELLED_HALF]:
			assert_eq(TOWER.host_height(storeys, form), float(storeys - 1) * 3.0)
			var parts := TOWER.parts(storeys, form)
			assert_eq(parts[-2].asset_id, &"pure_village.tower.window", "The top course closes all sides above the host.")


func test_baked_towers_have_collision_and_share_native_kit_textures() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var ids := {}
	for form: int in [TOWER.Form.ROUND, TOWER.Form.GROUNDED_HALF, TOWER.Form.CORBELLED_HALF]:
		for part: Dictionary in TOWER.parts(3, form): ids[part.asset_id] = true
	for id: StringName in ids:
		var visual := cache.visual(id)
		assert_not_null(visual)
		if visual == null: continue
		assert_false(visual.collisions.is_empty(), "Complete baked collision is required.")
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface)
				for property: Dictionary in material.get_property_list():
					if property.type != TYPE_OBJECT: continue
					var texture = material.get(property.name)
					if not texture is Texture2D: continue
					assert_true(texture.resource_path.begins_with("res://terrain/environment/textures/pure_village_kit/"),
						"New tower geometry reuses the existing native material maps.")


func test_native_cap_cut_matches_independent_vertical_ray_envelope() -> void:
	var data: Dictionary = FileAccess.open(TOWER.ROOF_GEOMETRY, FileAccess.READ).get_var()
	var surfaces: Array = data[&"pure_village.tower.roof"]
	var pose := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(13, 8.5, -7))
	var cutters := TOWER.roof_cutters(surfaces, pose)
	var checked := 0
	for x in range(-3, 4):
		for z in range(-3, 4):
			# Off-grid samples avoid shared source edges and roof symmetry.
			var origin := Vector3(float(x) * 0.55 + 0.071, 6, float(z) * 0.55 + 0.037)
			var top := -INF
			for surface: Dictionary in surfaces:
				var vertices: PackedVector3Array = surface.vertices
				var ids: PackedInt32Array = surface.indices
				for i in range(0, ids.size(), 3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN,
						vertices[ids[i]], vertices[ids[i + 1]], vertices[ids[i + 2]])
					if hit != null: top = maxf(top, (hit as Vector3).y)
			if top <= 0.01: continue
			checked += 1
			assert_true(_in_cutters(pose * Vector3(origin.x, top - 0.005, origin.z), cutters),
				"Host geometry immediately under the native roof skin is removed.")
			assert_false(_in_cutters(pose * Vector3(origin.x, top + 0.005, origin.z), cutters),
				"The cut never opens a gap above the actual native skin.")
			assert_false(_in_cutters(pose * Vector3(origin.x, -0.005, origin.z), cutters),
				"The cap does not cut the supporting shaft or facade below its base.")
	assert_gt(checked, 30, "The audit must cross both centre and outer slopes.")


func _in_cutters(point: Vector3, cutters: Array[Dictionary]) -> bool:
	for cutter: Dictionary in cutters:
		if not (cutter.bounds as AABB).grow(0.00001).has_point(point): continue
		var inside := true
		for plane: Plane in cutter.planes:
			if plane.distance_to(point) > 0.00001:
				inside = false
				break
		if inside: return true
	return false


func test_many_cutter_bounds_rejection_preserves_exact_triangle_output() -> void:
	const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var surface := {"vertices": PackedVector3Array([Vector3(-3, 1, -3), Vector3(3, 1, -3), Vector3(0, 1, 3)]),
		"normals": PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]),
		"uvs": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP]),
		"indices": PackedInt32Array([0, 1, 2])}
	var cutters: Array[Dictionary] = []
	var unfiltered: Array[Dictionary] = []
	for x in range(-4, 4):
		for z in range(-2, 2):
			var box := AABB(Vector3(x * 1.5, 0, z * 1.5), Vector3(0.3, 2, 0.3))
			var cutter := UNION.box_volume(box)
			cutters.append(cutter)
			var reference := cutter.duplicate()
			reference.erase("bounds")
			unfiltered.append(reference)
	var result := UNION.trim_surface(surface, Transform3D.IDENTITY, cutters)
	var reference := UNION.trim_surface(surface, Transform3D.IDENTITY, unfiltered)
	assert_true(result.changed, "The test must actually cut several holes, not compare two unchanged meshes.")
	for key: String in ["vertices", "normals", "uvs", "indices"]:
		assert_eq(result[key], reference[key], "Bounds rejection preserves exact " + key)


func test_compact_cap_core_stays_under_native_skin_and_reaches_main_taper() -> void:
	var data: Dictionary = FileAccess.open(TOWER.ROOF_GEOMETRY, FileAccess.READ).get_var()
	var cutters: Array = FileAccess.open(TOWER.ROOF_CORE, FileAccess.READ).get_var()
	assert_lte(cutters.size(), 40, "Curved cap junctions must not return to per-shingle clipping.")
	var checked := 0
	for x in range(-10, 11):
		for z in range(-10, 11):
			var origin := Vector3(x * 0.2 + 0.013, 6, z * 0.2 + 0.007)
			var native_top := -INF
			for surface: Dictionary in data[&"pure_village.tower.roof"]:
				var vertices: PackedVector3Array = surface.vertices
				var ids: PackedInt32Array = surface.indices
				for i in range(0, ids.size(), 3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN,
						vertices[ids[i]], vertices[ids[i + 1]], vertices[ids[i + 2]])
					if hit != null: native_top = maxf(native_top, (hit as Vector3).y)
			var core_top := _core_top(Vector2(origin.x, origin.z), cutters)
			assert_true(core_top <= native_top + 0.005,
				"A hidden cutter must not emerge through the actual authored cap.")
			# The ornate lip and metal finial are not the main join surface.
			# Bound the inward difference across the continuous tiled taper.
			if native_top < 0.4 or native_top > 3.8: continue
			checked += 1
			assert_gte(core_top, native_top - 0.15,
				"An overly deep envelope leaves the other roof crossing the cap.")
	assert_gt(checked, 250, "Check the main taper across the whole cap, not a few centre rays.")


func _core_top(point: Vector2, cutters: Array) -> float:
	var result := -INF
	for cutter: Dictionary in cutters:
		var lo := -INF
		var hi := INF
		for plane: Plane in cutter.planes:
			var d := plane.d - plane.normal.x * point.x - plane.normal.z * point.y
			if absf(plane.normal.y) < 0.000001:
				if d < 0: hi = -INF; break
			elif plane.normal.y > 0:
				hi = minf(hi, d / plane.normal.y)
			else:
				lo = maxf(lo, d / plane.normal.y)
		if lo <= hi and is_finite(hi): result = maxf(result, hi)
	return result


func test_native_attachments_participate_in_production_asset_demand() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({}, catalog)
	assert_not_null(program)
	if program == null: return
	var ids: Array[StringName] = [
		preload("res://scripts/terrain/features/villages/kit/KitRetainingRelief.gd").ASSET,
		preload("res://scripts/terrain/features/villages/kit/KitRetainingWindows.gd").ASSET]
	for form: TOWER.Form in [TOWER.Form.ROUND,TOWER.Form.GROUNDED_HALF,TOWER.Form.CORBELLED_HALF]:
		for storeys in range(1 if form == TOWER.Form.CORBELLED_HALF else 2,5):
			for part: Dictionary in TOWER.parts(storeys,form):
				if not ids.has(part.asset_id): ids.append(part.asset_id)
	for id: StringName in ids:
		assert_has(program.referenced_asset_ids,id,"Native attachments must be warmed by production demand")
		assert_eq(program.runtime_aabbs.get(id,AABB()),catalog.descriptor(id).measured_aabb,
			"Streaming bounds must include the complete authored geometry")
	for id: StringName in TOWER.asset_ids():
		assert_has(program.referenced_asset_ids,id,"Both native tower families must be warmed")
		assert_eq(program.runtime_aabbs.get(id,AABB()),catalog.descriptor(id).measured_aabb)
