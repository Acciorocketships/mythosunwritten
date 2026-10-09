extends SceneTree
class Flat:
	extends WaterSampler
	func _current_surface_level_at(_p:Vector2)->float:return 2.0
class OldFlat:
	extends Flat
	func _surface_frame(xz:Vector2)->PackedVector2Array:
		var key:=Vector2i((xz/FRAME_CELL).round())
		var frame:Variant=_frames.get(key)
		if frame==null:
			frame=WaterCurrentField.sample_surface_frame(Vector2(key)*FRAME_CELL,_current_surface_level_at)
			if _frames.size()>=FRAME_CACHE_CAP:_frames.clear()
			_frames[key]=frame
		return frame
func _init()->void:_run.call_deferred()
func _run()->void:
	for old in [true,false,true,false]:
		var sampler:WaterSampler=OldFlat.new() if old else Flat.new()
		for i in WaterSampler.FRAME_CACHE_CAP:
			sampler._surface_frame(Vector2(i,0)*WaterSampler.FRAME_CELL)
		var start:=Time.get_ticks_usec()
		var result:=sampler._surface_frame(Vector2(-1,0))
		print("FRAME_CACHE_COST ",JSON.stringify({"old":old,"miss_usec":Time.get_ticks_usec()-start,"retained":sampler._frames.size(),"result":str(result)}))
	quit()
