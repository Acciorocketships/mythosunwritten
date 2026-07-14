# scripts/terrain/water/WaterSurfaceBuilder.gd
# Thin adapter over the water pipeline: WaterField computes the per-cell
# water field; WaterContour turns its wet/dry boundary into smooth curves
# (r3 Task 3); WaterSkin welds those curves to an interior lattice + a
# meniscus rim into the one rendered SHEET (r3 Task 4-6) and bakes its own
# trigger footprints + a frozen WaterSampler snapshot (r3 Task 7 — the old
# marching-squares mesher, its fallback sheet path, and the per-cell
# sampled-plane volumes it used to build are all deleted; see that task's
# report for the removal). Falls are not a separate swept mesh — the sheet
# shader blends a continuous falling-look into the one water_unified.gdshader
# material, keyed on the mesh's own baked CUSTOM0 attributes. This class owns
# the one shared sheet material, the river-trace profile helpers other
# callers still read (surface_profile/steepness_profile — pure functions of
# a RiverTrace, used by WaterPlan tests and the review-spot tool), and
# build_chunk, which wires the pieces into one Node3D: a MeshInstance3D for
# the sheet, and one Area3D per trigger (swim triggers). Built beside each
# terrain chunk and parented under it (evicts together).
class_name WaterSurfaceBuilder
extends RefCounted

const RIBBON_DEPTH_OFFSET := 1.5      # river surface above its carved bed
const STOREY := 4.0                   # = HeightfieldPlan.STOREY_HEIGHT
const FLOOR_CLEARANCE := 0.8          # river surface above the QUANTIZED floor estimate
const STEEP_RISE := 5.0               # bed drop per sample that reads as rapids=1

static var _sheet_material: ShaderMaterial = null


## LEGACY surface definition (bed + 1.5, quantized-clamped): kept only for
## test_water_plan and the water_review_spots tool, which still read it.
## WaterField's profile() (bed + SURFACE_RIDE == 2.2, continuous) is the
## rendered truth for the current boundary-mesh pipeline — do not reuse this
## for new code.
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


## Build the water node for a chunk, or null when the chunk is dry. `region`
## is the chunk's heightfield region (the streamer computes it and shares it
## here — the water field must see the REAL rendered terrain).
## SHEET (r3 Task 4-6): WaterSkin — interior 3m lattice + a boundary strip
## conforming to WaterContour's smooth curves + a meniscus rim, so the
## waterline renders as a real curve with no bare edge.
## TRIGGERS (r3 Task 7): one Area3D per WaterSkin.build's own `triggers`
## entry (one per 24m wet tile; steep tiles excluded — see
## WaterSkin.STEEP_UNSWIMMABLE), each carrying set_meta("sampler", sampler)
## — a single frozen WaterSampler shared by every trigger this chunk emits
## (WaterSkin.build's own `sampler` return value). A character probe reads
## the exact water height at its own (x,z) from that sampler instead of a
## per-cell sampled plane; see WaterSampler.gd and characters/character.gd's
## own bridge comment in _update_in_water.
## Worker-safe phase: field, contour, mesh-array, trigger, and sampler data.
## No render/physics resource or Node is created here.
func compute_chunk(water: WaterPlan, chunk: Vector2i, region) -> Dictionary:
	return WaterSkin.build(water, chunk, region)


## Main-thread phase: turns a worker payload into render and physics nodes.
func commit_chunk(skin: Dictionary) -> Node3D:
	if skin.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Water"
	var mi := MeshInstance3D.new()
	mi.name = "WaterSheet"
	mi.mesh = WaterSkin.commit(skin.arrays)
	mi.material_override = WaterSurfaceBuilder.sheet_material()
	root.add_child(mi)
	var sampler: WaterSampler = skin.sampler
	for trig: Dictionary in skin.triggers:
		var area := Area3D.new()
		area.collision_layer = 1 << 7
		area.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var rect: Rect2 = trig.rect
		var top: float = trig.top
		var bottom: float = trig.bottom
		box.size = Vector3(rect.size.x, top - bottom, rect.size.y)
		shape.shape = box
		area.add_child(shape)
		area.position = Vector3(rect.position.x + rect.size.x * 0.5,
			(top + bottom) * 0.5, rect.position.y + rect.size.y * 0.5)
		area.set_meta("sampler", sampler)
		root.add_child(area)
	return root


## Main-thread compatibility wrapper for tests and offline harnesses.
func build_chunk(water: WaterPlan, chunk: Vector2i, region) -> Node3D:
	return commit_chunk(compute_chunk(water, chunk, region))
