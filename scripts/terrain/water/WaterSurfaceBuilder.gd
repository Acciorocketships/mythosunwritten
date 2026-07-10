# scripts/terrain/water/WaterSurfaceBuilder.gd
# Thin adapter over the boundary-mesh water pipeline: WaterField computes the
# per-cell water field, WaterMesher turns it into a marching-squares sheet
# mesh (welded free edges + a submerged hem), and FallMesher sweeps waterfall
# geometry from the sheet's own crest-edge vertices. This class owns the two
# shared materials, the river-trace profile helpers other callers still read
# (surface_profile/steepness_profile — pure functions of a RiverTrace, used
# by WaterPlan tests and the review-spot tool), and build_chunk, which wires
# the three pieces into one Node3D: a MeshInstance3D for the sheet, one for
# the falls, and one Area3D per wet-cell surface entry (swim volumes). Built
# beside each terrain chunk and parented under it (evicts together).
class_name WaterSurfaceBuilder
extends RefCounted

const TILE := 24.0
const RIBBON_DEPTH_OFFSET := 1.5      # river surface above its carved bed
const STOREY := 4.0                   # = HeightfieldPlan.STOREY_HEIGHT
const FLOOR_CLEARANCE := 0.8          # river surface above the QUANTIZED floor estimate
const STEEP_RISE := 5.0               # bed drop per sample that reads as rapids=1

static var _sheet_material: ShaderMaterial = null


## Water surface height per polyline sample: bed + offset, flattened into the
## terminal pond (backwater) and made monotone by a single backward pass —
## walking upstream, the surface may only rise. Pure function of the trace.
## The carved channel renders storey-QUANTIZED, and rounding can lift the
## floor up to half a storey above the bed — clearing the quantized floor
## estimate too keeps reaches just past a step from submerging under terrain.
static func surface_profile(river: RiverTrace) -> PackedFloat32Array:
	var n: int = river.points.size()
	var prof: PackedFloat32Array = PackedFloat32Array()
	prof.resize(n)
	for i in n:
		var floor_est: float = roundf(river.beds[i] / STOREY) * STOREY
		prof[i] = maxf(river.beds[i] + RIBBON_DEPTH_OFFSET, floor_est + FLOOR_CLEARANCE)
	if river.pond != null:
		prof[n - 1] = maxf(river.pond.surface_y(), river.beds[n - 1] + 0.2)
	for i in range(n - 2, -1, -1):
		prof[i] = maxf(prof[i], prof[i + 1])
	return prof


## 0 (calm) .. 1 (waterfall) steepness per sample, from the bed's local drop.
static func steepness_profile(river: RiverTrace) -> PackedFloat32Array:
	var n: int = river.points.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var a: int = maxi(i - 1, 0)
		var b: int = mini(i + 1, n - 1)
		var drop: float = river.beds[a] - river.beds[b]
		out[i] = clampf(drop / (STEEP_RISE * float(b - a if b > a else 1)), 0.0, 1.0)
	return out


static var _noise_texture: NoiseTexture2D = null
static var _fall_material: ShaderMaterial = null


static func _noise_tex() -> NoiseTexture2D:
	if _noise_texture == null:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = 7
		noise.frequency = 0.008
		_noise_texture = NoiseTexture2D.new()
		_noise_texture.noise = noise
		_noise_texture.seamless = true
	return _noise_texture


static func _make_material() -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://terrain/water/water_unified.gdshader")
	mat.set_shader_parameter("noise_tex", _noise_tex())
	return mat


static func sheet_material() -> ShaderMaterial:
	if _sheet_material == null:
		_sheet_material = _make_material()
	return _sheet_material


static func waterfall_material() -> ShaderMaterial:
	if _fall_material == null:
		_fall_material = ShaderMaterial.new()
		_fall_material.shader = load("res://terrain/water/waterfall.gdshader")
		_fall_material.set_shader_parameter("noise_tex", _noise_tex())
	return _fall_material


## Build the water node for a chunk, or null when the chunk is dry. `region`
## is the chunk's heightfield region (the streamer computes it for the mesher
## and shares it here — the water field must see the REAL rendered terrain).
## Boundary-conforming path (WaterMesher/FallMesher): the sheet is a marching-
## squares mesh whose free edges are welded to the ArrayMesh FallMesher sweeps
## from the sheet's own lip contour, so crest and curtain share vertices by
## construction. Swim volumes ride one Area3D per wet-cell SURFACE entry
## (WaterMesher's wet_cells; a cut-straddling cell gets two stacked volumes),
## each carrying the sampled surface plane (Task 10's contract) instead of a
## single scalar level — the plane lets a probe interpolate the true
## swell-free surface height anywhere inside the cell.
func build_chunk(water: WaterPlan, chunk: Vector2i, region) -> Node3D:
	var m: Dictionary = WaterMesher.build(water, chunk, region)
	if m.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Water"
	var mi := MeshInstance3D.new()
	mi.name = "WaterSheet"
	mi.mesh = WaterMesher.commit(m)
	mi.material_override = WaterSurfaceBuilder.sheet_material()
	root.add_child(mi)
	var falls: ArrayMesh = FallMesher.build(m.cuts, region)
	if falls != null:
		var fi := MeshInstance3D.new()
		fi.name = "Waterfalls"
		fi.mesh = falls
		fi.material_override = WaterSurfaceBuilder.waterfall_material()
		root.add_child(fi)
	for cell: Vector2i in m.wet_cells:
		# One Area3D per SURFACE ENTRY (usually one; a cell crossed by a fall
		# cut carries two stacked volumes, upper and lower, so no box ever
		# reports the upper level over the plunge pool — the owner's phantom
		# mid-air swim).
		for wc: Dictionary in m.wet_cells[cell]:
			var area := Area3D.new()
			area.collision_layer = 1 << 7
			area.collision_mask = 0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			var top: float = wc.lvl + 1.7
			# A straddling cell's UPPER entry floors at its "floor" key —
			# STRICTLY ABOVE the lower box's ceiling (lower level + 1.7), so
			# the stacked boxes never overlap: in the character's maxf-gating
			# over passing volumes an overlap band would pick the upper
			# surface, resurrecting the phantom mid-air swim. Plain entries
			# reach the cell's lowest ground minus clearance (half-cell ramps
			# dip below the centre ground).
			var bottom: float = wc.get("floor", wc.gnd_lo - 5.0)
			box.size = Vector3(TILE, top - bottom, TILE)
			shape.shape = box
			area.add_child(shape)
			area.position = Vector3((float(cell.x) + 0.5) * TILE,
				(top + bottom) * 0.5, (float(cell.y) + 0.5) * TILE)
			area.set_meta("surface_c", Vector3((float(cell.x) + 0.5) * TILE,
				wc.lvl, (float(cell.y) + 0.5) * TILE))
			area.set_meta("surface_g", wc.grad)
			root.add_child(area)
	return root
