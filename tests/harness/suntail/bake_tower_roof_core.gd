extends SceneTree
## Offline inner envelope of the native cap. Rendering always uses the original
## asset; this is only the hidden volume used to join neighbouring roof skins.
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const SIDES := 32
const STEP := 0.3
const INSET := 0.015

func _init() -> void:
	var shaft := OS.get_cmdline_user_args().has("--roof-turret")
	var narrow_cap := OS.get_cmdline_user_args().has("--narrow-cap")
	var input := "res://terrain/environment/geometry/pure_village_roof_turret.bin" if shaft or narrow_cap else TOWER.ROOF_GEOMETRY
	var data: Dictionary = FileAccess.open(input, FileAccess.READ).get_var()
	var surfaces: Array = data[&"pure_village.roof_turret.middle" if shaft else (&"pure_village.roof_turret.roof" if narrow_cap else &"pure_village.tower.roof")]
	var rings: Array[PackedVector3Array] = []
	for k in (32 if shaft else 20):
		rings.append(_ring(surfaces, minf(2.99,0.02+k*0.10) if shaft else 0.02+k*STEP))
	var cutters: Array[Dictionary] = []
	for k in rings.size() - 1:
		var lower := rings[k]
		var upper := rings[k + 1]
		if lower.size() != SIDES or upper.size() != SIDES: continue
		var centre := Vector3.ZERO
		var box := AABB(lower[0], Vector3.ZERO)
		for p in lower + upper:
			centre += p / float(SIDES * 2)
			box = box.expand(p)
		var planes: Array[Plane] = [Plane(Vector3.DOWN, -lower[0].y), Plane(Vector3.UP, upper[0].y)]
		for j in SIDES:
			var next := (j + 1) % SIDES
			for tri in [[lower[j], lower[next], upper[j]], [upper[j], upper[next], lower[next]]]:
				var plane := Plane(tri[0], tri[1], tri[2])
				if plane.distance_to(centre) > 0: plane = -plane
				planes.append(plane)
		cutters.append({"planes": planes, "bounds": box})
	if narrow_cap and not rings[0].is_empty():
		# The cap replaces the crossing eave, including the eave's curved
		# underside. Project only its measured inner lip down 0.8 metres;
		# the unchanged cap covers this small roof-to-roof seam from above.
		var lip := rings[0]
		var planes: Array[Plane] = [Plane(Vector3.DOWN, 0.8), Plane(Vector3.UP, lip[0].y)]
		var box := AABB(lip[0], Vector3.ZERO)
		for j in SIDES:
			var a := lip[j]
			var b := lip[(j+1)%SIDES]
			var n := Vector3(b.z-a.z,0,a.x-b.x).normalized()
			if n.dot(a)<0: n=-n
			planes.append(Plane(n,n.dot(a)))
			box=box.expand(a).expand(Vector3(a.x,-0.8,a.z))
		cutters.append({"planes":planes,"bounds":box})
	if shaft:
		# The plain course is a near-cylindrical shell. A single inscribed
		# prism avoids splitting a host roof at every stone-course sample.
		# Its radius is the nearest sampled native cross-section EDGE to the
		# axis (not the outer radius of its decorative stone vertices).
		var radius := INF
		for ring in rings:
			assert(ring.size()==SIDES)
			for j in SIDES:
				var a := Vector2(ring[j].x,ring[j].z)
				var b := Vector2(ring[(j+1)%SIDES].x,ring[(j+1)%SIDES].z)
				radius=minf(radius,Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b).length())
		assert(radius>0.6,"Every sampled cross-section must surround the full shaft axis")
		var planes: Array[Plane] = [Plane(Vector3.DOWN,-0.02),Plane(Vector3.UP,2.99)]
		for j in SIDES:
			planes.append(Plane(Vector3(cos(TAU*j/SIDES),0,sin(TAU*j/SIDES)),radius*cos(PI/SIDES)))
		cutters.assign([{"planes":planes,"bounds":AABB(Vector3(-radius,0.02,-radius),Vector3(radius*2,2.97,radius*2))}])
		print("SHAFT_INNER_RADIUS ",radius)
	var output := "res://terrain/environment/geometry/pure_village_roof_turret_core.bin" if shaft else TOWER.ROOF_CORE
	if narrow_cap: output = "res://terrain/environment/geometry/pure_village_corner_cap_core.bin"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_var(cutters)
	print("BAKED_TOWER_CORE ", cutters.size(), " slices; original roof untouched")
	quit()

func _ring(surfaces: Array, y: float) -> PackedVector3Array:
	var segments: Array[PackedVector2Array] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for surface: Dictionary in surfaces:
		var vs: PackedVector3Array = surface.vertices
		var ids: PackedInt32Array = surface.indices
		for i in range(0, ids.size(), 3):
			var points := PackedVector2Array()
			for edge in 3:
				var a := vs[ids[i + edge]]
				var b := vs[ids[i + (edge + 1) % 3]]
				if (a.y < y) == (b.y < y) or absf(a.y - b.y) < 0.000001: continue
				var p := a.lerp(b, (y - a.y) / (b.y - a.y))
				points.append(Vector2(p.x, p.z))
			if points.size() != 2: continue
			segments.append(points)
			for point in points:
				lo = lo.min(point)
				hi = hi.max(point)
	if segments.is_empty(): return PackedVector3Array()
	var centre := (lo + hi) * 0.5
	var ring := PackedVector3Array()
	for j in SIDES:
		var direction := Vector2(cos(TAU * j / SIDES), sin(TAU * j / SIDES))
		var radius := -INF
		for segment in segments:
			var hit: Variant = Geometry2D.segment_intersects_segment(centre, centre + direction * 6.0, segment[0], segment[1])
			if hit != null: radius = maxf(radius, centre.distance_to(hit))
		if not is_finite(radius) or radius <= INSET: return PackedVector3Array()
		var p := centre + direction * (radius - INSET)
		ring.append(Vector3(p.x, y, p.y))
	return ring
