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
##   5 stamp   -- stop_after = &"stamp" (claims, L-pairs, small edits)
##   6 final   -- full sealed plan (foundations + everything)
##
## GUI mode only -- headless capture scenes hang.
##
##   Godot --path . res://tests/harness/maze_source_review.tscn -- \
##     --seeds 4,12 --phases all --output /tmp/maze-shots [--legend]

const CELL := 3.0        # macro lattice cell, metres
const BAND := 3.0         # one vertical band, metres

const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
]

## Coloured-by-meaning palette. Reservations are translucent; claims and
## retained solid are opaque; the golden-ratio hue walk (LINEAGE_HUE_STEP)
## is the prototype's own scheme, kept so an L-pair sharing a hue is the
## visible check that pairing worked.
const TERRAIN_COLOR := Color("6b8f5a")
const FOUNDATION_COLOR := Color("3a3a3a")
const GREY_COLOR := Color("b7b7ae")
const SPINE_COLOR := Color("e8c76a")
const ALLEY_COLOR := Color("cf9350")
const MARKET_COLOR := Color("6fc4b8")
const COVERED_COLOR := Color("d8f5f0")
const SKYWALK_COLOR := Color("5aa9e6")
const RESERVATION_COLORS := {
	&"courtyard": Color("4f9e5c"),
	&"large_house": Color("e08a3c"),
	&"landmark_plot": Color("9a5fc7"),
	&"garden_terrace": Color("b5d94c"),
}
const LINEAGE_HUE_STEP := 0.6180339887

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
	&"massif", &"bore", &"air", &"reserve", &"stamp", &"final",
]

var _output_dir := "/tmp/maze-source-review"
var _seeds: Array[int] = [4]
var _phases_all := false
var _show_legend := false
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
			_show_legend = true


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_output_dir)
	if _show_legend:
		_print_legend()
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
			_draw_columns(root, plan, state)
			_draw_path(root, plan)
			if state == &"air":
				_draw_covered_bars(root, plan)
			_draw_skywalk_bars(root, plan)
			if state == &"final":
				final_plan = plan

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
		&"stamp":
			return &"stamp"
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
		_box_column(root, column, massif.base_at(column),
			massif.top_at(column), GREY_COLOR)


func _draw_columns(root: Node3D, plan: WarrenMazeSourcePlan,
		state: StringName) -> void:
	var claim_lookup := _claim_lookup(plan)
	var reservation_lookup := _reservation_lookup(plan)
	var foundation_lookup: Dictionary = {}
	if state == &"final":
		foundation_lookup = plan.audit.get("foundation_columns", {}) \
			as Dictionary
	for column: Vector2i in plan.massif.columns:
		var base := plan.massif.base_at(column)
		var top := plan.massif.top_at(column)
		if claim_lookup.has(column):
			var info := claim_lookup[column] as Dictionary
			_draw_owned_column(root, column, base, top,
				int(info.floor_band), int(info.top_band), info.color as Color,
				false, foundation_lookup.has(column))
		elif reservation_lookup.has(column):
			var info := reservation_lookup[column] as Dictionary
			var floor_band := plan.effective_base(column)
			var top_band := plan.effective_top(column)
			_draw_owned_column(root, column, base, top, floor_band, top_band,
				info.color as Color, true, foundation_lookup.has(column))
		else:
			_draw_solid_runs(root, plan, column, base, top)


## Every claimed or reserved column is, by construction, a wall column: the
## whole [base, top) interval is untouched original mass (a passage never
## runs through a column that fronts or reserves against it), so the
## foundation/owned/remainder split below never needs a carved-gap scan --
## only the generic unclaimed branch (_draw_solid_runs) does.
func _draw_owned_column(root: Node3D, column: Vector2i, base: int, top: int,
		floor_band: int, top_band: int, colour: Color, translucent: bool,
		show_foundation: bool) -> void:
	if floor_band > base:
		var segment_colour := FOUNDATION_COLOR if show_foundation \
			else GREY_COLOR
		_box_column(root, column, base, floor_band, segment_colour)
	var visual_top := maxi(floor_band + 1, top_band)
	_box_column(root, column, floor_band, visual_top, colour, translucent)
	var remainder_start := maxi(visual_top, top_band)
	if remainder_start < top:
		_box_column(root, column, remainder_start, top, GREY_COLOR)


func _draw_solid_runs(root: Node3D, plan: WarrenMazeSourcePlan,
		column: Vector2i, start: int, stop: int) -> void:
	var run_start := -1
	for band in range(start, stop):
		var solid := plan.state_at(Vector3i(column.x, band, column.y)) \
			== WarrenMazeSourcePlan.CellState.SOLID
		if solid and run_start < 0:
			run_start = band
		elif not solid and run_start >= 0:
			_box_column(root, column, run_start, band, GREY_COLOR)
			run_start = -1
	if run_start >= 0:
		_box_column(root, column, run_start, stop, GREY_COLOR)


func _claim_lookup(plan: WarrenMazeSourcePlan) -> Dictionary:
	var lineage_index: Dictionary = {}
	var next_index := 0
	var out: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		var hint := String(claim.get("lineage_hint", &""))
		if not lineage_index.has(hint):
			lineage_index[hint] = next_index
			next_index += 1
		var hue := fposmod(float(lineage_index[hint]) * LINEAGE_HUE_STEP, 1.0)
		var colour := Color.from_hsv(hue, 0.42, 0.86)
		var floor_band := int(claim.get("floor_band", 0))
		var top_band := int(claim.get("top_band", 0))
		for column: Vector2i in claim.get("footprint", []) as Array[Vector2i]:
			out[column] = {"floor_band": floor_band, "top_band": top_band,
				"color": colour}
	return out


func _reservation_lookup(plan: WarrenMazeSourcePlan) -> Dictionary:
	## skywalk_span is deliberately excluded: its flank columns are unedited
	## natural wall mass (claim_overhead never records an edit), so they
	## fall through to the ordinary retained-solid branch and the span
	## itself is drawn separately as an overhead bar (_draw_skywalk_bars).
	var out: Dictionary = {}
	for reservation: Dictionary in plan.reservations:
		var kind := StringName(reservation.get("kind", &""))
		if kind == &"skywalk_span":
			continue
		var colour: Color = RESERVATION_COLORS.get(kind, Color("aaaaaa"))
		for column: Vector2i in reservation.get("cells", []) as Array[Vector2i]:
			out[column] = {"kind": kind, "color": colour}
	return out


## ---------------------------------------------------------------------
## Path network, covered-passage markers, skywalk bars.
## ---------------------------------------------------------------------

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


func _draw_path_edge(root: Node3D, plan: WarrenMazeSourcePlan, a: Vector3i,
		b: Vector3i, is_route: bool) -> void:
	var kind_a := StringName(plan.passage_kinds.get(a, &""))
	var kind_b := StringName(plan.passage_kinds.get(b, &""))
	if kind_a == WarrenMazeSourcePlan.PASSAGE_MARKET \
			or kind_b == WarrenMazeSourcePlan.PASSAGE_MARKET:
		_edge(root, a, b, 0.55, MARKET_COLOR)
	elif is_route:
		_edge(root, a, b, 0.55, SPINE_COLOR)
	else:
		_edge(root, a, b, 0.22, ALLEY_COLOR)


func _draw_covered_bars(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		var roof := Vector3i(cell.x, cell.y + plan.excavation.slot_bands(cell),
			cell.z)
		var covered: bool = plan.massif.top_at(column) > roof.y \
			and not plan.excavation.carved.has(roof)
		if not covered:
			continue
		var origin := Vector3(float(cell.x) * CELL, float(roof.y) * BAND + 0.1,
			float(cell.z) * CELL)
		_box(root, origin, Vector3(CELL * 0.7, 0.18, CELL * 0.7),
			COVERED_COLOR, true)


func _draw_skywalk_bars(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	for reservation: Dictionary in plan.reservations:
		if StringName(reservation.get("kind", &"")) != &"skywalk_span":
			continue
		var walk_cells: Array[Vector3i] = reservation.get("walk_cells", []) \
			as Array[Vector3i]
		var cells: Array[Vector2i] = reservation.get("cells", []) \
			as Array[Vector2i]
		if walk_cells.is_empty() or cells.size() < 2:
			continue
		var walk: Vector3i = walk_cells[0]
		var band := walk.y + WarrenExcavation.HEADROOM_BANDS
		var a := cells[0]
		var b := cells[1]
		var centre_column := Vector2((float(a.x) + float(b.x)) * 0.5,
			(float(a.y) + float(b.y)) * 0.5)
		var length := Vector2(float(a.x - b.x), float(a.y - b.y)).length() \
			* CELL + CELL
		var origin := Vector3(centre_column.x * CELL, float(band) * BAND,
			centre_column.y * CELL)
		var horizontal := a.x != b.x
		var size := Vector3(length, BAND * 0.3, CELL * 0.6) if horizontal \
			else Vector3(CELL * 0.6, BAND * 0.3, length)
		_box(root, origin, size, SKYWALK_COLOR, true)


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
		"reservation_outcomes": outcomes,
	}


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


func _print_legend() -> void:
	print("[maze_source_review] legend:")
	print("  terrain quad               ", TERRAIN_COLOR.to_html(false))
	print("  foundation (rock)          ", FOUNDATION_COLOR.to_html(false))
	print("  unclaimed retained solid   ", GREY_COLOR.to_html(false))
	print("  claim (lineage hue)        golden-ratio HSV walk; an L-pair "
		+ "shares one hue")
	print("  reservation:courtyard      ",
		(RESERVATION_COLORS[&"courtyard"] as Color).to_html(false))
	print("  reservation:large_house    ",
		(RESERVATION_COLORS[&"large_house"] as Color).to_html(false))
	print("  reservation:landmark_plot  ",
		(RESERVATION_COLORS[&"landmark_plot"] as Color).to_html(false))
	print("  reservation:garden_terrace ",
		(RESERVATION_COLORS[&"garden_terrace"] as Color).to_html(false))
	print("  reservation:skywalk_span   ", SKYWALK_COLOR.to_html(false),
		" (overhead bar)")
	print("  path: spine (thick)        ", SPINE_COLOR.to_html(false))
	print("  path: alley (thin)         ", ALLEY_COLOR.to_html(false))
	print("  path: market               ", MARKET_COLOR.to_html(false))
	print("  covered-passage marker     ", COVERED_COLOR.to_html(false),
		" (air state only)")


## ---------------------------------------------------------------------
## Geometry primitives.
## ---------------------------------------------------------------------

func _box_column(root: Node3D, column: Vector2i, y0: int, y1: int,
		colour: Color, translucent: bool = false) -> void:
	if y1 <= y0:
		return
	var height := float(y1 - y0) * BAND
	var centre_y := (float(y0) + float(y1)) * 0.5 * BAND
	var origin := Vector3(float(column.x) * CELL, centre_y,
		float(column.y) * CELL)
	_box(root, origin, Vector3(CELL * 0.94, height * 0.96, CELL * 0.94),
		colour, translucent)


func _box(root: Node3D, origin: Vector3, size: Vector3, colour: Color,
		translucent: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	var draw_colour := colour
	if translucent:
		# Transparency mode alone does nothing without an actual alpha < 1;
		# the source colour is opaque (reservation/marker palette is all
		# full-alpha), so the see-through look has to be applied here.
		draw_colour.a = 0.55
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
