extends Node3D

## Constructive geometry debug view: renders the town as a plain 3D grid --
## air invisible, solids coloured by MEANING -- so a wrong partition is
## visible before any asset is involved. Consumes the constructive
## WarrenMazeSitePlanner pipeline directly (parcel_claims / reservations /
## column_edits / foundation_columns), never the legacy block partitioner.
##
## Six phase states per seed, each its own captures:
##   1 massif  -- WarrenMassifBuilder.build directly (terrain anchoring, shape)
##   2 bore    -- stop_after = &"carve", geometry only (routing, stride legality)
##   3 air     -- same carved plan, covered/open colouring (tunnel vs sky)
##   4 reserve -- stop_after = &"reserve" (feature placement, big edits)
##   5 partition -- stop_after = &"partition" (houses, heights, bridges)
##   6 final   -- full sealed plan (foundations + everything)
##
## GUI mode only -- headless capture scenes hang.
##
##   Godot --path . res://tests/harness/maze_source_review.tscn -- \
##     --seeds 4,12 --phases all --output /tmp/maze-shots [--legend]

const CELL := 3.0        # macro lattice cell, metres
const BAND := 1.5         # one vertical band, metres (WarrenBuildingParcel
                          # .STOREY_BANDS 2 bands/storey * this == 3.0 m,
                          # matching WarrenSpatialGrid.STOREY_CELLS 2 *
                          # CELL_SIZE_M 1.5 -- a storey really is 3 m)

const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
]

## Coloured-by-meaning palette. Reservations and house claims are opaque
## (they are the town's owned mass); passages are translucent voxels PLUS a
## no-depth-test line so the street network reads from any angle, even
## through a wall. Post-trim, whatever solid remains unclaimed is real
## structural mountain -- the rock a climbing street is cut into, or a tunnel
## roof -- not a generator error, so it draws OPAQUE as retained rock, same
## family as foundations but a visibly different stone tone: RETAINED_ROCK
## is rock nobody built on, FOUNDATION_COLOR is rock that IS carrying a
## raised floor above it.
const TERRAIN_COLOR := Color("6b8f5a")
const FOUNDATION_COLOR := Color("4a4640")
const RETAINED_ROCK_COLOR := Color("8a8578")
const PASSAGE_ALPHA := 0.45
const SPINE_COLOR := Color("e8c76a")
const ALLEY_COLOR := Color("cf9350")
const MARKET_COLOR := Color("6fc4b8")
const SKYWALK_COLOR := Color("5aa9e6")
const SPINE_WIDTH := 0.5
const ALLEY_WIDTH := 0.25
const MARKET_WIDTH := 0.45
## Task 3 (tunnels/bridges/plots): a covered passage cell's roof draws in a
## dark, distinctly cool tone -- never confusable with the warm retained-rock/
## foundation family -- and its through-wall line (drawn only for covered
## segments now; an open-to-sky segment's own translucent voxel already reads
## from any angle) uses the same cool family so "this is covered" reads as
## one consistent signal whether you are looking at the roof or the line.
const TUNNEL_ROOF_COLOR := Color("2a2130")
const TUNNEL_LINE_COLOR := Color("ff3ec9")
## Flat reservations (courtyard/garden_terrace, plot_kind == &"flat") are an
## open plot at street datum, not a building -- a thin slab reads as ground,
## not a lump of mass.
const FLAT_SLAB_HEIGHT := 0.3
const RESERVATION_COLORS := {
	&"courtyard": Color("4f9e5c"),
	&"large_house": Color("e08a3c"),
	&"landmark_plot": Color("9a5fc7"),
	&"garden_terrace": Color("b5d94c"),
}
const OUTLINE_MARGIN := 0.05

## Fixed ramp of 8 saturated, warm house colours. A claim's own lineage_hint
## hashes into this table (not the old pale golden-ratio HSV walk) so two
## unrelated houses reliably land on two different, clearly-saturated hues.
## Claims stacked on one column (an upper street's house above a lower
## house's roof) all draw from the LOWEST tier's hue -- one hue per physical
## stack -- stepped darker per floor above the lowest, so a stack still
## reads as one coherent tower rather than an unrelated colour jump.
const LINEAGE_PALETTE: Array[Color] = [
	Color("d1495b"), # rose red
	Color("ef8354"), # coral orange
	Color("f4c95d"), # golden yellow
	Color("8a5a44"), # warm brown
	Color("c1440e"), # burnt orange
	Color("9e2a2b"), # brick red
	Color("e07a5f"), # terracotta
	Color("a44a3f"), # rust
]
const STACK_FLOOR_STEP := 0.85

const FULL_BATTERY: Array[Dictionary] = [
	{"id": "iso", "dir": Vector3(1.0, 0.95, 1.0), "dist": 2.1},
	{"id": "iso-rear", "dir": Vector3(-1.0, 0.9, -0.85), "dist": 2.1},
	{"id": "top", "dir": Vector3(0.02, 1.0, 0.02), "dist": 1.9},
	{"id": "street", "dir": Vector3(0.9, 0.22, 0.5), "dist": 0.85},
]
const ISO_TOP_BATTERY: Array[Dictionary] = [
	{"id": "iso", "dir": Vector3(1.0, 0.95, 1.0), "dist": 2.1},
	{"id": "top", "dir": Vector3(0.02, 1.0, 0.02), "dist": 1.9},
]
const ALL_STATES: Array[StringName] = [
	&"massif", &"bore", &"air", &"reserve", &"partition", &"final",
]

var _output_dir := "/tmp/maze-source-review"
var _seeds: Array[int] = [4]
var _phases_all := false
var _camera := Camera3D.new()
var _captures: Array[Dictionary] = []
var _metrics: Dictionary = {}
var _bounds_min := Vector3(INF, INF, INF)
var _bounds_max := Vector3(-INF, -INF, -INF)


func _ready() -> void:
	_read_args()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_build_environment()
	add_child(_camera)
	_camera.current = true
	_run.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seeds" and index + 1 < args.size():
			_seeds.clear()
			for token: String in args[index + 1].split(",", false):
				_seeds.append(int(token.strip_edges()))
		elif args[index] == "--phases" and index + 1 < args.size():
			_phases_all = args[index + 1].strip_edges() == "all"
		elif args[index] == "--legend":
			pass # legend is always baked into every capture now; kept as a no-op


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_output_dir)
	for city_seed: int in _seeds:
		await _render_seed(city_seed)
	var file := FileAccess.open("%s/index.json" % _output_dir, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"captures": _captures,
			"metrics": _metrics}, "  "))
		file.close()
	print("[maze_source_review] done: ", _captures.size(), " captures")
	get_tree().quit()


func _render_seed(city_seed: int) -> void:
	var profile := WarrenVillageScaleProfile.select(city_seed)
	var states: Array[StringName] = [&"final"]
	if _phases_all:
		states = ALL_STATES
	var carve_failed := false
	var final_plan: WarrenMazeSourcePlan = null

	for state: StringName in states:
		for child in get_children():
			if child.is_in_group(&"maze_geometry"):
				child.queue_free()
		await get_tree().process_frame
		_bounds_min = Vector3(INF, INF, INF)
		_bounds_max = Vector3(-INF, -INF, -INF)

		var root := Node3D.new()
		root.add_to_group(&"maze_geometry")
		add_child(root)

		var plan: WarrenMazeSourcePlan = null
		if state == &"massif":
			var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
			if massif == null:
				push_warning("seed %d massif rejected: %s" \
					% [city_seed, WarrenMassifBuilder.last_failure])
				continue
			_draw_terrain(root, massif)
			_draw_massif_solid(root, massif)
		else:
			if carve_failed:
				continue
			var stop_after := _stop_after_for(state)
			plan = WarrenMazeSitePlanner.plan(city_seed, {}, profile, stop_after)
			if plan == null:
				push_warning("seed %d state=%s rejected: %s" % [city_seed,
					String(state), WarrenMazeSitePlanner.last_failure])
				if stop_after == &"carve":
					carve_failed = true
				continue
			_draw_terrain(root, plan.massif)
			var claims_by_column := _claims_by_column(plan)
			var bridge_columns := _bridge_span_columns(plan)
			_draw_columns(root, plan, state, claims_by_column, bridge_columns)
			_draw_passage_voxels(root, plan)
			_draw_path(root, plan)
			_draw_covered_roofs(root, plan)
			_draw_bridge_spans(root, plan, claims_by_column, bridge_columns)
			if state == &"final":
				final_plan = plan

		_build_legend(root, city_seed, profile, state, plan)

		print("[maze_source_review] seed=%d scale=%s state=%s" % [city_seed,
			String(profile.scale_id), String(state)])

		var centre := Vector3.ZERO
		var radius := 40.0
		if _bounds_min.x != INF:
			centre = (_bounds_min + _bounds_max) * 0.5
			radius = maxf(20.0, (_bounds_max - _bounds_min).length() * 0.5)

		var battery := FULL_BATTERY if state == &"final" else ISO_TOP_BATTERY
		for view: Dictionary in battery:
			await _capture(city_seed, String(state), view, centre, radius)

		if state == &"final" and plan != null:
			for r_index in plan.reservations.size():
				var reservation: Dictionary = plan.reservations[r_index]
				var kind := String(reservation.get("kind", "unknown"))
				var cells: Array[Vector2i] = reservation.get("cells", []) \
					as Array[Vector2i]
				if cells.is_empty():
					continue
				var datum := int(reservation.get("datum_band", 0))
				var sum := Vector3.ZERO
				for c: Vector2i in cells:
					sum += Vector3(float(c.x) * CELL, float(datum) * BAND,
						float(c.y) * CELL)
				var r_centre := sum / float(cells.size())
				await _capture_closeup(city_seed, r_index, kind, r_centre)

	if final_plan != null:
		_record_metrics(city_seed, final_plan)


func _stop_after_for(state: StringName) -> StringName:
	match state:
		&"bore", &"air":
			return &"carve"
		&"reserve":
			return &"reserve"
		&"partition":
			return &"partition"
		_:
			return &""


func _capture(city_seed: int, state: String, view: Dictionary, centre: Vector3,
		radius: float) -> void:
	var direction := (view.dir as Vector3).normalized()
	var position := centre + direction * radius * float(view.dist)
	_camera.fov = 55.0
	_camera.look_at_from_position(position, centre)
	for unused in 3:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var path := "%s/maze-seed-%d-%s-%s.png" % [_output_dir, city_seed, state,
		String(view.id)]
	var image := get_viewport().get_texture().get_image()
	if image != null and image.save_png(path) == OK:
		_captures.append({"seed": city_seed, "state": state,
			"view": view.id, "image": path})
		print("[maze_source_review] captured ", path)


func _capture_closeup(city_seed: int, index: int, kind: String,
		centre: Vector3) -> void:
	var direction := Vector3(0.85, 0.55, 0.6).normalized()
	var position := centre + direction * 13.0
	_camera.fov = 48.0
	_camera.look_at_from_position(position, centre)
	for unused in 3:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var view_id := "closeup-%02d-%s" % [index, kind]
	var path := "%s/maze-seed-%d-final-%s.png" % [_output_dir, city_seed,
		view_id]
	var image := get_viewport().get_texture().get_image()
	if image != null and image.save_png(path) == OK:
		_captures.append({"seed": city_seed, "state": "final",
			"view": view_id, "image": path})
		print("[maze_source_review] captured ", path)


## ---------------------------------------------------------------------
## Drawing: terrain, raw massif, and the per-state solid/claim/reservation
## column classification.
## ---------------------------------------------------------------------

func _draw_terrain(root: Node3D, massif: WarrenMassif) -> void:
	var apron := _terrain_apron_columns(massif)
	for column: Vector2i in apron:
		var base: int = apron[column]
		var origin := Vector3(float(column.x) * CELL, float(base) * BAND,
			float(column.y) * CELL)
		_box(root, origin, Vector3(CELL * 0.98, 0.16, CELL * 0.98),
			TERRAIN_COLOR)


func _terrain_apron_columns(massif: WarrenMassif) -> Dictionary:
	var out: Dictionary = {}
	for column: Vector2i in massif.columns:
		out[column] = massif.base_at(column)
	var frontier: Array[Vector2i] = []
	frontier.assign(out.keys())
	for _ring in 2:
		var next_frontier: Array[Vector2i] = []
		for column: Vector2i in frontier:
			var base: int = out[column]
			for direction: Vector2i in CARDINALS:
				var neighbor := column + direction
				if out.has(neighbor):
					continue
				out[neighbor] = base
				next_frontier.append(neighbor)
		frontier = next_frontier
	return out


func _draw_massif_solid(root: Node3D, massif: WarrenMassif) -> void:
	for column: Vector2i in massif.columns:
		_draw_rock_column(root, column, massif.base_at(column),
			massif.top_at(column))


## Retained rock: opaque stone with a slightly darker outline box, same
## treatment as a reservation. Used for the raw pre-carve massif and generic
## unclaimed columns, where [y0, y1) is already known to be one unbroken
## solid run (the massif's own range, or a run _draw_solid_runs already
## scanned) -- after the generator's own skyline trim this is genuinely
## structural (streets cut into a mountain, tunnel roofs), never an error to
## hide. A claimed/reserved column's own gaps go through _draw_gap instead
## (below), since slice 1c task 3 lets those be passage-hosting.
func _draw_rock_column(root: Node3D, column: Vector2i, y0: int, y1: int) -> void:
	if y1 <= y0:
		return
	_box_column_outline(root, column, y0, y1, RETAINED_ROCK_COLOR.darkened(0.35))
	_box_column(root, column, y0, y1, RETAINED_ROCK_COLOR)


## Fills [y0, y1) with `colour` wherever the plan itself still reports SOLID
## there, rather than blindly boxing the whole span like _draw_rock_column.
## Slice 1c task 3: a claimed/reserved column can now be passage-hosting (a
## bridge house, a tunnel-roof-bearing claim, a skywalk deck) -- the mass
## below its own floor (or above its own roof) may legitimately contain the
## passage's own PASSAGE/AIR cells now, and painting the whole span opaque
## would bury the passage voxel under solid rock/foundation, defeating the
## entire point of this view. `outline_colour` with alpha 0 (the default)
## skips the darker outline box -- FOUNDATION_COLOR never drew one, only
## retained rock did.
func _draw_gap(root: Node3D, plan: WarrenMazeSourcePlan, column: Vector2i,
		y0: int, y1: int, colour: Color,
		outline_colour: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	if y1 <= y0:
		return
	var draw_outline := outline_colour.a > 0.0
	var run_start := -1
	for band in range(y0, y1):
		var solid := plan.state_at(Vector3i(column.x, band, column.y)) \
			== WarrenMazeSourcePlan.CellState.SOLID
		if solid and run_start < 0:
			run_start = band
		elif not solid and run_start >= 0:
			if draw_outline:
				_box_column_outline(root, column, run_start, band, outline_colour)
			_box_column(root, column, run_start, band, colour)
			run_start = -1
	if run_start >= 0:
		if draw_outline:
			_box_column_outline(root, column, run_start, y1, outline_colour)
		_box_column(root, column, run_start, y1, colour)


func _draw_columns(root: Node3D, plan: WarrenMazeSourcePlan,
		state: StringName, claims_by_column: Dictionary,
		bridge_columns: Dictionary) -> void:
	var reservation_lookup := _reservation_lookup(plan)
	var foundation_lookup: Dictionary = {}
	if state == &"final":
		foundation_lookup = plan.audit.get("foundation_columns", {}) \
			as Dictionary
	for column: Vector2i in plan.massif.columns:
		var base := plan.massif.base_at(column)
		var top := plan.massif.top_at(column)
		if claims_by_column.has(column):
			_draw_stacked_column(root, plan, column, base, top,
				claims_by_column[column] as Array, foundation_lookup.has(column))
		elif reservation_lookup.has(column):
			var info := reservation_lookup[column] as Dictionary
			var floor_band := plan.effective_base(column)
			var top_band := plan.effective_top(column)
			_draw_reservation_column(root, plan, column, base, top, floor_band,
				top_band, info.color as Color, foundation_lookup.has(column),
				StringName(info.get("plot_kind", &"")))
		elif bridge_columns.has(column):
			continue # _draw_bridge_spans draws this column's real block.
		else:
			_draw_solid_runs(root, plan, column, base, top)


## A claimed or reserved column USED to be, by construction, a wall column
## (the whole [base, top) interval untouched original mass, since a passage
## never ran through a column that fronted or reserved against it) -- slice
## 1c task 1 broke that invariant on purpose (an upper street's house may
## bear on a lower one's roof) and task 3 lets a claim sit directly on a
## passage-hosting column (a bridge house, a tunnel-roof-bearing claim), so
## the foundation/owned/remainder split below now needs the same carved-gap
## scan the generic unclaimed branch (_draw_solid_runs) always used -- see
## _draw_gap.
##
## `tiers` is one column's stack of claims (Task 1: an upper street's house
## may sit flush above a lower house's roof), lowest floor_band first, each
## already carrying its stack-stepped colour from _claims_by_column.
## `plan` (slice 1c task 3): a claimed column can now be passage-hosting (a
## bridge house, a tunnel-roof-bearing claim -- rule 4), so the mass below its
## own first floor is no longer guaranteed to be one unbroken solid run --
## it may legitimately contain the passage's own PASSAGE/AIR cells. Every gap
## drawn here goes through _draw_gap, which asks plan.state_at per band
## instead of assuming solid, so the passage voxel underneath is never buried
## under an opaque rock/foundation box.
func _draw_stacked_column(root: Node3D, plan: WarrenMazeSourcePlan,
		column: Vector2i, base: int, top: int, tiers: Array,
		show_foundation: bool) -> void:
	var first_floor := int((tiers[0] as Dictionary).floor_band)
	if first_floor > base:
		if show_foundation:
			_draw_gap(root, plan, column, base, first_floor, FOUNDATION_COLOR)
		else:
			_draw_gap(root, plan, column, base, first_floor,
				RETAINED_ROCK_COLOR, RETAINED_ROCK_COLOR.darkened(0.35))
	var cursor := first_floor
	for tier_info: Dictionary in tiers:
		var floor_band := int(tier_info.floor_band)
		if floor_band > cursor:
			# Connective mass between two stacked tiers -- structural rock,
			# rare (a flush stack leaves no gap).
			_draw_gap(root, plan, column, cursor, floor_band,
				RETAINED_ROCK_COLOR, RETAINED_ROCK_COLOR.darkened(0.35))
		var visual_top := maxi(floor_band + 1, int(tier_info.top_band))
		_box_column(root, column, floor_band, visual_top,
			tier_info.color as Color)
		cursor = maxi(cursor, visual_top)
	if cursor < top:
		# Mass above the topmost claim that no claim ever reaches -- after
		# the skyline trim this is the mountain's own remaining shoulder.
		_draw_gap(root, plan, column, cursor, top, RETAINED_ROCK_COLOR,
			RETAINED_ROCK_COLOR.darkened(0.35))


func _draw_reservation_column(root: Node3D, plan: WarrenMazeSourcePlan,
		column: Vector2i, base: int, top: int, floor_band: int, top_band: int,
		colour: Color, show_foundation: bool, plot_kind: StringName) -> void:
	if floor_band > base:
		if show_foundation:
			_draw_gap(root, plan, column, base, floor_band, FOUNDATION_COLOR)
		else:
			_draw_gap(root, plan, column, base, floor_band,
				RETAINED_ROCK_COLOR, RETAINED_ROCK_COLOR.darkened(0.35))
	if plot_kind == &"flat":
		# Task 3 requirement 3: courtyard/garden read as an open plot, not a lump of
		# building. A flat reservation's own floor_band == top_band == datum
		# -- the ledger already reports every band above as AIR (an open sky
		# plot) -- so there is deliberately no "mass above" draw here: the old
		# generic box math would paint a rock dome over sky state_at no
		# longer agrees exists.
		_draw_flat_slab(root, column, floor_band, colour)
		return
	var visual_top := maxi(floor_band + 1, top_band)
	_box_column_outline(root, column, floor_band, visual_top,
		colour.darkened(0.45))
	_box_column(root, column, floor_band, visual_top, colour)
	if visual_top < top:
		_draw_gap(root, plan, column, visual_top, top, RETAINED_ROCK_COLOR,
			RETAINED_ROCK_COLOR.darkened(0.35))


## Task 3 requirement 3: a thin slab at the datum rather than a full-band box, so a
## flat courtyard/garden plot reads as open ground even from an iso angle.
func _draw_flat_slab(root: Node3D, column: Vector2i, band: int,
		colour: Color) -> void:
	var centre_y := float(band) * BAND + FLAT_SLAB_HEIGHT * 0.5
	var origin := Vector3(float(column.x) * CELL, centre_y,
		float(column.y) * CELL)
	var margin := OUTLINE_MARGIN * 2.0
	_box(root, origin, Vector3(CELL * 0.94 + margin,
		FLAT_SLAB_HEIGHT + margin, CELL * 0.94 + margin), colour.darkened(0.45))
	_box(root, origin, Vector3(CELL * 0.94, FLAT_SLAB_HEIGHT, CELL * 0.94),
		colour)


func _draw_solid_runs(root: Node3D, plan: WarrenMazeSourcePlan,
		column: Vector2i, start: int, stop: int) -> void:
	var run_start := -1
	for band in range(start, stop):
		var solid := plan.state_at(Vector3i(column.x, band, column.y)) \
			== WarrenMazeSourcePlan.CellState.SOLID
		if solid and run_start < 0:
			run_start = band
		elif not solid and run_start >= 0:
			_draw_rock_column(root, column, run_start, band)
			run_start = -1
	if run_start >= 0:
		_draw_rock_column(root, column, run_start, stop)


## Groups parcel_claims by column, sorted by floor_band ascending (tier 0 =
## lowest). Every tier on a column draws from the LOWEST tier's lineage hue,
## stepped darker per tier (STACK_FLOOR_STEP), so a stacked column reads as
## one coherent tower rather than two unrelated house colours colliding.
func _claims_by_column(plan: WarrenMazeSourcePlan) -> Dictionary:
	var raw: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		var entry := {"floor_band": int(claim.get("floor_band", 0)),
			"top_band": int(claim.get("top_band", 0)),
			"lineage_hint": StringName(claim.get("lineage_hint", &""))}
		for column: Vector2i in claim.get("footprint", []) as Array[Vector2i]:
			var list: Array = raw.get(column, [])
			list.append(entry)
			raw[column] = list
	var out: Dictionary = {}
	for column: Vector2i in raw.keys():
		var list: Array = raw[column]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.floor_band) < int(b.floor_band))
		var base_colour := _lineage_colour(StringName(list[0].lineage_hint))
		var tiers: Array = []
		for tier in list.size():
			var source := list[tier] as Dictionary
			var factor := pow(STACK_FLOOR_STEP, float(tier))
			var stepped := Color(base_colour.r * factor, base_colour.g * factor,
				base_colour.b * factor, 1.0)
			tiers.append({"floor_band": int(source.floor_band),
				"top_band": int(source.top_band), "tier": tier,
				"color": stepped})
		out[column] = tiers
	return out


func _lineage_colour(hint: StringName) -> Color:
	var index := absi(String(hint).hash()) % LINEAGE_PALETTE.size()
	return LINEAGE_PALETTE[index]


func _reservation_lookup(plan: WarrenMazeSourcePlan) -> Dictionary:
	## skywalk_span is deliberately excluded here: unlike every other kind,
	## it does not always own natural, ungrounded wall mass -- a bridge-
	## consumed instance genuinely edits its own passage-hosting columns, so
	## _draw_bridge_spans (which agrees with the generator's own datum/
	## plot_top formula for EVERY bridge span, not just the ones that became
	## a formal reservation) draws it instead, as a real block rather than
	## the old thin overhead bar.
	var out: Dictionary = {}
	for reservation: Dictionary in plan.reservations:
		var kind := StringName(reservation.get("kind", &""))
		if kind == &"skywalk_span":
			continue
		var colour: Color = RESERVATION_COLORS.get(kind, Color("aaaaaa"))
		var plot_kind := StringName(reservation.get("plot_kind", &""))
		for column: Vector2i in reservation.get("cells", []) as Array[Vector2i]:
			out[column] = {"kind": kind, "color": colour, "plot_kind": plot_kind}
	return out


## column -> {datum, plot_top}, mirroring WarrenMazeReservationPass.
## _claim_bridge_span's own formula exactly (max passage_headroom_top across
## the span's own cells, one storey above) so the debug view always draws
## the SAME deck height the generator would edit to -- whether or not this
## particular span actually became a formal skywalk_span reservation. The
## reservation quota can leave spans over; an unclaimed, unreserved bridge
## span should still read as a bridge, never as unlabeled retained rock.
func _bridge_span_columns(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for span_value: Variant in plan.excavation.bridge_spans:
		var span := span_value as Array[Vector3i]
		if span.is_empty():
			continue
		var datum := plan.passage_headroom_top(span[0])
		for cell: Vector3i in span:
			datum = maxi(datum, plan.passage_headroom_top(cell))
		var plot_top := datum + WarrenBuildingParcel.STOREY_BANDS
		for cell: Vector3i in span:
			var column := Vector2i(cell.x, cell.z)
			var existing: Dictionary = out.get(column, {})
			out[column] = {"datum": maxi(datum, int(existing.get("datum", datum))),
				"plot_top": maxi(plot_top, int(existing.get("plot_top", plot_top)))}
	return out


## Every cell any bridge span retains, for _draw_covered_roofs' own skip
## check (a bridge cell gets the taller, distinctly-coloured deck block from
## _draw_bridge_spans instead of the plain tunnel-roof slab).
func _bridge_span_cells(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for span_value: Variant in plan.excavation.bridge_spans:
		for cell: Vector3i in span_value as Array[Vector3i]:
			out[cell] = true
	return out


func _count_tiered_claims(plan: WarrenMazeSourcePlan) -> int:
	var count := 0
	for claim: Dictionary in plan.parcel_claims:
		if bool(claim.get("tiered", false)):
			count += 1
	return count


## ---------------------------------------------------------------------
## Path network, covered-passage markers, skywalk bars.
## ---------------------------------------------------------------------

## Requirement 1: every passage cell (not just the walked route) as its own
## translucent open-corridor voxel, sized to the excavation's real headroom
## (HEADROOM_BANDS bands), so the street network reads as open volume from
## any angle rather than only along the thin route line.
func _draw_passage_voxels(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	var height := float(WarrenExcavation.HEADROOM_BANDS) * BAND
	for cell: Vector3i in plan.passage_cells():
		var kind := StringName(plan.passage_kinds.get(cell, &""))
		var colour := _passage_colour(kind)
		var origin := Vector3(float(cell.x) * CELL, float(cell.y) * BAND \
			+ height * 0.5, float(cell.z) * CELL)
		_box(root, origin, Vector3(CELL * 0.92, height, CELL * 0.92), colour,
			PASSAGE_ALPHA)


func _passage_colour(kind: StringName) -> Color:
	if kind == WarrenMazeSourcePlan.PASSAGE_ALLEY:
		return ALLEY_COLOR
	if kind == WarrenMazeSourcePlan.PASSAGE_MARKET:
		return MARKET_COLOR
	return SPINE_COLOR


func _draw_path(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	var route: Array[Vector3i] = plan.excavation.route
	for index in range(1, route.size()):
		_draw_path_edge(root, plan, route[index - 1], route[index], true)
	for lane: Dictionary in plan.excavation.lanes:
		var walk: Array[Vector3i] = [lane.anchor as Vector3i]
		walk.append_array(lane.cells as Array[Vector3i])
		for index in range(1, walk.size()):
			_draw_path_edge(root, plan, walk[index - 1], walk[index], false)
	for edge: Dictionary in plan.excavation.loop_edges:
		_draw_path_edge(root, plan, edge.from as Vector3i, edge.to as Vector3i,
			false)


## Task 3 requirement 4: the no-depth-test through-wall line is only needed where
## rock actually hides the corridor from view -- an open-to-sky segment's own
## translucent voxel (_draw_passage_voxels, drawn for every passage cell
## regardless) already reads from any angle. A covered segment draws the
## line in the alternate tunnel colour instead of its usual spine/alley/
## market colour, so a covered stretch of street reads as covered at a
## glance, whichever kind of passage it is.
func _draw_path_edge(root: Node3D, plan: WarrenMazeSourcePlan, a: Vector3i,
		b: Vector3i, is_route: bool) -> void:
	var covered := bool(plan.excavation.covered.get(a, false)) \
		or bool(plan.excavation.covered.get(b, false))
	if not covered:
		return
	var kind_a := StringName(plan.passage_kinds.get(a, &""))
	var kind_b := StringName(plan.passage_kinds.get(b, &""))
	if kind_a == WarrenMazeSourcePlan.PASSAGE_MARKET \
			or kind_b == WarrenMazeSourcePlan.PASSAGE_MARKET:
		_edge(root, a, b, MARKET_WIDTH, TUNNEL_LINE_COLOR)
	elif is_route:
		_edge(root, a, b, SPINE_WIDTH, TUNNEL_LINE_COLOR)
	else:
		_edge(root, a, b, ALLEY_WIDTH, TUNNEL_LINE_COLOR)


## Task 3 requirement 1: every COVERED passage cell gets a dark, 1-band tunnel-roof
## slab at its own real headroom top (plan.passage_headroom_top -- a stair
## stride cell's own carved slot runs one band taller than the flat
## HEADROOM_BANDS constant, so a per-cell query is the only correct height).
## Bridge-span cells are excluded: _draw_bridge_spans already draws a taller,
## distinctly-coloured deck block starting at the very same y, which reads
## as "bridge" rather than "tunnel" -- drawing both would just paint two
## colours over the same band.
func _draw_covered_roofs(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	var bridge_cells := _bridge_span_cells(plan)
	for cell: Vector3i in plan.passage_cells():
		if bridge_cells.has(cell) \
				or not bool(plan.excavation.covered.get(cell, false)):
			continue
		var column := Vector2i(cell.x, cell.z)
		var roof_y := plan.passage_headroom_top(cell)
		_box_column(root, column, roof_y, roof_y + 1, TUNNEL_ROOF_COLOR)


## Task 3 requirement 2: every retained bridge span reads as a real block -- never a
## thin bar -- house-coloured where a claim actually built on top of it (a
## bridge house; already drawn by _draw_stacked_column, which now respects
## the passage beneath it via _draw_gap, so nothing further is drawn here for
## a claimed column), else the skywalk deck's own blue block from
## datum..plot_top, drawn here regardless of whether this particular span
## became a FORMAL skywalk_span reservation -- the quota can leave spans
## over, and an unclaimed one should still read as a bridge.
func _draw_bridge_spans(root: Node3D, plan: WarrenMazeSourcePlan,
		claims_by_column: Dictionary, bridge_columns: Dictionary) -> void:
	for column: Vector2i in bridge_columns.keys():
		if claims_by_column.has(column):
			continue
		var info := bridge_columns[column] as Dictionary
		var datum := int(info.datum)
		var plot_top := int(info.plot_top)
		var base := plan.massif.base_at(column)
		var top := plan.massif.top_at(column)
		_draw_gap(root, plan, column, base, datum, RETAINED_ROCK_COLOR,
			RETAINED_ROCK_COLOR.darkened(0.35))
		_box_column_outline(root, column, datum, plot_top,
			SKYWALK_COLOR.darkened(0.45))
		_box_column(root, column, datum, plot_top, SKYWALK_COLOR)
		if plot_top < top:
			_draw_gap(root, plan, column, plot_top, top, RETAINED_ROCK_COLOR,
				RETAINED_ROCK_COLOR.darkened(0.35))


## ---------------------------------------------------------------------
## Metrics: index.json per-seed ownership/lineage/reservation summary.
## ---------------------------------------------------------------------

func _record_metrics(city_seed: int, plan: WarrenMazeSourcePlan) -> void:
	var lineage_totals: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		var hint := String(claim.get("lineage_hint", &""))
		var footprint: Array = claim.get("footprint", [])
		lineage_totals[hint] = int(lineage_totals.get(hint, 0)) \
			+ footprint.size()
	var totals: Array = lineage_totals.values()
	totals.sort()
	var median := 0.0
	if not totals.is_empty():
		var mid := totals.size() / 2
		if totals.size() % 2 == 1:
			median = float(totals[mid])
		else:
			median = (float(totals[mid - 1]) + float(totals[mid])) * 0.5

	var breakdown := _ownership_breakdown(plan)
	var total_columns := plan.massif.columns.size()
	var ratio := float(breakdown.claimed) / float(maxi(1, total_columns))
	var stacked_columns := _count_stacked_columns(plan)

	var outcomes: Array = []
	for outcome: Dictionary in plan.audit.get(
			"reservation_outcomes", []) as Array:
		var clean := {}
		for key: Variant in outcome.keys():
			var value: Variant = outcome[key]
			clean[String(key)] = String(value) \
				if typeof(value) == TYPE_STRING_NAME else value
		outcomes.append(clean)

	_metrics[str(city_seed)] = {
		"scale": String(plan.scale_profile.scale_id),
		"parcels": plan.parcel_claims.size(),
		"median_lineage_footprint": median,
		"ownership_ratio": ratio,
		"ownership_breakdown": breakdown,
		"stacked_columns": stacked_columns,
		"reservation_outcomes": outcomes,
	}


func _count_stacked_columns(plan: WarrenMazeSourcePlan) -> int:
	var stacked := 0
	for tiers: Variant in _claims_by_column(plan).values():
		if (tiers as Array).size() > 1:
			stacked += 1
	return stacked


## Mirrors WarrenMazeBlockPartitioner._ownership_breakdown, restated here
## against the sealed source plan's own public fields directly (parcel_claims
## / reservations / effective_base / state_at) rather than through the
## legacy partitioner + volume adapter this harness no longer depends on.
func _ownership_breakdown(plan: WarrenMazeSourcePlan) -> Dictionary:
	var claimed: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		for column: Vector2i in claim.get("footprint", []) as Array[Vector2i]:
			claimed[column] = true
	var reserved: Dictionary = {}
	for reservation: Dictionary in plan.reservations:
		for column: Vector2i in reservation.get("cells", []) as Array[Vector2i]:
			reserved[column] = true
	var buildable_unclaimed := 0
	var unbuildable := 0
	for column: Vector2i in plan.massif.columns:
		if claimed.has(column) or reserved.has(column):
			continue
		var floor_band := plan.effective_base(column)
		if _column_ceiling(plan, column, floor_band) - floor_band \
				>= WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
			buildable_unclaimed += 1
		else:
			unbuildable += 1
	return {"claimed": claimed.size(), "reserved": reserved.size(),
		"buildable_unclaimed": buildable_unclaimed, "unbuildable": unbuildable}


func _column_ceiling(plan: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int) -> int:
	var top_limit := plan.massif.top_at(column)
	var y := floor_band
	while y < top_limit and plan.state_at(Vector3i(column.x, y, column.y)) \
			== WarrenMazeSourcePlan.CellState.SOLID:
		y += 1
	return y


## ---------------------------------------------------------------------
## Legend: a CanvasLayer overlay baked into every capture (requirement 3).
## ---------------------------------------------------------------------

func _build_legend(root: Node3D, city_seed: int, profile: WarrenVillageScaleProfile,
		state: StringName, plan: WarrenMazeSourcePlan) -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.78)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(430.0, 10.0)
	label.add_theme_font_size_override("normal_font_size", 22)
	label.add_theme_font_size_override("bold_font_size", 22)
	label.text = _legend_bbcode(city_seed, profile, state, plan)
	panel.add_child(label)


func _legend_bbcode(city_seed: int, profile: WarrenVillageScaleProfile,
		state: StringName, plan: WarrenMazeSourcePlan) -> String:
	var lines := PackedStringArray()
	lines.append("[b]constructive maze debug view[/b]")
	lines.append("seed %d   scale %s   state %s" % [city_seed,
		String(profile.scale_id), String(state)])
	lines.append("1 band = 1.5 m, 1 storey = 2 bands = 3 m")
	if plan != null:
		var stacked := _count_stacked_columns(plan)
		var tiered := _count_tiered_claims(plan)
		var breakdown := _ownership_breakdown(plan)
		var total_columns := maxi(1, plan.massif.columns.size())
		var ratio := float(breakdown.claimed) / float(total_columns)
		lines.append(
			"parcels %d   stacked columns %d   tiered houses %d   ownership %.0f%%" \
			% [plan.parcel_claims.size(), stacked, tiered, ratio * 100.0])
	lines.append("")
	var house_swatches := ""
	for colour: Color in LINEAGE_PALETTE:
		house_swatches += _swatch_glyph(colour)
	lines.append(house_swatches \
		+ " house (lineage hash mod 8; darker = higher stacked floor)")
	lines.append(_swatch(FOUNDATION_COLOR,
		"foundation (rock bearing a raised floor -- deep under upper streets)"))
	lines.append(_swatch(RETAINED_ROCK_COLOR, "retained rock (under streets)"))
	lines.append(_swatch(TUNNEL_ROOF_COLOR,
		"tunnel roof (covered passage, 1 band at headroom top)"))
	lines.append(_swatch(TERRAIN_COLOR, "terrain apron"))
	lines.append("[b]reservations (opaque, dark outline)[/b]")
	lines.append(_swatch(RESERVATION_COLORS[&"courtyard"] as Color,
		"courtyard (flat plot, 0.3 m slab)"))
	lines.append(_swatch(RESERVATION_COLORS[&"large_house"] as Color,
		"large house"))
	lines.append(_swatch(RESERVATION_COLORS[&"landmark_plot"] as Color,
		"landmark"))
	lines.append(_swatch(RESERVATION_COLORS[&"garden_terrace"] as Color,
		"garden terrace (flat plot, 0.3 m slab)"))
	lines.append(
		"plots: courtyard/garden flat 0.3 m slab, large house/landmark 3-storey")
	lines.append(_swatch(SKYWALK_COLOR,
		"bridge deck, reserved (block, datum..+1 storey)"))
	lines.append(
		"bridge deck, claimed: house colour (same stack-tier shading as a claim)")
	lines.append("[b]passages (translucent corridor voxel)[/b]")
	lines.append(_swatch(SPINE_COLOR, "spine voxel (wide corridor)"))
	lines.append(_swatch(ALLEY_COLOR, "alley voxel (narrow corridor)"))
	lines.append(_swatch(MARKET_COLOR, "market voxel"))
	lines.append(_swatch(TUNNEL_LINE_COLOR,
		"through-wall line (covered segments only; open segments need no line)"))
	return "\n".join(lines)


func _swatch(colour: Color, label: String) -> String:
	return "%s %s" % [_swatch_glyph(colour), label]


func _swatch_glyph(colour: Color) -> String:
	return "[color=#%s]■[/color]" % colour.to_html(false)


## ---------------------------------------------------------------------
## Geometry primitives.
## ---------------------------------------------------------------------

func _box_column(root: Node3D, column: Vector2i, y0: int, y1: int,
		colour: Color, alpha: float = 1.0) -> void:
	if y1 <= y0:
		return
	var height := float(y1 - y0) * BAND
	var centre_y := (float(y0) + float(y1)) * 0.5 * BAND
	var origin := Vector3(float(column.x) * CELL, centre_y,
		float(column.y) * CELL)
	_box(root, origin, Vector3(CELL * 0.94, height * 0.96, CELL * 0.94),
		colour, alpha)


func _box_column_outline(root: Node3D, column: Vector2i, y0: int, y1: int,
		colour: Color) -> void:
	if y1 <= y0:
		return
	var height := float(y1 - y0) * BAND
	var centre_y := (float(y0) + float(y1)) * 0.5 * BAND
	var origin := Vector3(float(column.x) * CELL, centre_y,
		float(column.y) * CELL)
	var margin := OUTLINE_MARGIN * 2.0
	_box(root, origin, Vector3(CELL * 0.94 + margin, height * 0.96 + margin,
		CELL * 0.94 + margin), colour)


func _box(root: Node3D, origin: Vector3, size: Vector3, colour: Color,
		alpha: float = 1.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	var draw_colour := colour
	draw_colour.a = alpha
	if alpha < 0.999:
		# Transparency mode alone does nothing without an actual alpha < 1;
		# the source palette is otherwise full-alpha, so the see-through
		# look has to be applied here.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = draw_colour
	material.roughness = 0.85
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = origin
	root.add_child(instance)
	_expand_bounds(origin)


func _edge(root: Node3D, from: Vector3i, to: Vector3i, thickness: float,
		colour: Color) -> void:
	var a := Vector3(float(from.x) * CELL, float(from.y) * BAND + 0.2,
		float(from.z) * CELL)
	var b := Vector3(float(to.x) * CELL, float(to.y) * BAND + 0.2,
		float(to.z) * CELL)
	var diff := b - a
	var length := diff.length()
	if length < 0.01:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness * 0.6, length)
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.7
	# Requirement 1: the polyline must read through solids from any angle, so
	# it ignores the depth test rather than being occluded by nearer walls.
	material.no_depth_test = true
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = (a + b) * 0.5
	instance.basis = Basis.looking_at(diff.normalized(), Vector3.UP)
	root.add_child(instance)
	_expand_bounds(a)
	_expand_bounds(b)


func _expand_bounds(point: Vector3) -> void:
	_bounds_min = _minv(_bounds_min, point)
	_bounds_max = _maxv(_bounds_max, point)


func _minv(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))


func _maxv(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_horizon_color = Color("c5dce0")
	sky_material.ground_bottom_color = Color("596152")
	sky_material.ground_horizon_color = Color("aebd9f")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -37.0, 0.0)
	sun.light_color = Color("ffe4b9")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
