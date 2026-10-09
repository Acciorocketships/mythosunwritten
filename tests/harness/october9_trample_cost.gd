extends SceneTree
func stamps_at(chunk:Vector2i)->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	for z in 20:
		for x in 20:
			var p:=Vector2(chunk)*192+Vector2(x,z)*9.6
			out.append({"position":Vector3(p.x,0,p.y),"points":PackedVector2Array([p+Vector2(-2,-1),p+Vector2(2,-1),p+Vector2(2,1),p+Vector2(-2,1)])})
	return out
func _init()->void:
	var field:=TrampleField.new()
	field._initialize(Vector2.ZERO)
	var chunks:Dictionary={}
	for x in range(-2,3):
		for z in range(-2,3):chunks[Vector2i(x,z)]=stamps_at(Vector2i(x,z))
	var initial:=Time.get_ticks_usec()
	_publish(field,chunks,chunks)
	print("TRAMPLE initial_us=",Time.get_ticks_usec()-initial," pixels=",hash(field._static_image.get_data()))
	var costs:Array[int]=[]
	for i in 25:
		var key:=Vector2i(2,2)
		chunks[key]=stamps_at(key)
		var t:=Time.get_ticks_usec()
		_publish(field,chunks,{key:chunks[key]})
		costs.append(Time.get_ticks_usec()-t)
	costs.sort()
	print("TRAMPLE far_change_p50_us=",costs[12]," max_us=",costs[-1]," pixels=",hash(field._static_image.get_data()))
	field._now=60
	var t:=Time.get_ticks_usec();field._update_time(0)
	print("TRAMPLE epoch_us=",Time.get_ticks_usec()-t)
	field.free();quit()
func _publish(field:TrampleField,chunks:Dictionary,changes:Dictionary)->void:
	if field.has_method("update_static_chunks"):
		field.call("update_static_chunks",changes)
	else:
		var flat:Array[Dictionary]=[]
		for values:Array in chunks.values():flat.append_array(values)
		field.set_static_stamps(flat)
