extends SceneTree
## Renders designed kit buildings through the real catalog/commit path.
## GUI only (captures need a renderer):
##   Godot --path . -s res://tests/harness/suntail/building_gallery.gd -- \
##     --output DIR [--set replica|designer] [--count N] [--seed S] [--compare]
##     [--growth STEP:CAP] (every exposed face of each designed house steps in)
##     [--street] (two facing rows along one lane instead of a grid, with eye-height
##     views along the lane: a Shambles-style street of the gallery's houses)
## `replica` rebuilds the pack's House_1 from a BuildingMass beside the source
## prefab; `designer` lays out BuildingDesigner results on a grid.
const GALLERY := preload("res://tests/harness/suntail/gallery_masses.gd")

var _out := "user://building_gallery"
var _set := "replica"
var _count := 12
var _seed := 1
var _compare := false
var _close := false
var _growth := ""
var _street := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--output": _out = args[i + 1]
			"--set": _set = args[i + 1]
			"--count": _count = int(args[i + 1])
			"--seed": _seed = int(args[i + 1])
			"--compare": _compare = true
			"--close": _close = true
			"--growth": _growth = args[i + 1]
			"--street": _street = true
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_run")


func _stage() -> Node3D:
	var stage := Node3D.new()
	get_root().add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.27, 0.46, 0.75)
	sky_material.sky_horizon_color = Color(0.71, 0.82, 0.92)
	sky_material.ground_bottom_color = Color(0.42, 0.5, 0.56)
	sky_material.ground_horizon_color = Color(0.68, 0.78, 0.86)
	var sky := Sky.new()
	sky.sky_material = sky_material
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.6, 0.55)
	e.ambient_light_sky_contribution = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.52, 0.24)
	ground.material_override = material
	ground.position.y = -0.02
	stage.add_child(ground)
	return stage


func _commit(stage: Node3D, payload: EnvironmentInstancePayload) -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var parent := Node3D.new()
	stage.add_child(parent)
	var queue := FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	while queue.pending_count() > 0:
		queue.drain(100000, 100000, 100000)
		await process_frame


func _shoot(stage: Node3D, eye: Vector3, target: Vector3, name: String,
		fov := 50.0) -> void:
	var camera := Camera3D.new()
	camera.fov = fov
	stage.add_child(camera)
	camera.look_at_from_position(eye, target)
	camera.current = true
	for i in 10:
		await process_frame
	RenderingServer.force_draw(false)
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	camera.queue_free()


## Every exposed face of one designed house steps in (growth knobs forced on).
func _grow(mass: BuildingMass, kit: BuildingKit) -> void:
	const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
	var setting := _growth.split(":")
	for storey: Dictionary in mass.storeys:
		storey.inset = false # growing houses take no jetty
	mass.grows = true
	var character := TownCharacter.draw(TownOddsProgram.builtin().with_overrides({
		&"growing_house_chance": 1.0, &"growth_street_face_chance": 1.0,
		&"growth_other_face_chance": 1.0, &"growth_max_lean": float(setting[1])}), _seed, 0.5)
	character.values[&"growth_step"] = {StringName(setting[0]): 1.0}
	var footprint := mass.cells_at_band(mass.ground_band)
	var grow_masses: Array[BuildingMass] = [mass]
	GROWTH.fit(grow_masses, {StringName(String(mass.stable_id).trim_prefix("kit.")): kit}, kit,
		EnvironmentCatalog.load_default(), character, [], [],
		func(_o: StringName, _c: Vector2i, _b: int) -> bool: return false,
		func(_o: StringName, _c: Vector2i, _b: int) -> bool: return false,
		func(cell: Vector2i, band: int) -> bool: return band <= mass.ground_band + 1 and not footprint.has(cell))


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var stage := _stage()
	var kit := SuntailBuildingKit.create()
	if OS.get_cmdline_user_args().has("--pure-village"):
		kit = preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").create()
	if OS.get_cmdline_user_args().has("--pure-roofs"):
		kit = preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
	var assembler := BuildingKitAssembler.new(kit)
	var payload := EnvironmentInstancePayload.new()
	var spots: Array[Vector3] = []
	var masses: Array[BuildingMass] = GALLERY.masses(_set, _count, _seed, kit)
	var spacing := 26.0
	var columns := int(ceil(sqrt(float(masses.size()))))
	# --street: even houses on the north side of a lane, odd ones turned to face them
	# from the south, each row packed along x with a narrow alley between houses.
	const LANE := 5.0 # native m between the two rows' lot lines (10 m world)
	const ALLEY := 1.0
	var row_x := [0.0, 0.0]
	for i in masses.size():
		var at := Vector3(float(i % columns) * spacing, 0.0,
			float(i / columns) * spacing)
		var frame := Transform3D(Basis.IDENTITY, at)
		if _street:
			var cells := {}
			for storey: Dictionary in masses[i].storeys:
				cells.merge(storey.cells)
			var rect := BuildingDesigner._bounds(cells)
			var lo := Vector2(rect.position) * kit.module_width
			var size := Vector2(rect.size) * kit.module_width
			var side := i % 2
			if side == 0: # lot line (max z) on z = 0
				frame = Transform3D(Basis.IDENTITY, Vector3(row_x[0] - lo.x, 0.0, -(lo.y + size.y)))
			else: # turned half round: its min-z face becomes its lot line on z = LANE
				frame = Transform3D(Basis(Vector3.UP, PI),
					Vector3(row_x[1] + lo.x + size.x, 0.0, LANE + lo.y + size.y))
			row_x[side] += size.x + ALLEY
		spots.append(frame.origin + Vector3(4, 4, 4))
		if not _growth.is_empty():
			_grow(masses[i], kit)
		var placements := assembler.assemble(masses[i])
		BuildingKitAssembler.append_to_payload(placements, frame, payload)
	if _set == "replica" or _compare:
		var prefab: Node3D = (load("res://assets/Raygeas/Models/Buildings/House_1.glb") as PackedScene).instantiate()
		prefab.position = Vector3(-24, -1, 4)
		stage.add_child(prefab)
		spots.append(Vector3(-24, 4, 4))
	await _commit(stage, payload)
	var centre := Vector3(float(columns - 1) * spacing * 0.5, 0,
		float((masses.size() - 1) / columns) * spacing * 0.5)
	if _street:
		var length := maxf(row_x[0], row_x[1])
		var eye := 0.9 # a person's eye in kit native metres (world = native x 2)
		await _shoot(stage, Vector3(-3, eye, LANE * 0.5), Vector3(length, eye + 2.0, LANE * 0.5), "street_west", 60)
		await _shoot(stage, Vector3(length + 3, eye, LANE * 0.5), Vector3(0, eye + 2.0, LANE * 0.5), "street_east", 60)
		await _shoot(stage, Vector3(length * 0.3, eye, LANE * 0.8), Vector3(length * 0.7, eye + 3.0, -1.0), "street_north", 70)
		await _shoot(stage, Vector3(length * 0.3, eye, LANE * 0.2), Vector3(length * 0.7, eye + 3.0, LANE + 1.0), "street_south", 70)
		await _shoot(stage, Vector3(length * 0.5, 14.0, LANE + 16.0), Vector3(length * 0.5, 2.0, LANE * 0.5), "street_above", 55)
		print("GALLERY_DONE ", _out)
		quit()
		return
	await _shoot(stage, centre + Vector3(-10, 70, 90), centre, "overview", 50)
	for i in spots.size():
		var c := spots[i]
		if _close:
			for k in 4:
				var ang := PI * 0.25 + PI * 0.5 * float(k)
				var dir := Vector3(cos(ang), 0, sin(ang))
				await _shoot(stage, c + dir * 11.0 + Vector3(0, -2.2, 0), c + Vector3(0, 0.5, 0),
					"b%02d_c%d" % [i, k], 60)
			await _shoot(stage, c + Vector3(6, 11, 8), c + Vector3(0, 5, 0), "b%02d_roof" % i, 55)
			continue
		await _shoot(stage, c + Vector3(15, 9, 17), c, "b%02d_a" % i, 55)
		await _shoot(stage, c + Vector3(-17, 6, -14), c, "b%02d_b" % i, 55)
	print("GALLERY_DONE ", _out)
	quit()
