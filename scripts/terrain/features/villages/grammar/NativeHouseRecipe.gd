extends RefCounted
## Native derivation expressed in the existing planner/assembler recipe format.
## Register and select before plot packing; never substitute into an unrelated
## sealed landmark reservation. Native module poses remain the render authority.
const Site = preload("res://scripts/terrain/features/villages/grammar/NativeHouseSite.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


static func cross(
	catalog: EnvironmentCatalog, id: StringName, x_bays: int, z_bays: int, seed_value: int
) -> FabricRecipe:
	var site := Site.cross(
		catalog,
		x_bays,
		z_bays,
		seed_value,
		VillageWorldScale.KIT_WORLD_SCALE,
		Vector3.ZERO,
		Vector3.BACK
	)
	return _from_site(catalog, id, site)


static func street(
	catalog: EnvironmentCatalog,
	id: StringName,
	bays: int,
	seed_value: int,
	rear_jetty: bool = false
) -> FabricRecipe:
	return _from_site(
		catalog,
		id,
		Site.street(
			catalog,
			bays,
			seed_value,
			VillageWorldScale.KIT_WORLD_SCALE,
			Vector3.ZERO,
			Vector3.BACK,
			rear_jetty
		)
	)


static func turret(
	catalog: EnvironmentCatalog, id: StringName, extra_upper_storeys: int
) -> FabricRecipe:
	return _from_site(
		catalog,
		id,
		preload("res://scripts/terrain/features/villages/grammar/NativeTurretSite.gd").place(
			catalog,
			extra_upper_storeys,
			VillageWorldScale.KIT_WORLD_SCALE,
			Vector3.ZERO,
			Vector3.BACK,
			true
		)
	)


static func arcade(
	catalog: EnvironmentCatalog, id: StringName, upper_storeys: int, upper_side_window: String
) -> FabricRecipe:
	return _from_site(
		catalog,
		id,
		preload("res://scripts/terrain/features/villages/grammar/NativeArcadeSite.gd").place(
			catalog,
			upper_storeys,
			upper_side_window,
			VillageWorldScale.KIT_WORLD_SCALE,
			Vector3.ZERO,
			Vector3.BACK
		)
	)


static func _from_site(
	catalog: EnvironmentCatalog, id: StringName, site: Dictionary
) -> FabricRecipe:
	if not site.ok or id.is_empty():
		return null
	var recipe := FabricRecipe.new(
		id, [&"room", &"prefab_anchor", &"terrain_bearing", &"native_grammar"], 0
	)
	var world_to_lattice := Transform3D(
		Basis.from_scale(Vector3.ONE / VillageWorldScale.frame_scale()), Vector3.ZERO
	)
	# Construction guard is shared with town structural surfaces. It keeps the
	# rough bottom bevels in the grade tolerance without claiming a lower band.
	var guarded_pose: Transform3D = site.pose
	guarded_pose.origin.y += VillageWorldScale.GROUND_DATUM_GUARD
	var module_bounds: Array[AABB] = []
	for index in site.parts.size():
		var part: Dictionary = site.parts[index]
		var canonical := Compiler.placement(
			part.module, world_to_lattice * guarded_pose * part.transform, part.get("asset_id", &"")
		)
		recipe.add_placement(
			StringName("native.%04d" % index), canonical.asset_id, canonical.transform
		)
		module_bounds.append(
			canonical.transform * catalog.descriptor(canonical.asset_id).measured_aabb
		)
	var envelope: AABB = (
		world_to_lattice
		* AABB(
			site.envelope.position + Vector3.UP * VillageWorldScale.GROUND_DATUM_GUARD,
			site.envelope.size
		)
	)
	if not recipe.set_local_clearance_bounds(envelope):
		return null
	# A conservative private volume prevents other rooms or through-routes
	# being packed inside the closed native house. The visual realization is
	# the compound derivation; this coarse reservation does not stretch it.
	var pitch := FabricRecipe.CELL_SIZE
	var half := Vector3(pitch * .5, 0, pitch * .5)
	var low := Vector3i(((envelope.position + half) / pitch).floor())
	var high := Vector3i(((envelope.end + half) / pitch).ceil())
	for x in range(low.x, high.x):
		for z in range(low.z, high.z):
			recipe.terrain_bearing_cells.append(Vector3i(x, 0, z))
			for y in range(0, high.y):
				var cell := Vector3i(x, y, z)
				if x == 0 and z == 0 and y < 2:
					continue
				# A high corner spire can extend the overall envelope in front
				# of the entrance without occupying its ground approach. Release
				# only proven-empty approach cells, never a solid wall or stair.
				if x == 0 and z > 0 and y < 2:
					var air := AABB(Vector3(cell) * pitch - half, Vector3.ONE * pitch)
					if module_bounds.all(func(box: AABB) -> bool: return not box.intersects(air)):
						continue
				recipe.solid_cells.append(cell)
	# The addressed entrance is the foot of the private stair, not the raised
	# door leaf. Only this approach is advertised; no invented upper sockets.
	for y in 2:
		recipe.headroom_cells.append(Vector3i(0, y, 0))
	recipe.inhabited_cells.assign(recipe.headroom_cells)
	if not recipe.terrain_bearing_cells.has(Vector3i.ZERO):
		recipe.terrain_bearing_cells.append(Vector3i.ZERO)
	recipe.add_entrance(&"front", Vector3i.ZERO, Vector3i.BACK)
	return recipe if recipe.seal(catalog) else null
