extends SceneTree
## Synthetic metric study (September 27): a straight tall wall at an angle
## to the grid, a one-storey step and a road crossing a step, measured for
## any number of envelope source files.
##   Godot --headless --path . -s res://tests/harness/cliff_slope_synthetic_metrics.gd -- FILE [FILE...]
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func _initialize()->void:_run.call_deferred()
static func wall_metrics(script,angle:float,height:float)->Dictionary:
 var n:=Vector2(cos(angle),sin(angle));var t:=Vector2(-n.y,n.x)
 var ground:=func(q:Vector2)->float:return height if q.dot(n)<0.0 else 0.0
 var area:=Rect2(-40,-40,80,80)
 STYLE.apply("sheet");var smooth=script.build(area,ground,Callable(),2697992464)
 STYLE.apply("sheet_bedrock");var rock=script.build(area,ground,Callable(),2697992464)
 var d2s:=[];var rises:=0;var max_rise:=0.0;var rocky:=0;var carved:=0
 for x in range(-60,61):
  for z in range(-60,61):
   var q:=Vector2(x,z)*.5
   if rock.rock_at(q)>.3:rocky+=1
   if absf(rock.at(q)-smooth.at(q))<.05:continue
   carved+=1
   d2s.append(absf(rock.sample(q+t*.5)-2.0*rock.sample(q)+rock.sample(q-t*.5)))
   var r:float=rock.sample(q+n*1.0)-rock.sample(q)
   if r>.1:rises+=1
   max_rise=maxf(max_rise,r)
 d2s.sort()
 return {"rock":rocky,"carved":carved,"rises":rises,"max_rise":snappedf(max_rise,.01),"d2_p90":snappedf(d2s[int(d2s.size()*.9)] if d2s.size() else 0.0,.001),"d2_p99":snappedf(d2s[int(d2s.size()*.99)] if d2s.size() else 0.0,.001),"d2_max":snappedf(d2s[-1] if d2s.size() else 0.0,.01),"d2_over_half":d2s.filter(func(v):return v>.5).size()}
static func step_metrics(script,height:float)->Dictionary:
 var ground:=func(q:Vector2)->float:return height if q.y<0.0 else 0.0
 STYLE.apply("sheet_bedrock");var env=script.build(Rect2(-40,-16,80,32),ground,Callable(),2697992464)
 var spread:=0.0;var rock:=0.0
 for z in range(-24,25):
  var lo:=INF;var hi:=-INF
  for x in range(-60,61):
   var y:float=env.at(Vector2(x*.5,z*.5));lo=minf(lo,y);hi=maxf(hi,y);rock=maxf(rock,env.rock_at(Vector2(x*.5,z*.5)))
  spread=maxf(spread,hi-lo)
 return {"along_spread":snappedf(spread,.001),"max_rock":snappedf(rock,.01)}
static func p03_metrics(script)->Dictionary:
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var water:=func(q:Vector2)->float:return d.wet[index.call(q)]
 var excluded:=func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0
 var area:=Rect2(476,924,92,96)
 STYLE.apply("sheet");var smooth=script.build(area,ground,excluded,2697992464,water)
 STYLE.apply("sheet_bedrock");var rock=script.build(area,ground,excluded,2697992464,water)
 var treads:=0;var patches:={};var dev:=[];var rises:=0;var d2over:=0
 for x in range(960,1113):
  for z in range(1856,2017):
   var q:=Vector2(x,z)*.5
   var dx:=Vector2(.5,0);var dz:=Vector2(0,.5)
   var backing:=Vector2(smooth.at(q+dx)-smooth.at(q-dx),smooth.at(q+dz)-smooth.at(q-dz))
   var face:=Vector2(rock.at(q+dx)-rock.at(q-dx),rock.at(q+dz)-rock.at(q-dz))
   if absf(rock.at(q)-smooth.at(q))>.05 and backing.length()>.2:
    var fall:=-backing.normalized();var t:=Vector2(-fall.y,fall.x)
    if rock.sample(q+fall)-rock.sample(q)>.1:rises+=1
    if absf(rock.sample(q+t*.5)-2.0*rock.sample(q)+rock.sample(q-t*.5))>.5:d2over+=1
   if rock.rock_at(q)<.6:continue
   if backing.length()>.6 and backing.length()<1.6 and face.length()>backing.length()*1.1:
    var a:=Vector3(-backing.x,1,-backing.y).normalized();var b:=Vector3(-face.x,1,-face.y).normalized()
    dev.append(rad_to_deg(acos(clampf(a.dot(b),-1,1))))
   if backing.length()<=.6 or face.length()>=.35 or rock.at(q)-smooth.at(q)<=.35:continue
   if absf(rock.sample(q+backing.normalized()*.5)-rock.sample(q-backing.normalized()*.5))>=.3:continue
   treads+=1;patches[Vector2i(q/8.0)]=true
 dev.sort()
 return {"treads":treads,"patches":patches.size(),"normal_median":snappedf(dev[dev.size()/2],.01) if dev.size() else -1.0,"normal_p90":snappedf(dev[int(dev.size()*.9)],.01) if dev.size() else -1.0,"faces":dev.size(),"rises":rises,"d2_over_half":d2over}

func _run()->void:
 for path:String in OS.get_cmdline_user_args():
  var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path);assert(script.reload()==OK)
  print("[synthetic] ",path.get_file())
  if OS.has_environment("WALLS_ONLY"):
   for a:float in [.52,.785]:print("  wall20 angle %.2f %s"%[a,JSON.stringify(wall_metrics(script,a,20.0))])
   continue
  for a:float in [0.0,.52,.785]:print("  wall20 angle %.2f %s"%[a,JSON.stringify(wall_metrics(script,a,20.0))])
  print("  wall12 angle .52 %s"%JSON.stringify(wall_metrics(script,.52,12.0)))
  for h:float in [4.0,8.0]:print("  step %.0f %s"%[h,JSON.stringify(step_metrics(script,h))])
  print("  p03 %s"%JSON.stringify(p03_metrics(script)))
 quit()
