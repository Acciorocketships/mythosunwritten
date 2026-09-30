extends RefCounted
## Review probe (September 27): envelope inputs and components along the
## owner's view line (player -> crosshair, extended), in the settled world.
func run(review:Node3D)->void:
 var view:Dictionary=review._views[0]
 var player:Vector3=view.player
 for v:Dictionary in review._views:
  if v.has("player"):player=v.player
 var input:Dictionary=review._inputs[FieldTerrainStreamer.chunk_of(player)]
 var area:=Rect2(Vector2(player.x,player.z)-Vector2(30,30),Vector2(60,60))
 var field=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,input.region,area,input.features,input.water)
 # <output>/probe_source may name another revision of the envelope source.
 var alt:=FileAccess.get_file_as_string(review._output_dir+"/probe_source").strip_edges()
 var source:=FileAccess.get_file_as_string(alt) if not alt.is_empty() else load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").source_code as String
 source=source.replace("var uncut:=env.surface.duplicate()","env.set_meta(\"wet\",wet_level)\n env.set_meta(\"caps\",caps)\n var uncut:=env.surface.duplicate()\n env.set_meta(\"uncut\",uncut)")
 source=source.replace(" var t:=_ridges(env,narrow,wide,wide_dilated,seed_value)\n"," var t:=_ridges(env,narrow,wide,wide_dilated,seed_value)\n env.set_meta(\"t\",t);env.set_meta(\"relief\",relief)\n")
 var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK)
 var env=script.build(area,field._ground_sampler(),field._exclusion(area.grow(33)),2697992464,field._water_level())
 var dir:=Vector2(float(review.get_meta("probe_dir_x",-1.0)),float(review.get_meta("probe_dir_z",0.0))).normalized()
 var node:=func(q:Vector2)->int:return clampi(roundi((q.y-env.origin.y)/.5),0,env.h-1)*env.w+clampi(roundi((q.x-env.origin.x)/.5),0,env.w-1)
 var lines:=[]
 for side in [-4.0,0.0,4.0]:
  lines.append("-- lateral %.0f dir %s"%[side,dir])
  for s in range(-20,21):
   var q:Vector2=Vector2(player.x,player.z)+Vector2(-dir.y,dir.x)*side+dir*s;var i:int=node.call(q)
   lines.append("%+3d %s ground %6.2f uncut %6.2f surf %6.2f caps %6.2f wet %6.2f t %.2f relief %5.2f rock %.2f"%[s,q,env.ground[i],(env.get_meta("uncut") as PackedFloat64Array)[i],env.surface[i],(env.get_meta("caps") as PackedFloat64Array)[i],(env.get_meta("wet") as PackedFloat64Array)[i] if (env.get_meta("wet") as PackedFloat64Array).size()>0 else NAN,(env.get_meta("t") as PackedFloat64Array)[i],(env.get_meta("relief") as PackedFloat64Array)[i],env.rock_at(q)])
 FileAccess.open(review._output_dir+"/line-profile%s.txt"%("-alt" if not alt.is_empty() else ""),FileAccess.WRITE).store_string("\n".join(lines))
 print("[line_probe] wrote ",lines.size())
