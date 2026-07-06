# scripts/terrain/biome/BiomeChunkFx.gd
# Render-only per-chunk children: pocket FogVolume + particle emitters from the
# dominant biome profile + glowing orb lights. Built by the streamer (never in
# headless); freed with the chunk. Internal positions are chunk-local (0..CHUNK);
# the streamer positions this node at the chunk's world origin. Spec §3 + §5.
class_name BiomeChunkFx
extends RefCounted

const CHUNK := 192.0

static func build(profile: BiomeProfile, orb_light_points: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "BiomeFx"
	if profile.pocket_fog_density > 0.0:
		var fv := FogVolume.new()
		fv.name = "PocketFog"
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(CHUNK, 40.0, CHUNK)
		fv.position = Vector3(CHUNK * 0.5, 16.0, CHUNK * 0.5)
		var fm := FogMaterial.new()
		fm.density = profile.pocket_fog_density
		fm.albedo = profile.fog_color
		fv.material = fm
		root.add_child(fv)
	for recipe: StringName in profile.particles:
		root.add_child(_emitter(recipe, profile.particles[recipe]))
	for p: Vector3 in orb_light_points:
		var l := OmniLight3D.new()
		l.light_color = Color("ffb347")
		l.light_energy = 1.6
		l.omni_range = 14.0
		l.position = p
		root.add_child(l)
	return root

static func _emitter(recipe: StringName, density: float) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.name = String(recipe)
	e.amount = int(clampf(density * 48.0, 4.0, 96.0))
	e.lifetime = 8.0
	e.visibility_aabb = AABB(Vector3(0, -8, 0), Vector3(CHUNK, 48, CHUNK))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(CHUNK * 0.5, 12.0, CHUNK * 0.5)
	m.gravity = Vector3.ZERO
	var mesh := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match recipe:
		&"fireflies":
			mesh.size = Vector2(0.25, 0.25)
			mat.albedo_color = Color(1.0, 0.85, 0.45, 0.9)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.4)
			mat.emission_energy_multiplier = 2.5
			m.turbulence_enabled = true
			m.turbulence_influence_min = 0.05
			m.turbulence_influence_max = 0.15
		&"orbs":
			mesh.size = Vector2(1.2, 1.2)
			mat.albedo_color = Color(1.0, 0.7, 0.28, 0.85)
			mat.emission_enabled = true
			mat.emission = Color("ffb347")
			mat.emission_energy_multiplier = 3.5
			e.lifetime = 14.0
			m.turbulence_enabled = true
			m.turbulence_influence_min = 0.02
			m.turbulence_influence_max = 0.08
		&"petals":
			mesh.size = Vector2(0.35, 0.35)
			mat.albedo_color = Color(0.95, 0.72, 0.85, 0.9)
			m.gravity = Vector3(0.4, -0.6, 0.2)
			m.initial_velocity_min = 0.2
			m.initial_velocity_max = 0.8
		&"motes":
			mesh.size = Vector2(0.12, 0.12)
			mat.albedo_color = Color(1.0, 0.95, 0.8, 0.35)
			m.turbulence_enabled = true
			m.turbulence_influence_min = 0.02
			m.turbulence_influence_max = 0.06
	mesh.material = mat
	e.process_material = m
	e.draw_pass_1 = mesh
	e.position = Vector3.ZERO
	return e
