extends RefCounted
## Immersion is a property of the complete rendered water field. A missing
## swim trigger means a fall cannot provide buoyancy; it does not mean air.
static func sample(owners:Array[Node],point:Vector3)->Dictionary:
 var best:={}
 var highest:=-INF
 var xz:=Vector2(point.x,point.z)
 for owner:Node in owners:
  if not owner.has_meta("sampler"):continue
  var sampler:WaterSampler=owner.get_meta("sampler")
  if sampler==null:continue
  var level:=sampler.level_at(xz)
  if not is_finite(level) or level<=highest:continue
  highest=level
  best={"level":level,"depth":level-point.y,"sampler":sampler}
 return best
