extends SceneTree
## Offline vocabulary export for validated native-scale grammar families.
const Cross = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")
const Foundation = preload(
	"res://scripts/terrain/features/villages/grammar/PureVillageCrossFoundation.gd"
)
const Street = preload("res://scripts/terrain/features/villages/grammar/PureVillageStreetHouse.gd")
const Stone = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeHouse.gd")
var reflected_modules: Dictionary = {}
const OUTPUT := "res://tools/environment_bake/manifests/pure_village_native_grammar.json"


func _init() -> void:
	var modules: Dictionary = {}
	for length in [1, 2, 3]:
		for seed_value in range(16):
			var cross := Cross.derive(length, length, Cross.sample(seed_value, length, length))
			_collect(modules, Cross.gable_details(cross))
			_collect(modules, Foundation.derive(cross, length, length, 2.0))
			cross.append_array(Foundation.derive(cross, length, length))
			_collect(modules, cross)
			_collect(modules, Cross.derive(length, length))
			if length >= 2:
				_collect(modules, Street.derive(length, Street.sample(seed_value, length)))
			_collect(modules, Stone.derive(length))
	# Native stone openings are an explicit compatible vocabulary, independent
	# of which seeded samples happen to choose them in the export corpus.
	for module: String in Stone.OPENINGS.values():
		modules[module] = true
	for module: String in Street.FACADE_WINDOWS + Street.FACADE_PROJECTIONS:
		modules[module] = true
	var names: Array = modules.keys()
	names.sort()
	var assets: Array[Dictionary] = []
	for module: String in names:
		assets.append(
			{
				"id": "pure_village.native." + module.to_lower(),
				"source": "res://assets/PureVillage/Models/Architecture/" + module + ".glb",
				"pivot": [0, 0, 0],
				"merge_pieces": true,
				"tags": ["village", "pure_village_native_grammar", "building"],
				"tint_group": "identity",
				"supports_instance_color": true,
				"max_mesh_bytes": 8388608,
				"max_visual_triangles": 40000,
				"max_surfaces": 20,
				"collision_profile": "building_trimesh",
				"max_collision_triangles": 40000,
				"max_collision_pieces": 1
			}
		)
	var reflected_assets: Array[Dictionary] = []
	for entry in assets:
		if not reflected_modules.has(String(entry.id).trim_prefix("pure_village.native.")):
			continue
		var reflected := entry.duplicate(true)
		reflected.id += ".mirror_x"
		reflected.mirror_axis = "x"
		reflected_assets.append(reflected)
	assets.append_array(reflected_assets)
	var manifest := {
		"pack": "pure_village_native_grammar",
		"license": "Unity Asset Store Standard EULA (BK Pure Village)",
		"default_scale": [1, 1, 1],
		"assets": assets,
		"texture_policy":
		{"compression": "basis_universal", "mipmaps": true, "namespace": "pure_village_kit"}
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	print("Exported %d native modules" % assets.size())
	quit()


func _collect(modules: Dictionary, parts: Array[Dictionary]) -> void:
	for part in parts:
		modules[part.module] = true
		if part.transform.basis.determinant() < 0:
			reflected_modules[String(part.module).to_lower()] = true
