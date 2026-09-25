extends SceneTree
func _init()->void:call_deferred("_run")
func _run()->void:
 var fixture=load("res://tests/test_september16_cliff_grass.gd").new()
 var f:Dictionary=fixture._fixture();fixture.free()
 var old:GDScript=load("res://tests/fixtures/september17/cliff-curved-treads/grass-field-before.gd")
 var linear:GDScript=load("res://tests/fixtures/september17/cliff-curved-treads/grass-field-unindexed.gd")
 var indexed:GDScript=load("res://scripts/terrain/grass/GrassField.gd")
 var baseline:Array=[];var checked:=0
 for repeat_index in 3:
  var times:Array=[]
  for generator:GDScript in [old,linear,indexed]:
   var start:=Time.get_ticks_msec()
   for z in 3:
    var payload:GrassPayload=generator.compute(f.program,99,Vector2i(3,z),f.region,f.water,null,f.data.grass_supports)
    if generator==linear:
     if repeat_index==0:baseline.append(var_to_bytes(payload.batches))
     else:assert(baseline[z]==var_to_bytes(payload.batches))
    if generator==indexed:
     assert(baseline[z]==var_to_bytes(payload.batches));checked+=1
   times.append(Time.get_ticks_msec()-start)
  print("SUPPORT_INDEX_COST repeat=",repeat_index," old_linear_indexed_ms=",times)
 print("SUPPORT_INDEX identical_full_tile_buffers=",checked)
 quit()
