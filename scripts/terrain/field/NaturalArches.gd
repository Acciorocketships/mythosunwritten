extends RefCounted

## A 96 m source parcel owns a complete cardinal or diagonal rock arch. Its
## centre is the lattice point 8 i + 4 (world 96 i + 48), its abutments the
## points two steps (24 m) away along the arch's axis. The minimum 27 m inset
## exceeds ordinary dressing's 26 m query margin, so no neighboring chunk can
## lose a reservation when this owner is projected.
const SPACING_POINTS := 8
const ABUTMENT_STEPS := 2
const HALF_SPAN := 18.0
const HALF_WIDTH := 3.5

## Arches owned by the lattice points [lo_x, lo_x + points) x [lo_z, lo_z + points).
static func compute(region: HeightfieldRegion, lo_x: int, lo_z: int, points: int,
		seed_value: int, features: FeatureContext, stone_uv: Vector2) -> Dictionary:
	var placements: Array[Dictionary] = []
	var clearance: Array[FeatureGroundShape] = []
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for z in range(lo_z,lo_z+points):
		for x in range(lo_x,lo_x+points):
			if posmod(x,SPACING_POINTS)!=SPACING_POINTS/2 or posmod(z,SPACING_POINTS)!=SPACING_POINTS/2: continue
			for axis: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(1,-1)]:
				var record := _site(region,Vector2i(x,z),axis,features)
				if record.is_empty(): continue
				placements.append(record)
				clearance.append(FeatureGroundShape.axis_rect(record.footprint))
				_mesh(record,seed_value,stone_uv,vertices,normals,uvs,colors)
				break
	var arrays: Array = []
	if not vertices.is_empty():
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
	return {"placements":placements,"clearance":clearance,"arrays":arrays,"collision_faces":vertices}

## A lattice point whose whole dual cell is flat at its own height (a cliff
## top stays flat right up to its walls).
static func _flat_point(region: HeightfieldRegion, p: Vector2i) -> bool:
	var s := TerrainTileField.SPACING
	var bounds := TerrainTileField.height_bounds_on_side(region,
		Rect2(Vector2(p) * s - Vector2.ONE * s * 0.5, Vector2.ONE * s), p)
	var h := region.surface_height(p.x, p.y)
	return is_equal_approx(bounds.x, h) and is_equal_approx(bounds.y, h)

static func _site(region: HeightfieldRegion, cell: Vector2i, axis: Vector2i,
		features: FeatureContext) -> Dictionary:
	var a := cell-axis*ABUTMENT_STEPS
	var b := cell+axis*ABUTMENT_STEPS
	if not _flat_point(region,a) or not _flat_point(region,b): return {}
	var low := region.surface_height(cell.x,cell.y)
	var top_a := region.surface_height(a.x,a.y)
	var top_b := region.surface_height(b.x,b.y)
	var top := minf(top_a,top_b)
	if absf(top_a-top_b)>4.0 or top-low<8.0 or top-low>24.0: return {}
	var center := Vector2(cell)*TerrainTileField.SPACING
	var along := Vector2(axis).normalized()
	var side := Vector2(-along.y,along.x)
	var half_span := HALF_SPAN if axis.x==0 or axis.y==0 else 26.0
	var size := along.abs()*half_span*2+side.abs()*HALF_WIDTH*2.1
	var footprint := Rect2(center-size*.5,size)
	if region.has_grade_effect_in(footprint.grow(1)): return {}
	if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(footprint),1): return {}
	# Both complete abutments enter actual high terrain. The opening below
	# the center has real low ground, independent of a logical cell label.
	for sign_value: float in [-1,1]:
		var end_height := top_a if sign_value<0 else top_b
		for inset: float in [0,1,2]:
			for lateral: float in [-HALF_WIDTH*1.05,0,HALF_WIDTH*1.05]:
				var p := center+along*sign_value*(half_span-inset)+side*lateral
				if absf(TerrainTileField.surface_y(region,p.x,p.y)-end_height)>.15: return {}
	# The opening: the centre point's own dual cell (inside its 6 m half).
	for distance: float in [-5,0,5]:
		for lateral: float in [-HALF_WIDTH,0,HALF_WIDTH]:
			var p := center+along*distance+side*lateral
			if TerrainTileField.surface_y(region,p.x,p.y)>top-6: return {}
	return {"owner":cell,"axis":axis,"center":center,"low":low,"top":top,
		"top_a":top_a,"top_b":top_b,"half_span":half_span,"footprint":footprint}

static func _ring(record: Dictionary, fraction: float) -> Array[Vector3]:
	var center: Vector2 = record.center
	var along := Vector2(record.axis).normalized()
	var side := Vector2(-along.y,along.x)
	var arch := maxf(0,sin(fraction*PI))
	var p := center+along*lerpf(-record.half_span,record.half_span,fraction)
	# The exposed crown narrows and bends while the abutments keep their
	# complete surveyed envelope. Beveled strata share vertices with the
	# underside: this is one closed rock volume, including collision.
	p += side * .3 * sin(fraction*TAU*2) * arch
	var width := HALF_WIDTH*(1.0-.25*arch+.07*sin(fraction*PI*9)*arch)
	var top: float = lerpf(record.top_a,record.top_b,fraction)+pow(arch,.85)*8.0 \
		+.65*sin(fraction*TAU*7)*arch
	var bottom: float = record.low-.15+(record.top-record.low+4.35)*pow(arch,.7)
	var section: Array[Vector2] = [Vector2(-.6,0),Vector2(-.88,.12),
		Vector2(-.96,.32),Vector2(-.9,.36),Vector2(-1,.39),
		Vector2(-.96,.62),Vector2(-.88,.66),Vector2(-.96,.69),
		Vector2(-.8,.9),Vector2(-.45,1),Vector2(.45,1),Vector2(.8,.9),
		Vector2(.96,.69),Vector2(.88,.66),Vector2(.96,.62),
		Vector2(1,.39),Vector2(.9,.36),Vector2(.96,.32),Vector2(.88,.12),Vector2(.6,0)]
	var result: Array[Vector3] = []
	for profile: Vector2 in section:
		var point := p+side*width*profile.x
		result.append(Vector3(point.x,lerpf(bottom,top,profile.y),point.y))
	return result

static func _mesh(record: Dictionary, seed_value: int, uv: Vector2,
		vertices: PackedVector3Array,normals: PackedVector3Array,
		uvs: PackedVector2Array,colors: PackedColorArray) -> void:
	var along := Vector3(record.axis.x,0,record.axis.y).normalized()
	var side := Vector3(-along.z,0,along.x)
	var tint := BiomeRegistry.ground_tint_at(Vector3(record.center.x,0,record.center.y),seed_value)
	for index in 16:
		var a := _ring(record,float(index)/16)
		var b := _ring(record,float(index+1)/16)
		for face in a.size():
			var next := (face+1)%a.size()
			var outward := -side if face<9 else side
			if face==9: outward=Vector3.UP
			if face==19: outward=Vector3.DOWN
			var shade := 1.0+.09*sin(float(index*7+face*3))
			if face in [2,3,5,6,12,13,15,16]: shade+=.1
			var color := Color(tint.r*shade,tint.g*shade,tint.b*shade,tint.a)
			_quad([a[face],a[next],b[next],b[face]],outward,uv,color,vertices,normals,uvs,colors)
	for end: int in [0,1]:
		var ring := _ring(record,end)
		# Strata make the section concave. A fan from the first perimeter
		# vertex overlaps its recesses and reverses internal edges.
		var polygon := PackedVector2Array()
		for point: Vector3 in ring: polygon.append(Vector2(point.dot(side),point.y))
		var indices := Geometry2D.triangulate_polygon(polygon)
		assert(indices.size()==(ring.size()-2)*3)
		for index in range(0,indices.size(),3):
			_triangle(ring[indices[index]],ring[indices[index+1]],ring[indices[index+2]],
				along*(end*2-1),uv,tint,vertices,normals,uvs,colors)

static func _quad(points: Array[Vector3],outward: Vector3,uv: Vector2,tint: Color,
		vertices: PackedVector3Array,normals: PackedVector3Array,
		uvs: PackedVector2Array,colors: PackedColorArray) -> void:
	for indices: Vector3i in [Vector3i(0,1,2),Vector3i(0,2,3)]:
		_triangle(points[indices.x],points[indices.y],points[indices.z],outward,uv,tint,vertices,normals,uvs,colors)

static func _triangle(a: Vector3,b: Vector3,c: Vector3,outward: Vector3,uv: Vector2,tint: Color,
		vertices: PackedVector3Array,normals: PackedVector3Array,
		uvs: PackedVector2Array,colors: PackedColorArray) -> void:
	if (c-a).cross(b-a).dot(outward)<0:
		var swap := b
		b=c
		c=swap
	var normal := (c-a).cross(b-a).normalized()
	for vertex: Vector3 in [a,b,c]:
		vertices.append(vertex)
		normals.append(normal)
		uvs.append(uv)
		colors.append(tint)
