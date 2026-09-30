# scripts/terrain/field/CliffDressing.gd
# The KayKit cliff piece vocabulary (rock wall slab, beveled grass lip, inner/outer
# corner pieces) and THE shared terrain palette/material. World terrain no longer
# places these pieces: its cliffs are the mesher's rock skirts under the rounded
# slope sheet (dual-grid terrain tiles, September 30). Village retaining rims
# (SettlementFabricAssembler) still dress their own lattice with the pieces, and
# every terrain surface binds the shared material, grass texel and biome tint here.
class_name CliffDressing
extends RefCounted

const VISUALS := {
	"wall": "res://terrain/environment/visuals/kaykit/kaykit_cliff_wall.tres",
	"lip": "res://terrain/environment/visuals/kaykit/kaykit_cliff_lip.tres",
	"outer_wall": "res://terrain/environment/visuals/kaykit/kaykit_cliff_outer_wall.tres",
	"outer_lip": "res://terrain/environment/visuals/kaykit/kaykit_cliff_outer_lip.tres",
	"inner_wall": "res://terrain/environment/visuals/kaykit/kaykit_cliff_inner_wall.tres",
	"inner_lip": "res://terrain/environment/visuals/kaykit/kaykit_cliff_inner_lip.tres",
}
const GROUND_PALETTE := "res://terrain/materials/ground_palette.tres"
const ASSETS := {
	"wall": &"kaykit.cliff.wall",
	"lip": &"kaykit.cliff.lip",
	"outer_wall": &"kaykit.cliff.outer_wall",
	"outer_lip": &"kaykit.cliff.outer_lip",
	"inner_wall": &"kaykit.cliff.inner_wall",
	"inner_lip": &"kaykit.cliff.inner_lip",
}
## Terrain-shaped village retaining skins use these exact catalogue pieces too.
## Keep their classification beside the canonical palette/tint authority so a
## new skin cannot silently acquire a separate settlement colour path.
const TERRAIN_SKIN_ASSETS := {
	&"kaykit.terrain.top_center": true,
	&"kaykit.cliff.wall": true,
	&"kaykit.cliff.lip": true,
	&"kaykit.cliff.outer_wall": true,
	&"kaykit.cliff.outer_lip": true,
	&"kaykit.cliff.inner_wall": true,
	&"kaykit.cliff.inner_lip": true,
}

const STOREY := 4.0
const PLACE := 10.5         # wall/lip/corner node origin — the OLD-TILE spacing (git 0bcc47ea
                            # CliffCorner.tscn), which is the only grid the 3-unit KayKit modules tile
                            # on: straight pieces at ±1.5..±10.5 along the 10.5 line, the corner piece
                            # AT (±10.5, ±10.5) in the end slot the edges drop. At 11.0 every corner
                            # left a 0.5 slit to the last straight piece and the corner lip protruded
                            # past the ±12 boundary (the owner's gaps + planes sticking out). The rock
                            # face spans PLACE+0.25..PLACE+1.0 (10.75..11.5), recessed inside the cell.
                            # Village rims and WaterSkin's rim reach still read it.
const PROFILE_SAMPLES := 24 # edge-profile resolution: 25 points, one per unit along the 24u edge.
                            # Wall depth is PER SLOT from the neighbour's actual boundary surface
                            # (TerrainSurfaceField.edge_profile): exactly the storey drop against a
                            # flat neighbour (no jutting slab below its thin surface), deeper where a
                            # slope neighbour dips along the edge (no see-through void — owner).
const LIP_LIFT := 0.05      # raise the grass lip a hair so it cleanly overlays the field
                            # grass (which now renders to the boundary) instead of z-fighting
static var _pieces: Dictionary = {}   # name -> [mesh, local_transform]
static var _shared_mat: Material = null
static var _ground_uv := Vector2.ZERO
static var _has_ground_uv := false

static func prepare(render_cache: EnvironmentRenderCache) -> void:
	if _pieces.is_empty():
		for key in ASSETS:
			var visual := render_cache.visual(ASSETS[key])
			assert(visual != null and visual.pieces.size() == 1)
			var piece := visual.pieces[0]
			_pieces[key] = [piece.mesh, piece.local_transform]
		_finish_piece_setup()
	_apply_cache_piece_overrides(render_cache)


static func _apply_cache_piece_overrides(
		render_cache: EnvironmentRenderCache) -> void:
	## Cliff dressing can also be emitted by the village's ordinary environment
	## payload. That path used to resolve the catalogue's raw lip meshes while
	## streamed terrain used the retexelled meshes prepared above plus the shared
	## ground material. Publish the exact prepared piece to this main-thread cache
	## so both producers draw one construction vocabulary; placement remains plain
	## worker-side data.
	var material := shared_material()
	for key in ASSETS:
		var visual := render_cache.visual(ASSETS[key])
		assert(visual != null and visual.pieces.size() == 1)
		var piece := visual.pieces[0]
		piece.mesh = _pieces[key][0] as Mesh
		piece.material_override = material

# THE terrain material, shared by every terrain surface — dressing pieces (via
# material_override), the walkable sheet, aprons, rock skirt, and dense-grass
# palette binding. Its dedicated resource is the single global editing point;
# specular stays killed because it lit big flat surfaces a different colour at
# some angles (owner round 7).
static func shared_material() -> Material:
	if _shared_mat != null:
		return _shared_mat
	var mat := load(GROUND_PALETTE) as StandardMaterial3D
	assert(mat != null and mat.albedo_texture != null)
	assert(mat.vertex_color_use_as_albedo and is_equal_approx(mat.roughness, 1.0)
		and is_zero_approx(mat.metallic_specular))
	var surface := ShaderMaterial.new()
	surface.shader = load("res://terrain/materials/ground_surface.gdshader")
	surface.set_shader_parameter("ground_palette_texture", mat.albedo_texture)
	_shared_mat = surface
	return _shared_mat

## The one palette binding consumed by the terrain sheet and dense grass.
## Both the texture object and its grass-island UV come from the same lip mesh,
## so changing the shared atlas can never leave grass with a copied swatch.
static func ground_texture() -> Texture2D:
	var material := load(GROUND_PALETTE) as StandardMaterial3D
	assert(material != null and material.albedo_texture != null)
	return material.albedo_texture

static func ground_uv() -> Vector2:
	_ensure_loaded()
	assert(_has_ground_uv)
	return _ground_uv

# Returns {wall, lip, outer_wall, outer_lip, inner_wall, inner_lip} -> Array[Transform3D].
static func compute_tints(transforms: Array, world_seed: int) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(transforms.size())
	for i in transforms.size():
		out[i] = Color(1, 1, 1) if world_seed == 0 else BiomeRegistry.ground_tint_at(
			(transforms[i] as Transform3D).origin, world_seed)
	return out


static func is_terrain_skin_asset(asset_id: StringName) -> bool:
	return TERRAIN_SKIN_ASSETS.has(asset_id)


## Convenience for adapters that turn one settlement-local terrain piece into
## a world-space instance. This still delegates to the streamed-cliff batch
## implementation, preserving one biome lookup authority.
static func tint_at(transform: Transform3D, world_seed: int) -> Color:
	return compute_tints([transform], world_seed)[0]

# Rows needed to cover a face of height `dip` (storey-quantised, rounded UP so the wall always
# reaches past the exposed face; the sub-storey overshoot is buried under the neighbour's surface).
static func _ensure_loaded() -> void:
	if not _pieces.is_empty():
		return
	for key in VISUALS:
		_pieces[key] = _piece(VISUALS[key])
	_finish_piece_setup()

static func _finish_piece_setup() -> void:
	# Straight and outer wall modules are authored as vertically tileable: both
	# boundary rings sample the exact same atlas row. The inner wall alone used
	# dark bottom UVs (v≈.671) and bright top UVs (v≈.581), so every 4 m stacked
	# instance exposed a hard light/dark stripe despite matching geometry and
	# normals. Retile only its two boundary rings to the established wall seam
	# row; interior UVs and the sculpted concave profile remain unchanged.
	var seam_v := _vertical_seam_v(_pieces["wall"][0])
	_pieces["inner_wall"][0] = _retile_vertical_seam(
		_pieces["inner_wall"][0], seam_v)
	# The authored lips use five nearby grass texels across their upward faces.
	# They look compatible in the source atlas, but texture-only render probes
	# show that their different values/mips form the bright band photographed at
	# seed 2697992464, cell (43,-50), even with lighting disabled. Remap EVERY
	# lip's entire grass region to one interior texel — the exact one the ground
	# sheet samples (TerrainChunkMesher._ensure_skirt_style). The curved front
	# bevel keeps its authored normals, so lighting still describes the curve
	# without painting a second lawn colour along the walkable top or the triangular
	# flare at a run end.
	var lip_mesh: Mesh = _pieces["lip"][0]
	var larr := lip_mesh.surface_get_arrays(0)
	var lverts: PackedVector3Array = larr[Mesh.ARRAY_VERTEX]
	var lnorms: PackedVector3Array = larr[Mesh.ARRAY_NORMAL]
	var luvs: PackedVector2Array = larr[Mesh.ARRAY_TEX_UV]
	for i in lverts.size():
		if lnorms[i].y > 0.9 and lverts[i].y > -0.05:
			_ground_uv = luvs[i]
			_has_ground_uv = true
			for key in ["lip", "outer_lip", "inner_lip"]:
				_pieces[key][0] = _retexel_grass_region(_pieces[key][0], luvs[i])
			break


static func _vertical_seam_v(mesh: Mesh) -> float:
	if mesh.get_surface_count() != 1:
		return 0.0
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var lo := INF
	var hi := -INF
	for vertex: Vector3 in verts:
		lo = minf(lo, vertex.y)
		hi = maxf(hi, vertex.y)
	var total := 0.0
	var count := 0
	for i in verts.size():
		if absf(verts[i].y - lo) < 0.001 or absf(verts[i].y - hi) < 0.001:
			total += uvs[i].y
			count += 1
	return total / float(count) if count > 0 else 0.0

static func _retile_vertical_seam(mesh: Mesh, seam_v: float) -> Mesh:
	if mesh.get_surface_count() != 1:
		return mesh
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var lo := INF
	var hi := -INF
	for vertex: Vector3 in verts:
		lo = minf(lo, vertex.y)
		hi = maxf(hi, vertex.y)
	for i in verts.size():
		if absf(verts[i].y - lo) < 0.001 or absf(verts[i].y - hi) < 0.001:
			uvs[i].y = seam_v
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	out.surface_set_material(0, mesh.surface_get_material(0))
	return out

# Rebuild a piece mesh with every grass-region texel set to `uv` (the palette's
# grass patches live in the low-uv corner; rock texels are untouched). Restricting
# this to upward normals left the photographed bright triangle on the lip's sloped
# run-end face. Geometry/normals still shade the bevel; its albedo must not change.
# The GLTF meshes are shared resources — work on a copy.
static func _retexel_grass_region(mesh: Mesh, uv: Vector2) -> Mesh:
	if mesh.get_surface_count() != 1:
		return mesh
	var arr := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	for i in uvs.size():
		if uvs[i].x < 0.15 and uvs[i].y < 0.15:
			uvs[i] = uv
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

static func _piece(path: String) -> Array:
	var visual := load(path) as EnvironmentVisual
	assert(visual != null and visual.pieces.size() == 1,
		"cliff visuals must contain exactly one piece: %s" % path)
	var piece := visual.pieces[0]
	return [piece.mesh, piece.local_transform]
