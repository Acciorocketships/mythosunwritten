extends SceneTree
const OUT:="res://docs/qa/2026-09-19-manual/115-hillside-fill-stages/"
func _initialize() -> void:
	var profiles:Array=FileAccess.open(OUT+"profiles.bin",FileAccess.READ).get_var()
	var output:Array[Dictionary]=[]
	for p:Vector2 in [Vector2(-1122,-624),Vector2(-1128,-624),Vector2(-1122,-618),Vector2(-1125.81225585938,-623.416259765625)]:
		var claims:Array[Dictionary]=[]
		for r:Dictionary in profiles:
			var consumed:Dictionary={}
			for d:Dictionary in r.profile.descents:
				for i in range(d.lo,d.hi):consumed[i]=true
				for i in d.pos.size()-1:offer(claims,p,r.source,i,true,d.pos[i],d.pos[i+1],d.w[i],d.w[i+1],d.lvl[i],d.lvl[i+1])
			for i in r.points.size()-1:
				if not consumed.has(i):offer(claims,p,r.source,i,false,r.points[i],r.points[i+1],r.widths[i],r.widths[i+1],r.profile.levels[i],r.profile.levels[i+1])
		claims.sort_custom(func(a,b):return a.margin<b.margin if absf(a.margin-b.margin)>.0001 else a.level<b.level)
		output.append({"point":[p.x,p.y],"claims":claims.slice(0,12)})
	FileAccess.open(OUT+"mouth-claims.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	quit()
func offer(claims:Array[Dictionary],p:Vector2,source:Vector2i,i:int,dense:bool,a:Vector2,b:Vector2,wa:float,wb:float,ha:float,hb:float)->void:
	var ab:=b-a;var t:=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.000001),0,1)
	var w:=lerpf(wa,wb,t);var distance:=p.distance_to(a+ab*t)
	if distance>w:return
	claims.append({"source":str(source),"station":i,"dense":dense,"a":[a.x,a.y],"b":[b.x,b.y],"t":t,"width":w,"distance":distance,"margin":distance-w,"level":lerpf(ha,hb,t)})
