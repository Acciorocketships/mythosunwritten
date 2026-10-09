extends RefCounted
## Shallow inhabited upper fronts in walls and multi-storey houses. The source room
## remains the bearing; the extension has its own floor, ceiling and returns.
const DEPTH := 0.65
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


static func fit(
	masses: Array[BuildingMass],
	kits: Dictionary,
	base: BuildingKit,
	catalog: EnvironmentCatalog,
	air: Array[Dictionary],
	towers: Array[Dictionary],
	blocked: Callable,
	capped: Callable,
	solid: Callable = Callable(),
	walked: Callable = Callable(),
	facing: Dictionary = {},
	sky_gap := 0.0
) -> Array[Dictionary]:
	var has_upper_front := false
	for mass: BuildingMass in masses:
		if _eligible(mass, kits):
			has_upper_front = true
			break
	if not has_upper_front:
		return []
	var obstacles: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var assembler := BuildingKitAssembler.new(kits.get(own, base))
		if solid.is_valid():
			assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
				return bool(solid.call(own, cell, band))
		if walked.is_valid():
			assembler.public_floor = walked
		for part: Dictionary in assembler.assemble(mass):
			obstacles.append(
				{
					"owner": mass.stable_id,
					"role": part.role,
					"asset": part.asset_id,
					"bounds": part.transform * catalog.descriptor(part.asset_id).measured_aabb
				}
			)
	for tower: Dictionary in towers:
		obstacles.append({"owner": &"", "bounds": tower.bounds})
	var out: Array[Dictionary] = []
	for pass_index in 2:
		for mass: BuildingMass in masses:
			if not _eligible(mass, kits):
				continue
			var own := StringName(String(mass.stable_id).trim_prefix("kit."))
			var kit: BuildingKit = kits.get(own, base)
			if not kit.has_role(&"frontage.return"):
				continue
			var embedded := String(mass.stable_id).contains("wall-room")
			var first_projection := out.size()
			var relieved_faces := {}
			for previous: Dictionary in out:
				if previous.host == mass.stable_id:
					relieved_faces[int(previous.dir)] = true
			# Keep every house's first fit before competing for a second front.
			# Extra relief must not displace a neighbour's established projection.
			if pass_index == 1 and (embedded or mass.storeys.size() < 4 or relieved_faces.is_empty()):
				continue
			var levels: Array[int] = []
			for index in range(1, mass.storeys.size()):
				levels.append(index)
			if not embedded:
				var shift := posmod(hash([mass.seed, "front.level"]), levels.size())
				levels = levels.slice(shift) + levels.slice(0, shift)
			for index: int in levels:
				# One complete bay per pass; the extra pass must use another
				# face, avoiding a repeated vertical apartment grid.
				if not embedded and out.size() > first_projection:
					break
				var storey: Dictionary = mass.storeys[index]
				# Growth fronts leave the storey's other faces free for one projection.
				if (storey.get("projections", []) as Array).any(
						func(p: Dictionary) -> bool: return not bool(p.get("growth", false))):
					continue
				var leaning: Dictionary = storey.get("growth", {})
				var band := int(storey.floor_band)
				if (
					band <= mass.ground_band
					or bool(storey.inset)
					or storey.material != BuildingMass.MATERIAL_TIMBER
				):
					continue
				var lower := mass.cells_at_band(band - 1)
				for run: Dictionary in _front_candidates(mass.seed, band, BuildingKitAssembler.boundary_runs(storey.cells)):
					if int(run.end) - int(run.start) < 2:
						continue
					var dir := int(run.dir)
					# Not on a leaning face, nor beside its returns.
					if leaning.has(dir) or leaning.has((dir + 1) % 4) or leaning.has((dir + 3) % 4):
						continue
					if pass_index == 1 and relieved_faces.has(dir):
						continue
					var first := int(run.start)
					var last := int(run.end)
					var edges: Array[Vector3i] = []
					var centres: Array[Vector2] = []
					var valid := true
					for along in range(first, last):
						var cell := BuildingKitAssembler._inside_cell(dir, run.line, along)
						var edge := BuildingMass.edge_key(cell, dir)
						if not lower.has(cell):
							valid = false
						if (
							storey.openings.get(edge, storey.default_opening)
							not in [BuildingMass.OPENING_WINDOW, BuildingMass.OPENING_PLAIN]
						):
							valid = false
						if (
							not mass.cells_at_band(band + 2).has(cell)
							and not bool(capped.call(own, cell, band + 2))
						):
							valid = false
						for b in range(band - 1, band + 2):
							if bool(blocked.call(own, cell + BuildingMass.DIRS[dir], b)):
								valid = false
						edges.append(edge)
						centres.append(
							Vector2(cell) + Vector2.ONE * .5 + Vector2(BuildingMass.DIRS[dir]) * .5
						)
					if not valid:
						continue
					var right := Vector2(BuildingKitAssembler.right_of(dir))
					centres.sort_custom(
						func(a: Vector2, b: Vector2) -> bool: return a.dot(right) < b.dot(right)
					)
					var a: Vector2 = centres.front() * kit.module_width
					var pose := Transform3D(
						Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)),
						Vector3(a.x, band * kit.band_height(), a.y)
					)
					# Complete new front, native brackets and return seams. Keep the
					# small attachment lap at the existing wall out of neighbour tests.
					var local := AABB(
						Vector3(-1.2, -1.0, 0.0),
						Vector3(centres.size() * kit.module_width + .4, 4.0, 1.05)
					)
					if CLEARANCE.intersects_air(local, pose, air):
						continue
					# Below the floor only the native joint brackets occupy space.
					# A single enclosing box wrongly collides with the lower wall's posts.
					var occupied: Array[AABB] = [
						(
							pose
							* AABB(
								Vector3(-1.15, -.15, .3),
								Vector3(centres.size() * kit.module_width + .3, 3.15, .75)
							)
						)
					]
					var bracket_id := kit.asset(&"bracket.small", 0)
					var bracket_box := catalog.descriptor(bracket_id).measured_aabb
					for joint in range(centres.size() + 1):
						var bracket_pose := (
							Transform3D(
								Basis.IDENTITY, Vector3((joint - .5) * kit.module_width, -BuildingKitAssembler.SMALL_BRACKET_DROP,
									-BuildingKitAssembler.SMALL_BRACKET_SETBACK)
							)
							* kit.anchor(&"bracket.small")
							* kit.asset_anchor(bracket_id)
						)
						var tip: AABB = bracket_pose * bracket_box
						var end := tip.end.z
						tip.position.z = maxf(tip.position.z, .3)
						tip.size.z = maxf(0, end - tip.position.z)
						if tip.size.z > 0:
							occupied.append(pose * tip)
					for obstacle: Dictionary in obstacles:
						if obstacle.owner == mass.stable_id and not String(obstacle.get("role", "")).begins_with("roof."):
							continue
						for box: AABB in occupied:
							if box.intersects(obstacle.bounds):
								valid = false
								break
						if not valid:
							break
					if not valid:
						continue
					# Keep the lane's sky gap to a growing house's leaned facade across it.
					if not facing.is_empty() and solid.is_valid() and not GROWTH.gap_ok(
							facing, solid, own, edges, dir, band, DEPTH, kit, sky_gap):
						continue
					var projection := {
						"edges": edges, "centres": centres, "dir": dir, "depth": DEPTH, "band": band
					}
					var fronts: Array = storey.get("projections", [])
					fronts.append(projection)
					storey["projections"] = fronts
					var offsets: Dictionary = storey.get("wall_offsets", {})
					storey["wall_offsets"] = offsets
					for edge: Vector3i in edges:
						offsets[edge] = DEPTH / kit.module_width
					# A new inhabited front needs an opening. Its final native pane
					# still goes through the ordinary roof/floor obstruction fitter.
					var window: Vector3i = edges[posmod(hash([mass.seed, band, dir]), edges.size())]
					storey.openings[window] = BuildingMass.OPENING_WINDOW
					if not embedded:
						for edge: Vector3i in edges:
							storey.openings[edge] = BuildingMass.OPENING_WINDOW

					for item: Dictionary in mass.decor:
						if (
							not item.has("dir")
							or int(item.dir) != dir
							or absf(float(item.get("y", -INF)) - band * kit.band_height()) > .01
						):
							continue
						if centres.has(item.centre):
							item.centre += Vector2(BuildingMass.DIRS[dir]) * DEPTH / kit.module_width
							item.y = float(item.y) - .14
					var body := AABB(
						Vector3(-kit.module_width * .5, 0, 0),
						Vector3(centres.size() * kit.module_width, kit.storey_height, DEPTH)
					)
					out.append(
						{
							"host": mass.stable_id,
							"bounds": pose * body,
							"envelope": pose * local,
							"band": band,
							"dir": dir
						}
					)
					obstacles.append({"owner": &"", "bounds": pose * local})
					break  # A single coherent projecting frontage per storey.
	return out


static func _eligible(mass: BuildingMass, kits: Dictionary) -> bool:
	if String(mass.stable_id).contains("wall-room"):
		return mass.storeys.size() > 1
	var own := StringName(String(mass.stable_id).trim_prefix("kit."))
	# Only inhabited house owners, never retaining walls or open skywalks.
	# A middle storey supplies both a bearing room and an upper closure.
	return kits.has(own) and mass.storeys.size() >= 3


## Keep the original seeded preference, then try smaller complete native bays.
## A door or neighbouring roof at one end need not reject an entire facade.
## Every candidate still passes the same measured bearing/air/junction checks.
static func _front_candidates(seed_value: int, band: int, runs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: Dictionary in runs:
		var first := int(run.start)
		var last := int(run.end)
		if last-first<2: continue
		var preferred := run.duplicate()
		if last-first>=5:
			var width := 2+posmod(hash([seed_value,band,int(run.dir),"front.width"]),2)
			preferred.start=first+1+posmod(hash([seed_value,band,int(run.dir),"front.position"]),last-first-width-1)
			preferred.end=int(preferred.start)+width
			# Keep flush shoulders on long fronts, including fallbacks.
			first+=1
			last-=1
		out.append(preferred)
		var options: Array[Dictionary] = []
		for width in [3,2]:
			for start in range(first,last-width+1):
				if start==int(preferred.start) and start+width==int(preferred.end):continue
				var candidate := run.duplicate()
				candidate.start=start
				candidate.end=start+width
				options.append(candidate)
		if not options.is_empty():
			var shift := posmod(hash([seed_value,band,int(run.dir),"front.fallback"]),options.size())
			out.append_array(options.slice(shift)+options.slice(0,shift))
	return out
