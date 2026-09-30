extends RefCounted
## Review probe (September 27, owner issue D): profiles the envelope inputs
## along the dead-end path and freezes its native inputs as a fixture.
func run(review:Node3D)->void:
 var view:Dictionary=review._views[0]
 var player:Vector3=view.player
 var chunk:=FieldTerrainStreamer.chunk_of(player)
 var input:Dictionary=review._inputs[chunk]
 var area:=Rect2(Vector2(player.x,player.z)-Vector2(30,30),Vector2(60,60))
 var field=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,input.region,area,input.features,input.water)
 var source:=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").source_code as String
 source=source.replace("var uncut:=env.surface.duplicate()","env.set_meta(\"wet\",wet_level)\n env.set_meta(\"excluded\",excluded)\n env.set_meta(\"caps\",caps)\n var uncut:=env.surface.duplicate()\n env.set_meta(\"uncut\",uncut)")
 var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK)
 var env=script.build(area,field._ground_sampler(),field._exclusion(area.grow(33)),2697992464,field._water_level())
 var region:HeightfieldRegion=input.region
 var node:=func(q:Vector2)->int:return clampi(roundi((q.y-env.origin.y)/.5),0,env.h-1)*env.w+clampi(roundi((q.x-env.origin.x)/.5),0,env.w-1)
 var lines:=[]
 for z in [player.z-4.0,player.z,player.z+4.0]:
  for x in range(int(player.x)+6,int(player.x)-30,-1):
   var q:=Vector2(x,z);var i:int=node.call(q)
   var cx:=TerrainSurfaceField._cell_of(q.x,region);var cz:=TerrainSurfaceField._cell_of(q.y,region)
   var kind:int=input.features.ground_field().surface_sampler_in(Rect2(q-Vector2.ONE,Vector2.ONE*2)).call(q) if input.features.has_modified_surface() else -1
   lines.append("x %6.1f z %6.1f ground %6.2f uncut %6.2f surf %6.2f caps %6.2f excl %d kind %d storey %d level %d rock %.2f"%[q.x,q.y,env.ground[i],(env.get_meta("uncut") as PackedFloat64Array)[i],env.surface[i],(env.get_meta("caps") as PackedFloat64Array)[i],(env.get_meta("excluded") as PackedByteArray)[i],kind,region.storey_at(cx,cz),region.level_at(cx,cz),env.rock_at(q)])
 FileAccess.open(review._output_dir+"/dead-end-profile.txt",FileAccess.WRITE).store_string("\n".join(lines))
 var data:={"origin":env.origin,"w":env.w,"h":env.h,"ground":env.ground,"surface":env.surface,"wet":env.get_meta("wet"),"excluded":env.get_meta("excluded"),"area":area}
 FileAccess.open(review._output_dir+"/native-inputs.var",FileAccess.WRITE).store_var(data)
 print("[dead_end_probe] wrote ",lines.size())
