extends "res://tests/harness/pure_village_lineup.gd"
## Inspect native relief before selecting a fortification vocabulary.
const DETAILS := ["StoneArch_1", "StoneArch_2", "StoneArch_3", "StoneArch_4",
	"SupportStone_Start_20x15", "SupportStone_Corner_30x15",
	"Window_14_1", "Window_18_3", "Balcony_4"]

func _run() -> void:
	get_root().size = Vector2i(1400,900)
	for file: String in DETAILS:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var part := (load(R+"Architecture/"+file+".glb") as PackedScene).instantiate()
		stage.add_child(part)
		var box := _aabb(part)
		print("DETAIL %s %s" % [file,box])
		var target := box.get_center()
		var reach := maxf(box.size.x,maxf(box.size.y,box.size.z))*1.8
		await _shoot(stage,target+Vector3(reach*0.4,reach*0.2,reach),target,file)
		stage.queue_free()
		await process_frame
	quit()
