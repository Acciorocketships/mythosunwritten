extends "res://tests/harness/frame_feel_profile.gd"
## Matched diagnostic only: alter the loaded script in memory before the world
## exists. Production source/defaults remain intact.
func _ready()->void:
	var path:="res://scripts/terrain/water/WaterSkin.gd"
	var script:GDScript=load(path)
	var source:=FileAccess.get_file_as_string(path)
	var call:="\tSURFACE_REFINEMENT.refine(st, func(p: Vector2) -> float: return WaterField.level_at(ctx, p))"
	assert(source.count(call)==1,"the ablation must remove exactly the production refinement call")
	script.source_code=source.replace(call,"\t# Surface refinement disabled for this matched diagnostic.")
	if script.reload(true)!=OK:
		push_error("Could not load water refinement ablation")
		get_tree().quit(1)
		return
	print("WATER_SURFACE_REFINEMENT_ABLATION disabled in memory")
	super._ready()
