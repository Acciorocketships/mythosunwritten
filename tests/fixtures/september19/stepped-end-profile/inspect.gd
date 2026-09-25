extends SceneTree
func _init()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/104-three-way-surface/raster/before-forms.bin",FileAccess.READ).get_var()
 print(preload("res://tests/fixtures/september19/stepped-end-profile/join.gd").apply(forms))
 quit()
