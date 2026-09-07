# scripts/terrain/biome/BiomeChunkFx.gd
# Main-thread render adapter for BiomeAtmosphereField's world-space arrays.
# Fog samples cross chunk edges continuously. Particle anchors follow the exact
# ground/water field; a spirit sprite and its moving light share one parent.
# The profile-only build() helper below is an isolated recipe preview for tests;
# production calls build_field(), never dominant-biome chunk selection.
class_name BiomeChunkFx
extends RefCounted

const CHUNK := 192.0

# Per-recipe particle configuration. Every field has a default in _emitter, so
# entries only list what differs. EVERY recipe renders as a billboard quad
# carrying the shared radial soft-glow texture — additive for glows (no hard
# silhouette at any size; owner: "much more glowy so you cant see a hard
# outline", "tiny 2d squares ... move to the floating orb version"), alpha for
# solid-ish drifters ("soft_alpha": petals). Unknown recipe names warn loudly
# instead of rendering an invisible default emitter.
const RECIPES := {
	&"fireflies": {
		"size": 0.35, "albedo": Color(1.0, 0.85, 0.45, 0.9),
		"emission": Color(1.0, 0.8, 0.4), "emission_energy": 2.5,
		"turbulence": Vector2(0.05, 0.15),
	},
	# Slowly drifting glowing balls of light — the twilight-marsh signature.
	&"orbs": {
		"size": 1.6, "albedo": Color(1.0, 0.75, 0.35, 1.0),
		"emission": Color("ffb347"), "emission_energy": 5.0,
		"amount_per_density": 24.0, "amount_max": 24,
		"lifetime": 22.0,
		"turbulence": Vector2(0.01, 0.04),          # barely-there drift
		"scale": Vector2(0.6, 1.5),                 # size variety between orbs
		"lights": true,
		"light_energy": 1.6, "light_range": 14.0,
	},
	&"petals": {
		"size": 0.35, "albedo": Color(0.95, 0.72, 0.85, 0.9), "soft_alpha": true,
		"gravity": Vector3(0.4, -0.6, 0.2), "velocity": Vector2(0.2, 0.8),
	},
	&"spray": {
		"size": 3.0, "albedo": Color(0.75, 0.90, 0.95, 0.10), "soft_alpha": true,
		"gravity": Vector3(0.03, 0.08, 0.0), "velocity": Vector2(0.03, 0.12),
		"lifetime": 4.0, "scale": Vector2(0.4, 1.2),
	},
	&"leaves": {
		"size": 0.23, "albedo": Color(1.0, 0.53, 0.18, 0.85), "soft_alpha": true,
		"gravity": Vector3(0.12, -0.12, 0.08), "velocity": Vector2(0.05, 0.2),
	},
	&"motes": {
		"size": 0.2, "albedo": Color(1.0, 0.95, 0.8, 0.6),
		"emission": Color(1.0, 0.95, 0.8), "emission_energy": 1.5,
		"turbulence": Vector2(0.02, 0.06),
	},
}

static var _glow_tex: GradientTexture2D = null
static var _petal_tex: ImageTexture = null

# Radial white→transparent falloff: the ONE soft-glow sprite every ambient
# particle uses — no hard silhouette at any size, bloom supplies the halo.
static func glow_texture() -> GradientTexture2D:
	if _glow_tex != null:
		return _glow_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_glow_tex = t
	return _glow_tex

static func petal_texture() -> ImageTexture:
	if _petal_tex != null:
		return _petal_tex
	var pixels := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) / 32.0 * 2.0 - Vector2.ONE
			var radius := Vector2(p.x * 1.7, p.y + 0.15 * p.x).length()
			var alpha := 1.0 - smoothstep(0.68, 0.92, radius)
			pixels.set_pixel(x, y, Color(1, 1, 1, alpha))
	_petal_tex = ImageTexture.create_from_image(pixels)
	return _petal_tex

# Does any of this profile's particle recipes want ground-anchored lights?
# (The streamer asks this before spending region lookups on surface points.)
static func wants_light_points(profile: BiomeProfile) -> bool:
	for recipe: StringName in profile.particles:
		if RECIPES.get(recipe, {}).get("lights", false):
			return true
	return false

# surf_lo/surf_hi: the chunk's walkable-surface height band (chunk-local y) —
# particles hover over the actual ground, fog volumes wrap it.
static func build(profile: BiomeProfile, light_points: Array, surf_lo := 0.0, surf_hi := 12.0) -> Node3D:
	var root := Node3D.new()
	root.name = "BiomeFx"
	if profile.pocket_fog_density > 0.0:
		var fv := FogVolume.new()
		fv.name = "PocketFog"
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(CHUNK, surf_hi - surf_lo + 40.0, CHUNK)
		fv.position = Vector3(CHUNK * 0.5, (surf_lo + surf_hi) * 0.5 + 8.0, CHUNK * 0.5)
		var fm := FogMaterial.new()
		fm.density = profile.pocket_fog_density
		fm.albedo = profile.fog_color
		fv.material = fm
		root.add_child(fv)
	var light_recipe: Dictionary = {}
	for recipe: StringName in profile.particles:
		var e := _emitter(recipe, profile.particles[recipe], surf_lo, surf_hi)
		if e != null:
			root.add_child(e)
		if RECIPES.get(recipe, {}).get("lights", false):
			light_recipe = RECIPES[recipe]
	for p: Vector3 in light_points:
		var l := OmniLight3D.new()
		l.light_color = light_recipe.get("emission", Color("ffb347"))
		l.light_energy = light_recipe.get("light_energy", 1.6)
		l.omni_range = light_recipe.get("light_range", 14.0)
		l.position = p
		root.add_child(l)
	return root

static func _emitter(recipe: StringName, density: float, surf_lo := 0.0, surf_hi := 12.0) -> GPUParticles3D:
	var r: Dictionary = RECIPES.get(recipe, {})
	if r.is_empty():
		push_warning("BiomeChunkFx: unknown particle recipe '%s' (add it to RECIPES)" % recipe)
		return null
	var e := GPUParticles3D.new()
	e.name = String(recipe)
	e.amount = int(clampf(density * r.get("amount_per_density", 48.0),
			r.get("amount_min", 4.0), r.get("amount_max", 96.0)))
	e.lifetime = r.get("lifetime", 8.0)
	# Everything in the NODE's (chunk-local) space, and the visibility AABB a
	# strict superset of the emission band — the old corner-centred world-space
	# box left 3/4 of the particles outside the AABB, so the whole system
	# frustum-culled whenever the in-AABB quadrant left view (owner: "when you
	# walk too close, they disappear").
	e.local_coords = true
	var band_lo := surf_lo + 0.5
	var band_hi := surf_hi + 10.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(CHUNK * 0.5, (band_hi - band_lo) * 0.5, CHUNK * 0.5)
	m.emission_shape_offset = Vector3(CHUNK * 0.5, (band_lo + band_hi) * 0.5, CHUNK * 0.5)
	e.visibility_aabb = AABB(Vector3(0.0, band_lo - 8.0, 0.0),
			Vector3(CHUNK, band_hi - band_lo + 16.0, CHUNK))
	m.gravity = r.get("gravity", Vector3.ZERO)
	var vel: Vector2 = r.get("velocity", Vector2.ZERO)
	m.initial_velocity_min = vel.x
	m.initial_velocity_max = vel.y
	var turb: Vector2 = r.get("turbulence", Vector2.ZERO)
	if turb != Vector2.ZERO:
		m.turbulence_enabled = true
		m.turbulence_influence_min = turb.x
		m.turbulence_influence_max = turb.y
	var scl: Vector2 = r.get("scale", Vector2.ONE)
	m.scale_min = scl.x
	m.scale_max = scl.y
	# One soft radial sprite for every recipe: additive glows melt into the
	# scene with no silhouette; petals keep plain alpha (a solid soft puff).
	var mat := StandardMaterial3D.new()
	var size: float = r.get("size", 0.25)
	mat.albedo_color = r.get("albedo", Color.WHITE)
	mat.albedo_texture = petal_texture() if recipe == &"petals" or recipe == &"leaves" else glow_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not r.get("soft_alpha", false):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if r.has("emission"):
		mat.emission_texture = glow_texture()
		mat.emission_enabled = true
		mat.emission = r["emission"]
		mat.emission_energy_multiplier = r.get("emission_energy", 2.0)
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = mat
	if recipe == &"petals" or recipe == &"leaves":
		m.angle_min = -180.0
		m.angle_max = 180.0
		m.angular_velocity_min = -35.0
		m.angular_velocity_max = 35.0
	e.process_material = m
	e.draw_pass_1 = qm
	return e

# Production uses this spatial payload; the profile-only builder above remains
# available for isolated recipe/asset previews.
static func build_field(data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BiomeFx"
	var fog_image := Image.create_empty(13, 13, false, Image.FORMAT_RGBAF)
	var ground_image := Image.create_empty(13, 13, false, Image.FORMAT_RF)
	var density_max := 0.0
	for i in 169:
		var c: Color = data.fog[i]
		fog_image.set_pixel(i % 13, i / 13, c)
		ground_image.set_pixel(i % 13, i / 13, Color(data.ground[i], 0, 0))
		density_max = maxf(density_max, c.a)
	if density_max > 0.0001:
		var volume := FogVolume.new()
		volume.name = "WorldMist"
		volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		volume.size = Vector3(CHUNK, data.hi - data.lo + 160.0, CHUNK)
		volume.position = Vector3(CHUNK * 0.5, (data.lo + data.hi) * 0.5 + 60.0, CHUNK * 0.5)
		var material := ShaderMaterial.new()
		material.shader = load("res://terrain/materials/biome_mist.gdshader")
		material.set_shader_parameter("atmosphere_field", ImageTexture.create_from_image(fog_image))
		material.set_shader_parameter("ground_field", ImageTexture.create_from_image(ground_image))
		material.set_shader_parameter("chunk_origin", Vector2(data.origin.x, data.origin.z))
		volume.material = material
		root.add_child(volume)
	for recipe: StringName in data.points:
		var points: PackedVector3Array = data.points[recipe]
		if points.is_empty():
			continue
		var emitter := _emitter(recipe, 1.0, data.lo, data.hi)
		emitter.amount = clampi(points.size() * 5, 8, 240)
		emitter.preprocess = 5.0
		emitter.fixed_fps = 30
		var process := emitter.process_material as ParticleProcessMaterial
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
		process.emission_shape_offset = Vector3.ZERO
		process.emission_point_count = points.size()
		var positions := Image.create_empty(points.size(), 1, false, Image.FORMAT_RGBF)
		for i in points.size():
			positions.set_pixel(i, 0, Color(points[i].x, points[i].y, points[i].z))
		process.emission_point_texture = ImageTexture.create_from_image(positions)
		root.add_child(emitter)
	for point: Vector3 in data.orbs:
		var orb := SpiritOrb.new()
		orb.name = "SpiritOrb"
		orb.anchor = point
		orb.position = point
		orb.phase = fposmod(point.x * 0.37 + point.z * 0.71, TAU)
		var sprite := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(2.2, 2.2)
		var material := ShaderMaterial.new()
		material.shader = load("res://terrain/materials/spirit_orb.gdshader")
		material.set_shader_parameter("phase", orb.phase)
		var color := Color("80e8df").lerp(Color("ffce83"), (sin(orb.phase) + 1.0) * 0.5)
		material.set_shader_parameter("glow_color", color)
		mesh.material = material
		sprite.mesh = mesh
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.add_child(sprite)
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.8
		light.omni_range = 8.0
		light.light_volumetric_fog_energy = 0.45
		light.distance_fade_enabled = true
		light.distance_fade_begin = 65.0
		light.distance_fade_length = 25.0
		orb.add_child(light)
		root.add_child(orb)
	return root
