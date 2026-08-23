extends Node3D

## Four-colour debug view for the plot-model town generator (design
## 2026-08-21, section "Visualisation"). Opaque boxes, no lines, no outlines,
## no translucency, and exactly four things about the town:
##
##   grey boxes    rock: derived solid (`plan.solid_at`) no plot claims;
##   blue boxes    plots: houses, assets, and bridges, one shade per
##                 `building_id` (a deck is never a box);
##   brown squares one flat slab per passage cell, on that cell's own band;
##   tan squares   one flat slab per deck cell, at the deck's floor.
##
## NOTHING is drawn for air. The void above a brown square IS the street, and
## a void with grey over it IS a tunnel: a street reads as missing mass, never
## as a coloured corridor. The dark-green terrain apron is context, not a town
## drawable. Six states per seed with `--phases all` (default: `final` alone):
## `massif` (the envelope alone), `bore` (the carve stage as the bore cut it:
## headroom only, so nothing is open to the sky and every street reads as a
## tunnel), `tunnel` (the same carve stage through `solid_at`, so the carver's
## open-to-sky policy turns most of them into trenches), `reserve` (assets and
## decks), `partition` (houses and bridges too; unsealed, so a no-plot column
## still shows its whole envelope), and `final` (sealed: no-plot columns
## lowered to their shoulder). GUI mode only -- headless capture hangs.
##
##   Godot --path . res://tests/harness/maze_source_review.tscn -- \
##     --seeds 4,3,9 --phases all --output /tmp/maze-shots

const CELL := 3.0         # macro lattice cell, metres
const BAND := 1.5         # one vertical band; one storey = 2 bands = 3 m
const SLAB_THICKNESS := 0.18
const SLAB_INSET := 0.96

## The whole palette. Nothing else is a colour in this view: the passage
## kind, the plot kind, and the tier are all deliberately invisible.
const ROCK := Color("8a8578")
const PASSAGE := Color("7a4b2a")
const DECK := Color("d9c08c")
const TERRAIN := Color("4f6b43")
## Eight blues stepped evenly from Color("2f5d8a") to Color("8fc1ef"). A
## plot's `building_id` hashes into this table, so a building is one shade
## wherever its columns stand and two neighbours are usually two shades.
const PLOT_SHADES: Array[Color] = [
	Color("2f5d8a"), Color("3d6b98"), Color("4a7aa7"), Color("5888b5"),
	Color("6696c4"), Color("74a4d2"), Color("81b3e1"), Color("8fc1ef"),
]

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
	&"massif", &"bore", &"tunnel", &"reserve", &"partition", &"final",
]
## The snapshot each state asks the planner for; `massif` never asks.
const STOP_AFTER := {&"bore": &"carve", &"tunnel": &"carve",
	&"reserve": &"reserve", &"partition": &"partition", &"final": &""}

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
	var states: Array[StringName] = ALL_STATES if _phases_all \
		else [&"final"] as Array[StringName]
	var carved: WarrenMazeSourcePlan = null

	for state: StringName in states:
		for child in get_children():
			if child.is_in_group(&"maze_geometry"):
				child.queue_free()
		await get_tree().process_frame
		_bounds_min = Vector3(INF, INF, INF)
		_bounds_max = Vector3(-INF, -INF, -INF)

		var massif: WarrenMassif = null
		var plan: WarrenMazeSourcePlan = null
		if state == &"massif":
			massif = WarrenMassifBuilder.build(city_seed, {}, profile)
			if massif == null:
				push_warning("seed %d massif rejected: %s" % [city_seed,
					WarrenMassifBuilder.last_failure])
				continue
		else:
			plan = WarrenMazeSitePlanner.plan(city_seed, {}, profile,
				STOP_AFTER[state] as StringName)
			if plan == null:
				push_warning("seed %d state=%s rejected: %s" % [city_seed,
					String(state), WarrenMazeSitePlanner.last_failure])
				continue
			massif = plan.massif
			# Coverage's demand needs a carve-stage plan; reuse bore/tunnel's.
			if STOP_AFTER[state] == &"carve":
				carved = plan
			elif carved == null:
				carved = WarrenMazeSitePlanner.plan(city_seed, {}, profile,
					&"carve")

		var root := Node3D.new()
		root.add_to_group(&"maze_geometry")
		add_child(root)
		_draw_state(root, state, massif, plan)
		var facts := _record_metrics(city_seed, state, profile, plan, carved)
		_build_legend(root, city_seed, profile, state, facts)
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


## The one place that says what each state shows. `massif` and `bore` draw the
## raw envelope (minus the bore's own removals for `bore`); every later state
## derives rock from `solid_at`, so the carver's open-to-sky policy and then
## the plots themselves cut that envelope down.
func _draw_state(root: Node3D, state: StringName, massif: WarrenMassif,
		plan: WarrenMazeSourcePlan) -> void:
	_draw_terrain(root, massif)
	if state == &"massif":
		_draw_rock(root, massif, null, {}, {})
		return
	if state == &"bore":
		_draw_rock(root, massif, null, _bore_removed(plan), {})
		_draw_passages(root, plan)
		return
	_draw_rock(root, massif, plan, {}, _plot_floors(plan))
	if state != &"tunnel":
		_draw_plots(root, plan)
		_draw_decks(root, plan)
	_draw_passages(root, plan)


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


# --- The four drawables, plus the terrain apron ----------------------------

## Context, not a town drawable: one thin ground slab per massif column at its
## own base, plus one ring outside at the neighbouring base.
func _draw_terrain(root: Node3D, massif: WarrenMassif) -> void:
	var apron: Dictionary = {}
	for column: Vector2i in massif.columns:
		apron[column] = massif.base_at(column)
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			if not massif.has_column(column + direction) \
					and not apron.has(column + direction):
				apron[column + direction] = massif.base_at(column)
	for column: Vector2i in apron:
		_box(root, Vector3(float(column.x) * CELL,
			float(apron[column]) * BAND, float(column.y) * CELL),
			Vector3(CELL * 0.98, 0.16, CELL * 0.98), TERRAIN)


## Grey rock: one box per maximal contiguous run of rock bands on a column.
## With `plan` null the state draws the raw envelope minus `carved_out` (the
## `massif` and `bore` states); otherwise rock is what `solid_at` reports below
## the column's lowest plot floor, scanned to the column's own ceiling.
func _draw_rock(root: Node3D, massif: WarrenMassif,
		plan: WarrenMazeSourcePlan, carved_out: Dictionary,
		plot_floors: Dictionary) -> void:
	for column: Vector2i in massif.columns:
		var ceiling := massif.top_at(column) if plan == null \
			else plan.column_ceiling(column)
		var rock_top: int = plot_floors.get(column, ceiling)
		var run_start := -1
		for band in range(massif.base_at(column), ceiling):
			var cell := Vector3i(column.x, band, column.y)
			var rock := not carved_out.has(cell)
			if plan != null:
				rock = band < rock_top and plan.solid_at(cell)
			if rock and run_start < 0:
				run_start = band
			elif not rock and run_start >= 0:
				_box_column(root, column, run_start, band, ROCK)
				run_start = -1
		if run_start >= 0:
			_box_column(root, column, run_start, ceiling, ROCK)


## Blue plots: every house, asset, and bridge, one box per footprint column so
## an L-shape reads as an L, all in the building's own shade. A deck has no
## height and draws as a tan square instead.
func _draw_plots(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	for plot: Dictionary in plan.plots:
		if StringName(plot["kind"]) == WarrenMazeSourcePlan.PLOT_DECK:
			continue
		var shade: Color = PLOT_SHADES[posmod(
			hash(String(plot["building_id"])), PLOT_SHADES.size())]
		for cell_value: Variant in plot["cells"] as Array:
			_box_column(root, cell_value as Vector2i, int(plot["floor"]),
				int(plot["top"]), shade)


## Brown squares: the walking floor of every passage cell, on the cell's own
## band. Nothing is drawn above it -- that void IS the street or the tunnel.
## Spine, alley, and market all draw the same brown.
func _draw_passages(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	for cell: Vector3i in plan.passage_cells():
		_slab(root, Vector2i(cell.x, cell.z), cell.y, PASSAGE)


## Tan squares: one per deck cell at the deck's floor -- courtyards, plazas,
## and the roof decks an upper street grows over a house's roof.
func _draw_decks(root: Node3D, plan: WarrenMazeSourcePlan) -> void:
	for plot: Dictionary in plan.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_DECK:
			continue
		for cell_value: Variant in plot["cells"] as Array:
			_slab(root, cell_value as Vector2i, int(plot["floor"]), DECK)


## The cells the bore itself removed: each passage cell and its headroom slot,
## nothing else. Subtracting only these from the envelope is what makes the
## `bore` state an all-tunnel town -- the open-to-sky policy is not applied.
func _bore_removed(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		out[cell] = true
		for slot: Vector3i in plan.excavation.headroom_slot(cell):
			out[slot] = true
	return out


## Column -> the lowest plot floor standing on it, which is where its rock
## stops: above that band `solid_at` is solid only inside a plot, never rock.
func _plot_floors(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for plot: Dictionary in plan.plots:
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			out[column] = mini(int(out.get(column, 1 << 30)),
				int(plot["floor"]))
	return out


# --- Metrics and legend ----------------------------------------------------

## Measures the state, records it under seed/state in index.json, and hands the
## same numbers back for the legend. A ratio is -1.0 -- recorded null, printed
## `n/a` -- where the state carries no such fact.
func _record_metrics(city_seed: int, state: StringName,
		profile: WarrenVillageScaleProfile, plan: WarrenMazeSourcePlan,
		carved: WarrenMazeSourcePlan) -> Dictionary:
	var facts := {"plots": 0, "houses": 0, "assets": 0, "decks": 0,
		"bridges": 0, "tiered": 0, "exterior_rock": -1.0, "coverage": -1.0,
		"ownership": -1.0}
	if plan != null:
		for plot: Dictionary in plan.plots:
			facts.plots += 1
			# The four plot kinds all pluralise with a bare "s".
			facts["%ss" % String(plot["kind"])] += 1
			facts.tiered += int(bool(plan.plot_facts(plot)["tiered"]))
		# A sealed plan carries the skin ratio in its audit; an unsealed
		# snapshot is measured on the spot by the very same method.
		var skin: Dictionary = plan.audit.get("exterior_rock_ratio", {}) \
			as Dictionary
		if skin.is_empty():
			skin = plan.exterior_rock_ratio()
		facts.exterior_rock = float(skin.get("ratio", 0.0))
		if state != &"bore" and state != &"tunnel":
			facts.coverage = _fronting_coverage(carved, plan)
		if state == &"final":
			facts.ownership = _translated_ownership(plan)
	var row := facts.duplicate()
	row["scale"] = String(profile.scale_id)
	for key: String in ["exterior_rock", "coverage", "ownership"]:
		if float(row[key]) < 0.0:
			row[key] = null
	var by_state: Dictionary = _metrics.get(str(city_seed), {})
	by_state[String(state)] = row
	_metrics[str(city_seed)] = by_state
	return facts


## Coverage, restated exactly from the plots suite's own
## test_partition_fills_every_street_fronting_column (its per-`demanded_slots`
## measure): a slot (column, band) is demanded where a passage cell's
## 4-neighbour column has `plot_support_ok` true at that band, read off the
## carve-stage plan alone; covered when some plot of the drawn state claims
## that column over `[floor, max(top, floor+1))`. `coverage = covered /
## demanded`.
func _fronting_coverage(carved: WarrenMazeSourcePlan,
		plan: WarrenMazeSourcePlan) -> float:
	if carved == null:
		return -1.0
	var seen: Dictionary = {}
	var demanded := 0
	var covered := 0
	for cell: Vector3i in carved.passage_cells():
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(cell.x, cell.z) + direction
			var slot := Vector3i(column.x, cell.y, column.y)
			if seen.has(slot) or not carved.massif.has_column(column) \
					or not carved.plot_support_ok(column, cell.y):
				continue
			seen[slot] = true
			demanded += 1
			for plot: Dictionary in plan.plots:
				var floor_band := int(plot["floor"])
				var reserved := maxi(int(plot["top"]), floor_band + 1)
				if slot.y >= floor_band and slot.y < reserved \
						and (plot["cells"] as Array).has(column):
					covered += 1
					break
	return float(covered) / float(maxi(1, demanded))


## `maze_ownership_ratio`: owned parcel mass over the plan's own derived solid,
## read off the translated parcel plan. Only a sealed plan has one, so every
## other state prints `n/a`, and so does a town the translator refuses.
func _translated_ownership(plan: WarrenMazeSourcePlan) -> float:
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
	if volume == null:
		return -1.0
	var parcels := WarrenMazeBlockPartitioner.partition(plan, volume)
	if parcels == null:
		return -1.0
	return float(parcels.audit.get("maze_ownership_ratio", 0.0))


## Baked into every capture: three lines of facts and the four swatches.
func _build_legend(root: Node3D, city_seed: int,
		profile: WarrenVillageScaleProfile, state: StringName,
		facts: Dictionary) -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.82)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Monospace", "Courier New"])
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("normal_font", mono)
	label.add_theme_font_size_override("normal_font_size", 22)
	label.text = "\n".join(PackedStringArray([
		"seed %d  scale %s  state %s" % [city_seed,
			String(profile.scale_id), String(state)],
		"plots %d  houses %d  assets %d  decks %d  bridges %d  tiered %d" % [
			facts.plots, facts.houses, facts.assets, facts.decks,
			facts.bridges, facts.tiered],
		"exterior rock %s  coverage %s  ownership %s" % [
			_ratio_text(facts.exterior_rock), _ratio_text(facts.coverage),
			_ratio_text(facts.ownership)],
		"%s rock  %s plot  %s passage  %s deck" % [_swatch(ROCK),
			_swatch(PLOT_SHADES[4]), _swatch(PASSAGE), _swatch(DECK)],
	]))
	panel.add_child(label)


func _ratio_text(value: float) -> String:
	return "n/a" if value < 0.0 else "%.3f" % value


func _swatch(colour: Color) -> String:
	return "[color=#%s]■[/color]" % colour.to_html(false)


# --- Geometry primitives ---------------------------------------------------

func _box_column(root: Node3D, column: Vector2i, y0: int, y1: int,
		colour: Color) -> void:
	if y1 <= y0:
		return
	_box(root, Vector3(float(column.x) * CELL,
		(float(y0) + float(y1)) * 0.5 * BAND, float(column.y) * CELL),
		Vector3(CELL, float(y1 - y0) * BAND, CELL), colour)


## A flat floor square sitting ON band `band`: its underside is the top of
## whatever solid holds it up.
func _slab(root: Node3D, column: Vector2i, band: int, colour: Color) -> void:
	_box(root, Vector3(float(column.x) * CELL,
		float(band) * BAND + SLAB_THICKNESS * 0.5, float(column.y) * CELL),
		Vector3(CELL * SLAB_INSET, SLAB_THICKNESS, CELL * SLAB_INSET), colour)


func _box(root: Node3D, origin: Vector3, size: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	material.metallic_specular = 0.0
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = origin
	root.add_child(instance)
	_bounds_min = Vector3(minf(_bounds_min.x, origin.x),
		minf(_bounds_min.y, origin.y), minf(_bounds_min.z, origin.z))
	_bounds_max = Vector3(maxf(_bounds_max.x, origin.x),
		maxf(_bounds_max.y, origin.y), maxf(_bounds_max.z, origin.z))


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
	# Near-flat on purpose: the four albedos ARE the information, so a white
	# ambient carries them and a weak sun only separates a box's faces. The
	# old warm 1.25 sun burnt grey rock to the deck's own tan.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffffff")
	environment.ambient_light_energy = 0.80
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Flat light alone hides a street: a canyon floor lit like a rooftop is no
	# canyon at all. Occlusion darkens the creases and keeps the hue.
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -37.0, 0.0)
	sun.light_color = Color("fff6ea")
	sun.light_energy = 0.50
	sun.shadow_enabled = true
	add_child(sun)
