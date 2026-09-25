extends RefCounted

## Finite native compact junction admission from complete exposed roof plates.
## Runtime realization consumes these owned pairs; it does not discover joins
## from intersecting rendered meshes or regenerate a town.
static func build(proposals: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if proposals.is_empty(): return out
	var topology := FabricRoofTopologyPlan.build(proposals)
	if topology == null: return out
	var by_id: Dictionary = {}
	for item: Dictionary in proposals:
		by_id[StringName(item.stable_id)] = item
	var ids: Array = by_id.keys()
	ids.sort()
	var candidates: Dictionary = {}
	for branch_id: StringName in ids:
		var branch := by_id[branch_id] as Dictionary
		if StringName(branch.kind)!=&"tower" or bool(branch.get("partial_plate",false)) \
				or bool(branch.get("compact_junction_excluded",false)):
			continue
		var seams := topology.fact(branch_id).junctions as Array
		# A square leaf can turn its ridge without invalidating a second joint.
		if seams.size()!=1: continue
		var seam := seams[0] as Dictionary
		if int(seam.height_delta)!=0 or int(seam.face_cells)!=2: continue
		var host_id := StringName(seam.neighbor_id)
		var host := by_id[host_id] as Dictionary
		if StringName(host.kind) not in [&"slim",&"row"] \
				or bool(host.get("partial_plate",false)) \
				or bool(host.get("compact_junction_excluded",false)):
			continue
		var host_columns := FabricRoofTopologyPlan._columns(host)
		var branch_columns := FabricRoofTopologyPlan._columns(branch)
		if host_columns.size()!=8 or branch_columns.size()!=4: continue
		var host_centre := _centre_twice(host_columns)
		var branch_centre := _centre_twice(branch_columns)
		# Row recipes use a quarter-turned native ridge. Compute signs in the
		# actual native frame, not the row grammar's opposite eave convention.
		var host_yaw := posmod(int(host.yaw_quarters)+int(StringName(host.kind)==&"row"),4)
		var ridge3 := FabricRecipe.transform_direction(Vector3i.BACK,host_yaw)
		var eave3 := FabricRecipe.transform_direction(Vector3i.RIGHT,host_yaw)
		var ridge := Vector2i(ridge3.x,ridge3.z)
		var eave := Vector2i(eave3.x,eave3.z)
		var delta := branch_centre-host_centre
		var along := delta.x*ridge.x+delta.y*ridge.y
		var across := delta.x*eave.x+delta.y*eave.y
		# A two-cell square occupies the terminal half of a four-cell host.
		# These integer doubled-centre tests also exclude gaps and overlaps.
		if absi(along)!=2 or absi(across)!=4: continue
		var host_ridge := topology.fact(host_id).ridge_axis as Vector2i
		var end_direction := ridge*signi(along)
		var end_side := FabricRoofTopologyPlan.Side.RIDGE_POSITIVE \
			if end_direction==host_ridge else FabricRoofTopologyPlan.Side.RIDGE_NEGATIVE
		var end_is_free := true
		for neighbor: Dictionary in topology.fact(host_id).junctions as Array:
			if int(neighbor.side)==end_side: end_is_free=false
		if not end_is_free: continue
		var record := {"host_id":host_id,"branch_id":branch_id,
			"host_yaw":host_yaw,"eave_sign":signi(across),"end_sign":signi(along),
			"host_centre_twice":host_centre,"branch_centre_twice":branch_centre,
			"roof_base_band":int(topology.fact(host_id).roof_base_band)}
		if not candidates.has(host_id): candidates[host_id]=[]
		(candidates[host_id] as Array).append(record)
	var host_ids: Array = candidates.keys()
	host_ids.sort()
	for host_id: StringName in host_ids:
		var options := candidates[host_id] as Array
		# The finite host carries one branch. Do not choose a winner by input
		# order or overwrite one of two physical junction obligations.
		if options.size()==1: out.append(options[0])
	return out


static func _centre_twice(columns: Dictionary) -> Vector2i:
	var low := Vector2i(2147483647,2147483647)
	var high := Vector2i(-2147483647,-2147483647)
	for point: Vector2i in columns:
		low=low.min(point)
		high=high.max(point)
	return low+high


static func matches_units(left: FabricUnit, left_recipe: FabricRecipe,
		right: FabricUnit, right_recipe: FabricRecipe) -> bool:
	if not metadata_holds(left_recipe) or not metadata_holds(right_recipe): return false
	var a:=left_recipe.compact_roof_junction
	var b:=right_recipe.compact_roof_junction
	if a.is_empty() or b.is_empty() or a.role==b.role: return false
	var host:=left if a.role==&"host" else right
	var branch:=right if a.role==&"host" else left
	var host_data:=a if a.role==&"host" else b
	var branch_data:=b if a.role==&"host" else a
	if host_data.theme!=branch_data.theme or host_data.eave_sign!=branch_data.eave_sign \
			or host_data.end_sign!=branch_data.end_sign: return false
	var host_pose:=host.transform()
	var branch_pose:=branch.transform()
	if not host_pose.basis.is_equal_approx(branch_pose.basis): return false
	var host_centre:=host_pose*(host_data.centre as Vector3)
	var branch_centre:=branch_pose*(branch_data.centre as Vector3)
	var expected:=host_pose.basis*Vector3(int(host_data.eave_sign)*3.0,0,int(host_data.end_sign)*1.5)
	return (branch_centre-host_centre).distance_to(expected)<.001


static func metadata_holds(recipe: FabricRecipe) -> bool:
	var data := recipe.compact_roof_junction
	if data.is_empty() or data.get("role") not in [&"host",&"branch"] \
			or data.get("theme") not in [&"blue",&"orange"] \
			or data.get("eave_sign") not in [-1,1] or data.get("end_sign") not in [-1,1]:
		return false
	var size := Vector3i(2,1,4) if data.role==&"host" else Vector3i(2,1,2)
	var minimum := Vector3i(-1,0,-2) if data.role==&"host" else Vector3i(-1,0,-1)
	var chimney_yaw:=int(data.get("chimney_yaw",-1))
	if chimney_yaw < -1 or chimney_yaw>3 or (data.role==&"host" and chimney_yaw!=-1): return false
	return recipe.recipe_id==SettlementFabricProgram.compact_valley_recipe_id(
		data.role,data.theme,data.eave_sign,data.end_sign,chimney_yaw) \
		and data.centre==FabricModuleProgram.footprint_centre(minimum,size) \
		and recipe.solid_cells==FabricRecipe.box_cells(minimum,size)


static func branch_alignment_holds(recipe: FabricRecipe) -> bool:
	if not metadata_holds(recipe): return false
	var data := recipe.compact_roof_junction
	var chimney_yaw:=int(data.get("chimney_yaw",-1))
	if data.role!=&"branch" or recipe.placements.size()!=(2 if chimney_yaw>=0 else 1): return false
	if chimney_yaw>=0:
		var chimney:=recipe.placements[1]
		var basis:=Basis(Vector3.UP,chimney_yaw*PI*.5)
		var pose:=Transform3D(basis,(data.centre as Vector3)+basis*Vector3(.65,-1.5,-.25))
		if chimney.asset_id!=SettlementFabricProgram.COMPACT_CHIMNEY \
				or not (chimney.transform as Transform3D).is_equal_approx(pose): return false
	var placement := recipe.placements[0]
	var expected := Transform3D(Basis.IDENTITY,
		(data.centre as Vector3)-Vector3(int(data.eave_sign)*3.0,0,0))
	# A clipped branch extends to its host ridge. Its datum is the original
	# native section pose, not the centre of the remaining asymmetric bounds.
	return placement.asset_id==SettlementFabricProgram._compact_valley_asset(
		data.theme,data.eave_sign,data.end_sign,&"branch") \
		and (placement.transform as Transform3D).is_equal_approx(expected) \
		and absf(recipe.placement_bounds[0].position.y)<.001


static func alignment_holds(recipe: FabricRecipe) -> bool:
	if not metadata_holds(recipe): return false
	var data:=recipe.compact_roof_junction
	if data.role==&"branch": return branch_alignment_holds(recipe)
	if recipe.placements.size()!=5 or recipe.placement_bounds.size()!=5: return false
	var sections: Array[String]=["start","negative","adjacent","positive","end"]
	for index in sections.size():
		var section:=sections[index]
		var direction: int=-1 if section in ["start","negative"] else 1 if section in ["positive","end"] else 0
		var role: StringName=&"adjacent" if direction==0 else &"end" if section in ["start","end"] else &"middle"
		var cut: bool=direction==0 or direction==int(data.end_sign)
		var expected_asset:=SettlementFabricProgram._compact_valley_asset(data.theme,data.eave_sign,data.end_sign,role)
		if not cut:
			var native_role: String=section if section in ["start","end"] else "middle"
			expected_asset=StringName("lpfv.fabric.roof.compact.%s.03.run.%s.tight%s" % [
				"slate" if data.theme==&"blue" else "orange",native_role,
				".flush" if native_role in ["start","end"] else ""])
		var placement:=recipe.placements[index]
		var pose:=placement.transform as Transform3D
		var expected: Vector3=(data.centre as Vector3)+Vector3(0,0,direction*1.5)
		if placement.asset_id!=expected_asset or placement.id!=StringName("roof."+section) \
				or not pose.basis.is_equal_approx(Basis.IDENTITY) \
				or absf(pose.origin.x-expected.x)>.001 or absf(pose.origin.z-expected.z)>.001 \
				or (absf(pose.origin.y)>.001 if cut else absf(recipe.placement_bounds[index].position.y)>.001): return false
	return true
