extends SceneTree
func _init()->void:
 load("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock")
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var env=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").build(Rect2(476,924,92,96),ground,func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0,2697992464,func(q:Vector2)->float:return d.wet[index.call(q)])
 var old:=GDScript.new();old.source_code=FileAccess.get_file_as_string("res://docs/qa/2026-09-26-p03-crown-colour/baseline-field.gd.txt");assert(old.reload()==OK)
 var before=old.new([],2697992464);before._env=env;before.ground_at=ground
 var after=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464);after._env=env;after.ground_at=ground
 var a:Dictionary=before.solid(Rect2(478,926,86,86))[0]
 var b:Dictionary=after.solid(Rect2(478,926,86,86))[0]
 var identical:bool=a.faces==b.faces
 var differences:=0
 for p:Vector3 in a.native_roots:
  if a.native_roots[p][0].distance_to(b.native_roots[p][0])>.001:differences+=1
 var result:={"triangles":a.faces.size()/3,"geometry_identical":identical,"vertices_with_changed_normals":differences}
 FileAccess.open("res://docs/qa/2026-09-26-p03-crown-colour/geometry-identity.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[geometry_identity] ",result);assert(identical);assert(differences>100);quit()
