extends RefCounted

# Review candidate: admit grade targets as complete ordinary terrain controls,
# then use unchanged natural slope/cliff classification and native tile joins.
static func region(source: HeightfieldRegion) -> HeightfieldRegion:
	var result := HeightfieldRegion.new(source._storeys.duplicate(),source._levels.duplicate(),source._carved.duplicate())
	for key: Vector2i in source._levels:
		var point := Vector2(key)*24.0
		var height := source.surface_height(key.x,key.y)
		for grade: TerrainGradePatch in source.terrain_grades:
			height=grade.surface_y(point,height)
		height=roundf(height)
		result._storeys[key] = floori(height/4.0)
		result._levels[key] = int(height)%4
	# Every claimed footprint owns its full ordinary interpolation stencil.
	# Otherwise a pad close to an edge still sags towards an unedited control.
	var requests: Array = []
	var owners: Dictionary = {}
	for grade: TerrainGradePatch in source.terrain_grades:
		for fine: Vector2i in grade._claims:
			var point := grade._origin+Vector2(fine)*grade._targets.pitch
			var radius := grade._targets.pitch*.5
			var own_lo := Vector2i(floori((point.x-radius)/24+.5),floori((point.y-radius)/24+.5))
			var own_hi := Vector2i(floori((point.x+radius)/24+.5),floori((point.y+radius)/24+.5))
			for z in range(own_lo.y,own_hi.y+1):
				for x in range(own_lo.x,own_hi.x+1):
					var key := Vector2i(x,z)
					owners[key]=minf(owners.get(key,INF),roundf(grade._claims[fine]))
			var lo := Vector2i(floori((point.x-radius)/24),floori((point.y-radius)/24))
			var hi := Vector2i(ceili((point.x+radius)/24),ceili((point.y+radius)/24))
			requests.append([point,radius,lo,hi,roundf(grade._claims[fine])])
	for key: Vector2i in owners:
		if not result._levels.has(key): continue
		var height := float(owners[key])
		result._storeys[key]=floori(height/4)
		result._levels[key]=int(height)%4
	# Only a genuinely sloping pad needs lower neighbouring controls lifted.
	# A normal flat cliff already supports its whole footprint; keep its drop.
	for iteration in result._levels.size()+1:
		var changed := false
		for request: Array in requests:
			var unsupported := false
			for offset: Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
				var point: Vector2=request[0]+offset*request[1]*.999
				if TerrainTileField.surface_y(result,point.x,point.y)<request[4]-.00001:
					unsupported=true
			if not unsupported: continue
			for z in range(request[2].y,request[3].y+1):
				for x in range(request[2].x,request[3].x+1):
					var key:=Vector2i(x,z)
					if not result._levels.has(key) or owners.has(key): continue
					if result.surface_height(x,z)>=request[4]: continue
					result._storeys[key]=floori(request[4]/4)
					result._levels[key]=int(request[4])%4
					changed=true
		if not changed: break
	return result
