extends SceneTree

## Where does a mass-first seed die? Reports the two stages that actually
## consume the corpus, per seed, so a change can be judged without reading a
## composed town's tail end.
##
## Reach for this when mass-first stops producing towns, or after touching
## WarrenSolidPartitioner / WarrenExcavationCarver / WarrenMassifBuilder: the
## `gate` stage is a ~15 s answer where `compose` is a ~8 min one, and the two
## report different failures, so a green `gate` run does not imply a composed
## town.
##
##   --stage gate      per-volume construction-gate metrics plus whether the
##                     real FabricRoofJunctionModuleTable accepts the partition.
##                     `gate=false` names a WarrenTownSolver threshold that the
##                     partition misses; `roofs=false` means the roofs cannot be
##                     joined and the plan is doomed however well it scores.
##   --stage compose   WarrenBuiltTownSolver.solve() per seed, reporting the
##                     rejecting stage for every seed that does not compose.
##   --stage bridge    whether the solid standing OVER the streets could become
##                     houses at all: how deep it is, how many street-spanning
##                     footprints exist, and how many of them are legal
##                     envelopes. Read it with `cover`, which says how much of
##                     that solid the partition actually built -- `cover` alone
##                     cannot tell lost cover from unbuildable trim.
##   --stage contact   both pipelines' building-contact metrics side by side,
##                     parcel-weighted against cell-weighted. Use it when
##                     touching the construction gate's contact threshold.
##   --seeds 1,3,4     seed list (default: the mass-first review corpus).
##
## Usage:
##   Godot --headless --path . -s tests/harness/warren_mass_first_report.gd \
##     -- --stage gate --seeds 1,3,4,5,6,9,11,13,16,20

const DEFAULT_SEEDS: Array[int] = [1, 3, 4, 5, 6, 9, 11, 13, 16, 20]

var _stage := "gate"
var _seeds: Array[int] = []


func _init() -> void:
	_read_args()
	if _seeds.is_empty():
		_seeds.assign(DEFAULT_SEEDS)
	if _stage == "cover":
		_report_cover()
		quit()
		return
	if _stage == "bridge":
		_report_bridge()
		quit()
		return
	if _stage == "skywalk":
		_report_skywalk()
		quit()
		return
	if _stage == "envelopes":
		_report_envelopes()
		quit()
		return
	if _stage == "contact":
		_report_contact()
		quit()
		return
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	if _stage == "compose":
		_report_composition()
	else:
		_report_gate()
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	quit()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--stage" and index + 1 < args.size():
			_stage = args[index + 1]
		elif args[index] == "--allow-corner-overlap":
			# See SettlementFabricPlan: diagnostic only, so a town blocked
			# solely by corner-envelope overlap can be measured and rendered.
			SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
		elif args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				_seeds.append(int(token))


func _report_gate() -> void:
	var passing := 0
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier -- %s" % [world_seed,
				WarrenTownSolver.last_failure])
			continue
		var best := ""
		var usable := false
		for volume: WarrenVolumePlan in frontier:
			var plan := WarrenTownSolver.partition_parcels(volume)
			if plan == null:
				continue
			var gate := WarrenTownSolver._passes_construction_gate(plan, true)
			var roofs := _roofs_compile(plan)
			usable = usable or (gate and roofs)
			if best.is_empty() or (gate and roofs):
				best = "n=%d cells=%d families=%d contact=%.2f contacted=%.2f " \
					% [int(plan.audit.parcel_count),
						int(plan.audit.get("parcel_footprint_cell_count", 0)),
						int(plan.audit.footprint_family_count),
						float(plan.audit.get(
							"largest_building_contact_component_cell_ratio",
							0.0)),
						float(plan.audit.get("contacted_building_ratio", 0.0))] \
					+ "isolated=%d roofbands=%d gate=%s roofs=%s" \
					% [int(plan.audit.get("isolated_building_count", -1)),
						int(plan.audit.get("roof_band_count", 0)), gate, roofs]
		passing += int(usable)
		print("seed %2d: usable=%s | %s" % [world_seed, usable, best])
	print("SEEDS with a gate-passing, roof-joinable volume: %d/%d" % [passing,
		_seeds.size()])


func _report_composition() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		print("no compiled construction vocabulary")
		return
	var composed := 0
	for world_seed: int in _seeds:
		var town := WarrenBuiltTownSolver.solve(world_seed, program)
		if town != null:
			composed += 1
			print("seed %2d: COMPOSED (%d buildings)" % [world_seed,
				town.town.parcels.parcels.size()])
			continue
		# An empty candidate-failure list means nothing was ever ranked, so the
		# corpus was consumed before composition and WarrenTownSolver holds the
		# reason.
		var reason := WarrenBuiltTownSolver.last_failure
		if WarrenBuiltTownSolver.last_candidate_failure_diagnostic.is_empty():
			reason = "no ranked candidate -- %s" % WarrenTownSolver.last_failure
		print("seed %2d: FAILED :: %s" % [world_seed, reason.substr(0, 400)])
	print("COMPOSED %d/%d" % [composed, _seeds.size()])


func _report_cover() -> void:
	## Is mass that stands OVER a street actually being built into houses?
	## A route cell with solid above its carved headroom is potential cover; if
	## the partition leaves that solid unbuilt, the overhead the visual gate
	## measures was available and lost in this stage. If instead there is no
	## mass above, the ceiling is structural and no partition can raise it.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		var volume := frontier[0]
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
		var excavation := WarrenExcavationVolumeAdapter.excavation_for_volume(
			bore, volume)
		var plan := WarrenTownSolver.partition_parcels(volume)
		if excavation == null or plan == null:
			print("seed %2d: no partition" % world_seed)
			continue
		var owned: Dictionary = {}
		for parcel: WarrenBuildingParcel in plan.parcels:
			for cell: Vector3i in WarrenSolidPartitioner.occupied_cells(parcel):
				owned[cell] = true
		var roofed := 0
		var bare := 0
		var lost_cells := 0
		for walk: Vector3i in excavation.route:
			var column := Vector2i(walk.x, walk.z)
			var ceiling := walk.y + excavation.slot_bands(walk)
			var above := massif.top_at(column) - ceiling
			if above <= 0:
				bare += 1
				continue
			roofed += 1
			for band in range(ceiling, massif.top_at(column)):
				var cell := Vector3i(column.x, band, column.y)
				if not excavation.carved.has(cell) and not owned.has(cell):
					lost_cells += 1
		print("seed %2d: route %d | cells with mass above %d | no mass above %d"
			% [world_seed, excavation.route.size(), roofed, bare]
			+ " | UNBUILT mass cells over the route %d" % lost_cells)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _report_skywalk() -> void:
	## Does a mass-first partition offer any occupied-link corridor at all?
	##
	## Route-first seeds one deliberately: WarrenParcelizer._best_connection_pair
	## reserves a skywalk pair BEFORE packing anything else, so two compatible
	## upper-room sockets are guaranteed to survive facing each other, and
	## WarrenBuiltTownSolver realises that reservation ahead of every other
	## detail. Mass-first replaced WarrenParcelizer.solve wholesale, so it seals
	## its plan with no reservations and skywalks are left to the detail phase.
	##
	## This asks the question the parcel stage would ask:
	## WarrenAssetCompiler.skywalk_reservation over every pair of partitioned
	## houses, with the volume's own public air, then the same
	## parcel_preserves_skywalk_reservation filter the parcelizer applies before
	## committing one. `standalone` is how many pairs form a corridor at all;
	## `preserved` is how many survive every other house in the partition; `cover`
	## counts those that pass over a ground route cell.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		print("no compiled construction vocabulary")
		return
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		var volumes := 0
		var best_standalone := 0
		var best_preserved := 0
		var best_cover := 0
		var best_solid := 0
		var best_envelope := 0
		var parcels := 0
		for volume: WarrenVolumePlan in frontier:
			var plan := WarrenTownSolver.partition_parcels(volume)
			var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
			if plan == null or realm == null:
				continue
			volumes += 1
			parcels = maxi(parcels, plan.parcels.size())
			var air := realm.air_claims()
			var cache: Dictionary = {&"enabled": true}
			var standalone := 0
			var preserved := 0
			var cover := 0
			var blocked_solid := 0
			var blocked_envelope := 0
			for left_index in plan.parcels.size():
				var left := plan.parcels[left_index]
				for right_index in range(left_index + 1, plan.parcels.size()):
					var right := plan.parcels[right_index]
					var reservation := WarrenAssetCompiler.skywalk_reservation(
						left, right, program, air, cache)
					if reservation.is_empty():
						continue
					standalone += 1
					var clear := true
					for other: WarrenBuildingParcel in plan.parcels:
						if other == left or other == right:
							continue
						if WarrenAssetCompiler \
								.parcel_preserves_skywalk_reservation(other,
									reservation, program, cache):
							continue
						clear = false
						# Which half of that predicate fired decides whether the
						# corridor is inside a building (structural) or merely
						# grazed by a roof overhang (the envelope class).
						if _occupies_reserved_cells(other, reservation, program):
							blocked_solid += 1
						else:
							blocked_envelope += 1
						break
					if not clear:
						continue
					preserved += 1
					cover += int(_reservation_covers_route(volume, reservation))
			if standalone > best_standalone:
				best_standalone = standalone
				best_solid = blocked_solid
				best_envelope = blocked_envelope
			best_preserved = maxi(best_preserved, preserved)
			best_cover = maxi(best_cover, cover)
		print("seed %2d: %d volumes, up to %d houses" % [world_seed, volumes,
			parcels]
			+ " | skywalk pairs: standalone %d, preserved by the whole partition"
				% best_standalone
			+ " %d, of those over a route cell %d" % [best_preserved, best_cover]
			+ " | blocked by a third house: mass %d, envelope %d"
				% [best_solid, best_envelope])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _occupies_reserved_cells(parcel: WarrenBuildingParcel,
		reservation: Dictionary, program: SettlementFabricProgram) -> bool:
	## The structural half of WarrenAssetCompiler
	## .parcel_preserves_skywalk_reservation, restated so a rejection can be
	## attributed: does this house's built mass actually stand in the corridor,
	## or does only its clearance envelope reach it?
	var reserved := reservation.reserved_cells as Dictionary
	var proposal := WarrenParcelConstruction.proposal(parcel)
	if proposal.is_empty():
		return false
	for component: Dictionary in \
			StaggeredFabricCompiler.proposal_components(proposal):
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			continue
		for group: Array[Vector3i] in [recipe_value.solid_cells,
				recipe_value.headroom_cells]:
			for local_cell: Vector3i in group:
				if reserved.has(FabricRecipe.transform_cell(local_cell,
						component.origin as Vector3i,
						int(component.yaw_quarters))):
					return true
	return false


func _reservation_covers_route(volume: WarrenVolumePlan,
		reservation: Dictionary) -> bool:
	## Mirrors WarrenParcelizer._reservation_lower_route_cover_count's test for a
	## single reservation: a reserved cell standing over a walk cell's column,
	## clear of its headroom.
	var cells := reservation.get("reserved_cells", {}) as Dictionary
	for walk: Vector3i in volume.walk_cells:
		for cell_value: Variant in cells.keys():
			var cell := cell_value as Vector3i
			if cell.x == walk.x and cell.z == walk.z \
					and cell.y >= walk.y + WarrenVolumePlan.HEADROOM_BANDS:
				return true
	return false


const BRIDGE_SHAPES: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1),
]
const BRIDGE_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]


func _report_bridge() -> void:
	## CAN the over-street mass become houses at all? `cover` says how much is
	## left unbuilt; this says how much of it any legal envelope could ever
	## claim, before conflict resolution, so a partition change can be judged
	## against a real ceiling rather than against zero.
	##
	## A bridging house is an ordinary house whose footprint spans a lower walk
	## cell, so it is bound by every rule any house is: its base band must BE a
	## frontage cell's band (WarrenBuildingParcel.seal), at least half its
	## columns must reach ground (the bearing majority), and -- because a
	## mixed-span parcel never descends (WarrenParcelConstruction
	## ._support_base_band) -- it must carry two complete storeys plus the roof
	## reservation in the mass left ABOVE the street's headroom.
	##
	## Scanned over the WHOLE frontier, not one volume: a different bore leaves a
	## different thickness of mass overhead, so a negative taken from a single
	## candidate would only be a statement about that candidate.
	var minimum := WarrenBuildingParcel.STOREY_BANDS * 2 \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		var route_cells := 0
		var with_mass := 0
		var buildable_depth := 0
		var deepest := 0
		var spanning := 0
		var tallest := 0
		var two_storey_bridges := 0
		var one_storey_bridges := 0
		var one_storey_route_cells := 0
		var scanned := 0
		var refused: Dictionary = {"column": 0, "bearing": 0, "height": 0}
		for volume: WarrenVolumePlan in frontier:
			var massif := volume.mass_context.get(&"massif") as WarrenMassif
			var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
			var excavation := WarrenExcavationVolumeAdapter.excavation_for_volume(
				bore, volume)
			if massif == null or excavation == null:
				continue
			scanned += 1
			var ceilings: Dictionary = {}
			var over_street: Dictionary = {}
			for walk: Vector3i in excavation.route:
				var column := Vector2i(walk.x, walk.z)
				var ceiling := walk.y + excavation.slot_bands(walk)
				ceilings[column] = maxi(int(ceilings.get(column, -(1 << 30))),
					ceiling)
			route_cells = maxi(route_cells, excavation.route.size())
			var volume_with_mass := 0
			var volume_buildable := 0
			for column_value: Variant in ceilings.keys():
				var column := column_value as Vector2i
				var ceiling := int(ceilings[column])
				var above := massif.top_at(column) - ceiling
				if above <= 0:
					continue
				volume_with_mass += 1
				deepest = maxi(deepest, above)
				volume_buildable += int(above >= minimum)
				for band in range(ceiling, massif.top_at(column)):
					var cell := Vector3i(column.x, band, column.y)
					if not excavation.carved.has(cell):
						over_street[cell] = true
			with_mass = maxi(with_mass, volume_with_mass)
			buildable_depth = maxi(buildable_depth, volume_buildable)
			# Every address the plan offers, at the band a house rooted there sits.
			var addresses: Array[Vector3i] = []
			var seen_addresses: Dictionary = {}
			for cell: Vector3i in volume.walk_cells:
				seen_addresses[cell] = true
				addresses.append(cell)
			for cell: Vector3i in excavation.route:
				if not seen_addresses.has(cell):
					seen_addresses[cell] = true
					addresses.append(cell)
			var two_storey := _bridge_scan(addresses, ceilings, over_street,
				massif, excavation, minimum)
			# The same scan with the storey minimum dropped to one, which is what
			# a bridge over a street would have to be if it were allowed at all.
			# Not a proposal -- the number that says what the question is worth.
			var one_storey := _bridge_scan(addresses, ceilings, over_street,
				massif, excavation, WarrenBuildingParcel.STOREY_BANDS
					+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
			spanning = maxi(spanning, int(two_storey["spanning"]))
			tallest = maxi(tallest, int(two_storey["tallest"]))
			two_storey_bridges = maxi(two_storey_bridges,
				int(two_storey["candidates"]))
			one_storey_bridges = maxi(one_storey_bridges,
				int(one_storey["candidates"]))
			one_storey_route_cells = maxi(one_storey_route_cells,
				int(one_storey["route_cells"]))
			for reason: String in ["column", "bearing", "height"]:
				refused[reason] = int(refused[reason]) \
					+ int(two_storey[reason])
		print("seed %2d: %d volumes | route %d, with mass above %d," % [world_seed,
			scanned, route_cells, with_mass]
			+ " of which %d carry a %d-band envelope (deepest %d bands)"
				% [buildable_depth, minimum, deepest]
			+ " | street-spanning footprints %d, tallest legal span %d bands"
				% [spanning, tallest]
			+ " | BRIDGES: 2-storey %d, 1-storey %d over %d route cells"
				% [two_storey_bridges, one_storey_bridges, one_storey_route_cells]
			+ " | refused off-massif %d, bearing %d, too short %d"
				% [int(refused["column"]), int(refused["bearing"]),
					int(refused["height"])])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _bridge_scan(addresses: Array[Vector3i], ceilings: Dictionary,
		unbuilt: Dictionary, massif: WarrenMassif,
		excavation: WarrenExcavation, mixed_minimum: int) -> Dictionary:
	var out: Dictionary = {"column": 0, "bearing": 0, "height": 0,
		"tallest": 0, "spanning": 0, "candidates": 0}
	var reached: Dictionary = {}
	var reached_columns: Dictionary = {}
	for address: Vector3i in addresses:
		for direction: Vector2i in BRIDGE_DIRECTIONS:
			for shape: Vector2i in BRIDGE_SHAPES:
				var footprint := _bridge_footprint(address, direction, shape.x,
					shape.y)
				var spans := false
				for column: Vector2i in footprint:
					spans = spans or (ceilings.has(column) \
						and int(ceilings[column]) <= address.y)
				if not spans:
					continue
				out["spanning"] = int(out["spanning"]) + 1
				var top := _bridge_top(footprint, address.y, massif, excavation,
					out, mixed_minimum)
				if top <= address.y:
					continue
				out["candidates"] = int(out["candidates"]) + 1
				for column: Vector2i in footprint:
					for band in range(address.y, top):
						var cell := Vector3i(column.x, band, column.y)
						if not unbuilt.has(cell):
							continue
						reached[cell] = true
						# SettlementFabricSolver only counts a route cell covered
						# when a room occupies 2..6 bands above it, so mass higher
						# than that buys nothing the visual gate can see.
						if cell.y - int(ceilings[column]) \
								+ WarrenExcavation.HEADROOM_BANDS <= 6:
							reached_columns[column] = true
	out["reachable"] = reached.size()
	out["route_cells"] = reached_columns.size()
	return out


func _bridge_footprint(walk: Vector3i, direction: Vector2i, width: int,
		depth: int) -> Array[Vector2i]:
	var perpendicular := Vector2i(-direction.y, direction.x)
	var threshold := Vector2i(walk.x, walk.z) + direction
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_offset in width:
			out.append(threshold + direction * depth_offset \
				+ perpendicular * width_offset)
	return out


func _bridge_top(footprint: Array[Vector2i], base: int, massif: WarrenMassif,
		excavation: WarrenExcavation, reasons: Dictionary,
		mixed_minimum: int) -> int:
	## WarrenSolidPartitioner._top_band without the claim/no-straddle rules --
	## this measures what the SOLID allows, not what one serving order left.
	var top := 1 << 30
	var bearing := 0
	for column: Vector2i in footprint:
		if not massif.has_column(column) or massif.base_at(column) > base:
			reasons["column"] = int(reasons.get("column", 0)) + 1
			return base
		top = mini(top, massif.top_at(column))
		var grounded := true
		for band in range(massif.base_at(column), base):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				grounded = false
				break
		bearing += int(grounded)
	var reachable_top := top
	for column: Vector2i in footprint:
		for band in range(base, reachable_top):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				reachable_top = band
				break
	reasons["tallest"] = maxi(int(reasons.get("tallest", 0)),
		reachable_top - base)
	if bearing * 2 < footprint.size():
		reasons["bearing"] = int(reasons.get("bearing", 0)) + 1
		return base
	for column: Vector2i in footprint:
		for band in range(base, top):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				top = band
				break
	var settled := base + (top - base) - (top - base) % 2
	var needed := mixed_minimum
	if bearing == footprint.size():
		needed = WarrenBuildingParcel.STOREY_BANDS * 2 \
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
		var ground := -(1 << 30)
		for column: Vector2i in footprint:
			ground = maxi(ground, massif.base_at(column))
		var support := ground
		if posmod(base - ground, WarrenBuildingParcel.STOREY_BANDS) != 0:
			support -= 1
		needed -= base - mini(support, base)
		needed = maxi(WarrenBuildingParcel.STOREY_BANDS
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
			needed + posmod(needed, 2))
	if settled - base < needed:
		reasons["height"] = int(reasons.get("height", 0)) + 1
		return base
	return settled


func _report_envelopes() -> void:
	## How far each authored roof's visual envelope reaches past the lattice
	## footprint it is placed on. SettlementFabricPlan rejects unrelated units
	## whose envelopes overlap by more than 0.10 m, so this overhang is what
	## decides which adjacencies are buildable at all. Reach for it before
	## assuming a trimmed variant exists for some junction.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		print("no compiled construction vocabulary")
		return
	for recipe: FabricRecipe in program.recipes():
		var text := String(recipe.recipe_id)
		if not (text.begins_with("roof.") or text.begins_with("room.")):
			continue
		var bounds := recipe.local_bounds
		var clearance := recipe.local_clearance_bounds
		var overhang_x := maxf(bounds.position.x - clearance.position.x,
			clearance.end.x - bounds.end.x)
		var overhang_z := maxf(bounds.position.z - clearance.position.z,
			clearance.end.z - bounds.end.z)
		print("%-42s bounds=%s clearance=%s overhang x=%.3f z=%.3f" % [
			recipe.recipe_id, bounds.size, clearance.size, overhang_x,
			overhang_z])


func _report_contact() -> void:
	## Both pipelines, same measurement, so a threshold change can be judged
	## against the pipeline that ships as well as the one being built.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	for mode: StringName in [WarrenTownSolver.MODE_ROUTE_FIRST,
			WarrenTownSolver.MODE_MASS_FIRST]:
		WarrenTownSolver.GENERATION_MODE = mode
		for world_seed: int in _seeds:
			var towns := WarrenTownSolver.ranked_candidates(world_seed, {},
				program, 4)
			if towns.is_empty():
				print("%s seed %2d: no ranked candidate" % [mode, world_seed])
				continue
			for town: WarrenTownPlan in towns:
				var audit := town.parcels.audit
				print("%s seed %2d attempt %d: n=%d cells=%d parcelratio=%.2f " \
					% [mode, world_seed, int(town.audit.get("route_attempt",
							-1)), int(audit.parcel_count),
						int(audit.get("parcel_footprint_cell_count", 0)),
						float(audit.get(
							"largest_building_contact_component_ratio", 0.0))] \
					+ "cellratio=%.2f isolated=%d isolatedcells=%.3f" \
					% [float(audit.get(
							"largest_building_contact_component_cell_ratio",
							0.0)),
						int(audit.get("isolated_building_count", -1)),
						float(audit.get("isolated_building_cell_ratio", 0.0))])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _roofs_compile(plan: WarrenParcelPlan) -> bool:
	var proposals: Array[Dictionary] = []
	for parcel: WarrenBuildingParcel in plan.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			return false
		proposals.append(proposal)
	var topology := FabricRoofTopologyPlan.build(proposals)
	if topology == null:
		return false
	return not FabricRoofJunctionModuleTable.build(proposals,
		topology).is_empty()
