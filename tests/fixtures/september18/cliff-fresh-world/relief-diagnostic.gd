extends SceneTree
const SOURCE=preload("res://tests/fixtures/september18/cliff-fresh-world/relief-diagnostic-source.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var a:Array=anchors[20]
 SOURCE.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])
 for height:float in [32,64]:SOURCE.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)
 FileAccess.open("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/relief-diagnostics.json",FileAccess.WRITE).store_string(JSON.stringify(SOURCE.diagnostics,"  "))
 print("RELIEF_DIAGNOSTICS ",SOURCE.diagnostics)
 quit()
