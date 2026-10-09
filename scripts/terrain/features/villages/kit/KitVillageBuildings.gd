class_name KitVillageBuildings
extends RefCounted

## Adapter from the sealed warren plan to kit-built buildings.
##
## The planner's buildings (`WarrenSpatialPlan.buildings`: rooms stacked in
## 3 m / two-band storeys on the 1.5 m authored lattice) become pack-agnostic
## `BuildingMass`es on a one-module-per-fine-cell grid, are articulated by
## `BuildingDesigner`, realized by `BuildingKitAssembler`, and mapped back into
## the authored lattice frame. Legacy recipe placements owned by those
## buildings are withdrawn; public surfaces, guards, stairs and turf are not
## touched. Occupancy, collision boxes and terrain grade remain plan facts.

## Native kit metres -> authored lattice metres: one module per 1.5 m fine
## cell horizontally, one kit band per 1.5 m band vertically. Fine cells are
## centred on `cell * 1.5`; bands start at `band * 1.5`.
static func native_to_lattice(kit: BuildingKit) -> Transform3D:
	var h := FabricRecipe.CELL_SIZE / kit.module_width
	var v := WarrenVolumePlan.VERTICAL_BAND_SIZE_M / kit.band_height()
	return Transform3D(Basis.from_scale(Vector3(h, v, h)),
		Vector3(-FabricRecipe.CELL_SIZE * 0.5, 0.0, -FabricRecipe.CELL_SIZE * 0.5))


## Lattice metres a kit wall's outer face stands proud of its cell edge.
static func wall_face_lattice(kit: BuildingKit) -> float:
	return kit.wall_face * FabricRecipe.CELL_SIZE / kit.module_width


## Feature kinds whose legacy recipe units are superseded by kit buildings.
## Arcade support frames retain their measured native recipe: its four
## corner posts are proved clear of the body lanes. Cell-based replacement
## posts were all dropped at public floors, leaving their upper rooms floating.
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const REPLACED_FEATURE_KINDS: Array[StringName] = [
	&"facade_bay", &"prefab_landmark", &"balcony", &"room_overhang_support",
]
## Terrace-payload families that belonged to the legacy buildings.
const REPLACED_TERRACE_PREFIXES: Array[String] = ["house-plinth", "maze-skywalk",
	"maze-stone", "masonry-joint", "masonry-room-return", "masonry-room-seam",
	"maze-outcrop"]
## Legacy fabric placement families the kit supersedes.
const REPLACED_PLACEMENT_PREFIXES: Array[String] = ["facade-corner",
	"facade-joint", "facade-run-joint", "facade-door-return"]


## One kit house: every planner building volume of one lineage (a house's
## storeys arrive as `...partNN` volumes) or one reserved landmark.
static func house_id_for(building_id: StringName) -> StringName:
	var id := String(building_id)
	var index := id.rfind(".part")
	return StringName(id.substr(0, index)) if index > 0 else building_id


## Returns {payload: EnvironmentInstancePayload (town-local lattice frame),
## replaced_units: Dictionary unit stable_id -> true, masses: Array, plus the
## native-frame roof union inputs placements / roofs / walls}.
static func build(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		kit: BuildingKit, mixed_styles := true, native_roofs := true) -> Dictionary:
	var grid := spatial.grid
	var houses := _houses(spatial)
	var owner_at: Dictionary = {}
	for house_id: StringName in houses:
		for cell: Vector3i in (houses[house_id] as Dictionary).cells:
			owner_at[cell] = house_id
	var replaced := _replaced_units(spatial, fabric)
	var exterior := SettlementFabricAssembler.maze_exterior_network(fabric)
	var spans: Array[Dictionary] = exterior.spans
	var public_crowns: Dictionary = exterior.terrace_cells
	var passages := _passage_house_claims(spans, houses, owner_at)
	var feature_masses := _feature_masses(spatial, fabric, houses, grid, spans, kit)
	var seated_balcony_brackets := preload("res://scripts/terrain/features/villages/kit/KitBalconySupports.gd").seat(feature_masses,houses,grid)
	var bracket_bearings := preload("res://scripts/terrain/features/villages/kit/KitBracketBearings.gd").cells(feature_masses)
	# Adjacent lots on one ground become one building (after the balconies
	# have opened their doors in their owner lots).
	houses = merge_houses(houses, spatial.world_seed)
	owner_at.clear()
	for house_id: StringName in houses:
		for cell: Vector3i in (houses[house_id] as Dictionary).cells:
			owner_at[cell] = house_id
	# Growing upper floors read the town's odds; a fixture without a source plan never grows.
	var growth_character: TownCharacter = null
	if spatial.source_volume != null:
		var growth_source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		if growth_source != null and growth_source.scale_profile != null:
			growth_character = TownCharacter.of(growth_source.scale_profile, growth_source.world_seed)
	var growth_solid := func(own: StringName, cell: Vector2i, band: int) -> bool:
		return _solid_other(grid, owner_at, own, Vector3i(cell.x, band, cell.y))
	var growth_street := func(cell: Vector2i, band: int) -> bool:
		var at := Vector3i(cell.x, band, cell.y)
		return grid.contains(at) and grid.use_at(at) == WarrenSpatialGrid.Use.PUBLIC_AIR
	var growth_context := {} if growth_character == null else \
		{"character": growth_character, "solid": growth_solid, "street": growth_street}
	var payload := EnvironmentInstancePayload.new()
	var map := native_to_lattice(kit)
	var masses: Array[BuildingMass] = []
	var ids := sorted_ids(houses.keys())
	var flights := flight_columns(spatial, fabric)
	var canopy_claims: Array = []
	var podium := _podium_cells(feature_masses)
	var house_kits: Dictionary = {}
	var ridge_counts := Vector2i.ZERO
	for house_id: StringName in ids:
		var house: Dictionary = houses[house_id]
		var house_kit := preload("res://scripts/terrain/features/villages/kit/TownBuildingStyles.gd").for_house(
			kit, spatial.world_seed, house_id, native_roofs) if mixed_styles else kit
		house_kits[house_id] = house_kit
		var mass := _mass_for(house_id, house, grid, owner_at, spatial.world_seed, house_kit,
			flights, canopy_claims, podium, passages, ridge_counts, public_crowns, bracket_bearings, growth_context)
		if mass != null:
			masses.append(mass)
			var principal := {}
			for roof: Dictionary in mass.roofs:
				if principal.is_empty() or roof.rect.get_area() > principal.rect.get_area(): principal = roof
			if not principal.is_empty(): ridge_counts[int(principal.axis)] += 1
	var house_masses := masses.duplicate()
	masses.append_array(feature_masses)
	preload("res://scripts/terrain/features/villages/kit/KitSkywalkLandings.gd").open_landings(masses, spans)
	preload("res://scripts/terrain/features/villages/kit/KitRoomCeilings.gd").close(masses)
	var room_cells := {}
	for room_mass: BuildingMass in house_masses:
		for floor: Dictionary in room_mass.storeys:
			for cell: Vector2i in floor.cells:
				for band in range(int(floor.floor_band),int(floor.floor_band)+int(floor.get("bands",2))):
					room_cells[Vector3i(cell.x,band,cell.y)] = true
	var parallel_joins := KitRoofJunctions.combine_parallel(house_masses,
		func(a: BuildingMass,b: BuildingMass,rect: Rect2i,axis: int,eave: int) -> bool:
			var aid := StringName(String(a.stable_id).trim_prefix("kit."))
			var bid := StringName(String(b.stable_id).trim_prefix("kit."))
			var ak: BuildingKit = house_kits.get(aid,kit)
			var bk: BuildingKit = house_kits.get(bid,kit)
			if ak.kit_id != bk.kit_id: return false
			var aa: Dictionary = houses.get(aid,{}).get("own_air",{})
			var ba: Dictionary = houses.get(bid,{}).get("own_air",{})
			var depth := rect.size[1-axis]
			var ridge_head := KitRoofJunctions.ridge_clearance_head(ak,EnvironmentCatalog.load_default())
			for cell: Vector2i in BuildingMass.rect_cells(rect):
				var row := cell[1-axis]-rect.position[1-axis]
				var height := KitRoofJunctions.column_clearance_height(ak,depth,row,ridge_head)
				var bands := ceili(height/ak.band_height())
				for band in range(eave,eave+bands):
					var p := Vector3i(cell.x,band,cell.y)
					if room_cells.has(p) or passages.has(p) or public_crowns.has(p): return false
					if grid.use_at(p) == WarrenSpatialGrid.Use.PUBLIC_AIR: return false
					if aa.has(p) or ba.has(p): continue
					if _keep_clear(grid,owner_at,aid,p) and _keep_clear(grid,owner_at,bid,p): return false
			return true)
	var joins := preload("res://scripts/terrain/features/villages/kit/KitRoofJunctions.gd").join(masses,
		func(cell: Vector2i, band: int) -> bool:
			var p := Vector3i(cell.x, band, cell.y)
			return not grid.contains(p) or grid.use_at(p) in [WarrenSpatialGrid.Use.OUTSIDE, WarrenSpatialGrid.Use.ALLOCATABLE])
	var public_cells: Array[Vector3i] = []
	if fabric.surface_plan != null:
		for patch: Dictionary in fabric.surface_plan.patches:
			public_cells.append_array(patch.cells)
	for cell: Vector3i in public_crowns:
		if not public_cells.has(cell):
			public_cells.append(cell)
	KitRoofJunctions.fit_public_verges(masses, public_cells, kit)
	var roofs: Array[Dictionary] = []
	var roof_kits: Dictionary = {}
	var walls: Array[Dictionary] = []
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var roof_kit: BuildingKit = house_kits.get(own, kit)
		for roof: Dictionary in mass.roofs:
			roof.union_index = roofs.size()
			roof_kits[roofs.size()] = roof_kit
			roofs.append(roof)
		for storey: Dictionary in mass.storeys:
			for rect: Rect2i in BuildingDesigner.decompose(storey.cells):
				walls.append(union_script.box_volume(AABB(Vector3(rect.position.x * kit.module_width,
					storey.floor_band * kit.band_height(), rect.position.y * kit.module_width),
					Vector3(rect.size.x * kit.module_width, int(storey.get("bands", 2)) * kit.band_height(), rect.size.y * kit.module_width))))
	# Use the finished floors/treads, including derived surfaces and exterior
	# approaches. Quantized route bands missed the upper part of stair treads.
	# Open air still cannot cut a gable wall and leave a hole in the attic.
	var public_air := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd").build(
		spatial, fabric, kit)
	var ornament_air := public_air.duplicate()
	ornament_air.append_array(preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd").skywalk_ornament_air(spans, kit))
	walls.append_array(public_air)
	var tower_catalog := EnvironmentCatalog.load_default()
	var tower_audit := {}
	# Inhabited bridge floors are private room cells but carry through-routes.
	# Their internal clearance is an obstacle to a shaft, not a roof cutter.
	var tower_air := public_air.duplicate()
	tower_air.append_array(preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd").inhabited_bridge_rooms(spatial, kit))
	var towers := preload("res://scripts/terrain/features/villages/kit/KitTownTowers.gd").propose(
		masses,house_kits,kit,tower_catalog,tower_air,
		func(own: StringName,cell: Vector2i,band: int) -> bool:
			var at := Vector3i(cell.x,band,cell.y)
			# Public columns may extend to open sky. Their finished walking
			# headroom is checked geometrically by the tower proposer. Other
			# private, structural and daylight reservations remain protected.
			return grid.use_at(at) != WarrenSpatialGrid.Use.PUBLIC_AIR \
				and _keep_clear(grid,owner_at,own,at),tower_audit,
		func(_own: StringName,cell: Vector2i,band: int) -> bool:
			if spatial.source_volume == null: return false
			return _tower_bearing(spatial.source_volume.envelope,podium,cell,band))
	var tower_hosts := {}
	var tower_core: Array = []
	if not towers.is_empty():
		tower_core = FileAccess.open(preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd").ROOF_CORE,FileAccess.READ).get_var()
	for tower: Dictionary in towers:
		preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd").apply(tower.host,tower.host_plan)
		tower_hosts[tower.host.stable_id] = tower
		if tower.attachment == &"roof":
			tower["cutters"] = preload("res://scripts/terrain/features/villages/kit/KitRoofTurrets.gd").cutters(tower)
		else:
			tower["cutters"] = preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd").placed_cutters(
				(FileAccess.open(tower.cap_core_path,FileAccess.READ).get_var() as Array) if tower.has("cap_core_path") else tower_core,tower.pose*tower.parts[-1].transform)
	# Growing upper floors (after roof joins and towers, before projections and
	# bays): lower storeys step in under a fixed roof (nothing moves outward).
	var growth := GROWTH.fit(masses,house_kits,kit,tower_catalog,growth_character,ornament_air,towers,
		func(own: StringName,cell: Vector2i,band: int) -> bool:
			var at := Vector3i(cell.x,band,cell.y)
			if passages.has(at) or podium.has(at): return true
			if owner_at.has(at): return owner_at[at] != own
			return grid.contains(at) and grid.use_at(at) in [WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
				WarrenSpatialGrid.Use.SERVICE_VOID,WarrenSpatialGrid.Use.PRIVATE_VOLUME],
		growth_solid,growth_street,_growth_grade(spatial,grid))
	var room_projections := preload("res://scripts/terrain/features/villages/kit/KitRoomProjections.gd").fit(
		masses,house_kits,kit,tower_catalog,public_air,towers,
		func(own:StringName,cell:Vector2i,band:int)->bool:
			var at:=Vector3i(cell.x,band,cell.y)
			return grid.use_at(at)!=WarrenSpatialGrid.Use.PUBLIC_AIR and _keep_clear(grid,owner_at,own,at),
		func(own:StringName,cell:Vector2i,band:int)->bool:
			var at:=Vector3i(cell.x,band,cell.y)
			return podium.has(at) or fabric.surface_plan.has_cell(at) or _walked(grid,at) or public_crowns.has(at) or _solid_other(grid,owner_at,own,at),
		func(own:StringName,cell:Vector2i,band:int)->bool:return _solid_other(grid,owner_at,own,Vector3i(cell.x,band,cell.y)),
		func(cell:Vector2i,band:int)->bool:return fabric.surface_plan.has_cell(Vector3i(cell.x,band,cell.y)),
		growth.registry,growth_character.value(GROWTH.GAP_KNOB) if growth_character != null else 0.0)
	for projection:Dictionary in room_projections:
		walls.append(union_script.box_volume(projection.bounds))
	var facade_bays := preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd").fit(
		masses,house_kits,kit,tower_catalog,public_air,towers,
		func(own: StringName,cell: Vector2i,band: int) -> bool:
			var at := Vector3i(cell.x,band,cell.y)
			return grid.use_at(at) != WarrenSpatialGrid.Use.PUBLIC_AIR and _keep_clear(grid,owner_at,own,at))
	var placements: Array[Dictionary] = []
	var fitted_eaves := preload("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd").fit(roofs,kit,roof_kits,walls)
	var fitted_dormers := preload("res://scripts/terrain/features/villages/kit/KitRoofDormerFits.gd").fit(roofs,kit,roof_kits,walls)
	var facade_contacts := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
	var facade_context := facade_contacts.prepare(roofs,kit,roof_kits,walls)
	var floor_contacts := {"volumes":[],"skins":[],"openings":facade_context.openings,
		"frames":facade_context.frames}
	for mesh: Dictionary in preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd").floor_meshes(spatial,fabric):
		facade_contacts.add_floor(floor_contacts,mesh,map.affine_inverse())
	var floor_catalog := EnvironmentCatalog.load_default()
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var floor_assembler := BuildingKitAssembler.new(house_kits.get(own,kit))
		facade_contacts.add_inhabited_floors(floor_contacts,mass,floor_assembler,floor_catalog)
	facade_context.volumes.append_array(floor_contacts.volumes)
	facade_context.skins.append_array(floor_contacts.skins)
	var roof_blocked_windows := 0
	var fitted_window_boxes := 0
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var assembler := BuildingKitAssembler.new(house_kits.get(own, kit))
		assembler.prop_scale = VillageWorldScale.kit_human_prop_scale()
		assembler.overhead_solids = walls
		assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
			return _solid_other(grid, owner_at, own, Vector3i(cell.x, band, cell.y))
		assembler.public_floor = func(cell: Vector2i, band: int) -> bool:
			return fabric.surface_plan != null and fabric.surface_plan.has_cell(Vector3i(cell.x,band,cell.y))
		assembler.ornament_clear = func(id: StringName, pose: Transform3D) -> bool:
			var local_box: AABB = tower_catalog.descriptor(id).measured_aabb
			if preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd").intersects_air(
					local_box,pose,ornament_air): return false
			var box: AABB = pose*local_box
			for tower: Dictionary in towers:
				if box.intersects(tower.bounds): return false
			for bay: Dictionary in facade_bays:
				if box.intersects(bay.bounds): return false
			return _clear_of_others(box,mass.stable_id,room_projections) \
				and _clear_of_others(box,mass.stable_id,growth.leans)
		roof_blocked_windows += facade_contacts.fit(mass,assembler,facade_context,tower_catalog)
		var parts := assembler.assemble(mass)
		fitted_window_boxes += preload("res://scripts/terrain/features/villages/kit/KitWindowBoxes.gd").fit(
			parts, assembler.kit, tower_catalog, facade_context.openings)
		if tower_hosts.has(mass.stable_id):
			var tower: Dictionary = tower_hosts[mass.stable_id]
			if tower.attachment != &"roof":
				preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd").fit_parts(parts,tower,assembler.kit,tower_catalog)
			for part: Dictionary in parts:
				if int(part.get("roof_index",-1)) < 0: continue
				var box: AABB = part.transform*tower_catalog.descriptor(part.asset_id).measured_aabb
				var cutters: Array = part.get("clip_volumes",[]).duplicate()
				for cutter: Dictionary in tower.cutters:
					if box.grow(0.001).intersects(cutter.bounds): cutters.append(cutter)
				part["clip_volumes"] = cutters
		_fit_retaining_ceiling(parts,floor_catalog)
		roof_blocked_windows += facade_contacts.fit_gables(parts,assembler.kit,floor_contacts)
		placements.append_array(parts)
	var retaining_flight_joints := preload("res://scripts/terrain/features/villages/kit/KitRetainingFlightJoints.gd").fit(
		placements,spatial.source_volume.transitions if spatial.source_volume != null else [],map,floor_catalog)
	var retaining_windows := preload("res://scripts/terrain/features/villages/kit/KitRetainingWindows.gd").fit(masses,placements,kit,floor_catalog,public_air,towers,facade_context)
	placements.append_array(retaining_windows)
	var fortified_windows := preload("res://scripts/terrain/features/villages/kit/KitFortifiedFacades.gd").fit(placements,kit,floor_catalog,public_air,facade_context)
	var retaining_relief := preload("res://scripts/terrain/features/villages/kit/KitRetainingRelief.gd").fit(masses,placements,kit,floor_catalog,public_air,towers)
	placements.append_array(retaining_relief)
	var decor_clearance := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd").fit_decor(
		placements,walls,EnvironmentCatalog.load_default())
	var roof_audit := union_script.append_prepared(placements,facade_context.roof_context,map,payload)
	for tower: Dictionary in towers:
		for index in tower.parts.size():
			var part: Dictionary = tower.parts[index]
			payload.add(part.asset_id,map*tower.pose*part.transform,Color.WHITE,
				StringName("%s/tower.%d" % [tower.host.stable_id,index]),true)
	tower_audit["accepted"] = towers.size()
	roof_audit["towers"] = tower_audit
	roof_audit["facade_bays"] = facade_bays.size()
	roof_audit["room_projections"] = room_projections.size()
	roof_audit["growth_faces"] = growth.leans.size()
	roof_audit["retaining_relief"] = retaining_relief.size()
	roof_audit["retaining_flight_joints"] = retaining_flight_joints
	roof_audit["retaining_windows"] = retaining_windows.size()
	roof_audit["fortified_windows"] = fortified_windows
	roof_audit["retaining_recesses"] = placements.filter(func(part: Dictionary) -> bool: return bool(part.get("retaining_recess",false))).size()
	roof_audit["decor_clearance"] = decor_clearance
	roof_audit["fitted_window_boxes"] = fitted_window_boxes
	roof_audit["joins"] = joins
	roof_audit["parallel_joins"] = parallel_joins
	roof_audit["fitted_eaves"] = fitted_eaves
	roof_audit["dormers"] = fitted_dormers
	roof_audit["seated_balcony_brackets"] = seated_balcony_brackets
	roof_audit["roof_blocked_windows"] = roof_blocked_windows
	roof_audit["roof_fitted_windows"] = int(facade_context.get("substituted",0))
	return {"payload": payload, "replaced_units": replaced, "masses": masses, "houses": house_masses,
		"house_kits": house_kits, "roof_kits": roof_kits, "towers": towers, "facade_bays": facade_bays,
		"room_projections":room_projections,"growth":growth.leans,"growth_rejections":growth.rejections,"roof_audit": roof_audit, "placements": placements, "roofs": roofs, "walls": walls}


## Growth ruling (e): the ground outside a face stands at `band` at that fine cell:
## terrain whose datum is that band, or anything floored directly under it (a lane,
## deck, court, garden or retained top: the band below is neither air nor outside).
static func _growth_grade(spatial: WarrenSpatialPlan, grid: WarrenSpatialGrid) -> Callable:
	var envelope := spatial.source_volume.envelope if spatial.source_volume != null else null
	return func(cell: Vector2i, band: int) -> bool:
		if envelope != null and envelope.ground_at(Vector2i(floori(cell.x / 2.0), floori(cell.y / 2.0))) == band:
			return true
		var below := Vector3i(cell.x, band - 1, cell.y)
		return grid.contains(below) and not (grid.use_at(below) in [WarrenSpatialGrid.Use.PUBLIC_AIR,
			WarrenSpatialGrid.Use.DAYLIGHT_AIR, WarrenSpatialGrid.Use.OUTSIDE])


## True when `box` misses every fitted front (`bounds`) another house hosts.
static func _clear_of_others(box: AABB, host: StringName, fronts: Array) -> bool:
	return GROWTH.clear_of(box, fronts, func(front: Dictionary) -> bool: return front.host != host)


## Balconies, overhang supports and skywalks as kit masses. Balconies also
## open a door in their owner house, so this runs before houses are designed.
static func _feature_masses(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		houses: Dictionary, grid: WarrenSpatialGrid,
		spans: Array[Dictionary], kit: BuildingKit = null) -> Array[BuildingMass]:
	var out: Array[BuildingMass] = []
	for feature: WarrenFeatureReservation in spatial.features:
		match feature.kind:
			&"balcony":
				var balcony := _balcony_mass(feature, houses, grid, spatial.world_seed)
				if balcony != null:
					out.append(balcony)
			&"room_overhang_support":
				out.append(_support_mass(feature, grid, spatial.world_seed))
	for span: Dictionary in spans:
		out.append(_skywalk_mass(span, spatial.world_seed, kit))
	# The legacy fabric can classify a passage crown as a flat roof and
	# subtract it from retained-terrain skin. Every crown -- a bored tunnel's
	# ceiling or a rock shoulder left over a street -- gets its own kit closure
	# here. A crown survives the plan only while it carries a room or walk
	# (`WarrenVolumetricSolver.unborne_crown_cells`), so it is drawn as its
	# whole stone run up to that construction: its lowest band alone left the
	# rest invisible and the slab floating under the house it bears.
	var tunnel := _retained_mass(fabric.passage_crown_cells, spatial.world_seed)
	if tunnel != null:
		tunnel.stable_id = &"kit.tunnel-ceilings"
		# No deck of its own: the room or public floor it carries
		# already closes its top.
		for storey: Dictionary in tunnel.storeys:
			# A carried crown belongs to the same masonry structure as
			# its jambs; plaster here made one support alternate families
			# at the arbitrary half-storey partition boundaries.
			storey.material = BuildingMass.MATERIAL_STONE
			storey.default_opening = BuildingMass.OPENING_PLAIN
			storey.soffit = true
		out.append(tunnel)
	# A raised district's plinth is its own coursed-stone retaining wall; the
	# rest of the retained massif keeps the ordinary treatment.
	var retained_cells := fabric.retained_terrace_cells.duplicate()
	if spatial.source_volume != null:
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		if source != null:
			for plot: Dictionary in source.plots:
				# Legacy flat roofs own their slab's side faces. When a retained
				# cap sits on that slab, native replacement must carry those faces
				# down to the room ceiling too. An ordinary free roof has no such
				# retained cap and must not regain its old stone envelope.
				var roof := WarrenMazeBlockPartitioner.plot_roof_band_span(source,plot,spatial.source_volume)
				if roof.x >= roof.y: continue
				for column: Vector2i in plot.cells:
					for dx in 2:
						for dz in 2:
							var fine := column*2+Vector2i(dx,dz)
							var wall_room := bool(plot.get("wall_room",false))
							if not wall_room and not fabric.retained_terrace_cells.has(
									Vector3i(fine.x,roof.y-1,fine.y)): continue
							for band in range(roof.x,roof.y):
								var cell := Vector3i(fine.x,band,fine.y)
								if grid.use_at(cell) != WarrenSpatialGrid.Use.STRUCTURAL_VOLUME: continue
								if not wall_room and grid.owner_name_at(cell) != WarrenVolumetricSolver.MAZE_STONE_FEATURE_ID: continue
								retained_cells[cell] = true

	var split := _split_platform_cells(spatial, retained_cells)
	var retained := _retained_mass(split.rest, spatial.world_seed)
	var platform := _platform_wall_mass(split.platform, spatial.world_seed,
		_platform_gate_edges(spatial))
	var envelope := spatial.source_volume.envelope if spatial.source_volume != null else null
	for wall: BuildingMass in [retained, platform]:
		if wall == null:
			continue
		for storey: Dictionary in wall.storeys:
			var floor := int(storey.floor_band)
			# A one-band foot course whose every cell stands at or below its
			# column's ground datum sinks a full panel into the ground.
			var sunk := int(storey.get("bands", 2)) == 1
			for cell: Vector2i in storey.cells:
				if grid.use_at(Vector3i(cell.x, floor - 1, cell.y)) == WarrenSpatialGrid.Use.PUBLIC_AIR:
					storey["soffit"] = true
				var ground := envelope.ground_at(Vector2i(floori(cell.x / 2.0),
					floori(cell.y / 2.0))) if envelope != null else 0
				sunk = sunk and floor <= ground
			storey["sunk"] = sunk
		out.append(wall)
	return out


## Retained cells split into the raised district's plinth (fine cells of a
## platform column below its bearing surface, `WarrenMassif.bearing_at`) and
## the rest. A town without a platform has an empty plinth.
static func _split_platform_cells(spatial: WarrenSpatialPlan,
		retained: Dictionary) -> Dictionary:
	var massif: WarrenMassif = null
	if spatial.source_volume != null:
		massif = spatial.source_volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null or massif.platform_columns().is_empty():
		return {"platform": {}, "rest": retained}
	var platform: Dictionary = {}
	var rest: Dictionary = {}
	for cell: Vector3i in retained:
		var column := Vector2i(floori(cell.x / 2.0), floori(cell.z / 2.0))
		if massif.is_platform(column) and cell.y < massif.bearing_at(column):
			platform[cell] = retained[cell]
		else:
			rest[cell] = retained[cell]
	return {"platform": platform, "rest": rest}


## The plinth of a raised district (WarrenTownPlatform): coursed stone from
## the ground to the platform's bearing surface, whatever its height -- the
## one place a town wears a tall stone wall. Full facade courses may receive
## native recessed windows; the houses above stay timber and plaster.
static func _platform_wall_mass(cells: Dictionary, world_seed: int,
		gates: Dictionary = {}) -> BuildingMass:
	var mass := _retained_mass(cells, world_seed)
	if mass == null:
		return null
	mass.stable_id = &"kit.platform-wall"
	var framed := {}
	for storey: Dictionary in mass.storeys:
		storey.material = BuildingMass.MATERIAL_STONE
		storey["fortified"] = true
		var top := int(storey.floor_band)+int(storey.get("bands",2))
		storey["gates"] = gates.get(top,{})
		# A gate's opening can be air in the retained grid. Its frame belongs
		# to the rim datum, not to whichever half of the opening retains rock.
		storey["gate_frames"] = {} if framed.has(top) else gates.get(top,{})
		framed[top] = true
	return mass


## Module-cell rim edges where a gate flight (WarrenPlatformStreets
## .carve_gate) enters a raised district: band -> edge keys. Each edge is
## true on the left gate cell (seen from outside), false on the other.
static func _platform_gate_edges(spatial: WarrenSpatialPlan) -> Dictionary:
	var out: Dictionary = {}
	if spatial.source_volume == null:
		return out
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.excavation == null:
		return out
	for lane: Dictionary in source.excavation.lanes:
		if StringName(lane.get("feature_kind", &"")) != &"citadel_gate":
			continue
		for transition: Dictionary in lane.transitions:
			var gate := transition.to as Vector3i
			var from := transition.from as Vector3i
			if not source.massif.is_platform(Vector2i(gate.x, gate.z)) \
					or source.massif.plinth_at(Vector2i(from.x, from.z)) >= source.massif.plinth_at(Vector2i(gate.x,gate.z)) \
					or gate.y != source.massif.bearing_at(Vector2i(gate.x,gate.z)):
				continue
			var step := Vector2i(from.x - gate.x, from.z - gate.z)
			var dir := BuildingMass.DIRS.find(step)
			if dir < 0:
				continue
			var right := BuildingKitAssembler.right_of(dir)
			var cells: Array[Vector2i] = []
			for dz in 2:
				for dx in 2:
					var fine := Vector2i(gate.x * 2 + dx, gate.z * 2 + dz)
					var ahead := fine + step
					if Vector2i(floori(ahead.x / 2.0), floori(ahead.y / 2.0)) \
							!= Vector2i(gate.x, gate.z):
						cells.append(fine)
			var edges: Dictionary = out.get(gate.y,{})
			for fine: Vector2i in cells:
				edges[BuildingMass.edge_key(fine, dir)] = not cells.has(fine - right)
			out[gate.y] = edges
	return out


static func _fit_retaining_ceiling(parts: Array[Dictionary], catalog: EnvironmentCatalog) -> void:
	# Authored timber heads protrude beyond a nominal storey. Under a garden
	# they must end at the bearing plane, including their collision hull.
	# Preserve each panel's foot and horizontal dimensions while fitting its
	# measured top. Ordinary house frames and fortified parapets keep their shape.
	for part: Dictionary in parts:
		if part.has("soffit_stone_asset"):
			# The authored masonry projects behind the narrower timber rim.
			# Fit only the beam's depth to close that underside return; keep
			# its length, height, bearing plane and the carrying stone intact.
			var beam := catalog.descriptor(StringName(part.asset_id)).measured_aabb
			var stone := catalog.descriptor(StringName(part.soffit_stone_asset)).measured_aabb
			var pose: Transform3D = part.transform
			var relative: AABB = pose.affine_inverse()*part.soffit_stone_transform*stone
			var start := minf(beam.position.z,relative.position.z)-0.01
			var end := maxf(beam.end.z,relative.end.z)+0.01
			var depth_scale := (end-start)/beam.size.z
			part.transform = pose*Transform3D(Basis.from_scale(Vector3(1,1,depth_scale)),
				Vector3(0,0,start-beam.position.z*depth_scale))
		if not part.has("retaining_ceiling"): continue
		var descriptor := catalog.descriptor(StringName(part.asset_id))
		if descriptor == null: continue
		var transform: Transform3D = part.transform
		var box: AABB = transform*descriptor.measured_aabb
		var ceiling := float(part.retaining_ceiling)
		if box.end.y <= ceiling or box.size.y <= 0.001: continue
		var scale_y := (ceiling-box.position.y)/box.size.y
		if scale_y <= 0.0: continue
		part.transform = Transform3D(Basis.from_scale(Vector3(1,scale_y,1)),
			Vector3(0,box.position.y*(1.0-scale_y),0))*transform


## The retained massif wears native masonry courses up to its
## terrace top. Its crown is the garden or deck the public realm lays there.
static func _retained_mass(retained: Dictionary, world_seed: int) -> BuildingMass:
	if retained.is_empty():
		return null
	var columns: Dictionary = {}
	var base := 1 << 20
	for cell: Vector3i in retained:
		var column := Vector2i(cell.x, cell.z)
		if not columns.has(column):
			columns[column] = {}
		(columns[column] as Dictionary)[cell.y] = true
		base = mini(base, cell.y)
	var mass := _feature_base("retained", world_seed)
	mass.ground_band = base
	var layers: Dictionary = {}
	for column: Vector2i in columns:
		var bands: Dictionary = columns[column]
		var top := -(1 << 20)
		for band: int in bands:
			top = maxi(top, band)
		# Full storeys hang from the terrace top; an odd remaining band is a
		# stone base course at the foot, never a parapet above timber.
		var band := top
		while bands.has(band):
			var key: Vector2i
			if bands.has(band - 1):
				key = Vector2i(band - 1, 2)
				band -= 2
			else:
				key = Vector2i(band, 1)
				band -= 1
			if not layers.has(key):
				layers[key] = {}
			(layers[key] as Dictionary)[column] = true
	var keys := layers.keys()
	keys.sort()
	for key: Vector2i in keys:
		# Earth-backed supports use authored masonry, including tall courses.
		# Plaster made these read as windowless houses rather than foundations.
		var material := BuildingMass.MATERIAL_STONE
		var storey := mass.add_storey(key.x, layers[key], material)
		storey.bands = key.y
		# Retained ground is solid earth behind its face: a retaining wall or
		# podium has no rooms, so it never shows windows or doors, and its
		# masonry stays flush under the lawn it retains.
		storey.default_opening = BuildingMass.OPENING_PLAIN
		storey.retaining = true
	return mass


static func _feature_base(feature_id: String, world_seed: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = StringName("kit.%s" % feature_id)
	mass.seed = hash([world_seed, feature_id])
	return mass


static func _balcony_mass(feature: WarrenFeatureReservation, houses: Dictionary,
		grid: WarrenSpatialGrid, world_seed: int) -> BuildingMass:
	if feature.reserved_cells.is_empty():
		return null
	var band := 1 << 20
	for cell: Vector3i in feature.reserved_cells:
		band = mini(band, cell.y)
	var deck: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		if cell.y == band:
			deck[Vector2i(cell.x, cell.z)] = true
	var mass := _feature_base(String(feature.stable_id), world_seed)
	mass.ground_band = band
	mass.decks.append({"cells": deck, "band": band, "rails": true, "open_edges": {}})
	# The owner room gets a door onto its balcony.
	for endpoint: Dictionary in feature.endpoints:
		var owner := house_id_for(StringName(endpoint.get("owner_id", &"")))
		var cell := endpoint.get("cell", Vector3i.ZERO) as Vector3i
		for dir in 4:
			var next := Vector2i(cell.x, cell.z) + BuildingMass.DIRS[dir]
			if deck.has(next) and houses.has(owner):
				(houses[owner].doors as Array).append({"cell": cell,
					"direction": Vector3i(BuildingMass.DIRS[dir].x, 0,
						BuildingMass.DIRS[dir].y), "balcony": true})
				break
	# Short wall-tied brackets carry the whole platform. A high balcony must
	# not grow an isolated pole through several floors to reach the terrain.
	# Each bracket bears on a wall-module joint (a cell vertex on the wall
	# line) and runs square to the wall: a module's window or door is centred
	# between two joints, so no bracket ever crosses an opening.
	var braced: Dictionary = {}
	for cell: Vector2i in deck:
		var support := _balcony_bearing(grid, deck, cell, band)
		if support.is_empty(): continue
		var normal := support.normal as Vector2
		for joint: Vector2 in support.joints:
			if braced.has(joint): continue
			braced[joint] = true
			var outer: Vector2 = joint + normal * float(support.reach)
			mass.decor.append({"kind": &"raker", "dir": 0, "centre": joint,
				"from": Vector3(joint.x, band - 0.85, joint.y),
				"to": Vector3(outer.x, band - 0.08, outer.y)})
			mass.decor.append({"kind": &"raker", "dir": 0, "centre": joint,
				"from": Vector3(joint.x, band - 0.08, joint.y),
				"to": Vector3(outer.x, band - 0.08, outer.y)})
	mass.decor.append({"kind": &"planter", "dir": 1,
		"centre": Vector2(deck.keys()[0]) + Vector2(0.5, 0.5), "y_band": band})
	return mass


static func _balcony_bearing(grid: WarrenSpatialGrid, deck: Dictionary,
		cell: Vector2i, band: int) -> Dictionary:
	var centre := Vector2(cell) + Vector2(0.5, 0.5)
	var best := {}
	var nearest := INF
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var probe := cell + Vector2i(dx, dz)
			if deck.has(probe): continue
			if grid.use_at(Vector3i(probe.x, band, probe.y)) != WarrenSpatialGrid.Use.PRIVATE_VOLUME: continue
			var wall := centre.clamp(Vector2(probe), Vector2(probe + Vector2i.ONE))
			var distance := centre.distance_to(wall)
			if distance >= nearest or distance > 3.0: continue
			var clear := true
			for k in range(1, ceili(distance * 4.0) + 1):
				var p := wall.lerp(centre, float(k) / ceili(distance * 4.0))
				var between := Vector2i(floori(p.x), floori(p.y))
				if not deck.has(between): clear = false
				if grid.use_at(Vector3i(between.x, band - 1, between.y)) == WarrenSpatialGrid.Use.PUBLIC_AIR: clear = false
			if clear:
				nearest = distance
				best = {"dir": 0, "wall": wall}
	if best.is_empty():
		return best
	# The bearing point on the wall face, moved along the face to the module
	# joints either side of it (a wall corner already is a joint).
	var wall: Vector2 = best.wall
	var normal := (centre - wall).normalized()
	var joints: Array[Vector2] = []
	if absf(normal.x) > 0.99:
		joints = [Vector2(wall.x, floorf(wall.y)), Vector2(wall.x, ceilf(wall.y))]
	elif absf(normal.y) > 0.99:
		joints = [Vector2(floorf(wall.x), wall.y), Vector2(ceilf(wall.x), wall.y)]
	else:
		joints = [wall]
	best.normal = normal
	best.joints = joints
	best.reach = nearest + 0.35
	return best


static func _support_mass(feature: WarrenFeatureReservation, grid: WarrenSpatialGrid,
		world_seed: int) -> BuildingMass:
	var mass := _feature_base(String(feature.stable_id), world_seed)
	var low := 1 << 20
	var cells: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		low = mini(low, cell.y)
		cells[Vector2i(cell.x, cell.z)] = true
	# reserved_cells are the carried ROOM, not the shaft beneath it. Its
	# bottom is the bearing plane. Extending to the room top buried an extra
	# storey of timber in the wall, exposed when that room became a roofed wing.
	var rect := BuildingDesigner._bounds(cells)
	# Each post stands on one of the overhang's outer corner vertices: a
	# wall-module joint of every wall on either line through it, like a
	# balcony raker's. A module's window or door is centred between two
	# joints, so a post on a joint never stands in front of an opening (the
	# former corner-cell point, pushed diagonally outward, could).
	for vertex: Vector2i in [rect.position, Vector2i(rect.end.x, rect.position.y),
			Vector2i(rect.position.x, rect.end.y), rect.end]:
		var corner := Vector2i(mini(vertex.x, rect.end.x - 1),
			mini(vertex.y, rect.end.y - 1))
		# A post stands only on ground or structure, never in a public way.
		var landing := _post_landing(grid, Vector3i(corner.x, low - 1, corner.y))
		if landing == 1 << 20:
			continue
		mass.decor.append({"kind": &"post", "dir": 1, "centre": Vector2(vertex),
			"from_band": landing, "to_band": low})
	return mass


## An enclosed span is a timber bridge-house: windowed walls, open ends, a
## roof along the span and a boarded underside. Open spans are railed decks.
static func _skywalk_mass(span: Dictionary, world_seed: int,
		roof_kit: BuildingKit = null) -> BuildingMass:
	var cell := span.cell as Vector3i
	var step := span.step as Vector3i
	var gap := int(span.gap)
	var width := int(span.get("width", 1))
	var cross := span.get("cross", Vector3i(step.z, 0, step.x)) as Vector3i
	var cells: Dictionary = {}
	for k in range(1, gap + 1):
		var c := cell + step * k
		cells[Vector2i(c.x, c.z)] = true
		if width == 2:
			cells[Vector2i(c.x + cross.x, c.z + cross.z)] = true
	var mass := _feature_base("skywalk.%d.%d.%d.%d.%d" % [cell.x, cell.y, cell.z,
		step.x, step.z], world_seed)
	mass.ground_band = cell.y - 100
	var dir_along := BuildingMass.DIRS.find(Vector2i(step.x, step.z))
	var open_edges: Dictionary = {}
	for c: Vector2i in cells:
		for d in [dir_along, (dir_along + 2) % 4]:
			if not cells.has(c + BuildingMass.DIRS[d]):
				open_edges[BuildingMass.edge_key(c, d)] = true
	if gap > 1 and bool(span.get("enclosed", false)):
		var storey := mass.add_storey(cell.y, cells, BuildingMass.MATERIAL_TIMBER)
		storey["ceiling"] = true
		for key: Vector3i in open_edges:
			storey.openings[key] = BuildingMass.OPENING_NONE
		var rect := BuildingDesigner._bounds(cells)
		# The ridge runs along the span when the bridge is two modules wide.
		# A one-module-wide bridge-house instead turns its ridge across the
		# span: a roof one module deep is a lone ridge-top strip (the owner's
		# "tiny roof"), while the transverse roof is `gap` modules deep, its
		# slopes running into the two endpoint houses (trimmed inside their
		# walls) and its gables facing the lane it crosses, like a gatehouse.
		var along := 0 if step.x != 0 else 1
		var axis := along if width >= 2 else 1 - along
		var colour := &"blue" if absi(hash([world_seed, cell])) % 2 == 0 else &"red"
		# Closed gables: an end meeting a taller endpoint house is trimmed
		# inside its walls; one standing clear of a lower endpoint stays a
		# finished gable (an unconditionally open end was see-through).
		# KitRoofJunctions still opens an end into a same-eave host roof.
		# A long one-module bridge would raise that transverse roof far above
		# its 2 m ridge (31/large: 12 m over an eight-module span, its gable
		# infill four storeys of windows). Out of proportion
		# (BuildingDesigner.roof_proportion_ok), the bridge instead takes ONE
		# long gable whose ridge runs along the span, like a covered bridge
		# (October 8 owner ruling; a row of transverse gables read as a
		# sawtooth). Its gables face the bridge ends. A one-module roof is the
		# kit's ridge-top course alone, with no eave row to carry a dormer, so
		# it is dressed on the ridge: finials along the crest and a chimney
		# stack at mid-span (KitRoofMeshUnion.fit_chimneys moves or withdraws
		# a stack that meets anything, never the bridge).
		var kit := roof_kit if roof_kit != null else SuntailBuildingKit.create()
		var long_gable := not BuildingDesigner.roof_proportion_ok(kit, rect, axis)
		if long_gable:
			axis = along
		var wing := mass.add_roof(rect, axis, cell.y + 2, colour)
		if long_gable:
			wing.ridge_peaks = true
			wing.chimney = true
			wing.chimney_u = float(rect.position[axis] + rect.size[axis] / 2)
		# Timber portal posts frame each open end.
		for key: Vector3i in open_edges:
			var c := Vector2(key.x, key.y) + Vector2(0.5, 0.5) \
				+ Vector2(BuildingMass.DIRS[key.z]) * 0.45
			var side := Vector2(BuildingMass.DIRS[(key.z + 1) % 4])
			for sign: float in [-1.0, 1.0]:
				var at: Vector2 = c + side * 0.45 * sign
				var near := Vector2i(floori(at.x + side.x * 0.1 * sign), floori(at.y + side.y * 0.1 * sign))
				var far := Vector2i(floori(at.x + side.x * 0.6 * sign), floori(at.y + side.y * 0.6 * sign))
				if cells.has(near) and not cells.has(far):
					mass.decor.append({"kind": &"frame_post", "dir": key.z, "centre": at,
						"from_band": cell.y, "to_band": cell.y + 2})
	else:
		mass.decks.append({"cells": cells, "band": cell.y, "rails": true,
			"open_edges": open_edges})
	return mass


## A bridge-house spans between two building storeys (see
## `SettlementFabricAssembler._maze_passage_house_candidates`). Each endpoint
## house opens a door onto the passage at the bridge floor, and the passage's
## body and roof air is kept clear of the houses' own articulation (jetties,
## bays, canopies) so nothing grows into it. Returns the reserved cells.
static func _passage_house_claims(spans: Array[Dictionary],
		houses: Dictionary, owner_at: Dictionary) -> Dictionary:
	var reserved: Dictionary = {}
	for span: Dictionary in spans:
		if not bool(span.get("enclosed", false)):
			continue
		var step := span.step as Vector3i
		var lanes := SettlementFabricAssembler._skywalk_candidate_lanes(span)
		var near := lanes[0]
		var far := near + step * (int(span.gap) + 1)
		for end: Array in [[near, step], [far, -step]]:
			var house_id: Variant = owner_at.get(end[0])
			if house_id != null and houses.has(house_id):
				(houses[house_id].doors as Array).append({"cell": end[0],
					"direction": end[1], "passage": true})
		for lane: Vector3i in lanes:
			for index in range(1, int(span.gap) + 1):
				for rise in 4:
					reserved[lane + step * index + Vector3i.UP * rise] = true
	return reserved


static func _layer_is_low(columns: Dictionary, cells: Dictionary, floor: int) -> bool:
	for column: Vector2i in cells:
		if (columns[column] as Dictionary).has(floor + 2):
			return false
	return true


## Band a post may stand on below `cell`, or 1 << 20 when the column meets a
## public walk (a post there would block the way) before ground or structure.
static func _post_landing(grid: WarrenSpatialGrid, cell: Vector3i) -> int:
	var probe := cell
	while probe.y > -64:
		if not grid.contains(probe):
			return probe.y + 1
		var use := grid.use_at(probe)
		if use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
			return probe.y + 1
		if use == WarrenSpatialGrid.Use.PUBLIC_AIR and _walked(grid, probe):
			return 1 << 20
		probe.y -= 1
	return 1 << 20


## Lowest free band beneath `cell` before a floor, a solid or the envelope.
static func _ground_band_below(grid: WarrenSpatialGrid, cell: Vector3i) -> int:
	var probe := cell
	while probe.y > -64:
		if not grid.contains(probe):
			return probe.y + 1
		var use := grid.use_at(probe)
		if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				or use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
			return probe.y + 1
		if use == WarrenSpatialGrid.Use.PUBLIC_AIR and _walked(grid, probe):
			return probe.y
		probe.y -= 1
	return probe.y


static func _houses(spatial: WarrenSpatialPlan) -> Dictionary:
	var houses: Dictionary = {}
	for building: WarrenBuildingVolume in spatial.buildings:
		var house_id := house_id_for(building.stable_id)
		# A maze back room (or passage cover) is its parcel's own room: the
		# planner's one building, not a separate house beside it (which stood
		# as a twin gable against its host).
		for room: WarrenRoomStamp in building.room_records:
			var host := StringName(room.audit.get("back_room_parcel_id", &""))
			if not host.is_empty():
				house_id = StringName("spatial.%s" % host)
		if not houses.has(house_id):
			houses[house_id] = {"cells": [], "storeys": {}, "doors": [],
				"terrain_band": 1 << 20, "landmark": false, "grounded": {}}
		var house: Dictionary = houses[house_id]
		(house.cells as Array).append_array(building.private_cells)
		for room: WarrenRoomStamp in building.room_records:
			if room.private_cells.is_empty():
				continue
			var floor := 1 << 20
			for cell: Vector3i in room.private_cells:
				floor = mini(floor, cell.y)
			_add_storey_cells(house, floor, room.private_cells)
			if room.terrain_bearing:
				house.terrain_band = mini(int(house.terrain_band), floor)
				# Cells resting on the ground at this floor (a room on higher
				# ground than the house's lowest one): footing, not soffit.
				if not (house.grounded as Dictionary).has(floor):
					house.grounded[floor] = {}
				for cell: Vector3i in room.private_cells:
					if cell.y == floor:
						(house.grounded[floor] as Dictionary)[Vector2i(cell.x, cell.z)] = true
		for threshold: Dictionary in building.thresholds:
			(house.doors as Array).append({"cell": threshold.private_cell,
				"direction": threshold.direction})
	var source: WarrenMazeSourcePlan = null
	if spatial.source_volume != null:
		source = spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"prefab_landmark" or feature.reserved_cells.is_empty() or _native_landmark(feature):
			continue
		houses[feature.stable_id] = _landmark_house(feature, source)
	return houses


## `ids` (StringNames) in lexicographic order. `Array.sort()` orders
## StringNames by their interned pointers, not their text, so the order (and
## every order-dependent choice after it: shared canopy claims, roof joins,
## merges) changed with whatever the process had interned before; a town
## was not a pure function of its seed (September 29 review).
static func sorted_ids(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	return out


## Compound buildings (September 29 town review, photo 11). The planner
## parcels a town into one-macro-cell lots; built one by one they read as a
## row of identical little gabled boxes. Neighbouring lots standing on the
## same ground merge, by a seeded choice per shared wall, into one building
## of at most MERGE_MAX_CELLS modules and MERGE_MAX_SPAN across, so its crown
## is designed as a whole: a side-gabled range, an L or T with a main ridge
## and wings, a block stepping up the slope (grounds one storey apart) or
## a taller part beside a lower one that keeps its own roof. Occupancy,
## doors and bearing stay the planner's; only the kit's building identity
## (walls, roofs, colour) changes. A lot bearing a building that does not
## stand on the ground (a bridge-house, an upper room on its roof or beside
## it) keeps its own identity: that building's seams are coordinated with it.
const MERGE_CHANCE := 0.85
const RANGE_MERGE_CHANCE := 1.0
const MERGE_MAX_CELLS := 24
const MERGE_MAX_SPAN := 8
## Two ordinary 4x2 lots may form a 4x4 house. The broad-cluster limit starts
## beyond that useful join; otherwise it preserves precisely the twin gables
## the owner asked to combine.
const LARGE_PLAIN_RANGE_CELLS := 16
const LARGE_PLAIN_RANGE_CHANCE := 0.2


static func merge_houses(houses: Dictionary, world_seed: int) -> Dictionary:
	var ids := sorted_ids(houses.keys())
	var owner: Dictionary = {}
	for house_id: StringName in ids:
		for cell: Vector3i in (houses[house_id] as Dictionary).cells:
			owner[cell] = house_id
	# Lots that may merge: whole storeys on their own base (terrain, a terrace
	# or another lot), keyed by their lowest storey.
	var ground: Dictionary = {}
	for house_id: StringName in ids:
		var house: Dictionary = houses[house_id]
		if bool(house.landmark) or int(house.terrain_band) >= (1 << 20):
			continue
		var floors: Array = (house.storeys as Dictionary).keys()
		floors.sort()
		if int(floors[0]) != int(house.terrain_band):
			continue
		var phase_ok := true
		for floor: int in floors:
			phase_ok = phase_ok and posmod(floor - int(house.terrain_band), 2) == 0
		if phase_ok:
			ground[house_id] = house.storeys[floors[0]]
	# A lot touching a building that cannot merge (a bridge-house, a
	# landmark, a split-level room) keeps its identity: that building's
	# seams are coordinated with it.
	var bearing: Dictionary = {}
	var stacked: Dictionary = {}
	for cell: Vector3i in owner:
		var house_id: StringName = owner[cell]
		var below: StringName = owner.get(cell + Vector3i.DOWN, &"")
		if below != &"" and below != house_id:
			stacked[[below, house_id]] = true
			if not ground.has(house_id): bearing[below] = true
			if not ground.has(below): bearing[house_id] = true
		if ground.has(house_id):
			continue
		for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
				Vector3i(0, 0, -1)]:
			var other: StringName = owner.get(cell + step, &"")
			if other != &"" and other != house_id:
				bearing[other] = true
	var pairs: Array = []
	# A lineage standing on another lot is one building with it (a tower
	# of one-storey lots): always merged, before any neighbour.
	for pair: Array in stacked:
		var lower: StringName = pair[0]
		var upper: StringName = pair[1]
		if not ground.has(lower) or not ground.has(upper) \
				or bearing.has(lower) or bearing.has(upper):
			continue
		if posmod(int(houses[upper].terrain_band) - int(houses[lower].terrain_band), 2) != 0:
			continue
		pairs.append([-1000.0, lower, upper])
	for a: StringName in ids:
		if not ground.has(a) or bearing.has(a): continue
		for b: StringName in ids:
			if String(b) <= String(a) or not ground.has(b) or bearing.has(b): continue
			# Lots whose grounds differ by at most one storey (a house stepping
			# up the slope), on the same storey phase.
			var rise := int(houses[b].terrain_band) - int(houses[a].terrain_band)
			if absi(rise) > 2 or rise % 2 != 0: continue
			# They share at least one whole wall module of one storey (two
			# modules, two bands), never a corner touch.
			var shared := 0
			for cell: Vector3i in houses[a].cells:
				for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
						Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					if owner.get(cell + step, &"") == b: shared += 1
			if shared < 4: continue
			# Two lots whose union is one rectangle would otherwise stand as
			# side-by-side copies (twin gables, the photo-11 sawtooth): they
			# become small ranges. Articulated contacts get first choice, so
			# filling a rectangle does not consume every possible L/T wing.
			var union: Dictionary = (ground[a] as Dictionary).duplicate()
			union.merge(ground[b])
			var box := BuildingDesigner._bounds(union)
			var range_pair := box.get_area() == union.size() \
				and int(houses[a].terrain_band) == int(houses[b].terrain_band)
			var roll := float(absi(hash([world_seed, a, b, &"merge"])) % 10000) / 10000.0
			if roll < (RANGE_MERGE_CHANCE if range_pair else MERGE_CHANCE):
				# Articulated contacts first, then the longest shared wall and roll.
				pairs.append([(1000.0 if range_pair else 0.0) - float(shared) + roll, a, b])
	pairs.sort_custom(func(p: Array, q: Array) -> bool:
		return p[0] < q[0] or (p[0] == q[0] and String(p[1]) + String(p[2]) < String(q[1]) + String(q[2])))
	var root: Dictionary = {}
	var members: Dictionary = {}
	for house_id: StringName in ids:
		root[house_id] = house_id
		members[house_id] = [house_id]
	for pair: Array in pairs:
		var ra: StringName = root[pair[1]]
		var rb: StringName = root[pair[2]]
		if ra == rb: continue
		var cells: Dictionary = {}
		for member: StringName in (members[ra] as Array) + (members[rb] as Array):
			for cell: Vector3i in houses[member].cells:
				cells[Vector2i(cell.x, cell.z)] = true
		var extent := BuildingDesigner._bounds(cells)
		if cells.size() > MERGE_MAX_CELLS or maxi(extent.size.x, extent.size.y) > MERGE_MAX_SPAN:
			continue
		# Test the complete proposed group, not just the original pair: several
		# harmless two-lot joins otherwise accumulate into a huge plain block.
		# Stepped crowns remain articulated even on a rectangular footprint.
		var crowns := {}
		var member_names: Array[String] = []
		for member: StringName in (members[ra] as Array) + (members[rb] as Array):
			member_names.append(String(member))
			var floors: Array = (houses[member].storeys as Dictionary).keys()
			floors.sort()
			crowns[int(floors.back())] = true
		if cells.size() > LARGE_PLAIN_RANGE_CELLS \
				and extent.get_area() == cells.size() and crowns.size() == 1:
			member_names.sort()
			var roll := float(posmod(hash([world_seed, member_names,
				"large_plain_range"]), 10000)) / 10000.0
			if roll >= LARGE_PLAIN_RANGE_CHANCE:
				continue
		var keep := ra if String(ra) < String(rb) else rb
		var gone := rb if keep == ra else ra
		(members[keep] as Array).append_array(members[gone])
		for member: StringName in members[gone]:
			root[member] = keep
		members.erase(gone)
	var out: Dictionary = {}
	for keep: StringName in members:
		var group: Array = members[keep]
		if group.size() == 1:
			out[keep] = houses[keep]
			continue
		group = sorted_ids(group)
		var merged := {"cells": [], "storeys": {}, "doors": [], "terrain_band": 1 << 20,
			"landmark": false, "roof_crowns": {}, "grounded": {}, "crown_parts": {},
			"members": group}
		var tops: Dictionary = {}
		for member: StringName in group:
			var house: Dictionary = houses[member]
			(merged.cells as Array).append_array(house.cells)
			(merged.doors as Array).append_array(house.doors)
			merged.terrain_band = mini(int(merged.terrain_band), int(house.terrain_band))
			var base := int(house.terrain_band)
			if not (merged.grounded as Dictionary).has(base):
				merged.grounded[base] = {}
			(merged.grounded[base] as Dictionary).merge(house.storeys[base])
			for floor: int in house.get("grounded", {}):
				if not (merged.grounded as Dictionary).has(floor):
					merged.grounded[floor] = {}
				(merged.grounded[floor] as Dictionary).merge(house.grounded[floor])
			var top := -(1 << 20)
			for floor: int in house.storeys:
				top = maxi(top, floor)
				if not (merged.storeys as Dictionary).has(floor):
					merged.storeys[floor] = {}
				(merged.storeys[floor] as Dictionary).merge(house.storeys[floor])
			tops[member] = top
		# Each member's own top is roofed in the compound unless another
		# member stands directly on it; crowns beneath the compound's own
		# upper storeys (a stepped plan, a recessed loggia) keep the house's
		# terrace rule.
		var solid: Dictionary = {}
		for member: StringName in group:
			for cell: Vector3i in houses[member].cells:
				solid[cell] = true
		for member: StringName in group:
			var top: int = tops[member]
			if not (merged.roof_crowns as Dictionary).has(top):
				merged.roof_crowns[top] = {}
			for cell: Vector2i in houses[member].storeys[top]:
				if not solid.has(Vector3i(cell.x, top + 2, cell.y)):
					(merged.roof_crowns[top] as Dictionary)[cell] = true
		# Every member's footprint per storey: the designer may fall back to
		# the members' own crown packing.
		for member: StringName in group:
			for floor: int in houses[member].storeys:
				if not (merged.crown_parts as Dictionary).has(floor):
					merged.crown_parts[floor] = []
				(merged.crown_parts[floor] as Array).append(houses[member].storeys[floor])
		out[keep] = merged
	return out


static func _add_storey_cells(house: Dictionary, floor: int,
		cells: Array) -> void:
	var storeys: Dictionary = house.storeys
	if not storeys.has(floor):
		storeys[floor] = {}
	for cell: Vector3i in cells:
		if cell.y == floor:
			(storeys[floor] as Dictionary)[Vector2i(cell.x, cell.z)] = true


## A reserved landmark becomes a kit house on its terrain-rooted footprint:
## storeys fill the reserved height below a two-band roof allowance.
static func _landmark_house(feature: WarrenFeatureReservation,
		source: WarrenMazeSourcePlan = null) -> Dictionary:
	# The reservation is the measured shell ring of a complete prefab; broad
	# envelopes admit connected wings while keeping the authored entrance.
	# Landmarks are the village's large houses:
	# two or three storeys whatever the prefab's height was -- except on the
	# town's edge rings, where they keep the same one-storey-per-ring profile
	# as every other house (September 29 edges; a landmark on the rim is a
	# long one-storey hall, not a three-storey wall on the lawn).
	var base := 1 << 20
	var top := -(1 << 20)
	var ring: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		base = mini(base, cell.y)
		top = maxi(top, cell.y + 1)
	for cell: Vector3i in feature.reserved_cells:
		if cell.y == base:
			ring[Vector2i(cell.x, cell.z)] = true
	var rect := BuildingDesigner._bounds(ring)
	var entrance := feature.audit.get("landmark_entrance_cell", Vector3i.ZERO) as Vector3i
	var landing := feature.audit.get("landmark_public_landing_cell", entrance) as Vector3i
	var footprint := _landmark_footprint(rect, entrance, landing,
		hash([source.world_seed if source != null else 0,String(feature.stable_id),rect]))
	var storey_count := clampi((top - base) / 2, 2, 3)
	if source != null:
		var columns: Array = []
		for cell: Vector2i in ring:
			columns.append(Vector2i(floori(cell.x / 2.0), floori(cell.y / 2.0)))
		var cap := WarrenPlotPlanner.edge_storey_cap(source, columns, base)
		if cap >= 0:
			storey_count = clampi(cap, 1, storey_count)
	var house := {"cells": [], "storeys": {}, "doors": [], "terrain_band": base,
		"landmark": true}
	for s in storey_count:
		var floor := base + s * 2
		var layer: Array = []
		for cell: Vector2i in footprint:
			layer.append(Vector3i(cell.x, floor, cell.y))
			layer.append(Vector3i(cell.x, floor + 1, cell.y))
		(house.cells as Array).append_array(layer)
		_add_storey_cells(house, floor, layer)
	# The reserved volume above a capped landmark stays its own air: its roof
	# may rise into it (it is not another owner's space to keep clear).
	var own_air: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		if cell.y >= base + storey_count * 2 or not footprint.has(Vector2i(cell.x,cell.z)):
			own_air[cell] = true
	house["own_air"] = own_air
	if entrance != landing:
		(house.doors as Array).append({"cell": entrance,
			"direction": landing - entrance})
	return house


static func _landmark_footprint(rect: Rect2i, entrance: Vector3i,
		landing: Vector3i, seed_value: int) -> Dictionary:
	var full := {}
	for x in range(rect.position.x,rect.end.x):
		for z in range(rect.position.y,rect.end.y): full[Vector2i(x,z)] = true
	if rect.get_area() <= LARGE_PLAIN_RANGE_CELLS or mini(rect.size.x,rect.size.y)<4:
		return full
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if rng.randf()<0.15: return full
	var door := Vector2i(entrance.x,entrance.z)
	var direction := Vector2i(landing.x-entrance.x,landing.z-entrance.z)
	var protected := {door:true,door-direction:true}
	var tangent := Vector2i(-direction.y,direction.x)
	# Preserve both possible halves of the doorway and its interior approach.
	for offset in [-1,1]:
		protected[door+tangent*offset] = true
		protected[door-direction+tangent*offset] = true
	var first := rng.randi_range(0,3)
	var tee := rng.randf()<0.5 and maxi(rect.size.x,rect.size.y)>=6
	for attempt in 4:
		var corner := (first+attempt)%4
		var cut_width := 2 if tee else maxi(2,(rect.size.x/2)/2*2)
		var cut_depth := 2 if tee else maxi(2,(rect.size.y/2)/2*2)
		var cut := Rect2i(Vector2i(rect.position.x if corner%2==0 else rect.end.x-cut_width,
			rect.position.y if corner<2 else rect.end.y-cut_depth),Vector2i(cut_width,cut_depth))
		var second := cut
		if rect.size.x>=rect.size.y:
			second.position.x = rect.end.x-cut_width if corner%2==0 else rect.position.x
		else:
			second.position.y = rect.end.y-cut_depth if corner<2 else rect.position.y
		var candidate := full.duplicate()
		for cell: Vector2i in full:
			if cut.has_point(cell) or (tee and second.has_point(cell)): candidate.erase(cell)
		var keeps_door := true
		for cell: Vector2i in protected:
			if full.has(cell) and not candidate.has(cell): keeps_door = false
		if keeps_door: return candidate
	return full


static func _native_landmark(feature: WarrenFeatureReservation) -> bool:
	# Its measured derivation was reserved before packing. Keep the exact
	# fabric recipe; converting its volume into a kit mass loses native joints.
	return feature.kind == &"prefab_landmark" and String(feature.audit.get(
		"landmark_recipe_id", &"")).begins_with("anchor.z_native.")


static func _replaced_units(spatial: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Dictionary:
	var room_ids: Dictionary = {}
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_ids[room.stable_id] = true
	var feature_ids: Dictionary = {}
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind in REPLACED_FEATURE_KINDS and not _native_landmark(feature):
			feature_ids[feature.stable_id] = true
	var replaced: Dictionary = {}
	for unit: FabricUnit in fabric.units:
		var id := String(unit.stable_id)
		if id.begins_with("spatial.fabric."):
			var rest := id.trim_prefix("spatial.fabric.")
			if room_ids.has(StringName(rest)) \
					or feature_ids.has(StringName(rest.get_slice(".component", 0))):
				replaced[unit.stable_id] = true
		elif id.begins_with("spatial.roof."):
			var room_id := id.trim_prefix("spatial.roof.")
			for suffix: String in [".tile", ".garden"]:
				var cut := room_id.find(suffix)
				if cut > 0:
					room_id = room_id.substr(0, cut)
			if room_ids.has(StringName(room_id)):
				replaced[unit.stable_id] = true
	return replaced


## Drops placements whose stable id starts with one of `prefixes`.
static func without_prefixes(source: EnvironmentInstancePayload,
		prefixes: Array[String]) -> EnvironmentInstancePayload:
	var out := EnvironmentInstancePayload.new()
	for asset_id: StringName in source.asset_ids():
		var batch: Dictionary = source.batches[asset_id]
		for index in batch.transforms.size():
			var id := String(batch.ids[index]) if not batch.ids.is_empty() else ""
			var drop := false
			for prefix: String in prefixes:
				drop = drop or id.begins_with(prefix)
			if drop:
				continue
			var flags: Array = batch.get("collision_enabled", [])
			var owners: Array = batch.get("visibility_owners", [])
			out.add(asset_id, batch.transforms[index], batch.colors[index],
				StringName(id), flags.is_empty() or bool(flags[index]),
				owners[index] if index < owners.size() else AABB())
	for mesh: Dictionary in source.surface_meshes:
		if not _has_prefix(String(mesh.get("stable_id", "")), prefixes):
			out.add_surface_mesh(mesh)
	for box: Dictionary in source.collision_boxes:
		if not _has_prefix(String(box.get("stable_id", "")), prefixes):
			out.add_collision_box(box.transform, box.size, StringName(box.get("stable_id", &"")))
	return out


static func _has_prefix(id: String, prefixes: Array[String]) -> bool:
	for prefix: String in prefixes:
		if id.begins_with(prefix):
			return true
	return false


## `SettlementFabricAssembler.payload` without the replaced building units.
static func legacy_payload_without(fabric: SettlementFabricPlan,
		replaced_units: Dictionary) -> EnvironmentInstancePayload:
	var out := EnvironmentInstancePayload.new()
	for placement: Dictionary in fabric.expanded_placements():
		var stable_id := String(placement.stable_id)
		# A constructed support can have a slash-containing unit ID beneath a
		# replaced room. Only that exact unit is replaced, not its descendants.
		var unit_id := StringName(placement.get("unit_id",stable_id.get_slice("/",0)))
		if replaced_units.has(unit_id):
			continue
		var family_dropped := false
		for prefix: String in REPLACED_PLACEMENT_PREFIXES:
			family_dropped = family_dropped or stable_id.begins_with(prefix)
		if family_dropped:
			continue
		var pose := placement.transform as Transform3D
		var unit := fabric.unit(unit_id)
		if unit != null and StringName(placement.get("placement_id",&"")) == &"post" \
				and fabric.recipe(unit.recipe_id).has_tag(&"grounded_frame_member"):
			pose = _kit_frame_post_transform(fabric,unit,replaced_units,pose,placement.bounds)
		var owner := placement.get("visibility_owner",placement.get("bounds",AABB())) as AABB
		if pose != (placement.transform as Transform3D):
			owner = owner.merge((pose*(placement.transform as Transform3D).affine_inverse())*(placement.bounds as AABB))
		out.add(StringName(placement.asset_id),
			pose, Color.WHITE,
			StringName(placement.stable_id), true,
			owner)
	for cap: Dictionary in fabric.wall_cap_surfaces:
		var owner := StringName(String(cap.get("stable_id", "")).get_slice("/", 0))
		if replaced_units.has(owner):
			continue
		out.add_surface_mesh(cap)
	return out


static func _kit_frame_post_transform(fabric: SettlementFabricPlan, unit: FabricUnit,
		replaced: Dictionary, pose: Transform3D, bounds: AABB) -> Transform3D:
	# The old room floor hung below its datum. Kit floor boards start at the
	# datum instead; retain the same native post and foot, extending only the
	# topmost course to the floor it explicitly bears. Intermediate courses
	# keep their original endpoints and cannot acquire a gap or overlap.
	for parent_id: StringName in unit.visual_seam_ids:
		var parent := fabric.unit(parent_id)
		if parent == null or not replaced.has(parent_id) \
				or not fabric.recipe(parent.recipe_id).has_tag(&"room"): continue
		var underside := float(parent.lattice_origin.y)*FabricRecipe.CELL_SIZE
		if underside<=bounds.end.y or underside-bounds.end.y>FabricRecipe.CELL_SIZE*.5: continue
		var scale_y := (underside-bounds.position.y)/bounds.size.y
		return Transform3D(Basis.from_scale(Vector3(1,scale_y,1)),
			Vector3(0,bounds.position.y*(1.0-scale_y),0))*pose
	return pose


static func _solid_other(grid: WarrenSpatialGrid, owner_at: Dictionary,
		own_id: StringName, cell: Vector3i) -> bool:
	if owner_at.has(cell):
		return owner_at[cell] != own_id
	if not grid.contains(cell):
		return false
	return grid.use_at(cell) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME


## True where the kit may not put anything outside the mass (public air and
## its walked floors, reserved daylight, other owners, retained structure).
static func _keep_clear(grid: WarrenSpatialGrid, owner_at: Dictionary,
		own_id: StringName, cell: Vector3i) -> bool:
	if owner_at.has(cell):
		return owner_at[cell] != own_id
	if not grid.contains(cell):
		return false
	var use := grid.use_at(cell)
	return use != WarrenSpatialGrid.Use.ALLOCATABLE \
		and use != WarrenSpatialGrid.Use.OUTSIDE


static func _walked(grid: WarrenSpatialGrid, cell: Vector3i) -> bool:
	if not grid.contains(cell) \
			or grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
		return false
	var claim := grid.face_claim(cell, Vector3i.DOWN)
	return not claim.is_empty() \
		and int(claim.get("kind", -1)) == WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR


## Plan columns (fine cells) crossed by a public flight: every STAIR claim
## (a sloped transition, its bands) and every raised gate's exterior approach
## flight (any band: it descends to the ground outside the town). Values are
## the claimed bands; gate approaches use an empty list meaning "all bands".
static func flight_columns(spatial: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Dictionary:
	var out: Dictionary = {}
	if fabric == null or fabric.surface_plan == null:
		return out
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.STAIR):
		var column := Vector2i(cell.x, cell.z)
		if not out.has(column):
			out[column] = [cell.y]
		else:
			(out[column] as Array).append(cell.y)
	var size := FabricRecipe.CELL_SIZE
	for spec: Dictionary in VillageWarrenFabricSolver.terrain_contact_specs(spatial, fabric):
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		if not bool(geometry.get("has_stairs", false)):
			continue
		var a := geometry.inner_centre as Vector3
		var b := geometry.outer_centre as Vector3
		var lateral := Vector3(spec.lateral) * float(geometry.half_width)
		var rect := Rect2(Vector2(a.x, a.z), Vector2.ZERO)
		for p: Vector3 in [a - lateral, a + lateral, b - lateral, b + lateral]:
			rect = rect.expand(Vector2(p.x, p.z))
		for x in range(floori(rect.position.x / size + 0.5 + 0.01),
				floori(rect.end.x / size + 0.5 - 0.01) + 1):
			for z in range(floori(rect.position.y / size + 0.5 + 0.01),
					floori(rect.end.y / size + 0.5 - 0.01) + 1):
				out[Vector2i(x, z)] = []
	return out


## True when a flight crosses `cell` within the bands a floor-standing
## feature at `band` would occupy (its floor, its height, one band below).
static func crosses_flight(flights: Dictionary, cell: Vector2i, band: int) -> bool:
	if not flights.has(cell):
		return false
	var bands: Array = flights[cell]
	if bands.is_empty():
		return true
	for claimed: int in bands:
		if claimed >= band - 1 and claimed <= band + 2:
			return true
	return false


## Cells walled by the retained massif's own courses (terraces and tunnel
## ceilings): the podium houses may stand on.
static func _podium_cells(feature_masses: Array[BuildingMass]) -> Dictionary:
	var podium: Dictionary = {}
	for mass: BuildingMass in feature_masses:
		if mass.stable_id not in [&"kit.retained", &"kit.tunnel-ceilings", &"kit.platform-wall"]:
			continue
		for storey: Dictionary in mass.storeys:
			var floor := int(storey.floor_band)
			for cell: Vector2i in storey.cells:
				for band in range(floor, floor + int(storey.get("bands", 2))):
					podium[Vector3i(cell.x, band, cell.y)] = true
	return podium


static func _mass_for(house_id: StringName, house: Dictionary,
		grid: WarrenSpatialGrid, owner_at: Dictionary, world_seed: int,
		kit: BuildingKit, flights: Dictionary = {}, canopy_claims: Array = [],
		podium: Dictionary = {}, passages: Dictionary = {}, ridge_counts := Vector2i.ZERO,
		public_crowns: Dictionary = {}, bracket_bearings: Variant = null,
		growth: Dictionary = {}) -> BuildingMass:
	var storeys_by_band: Dictionary = house.storeys
	if storeys_by_band.is_empty():
		return null
	var terrain_band := int(house.terrain_band)
	var mass := BuildingMass.new()
	mass.stable_id = StringName("kit.%s" % house_id)
	mass.seed = hash([world_seed, house_id])
	var floors := storeys_by_band.keys()
	floors.sort()
	mass.ground_band = terrain_band if terrain_band < (1 << 20) else int(floors[0])
	var terrain_storey := -1
	for floor: int in floors:
		if floor == terrain_band:
			terrain_storey = mass.storeys.size()
		var storey := mass.add_storey(floor, storeys_by_band[floor], BuildingMass.MATERIAL_TIMBER)
		if house.has("roof_crowns"):
			storey["roofed"] = (house.roof_crowns as Dictionary).get(floor, {})
			storey["crown_parts"] = (house.crown_parts as Dictionary).get(floor, [])
		# A part standing on higher ground than the house's lowest one (a
		# compound member, a back room up the slope): its cells on the
		# terrain or a retained terrace rest on the ground (a footing
		# course, no soffit), not over air.
		if floor != terrain_band:
			var grounded := {}
			for cell: Vector2i in (house.get("grounded", {}) as Dictionary).get(floor, {}):
				var under := Vector3i(cell.x, floor - 1, cell.y)
				if not grid.contains(under) \
						or grid.use_at(under) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
					grounded[cell] = true
			if not grounded.is_empty():
				storey["grounded"] = grounded
		# A storey at or below the house's datum still closes its underside
		# where it hangs over public air (a bridge-house over a lane has no
		# terrain-bearing room, so its lowest floor IS the datum). Without it
		# the lane looked up into the empty room: inner walls, gable timbers
		# and sky between them.
		if floor <= mass.ground_band:
			var overhang: Dictionary = {}
			for cell: Vector2i in storeys_by_band[floor]:
				var under := Vector3i(cell.x, floor - 1, cell.y)
				if grid.contains(under) and grid.use_at(under) in [
						WarrenSpatialGrid.Use.PUBLIC_AIR, WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
					overhang[cell] = true
			if not overhang.is_empty():
				storey["soffit"] = true
				storey["soffit_cells"] = overhang
	for door: Dictionary in house.doors:
		var private_cell := door.cell as Vector3i
		var direction := door.direction as Vector3i
		var dir := BuildingMass.DIRS.find(Vector2i(direction.x, direction.z))
		if dir < 0:
			continue
		var storey := _storey_for_band(mass, private_cell.y)
		if storey.is_empty():
			continue
		storey.openings[BuildingMass.edge_key(Vector2i(private_cell.x,
			private_cell.z), dir)] = BuildingMass.OPENING_DOOR
		if bool(door.get("passage", false)):
			var passage_edges: Dictionary = storey.get("passage_edges", {})
			passage_edges[BuildingMass.edge_key(Vector2i(private_cell.x,
				private_cell.z), dir)] = true
			storey["passage_edges"] = passage_edges
			# A passage-house abuts this wall line: the storey stays flush
			# (an inset storey recedes half a module, leaving a gap and the
			# passage's corner posts standing in front of its openings).
			storey["abutted"] = true
		if bool(door.get("balcony", false)):
			# The balcony's rakers bear on the wall below this storey at its
			# module joints; the designer keeps that wall flush (no jetty).
			storey["bears_balcony"] = true
	var designer := BuildingDesigner.new(kit)
	designer.square_axis_weights = Vector2(ridge_counts.y + 1,ridge_counts.x + 1)
	var own_air: Dictionary = house.get("own_air", {})
	designer.forbidden = func(cell: Vector2i, band: int) -> bool:
		return passages.has(Vector3i(cell.x, band, cell.y)) \
			or (not own_air.has(Vector3i(cell.x, band, cell.y)) \
			and _keep_clear(grid, owner_at, house_id, Vector3i(cell.x, band, cell.y)))
	designer.walked = func(cell: Vector2i, band: int) -> bool:
		return public_crowns.has(Vector3i(cell.x, band, cell.y)) \
			or _walked(grid, Vector3i(cell.x, band, cell.y))
	designer.public_air = func(cell: Vector2i, band: int) -> bool:
		var probe := Vector3i(cell.x, band, cell.y)
		return grid.contains(probe) and grid.use_at(probe) == WarrenSpatialGrid.Use.PUBLIC_AIR \
			and not _walked(grid, probe)
	designer.covered = func(cell: Vector2i, band: int) -> bool:
		return _solid_other(grid, owner_at, house_id, Vector3i(cell.x, band, cell.y))
	designer.flight = func(cell: Vector2i, band: int) -> bool:
		return crosses_flight(flights, cell, band)
	designer.canopy_claims = canopy_claims
	# Decide the primary silhouette before a small loggia notch disqualifies
	# a rectangular crown, including long two-module-wide houses.
	var shaped := false
	var bearing := Callable()
	if bracket_bearings != null:
		bearing = func(cell: Vector2i, band: int) -> bool:
			return bracket_bearings.has(Vector3i(cell.x,band,cell.y))
	if not mass.storeys.is_empty():
		var crown_bounds := BuildingDesigner._bounds(mass.storeys[-1].cells)
		if mini(crown_bounds.size.x,crown_bounds.size.y)>=2 \
				and maxi(crown_bounds.size.x,crown_bounds.size.y)>=4:
			shaped = preload("res://scripts/terrain/features/villages/kit/KitSteppedWings.gd").shape(
				mass, designer.covered, designer.walked, bearing)
	preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd").recess(
		mass, designer.forbidden, designer.walked, designer.public_air)
	if not shaped:
		preload("res://scripts/terrain/features/villages/kit/KitSteppedWings.gd").shape(
			mass, designer.covered, designer.walked, bearing)
	var context := {"terrain_storey": terrain_storey, "terraced": true,
		"colour": _district_colour(world_seed, house.cells)}
	# A house standing on the retained podium already has its masonry base:
	# the podium's course. A stone storey on it would stack a second, deeper
	# stone wall on the course (a 0.2 m jog, offset corner posts, two brick
	# fields; September 29 photo 7), so its ground storey is timber-framed.
	# Likewise beside it: a podium course abutting the ground storey runs
	# its flush face on the same wall line as the storey's deep masonry (a
	# merged compound's range can end against a terrace).
	if terrain_storey >= 0:
		for cell: Vector2i in storeys_by_band[terrain_band]:
			var near := podium.has(Vector3i(cell.x, terrain_band - 1, cell.y))
			for step: Vector2i in BuildingMass.DIRS:
				near = near or podium.has(Vector3i(cell.x + step.x, terrain_band, cell.y + step.y))
			if near:
				context["stone_chance"] = 0.0
				break
	if not growth.is_empty():
		mass.grows = GROWTH.house_grows(growth.character, mass, growth.solid, growth.street)
		if mass.grows:
			context["grows"] = true
	designer.articulate(mass, context)
	# The circulation compiler can use a construction crown as a bridge
	# landing. Replacing that flat roof with a gable leaves the accepted
	# bridge without its far floor. Draw its real native deck here; existing
	# exterior terrace guards already own the boundary and bridge openings.
	for storey: Dictionary in mass.storeys:
		var band := int(storey.floor_band) + 2
		var deck := {}
		for cell: Vector2i in storey.cells:
			if public_crowns.has(Vector3i(cell.x, band, cell.y)):
				deck[cell] = true
		if not deck.is_empty():
			mass.decks.append({"cells": deck, "band": band, "rails": false})
	# Wall rooms retain the city's structural cap. A native pent eave marks
	# the inhabited frontage under that cap, instead of giving the room a
	# free-standing cottage roof. The assembler admits the complete hood and
	# its two end boards against finished public headroom.
	if String(house_id).contains("wall-room"):
		for storey: Dictionary in mass.storeys:
			storey["pent_colour"] = context.colour
	return mass


static func _storey_for_band(mass: BuildingMass, band: int) -> Dictionary:
	for storey: Dictionary in mass.storeys:
		if int(storey.floor_band) == band:
			return storey
	for storey: Dictionary in mass.storeys:
		var floor := int(storey.floor_band)
		if band >= floor and band < floor + 2:
			return storey
	return {}


## Roof colour districts: coarse hashed patches so neighbouring houses share
## a colour family, as in the reference village.
static func _district_colour(world_seed: int, cells: Array) -> StringName:
	var centre := Vector2.ZERO
	for cell: Vector3i in cells:
		centre += Vector2(cell.x, cell.z)
	centre /= maxf(1.0, float(cells.size()))
	# Small colour quarters, evenly red and blue, with the odd house breaking
	# ranks so a quarter never reads as one uniform sheet.
	var district := Vector2i(floori(centre.x / 7.0), floori(centre.y / 7.0))
	var blue := absi(hash([world_seed, district])) % 2 == 0
	if absi(hash([world_seed, cells.size(), centre])) % 6 == 0:
		blue = not blue
	return &"blue" if blue else &"red"


## A native tower may stand on natural ground or the exposed top of an actual
## retained stone course. Room roofs and public timber floors are not bearing.
static func _tower_bearing(envelope: WarrenVolumeEnvelope, podium: Dictionary,
		cell: Vector2i, band: int) -> bool:
	if envelope == null: return false
	if band == envelope.ground_at(Vector2i(floori(cell.x/2.0),floori(cell.y/2.0))): return true
	return podium.has(Vector3i(cell.x,band-1,cell.y)) \
		and not podium.has(Vector3i(cell.x,band,cell.y))
