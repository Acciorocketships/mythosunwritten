extends GutTest

## September 27 owner judging pass (seed 2697992464), "details" stream.
##  * photo 8: a miniature market stall floats inside a stall beside a building.
##  * photo 7: an L-shaped town approach path has a notch cut from its corner.
##  * photo 2: diagonal timber braces under an upper floor cross the arched
##    windows of the stone storey below.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
## (city seed, profile): the photo-2/7 town (frame centre (312,1056)), the
## photo-4/8 town (super (-1,1)) and a small corpus.
const TOWNS := [[1260018864828801968, &"compact"], [85830433957479026, &""],
	[2, &"compact"], [4, &"compact"], [3, &"standard"], [7, &"standard"]]

static var _towns: Array = []


func _built_towns() -> Array:
	if not _towns.is_empty():
		return _towns
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for job: Array in TOWNS:
		var profile := WarrenVillageScaleProfile.select(int(job[0])) \
			if StringName(job[1]).is_empty() else WarrenVillageScaleProfile.for_id(job[1])
		var source := WarrenMazeSitePlanner.plan(int(job[0]), {}, profile, &"", false)
		if source == null:
			continue
		var spatial := FROZEN.spatial(source, program)
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
		_towns.append({"id": "%d/%s" % [job[0], job[1]], "built": built})
	return _towns


# --- photo 8: a stall is redrawn once, as a whole -----------------------------

func test_a_stall_and_its_dressing_become_one_kit_stall() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	KitSubstitution.prepare(catalog, kit)
	var shops: Array = kit.roles[&"prop.shop"]
	var canopies: Array[StringName] = [SettlementFabricAssembler.PLAZA_MARKET_STALL,
		SettlementFabricProgram.ROOF_TERRACE_AWNING]
	for canopy: StringName in canopies:
		var source := EnvironmentInstancePayload.new()
		var at := Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, -6.0))
		source.add(canopy, at, Color.WHITE, &"stall")
		for goods: Dictionary in SettlementFabricAssembler.maze_stall_goods(canopy,
				at.origin, 0.0, Vector4i(1, 0, 2, 0)):
			source.add(StringName(goods.asset), goods.transform, Color.WHITE,
				StringName("stall/%s" % goods.station))
		var out := KitSubstitution.apply(source)
		var count := 0
		for asset_id: StringName in out.asset_ids():
			if shops.has(asset_id):
				count += (out.batches[asset_id].transforms as Array).size()
		assert_eq(count, 1, "%s: exactly one kit stall per legacy stall (no miniature copies)" % canopy)
		assert_false(out.batches.has(SettlementFabricProgram.COVERED_MARKET_HANGING_GOODS),
			"%s: the legacy canopy's hanging string has no canopy left to hang from" % canopy)
	# No catalog part of a stall (attachments, chimneys, supports, strings)
	# may be fitted with a whole kit stall.
	for asset_id: StringName in catalog.ids():
		if not String(asset_id).begins_with("sfm.stall."):
			continue
		var tags := catalog.descriptor(asset_id).tags
		var whole := tags.has(&"stall") and not tags.has(&"support")
		var probe := EnvironmentInstancePayload.new()
		probe.add(asset_id, Transform3D.IDENTITY, Color.WHITE, &"probe")
		var redrawn := false
		for id: StringName in KitSubstitution.apply(probe).asset_ids():
			redrawn = redrawn or shops.has(id)
		if not whole:
			assert_false(redrawn, "%s is a stall part, not a stall" % asset_id)


# --- photo 7: square path joints close their outer corner --------------------

func test_a_square_path_joint_closes_its_outer_corner() -> void:
	# The reported handoff: a 1.12 m incoming stub turning onto the town street
	# (too short for the fillet, so the joint is square).
	var points: Array[Vector2] = [Vector2(264.0, 1056.0), Vector2(265.1246, 1056.0),
		Vector2(265.1246, 1086.56)]
	var shapes := PathProgram.filleted_path_shapes(points, PathProgram.PATH_HALF_WIDTH,
		FeatureGroundField.WORN_PATH, 120, &"probe")
	var gaps := 0
	for x in range(0, 5):
		for z in range(0, 5):
			# The joint's outer corner: past the vertex along the incoming run,
			# on the side away from the outgoing run.
			var p := Vector2(265.1246, 1056.0) + Vector2(x, -z) * 0.49
			var covered := false
			for shape: FeatureGroundShape in shapes:
				covered = covered or shape.contains(p)
			gaps += int(not covered)
	assert_eq(gaps, 0, "the square joint's outer corner is painted")


# --- photo 2: supports never cross an opening --------------------------------

## Native-space box in front of a wall panel's aperture (window or door),
## in the panel's own frame: the opening plus the metre of air a wall-tied
## brace or bracket would cross (free-standing arcade posts stand farther out).
const OPENING_LOCAL := AABB(Vector3(-0.45, 1.05, -0.2), Vector3(0.9, 1.35, 1.2))
const SUPPORT_ROLES: Array[StringName] = [&"bracket.jetty", &"bracket.small", &"post.timber"]


func test_supports_never_cross_a_window_or_door() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var crossings: Array[String] = []
	var supports := 0
	for town: Dictionary in _built_towns():
		var openings: Array[Transform3D] = []
		var braces: Array[Dictionary] = []
		for mass: BuildingMass in town.built.masses:
			var assembler := BuildingKitAssembler.new(kit)
			for placement: Dictionary in assembler.assemble(mass):
				var role := String(placement.role)
				if role.ends_with(".window") or role.ends_with(".door"):
					openings.append(placement.transform)
				elif SUPPORT_ROLES.has(StringName(role)):
					braces.append(placement)
		for brace: Dictionary in braces:
			var t := brace.transform as Transform3D
			var box := catalog.descriptor(StringName(brace.asset_id)).measured_aabb
			# Sample the support's centre lines (a member beside an opening
			# is fine; one whose body passes in front of it is not).
			var samples: Array[Vector3] = []
			for k in 11:
				var f := float(k) / 10.0
				samples.append(t * (box.get_center() + Vector3(0.0, (f - 0.5) * box.size.y, 0.0)))
				samples.append(t * (box.get_center() + Vector3(0.0, 0.0, (f - 0.5) * box.size.z)))
			supports += 1
			for opening: Transform3D in openings:
				var inverse := opening.affine_inverse()
				var hit := false
				for sample: Vector3 in samples:
					hit = hit or OPENING_LOCAL.has_point(inverse * sample)
				if hit:
					var local: Array = []
					for sample: Vector3 in samples:
						if OPENING_LOCAL.has_point(inverse * sample): local.append((inverse * sample).snappedf(0.01))
					crossings.append("%s %s at %s local %s" % [town.id, brace.stable_id, t.origin, local.slice(0, 3)])
					break
	assert_gt(supports, 50, "the corpus builds supports")
	assert_eq(crossings.size(), 0, "no support crosses an opening: %s" % [crossings.slice(0, 12)])


# --- photo 4: storey masonry has depth ---------------------------------------

## Front z of every vertex of the named material in the asset's visual.
static func _front(asset_id: StringName, material: String) -> float:
	var catalog := EnvironmentCatalog.load_default()
	var visual := load(catalog.descriptor(asset_id).visual_path) as EnvironmentVisual
	var front := -INF
	for piece: EnvironmentVisualPiece in visual.pieces:
		for surface in piece.mesh.get_surface_count():
			var mat := piece.mesh.surface_get_material(surface)
			if mat == null or mat.resource_name != material:
				continue
			for vertex: Vector3 in piece.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				front = maxf(front, (piece.local_transform * vertex).z)
	return front


func test_stone_storey_windows_are_sunk_and_the_masonry_stands_proud() -> void:
	var kit := SuntailBuildingKit.create()
	var stone_window := kit.asset(&"wall.stone.window")
	var timber_window := kit.asset(&"wall.timber.window")
	# Reveal: from the stone face back to the glass.
	var reveal := _front(stone_window, "Stone_Wall") - _front(stone_window, "Window")
	var timber_reveal := _front(timber_window, "Wall") - _front(timber_window, "Window")
	assert_gt(reveal, timber_reveal + 0.15,
		"stone windows sit in a deep reveal (%.3f m vs timber %.3f m)" % [reveal, timber_reveal])
	# The stone storey's face stands proud of the timber storey above it.
	var stone_face := _front(kit.asset(&"wall.stone.plain"), "Stone_Wall")
	var timber_face := _front(kit.asset(&"wall.timber.plain"), "Wall")
	assert_gt(stone_face - timber_face, 0.1,
		"stone storey face %.3f proud of timber face %.3f" % [stone_face, timber_face])
	# Doors are set into the same depth, and retaining courses stay flush.
	for door: StringName in kit.roles[&"wall.stone.door"]:
		assert_gt(_front(door, "Stone_Wall"), stone_face - 0.001, "%s is deep masonry" % door)
	assert_almost_eq(_front(kit.asset(&"wall.stone.retaining"), "Stone_Wall"),
		_front(&"suntail.stone.stone_wall", "Stone_Wall"), 0.001, "retaining walls stay flush")
