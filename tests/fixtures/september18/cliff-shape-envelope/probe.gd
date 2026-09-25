extends SceneTree
const SOURCE=preload("res://tests/fixtures/september18/cliff-shape-envelope/audit.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var rows:Array=[]
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var a:Array=anchors[20]
 for item:Array in [["photo",a[0],a[1],a[2]],["tall",Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,32]]:
  var form:Dictionary=SOURCE.make(item[1],item[2],item[3],2697992464)[0]
  var bins:Array=[]
  for band in 4:
   var samples:=0;var clamped:=0;var worst:=0.0;var mean:=0.0
   for row:Array in form.envelope_audit:
    if row[1]<item[3]*band/4.0 or row[1]>=item[3]*(band+1)/4.0:continue
    samples+=1
    if row[5]>0.0:clamped+=1;mean+=row[5];worst=maxf(worst,row[5])
   bins.append({"band_from_ground":band,"samples":samples,"clamped":clamped,"fraction":float(clamped)/maxi(1,samples),"mean_removed":mean/maxi(1,clamped),"max_removed":worst})
  print(item[0]," ",JSON.stringify(bins))
  rows.append({"fixture":item[0],"bins":bins})
 FileAccess.open("res://docs/qa/2026-09-18-manual/77-cliff-shape-envelope/envelope.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 quit()
