class_name WarrenTransitionSurfaceBuilder
extends RefCounted

## Pure mesh/collision compiler for one volumetric vertical transition. Both
## landings are external platform facts; this compiler owns precisely the
## reserved span between them and derives its two side guards from that span.
const CELL_SIZE := FabricRecipe.CELL_SIZE
const MACRO_SIZE := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
const BAND_SIZE := WarrenVolumePlan.VERTICAL_BAND_SIZE_M
const FLOOR_THICKNESS := PublicRealmSurfacePlan.FLOOR_THICKNESS
const GUARD_HEIGHT := PublicRealmSurfacePlan.GUARD_HEIGHT
const GUARD_BEAM := PublicRealmSurfacePlan.GUARD_BEAM
const STAIR_STEP_RUN := 0.5
const MAX_STAIR_RISE := (TraversalEnvelope.MAX_PLANNED_STEP \
	- VillageWorldScale.GROUND_DATUM_GUARD) / VillageWorldScale.VERTICAL_SCALE
const POST_SPACING := 1.5
const END_POST_WIDTH := 0.22
const END_POST_HEADROOM := 0.20
## sfv.deck.railing.s.001 ends have post centres 0.074 m inside their
## 1.5 m span and solid timber through y=0.80 (pointed head ends at 0.93).
## Public native fences sit 0.025 m above the logical landing datum.
const LANDING_POST_INSET := 0.074
const LANDING_RAIL_HEIGHT := 0.825


static func build(stable_id: StringName,
		transition: WarrenVolumeTransition,
		claim_cells: Array[Vector3i], wall_boxes: Array[AABB] = [], defer_guards := false,
		side_insets := Vector2.ZERO) -> Dictionary:
	if stable_id.is_empty() or transition == null \
			or not transition.is_sealed() or not transition.is_vertical() \
			or claim_cells.is_empty() or not valid_side_insets(side_insets):
		return {}
	var payload := _empty_payload(stable_id, claim_cells)
	var endpoints := _span_endpoints(transition)
	var start := endpoints.start as Vector3
	var end := endpoints.end as Vector3
	var direction := Vector3(float(transition.direction.x), 0.0,
		float(transition.direction.y))
	payload["run_direction"] = Vector3i(direction)
	var lateral := Vector3(-direction.z, 0.0, direction.x)
	var original_start := start
	var original_end := end
	var shift := lateral * (side_insets.x-side_insets.y)*0.5
	start += shift
	end += shift
	var half_width := (MACRO_SIZE-side_insets.x-side_insets.y)*0.5
	if transition.kind == WarrenVolumeTransition.Kind.RAMP:
		_append_ramp(payload, start, end, lateral, half_width)
	else:
		_append_stairs(payload, start, end, direction, lateral, half_width)
	var span := {"start": start, "end": end, "lateral": lateral}
	if side_insets != Vector2.ZERO:
		span["half_width"] = half_width
		span["landing_start"] = original_start
		span["landing_end"] = original_end
	if defer_guards:
		payload["pending_guard_span"] = span
	else:
		finish_profile_guards(payload, span, wall_boxes)
	return payload


## Insets are local metres at the negative/positive lateral edge. Both reserved
## lane centres must stay on the real flight, with clearance for the guard beam.
static func valid_side_insets(insets: Vector2) -> bool:
	var limit := CELL_SIZE*0.5-GUARD_BEAM
	return insets.is_finite() and insets.x >= 0.0 and insets.y >= 0.0 \
		and insets.x <= limit and insets.y <= limit


static func finish_profile_guards(payload: Dictionary, span: Dictionary,
		wall_boxes: Array[AABB]) -> void:
	var half_width := float(span.get("half_width", MACRO_SIZE*0.5))
	_append_side_guards(payload,span.start,span.end,span.lateral,true,wall_boxes,
		GUARD_HEIGHT,0.0,half_width)
	if not span.has("landing_start"): return
	var lateral: Vector3 = span.lateral
	for endpoint in ["start","end"]:
		var centre: Vector3 = span[endpoint]
		var landing: Vector3 = span["landing_"+endpoint]
		for side: float in [-1.0,1.0]:
			var inner := centre+lateral*half_width*side
			var outer := landing+lateral*MACRO_SIZE*0.5*side
			if inner.distance_to(outer) > 0.00001:
				_append_landing_return(payload,inner,outer,wall_boxes)


## The wider landing owns the small shoulder left beside a narrower flight.
## Close its exposed edge to the inset side rail at both ends. These rails use
## the same collision, clipping and native redraw metadata as the long rails.
static func _append_landing_return(payload: Dictionary, inner: Vector3,
		outer: Vector3, wall_boxes: Array[AABB]) -> void:
	var first := (payload.indices as PackedInt32Array).size()
	var spans: Array = payload.get("guard_spans",[])
	var rails: Array[PackedVector3Array] = []
	for fraction: float in [0.52,1.0]:
		var height := Vector3.UP*GUARD_HEIGHT*fraction
		for rail: PackedVector3Array in _exposed_guard_spans(inner+height,outer+height,wall_boxes):
			rails.append(rail)
			_append_beam(payload,rail[0],rail[1],GUARD_BEAM)
			if fraction == 1.0:
				spans.append({"top_a":rail[0],"top_b":rail[1],
					"foot_a":rail[0]-height,"foot_b":rail[1]-height,
					"lateral":(outer-inner).normalized().cross(Vector3.UP),"landing_return":true})
	for post: PackedVector3Array in _exposed_guard_spans(outer,
			outer+Vector3.UP*(GUARD_HEIGHT+END_POST_HEADROOM),wall_boxes):
		if _post_meets_rail(post,rails,END_POST_WIDTH):
			_append_beam(payload,post[0],post[1],END_POST_WIDTH)
	payload["guard_spans"] = spans
	var ranges: Array = payload.get("guard_index_ranges",[])
	ranges.append(Vector2i(first,(payload.indices as PackedInt32Array).size()))
	payload["guard_index_ranges"] = ranges


static func _span_endpoints(transition: WarrenVolumeTransition) -> Dictionary:
	var direction := Vector3(float(transition.direction.x), 0.0,
		float(transition.direction.y))
	# Macro coordinates identify the lower-left lattice phase. Their expanded
	# 2x2 landing square is centered one half fabric cell into that phase.
	var from_center := Vector3(
		float(transition.from_cell.x) * MACRO_SIZE + CELL_SIZE * 0.5,
		float(transition.from_cell.y) * BAND_SIZE,
		float(transition.from_cell.z) * MACRO_SIZE + CELL_SIZE * 0.5)
	var to_center := Vector3(
		float(transition.to_cell.x) * MACRO_SIZE + CELL_SIZE * 0.5,
		float(transition.to_cell.y) * BAND_SIZE,
		float(transition.to_cell.z) * MACRO_SIZE + CELL_SIZE * 0.5)
	return {
		"start": from_center + direction * MACRO_SIZE * 0.5,
		"end": to_center - direction * MACRO_SIZE * 0.5,
	}


## A topology-declared exterior gate uses the same tread and guard construction
## as an internal flight, followed by a full ground landing.
static func build_gate_approach(stable_id: StringName, geometry: Dictionary) -> Dictionary:
	var payload := _empty_payload(stable_id,[] as Array[Vector3i])
	var start: Vector3 = geometry.inner_centre
	var end: Vector3 = geometry.stair_end
	var outer: Vector3 = geometry.outer_centre
	var direction := ((end-start)*Vector3(1,0,1)).normalized()
	var lateral := Vector3(-direction.z,0,direction.x)
	payload["run_direction"] = Vector3i(direction)
	_append_stairs(payload,start,end,direction,lateral)
	# The upper landing owns the attachment posts. Each new span owns its end
	# posts, so the flight/landing seam cannot emit two coincident timber posts.
	_append_side_guards(payload,start,end,lateral,false,[],LANDING_RAIL_HEIGHT,
		LANDING_POST_INSET)
	_append_ramp(payload,end,outer,lateral)
	_append_side_guards(payload,end,outer,lateral,false)
	return payload


static func _empty_payload(stable_id: StringName,
		claim_cells: Array[Vector3i]) -> Dictionary:
	return {
		"stable_id": stable_id,
		"kind": PublicRealmSurfacePlan.SurfaceKind.STAIR,
		"is_transition": true,
		"claim_cells": claim_cells.duplicate(),
		"vertices": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"uvs": PackedVector2Array(),
		"indices": PackedInt32Array(),
		"collision_faces": PackedVector3Array(),
	}


static func _append_ramp(payload: Dictionary, start: Vector3, end: Vector3,
		lateral: Vector3, half_width := MACRO_SIZE * 0.5) -> void:
	# The lit board material shades by these normals; a run direction that
	# flips the cross product must not turn the walk surface downward-facing.
	var top_normal := lateral.cross(end - start).normalized()
	if top_normal.y < 0.0:
		top_normal = -top_normal
	var a := start - lateral * half_width
	var b := start + lateral * half_width
	var c := end + lateral * half_width
	var d := end - lateral * half_width
	_append_quad(payload, a, b, c, d, top_normal, true, true)
	var down := Vector3.DOWN * FLOOR_THICKNESS
	_append_quad(payload, d + down, c + down, b + down, a + down,
		-top_normal, true)
	_append_quad(payload, a + down, a, d, d + down, -lateral, true)
	_append_quad(payload, b, b + down, c + down, c, lateral, true)
	_append_quad(payload, a + down, b + down, b, a,
		-(end - start).normalized(), true)
	_append_quad(payload, d, c, c + down, d + down,
		(end - start).normalized(), true)


static func _append_stairs(payload: Dictionary, start: Vector3, end: Vector3,
		direction: Vector3, lateral: Vector3, half_width := MACRO_SIZE * 0.5) -> void:
	var horizontal_length := Vector2(end.x - start.x,
		end.z - start.z).length()
	# Run length alone formerly made 0.5 m world risers. The ground approach
	# adds the frame guard, making the first one 0.58 m and blocking walking.
	var step_count := maxi(ceili(absf(end.y-start.y)/MAX_STAIR_RISE),
		maxi(2, roundi(horizontal_length / STAIR_STEP_RUN)))
	var step_run := horizontal_length / float(step_count)
	var rise := end.y - start.y
	for index in step_count:
		var t0 := float(index) / float(step_count)
		var t1 := float(index + 1) / float(step_count)
		var distance0 := step_run * float(index)
		var distance1 := step_run * float(index + 1)
		var top_y := lerpf(start.y, end.y,
			t1 if rise > 0.0 else t0)
		var center0 := Vector3(start.x, top_y, start.z) \
			+ direction * distance0
		var center1 := Vector3(start.x, top_y, start.z) \
			+ direction * distance1
		var a := center0 - lateral * half_width
		var b := center0 + lateral * half_width
		var c := center1 + lateral * half_width
		var d := center1 - lateral * half_width
		_append_quad(payload, a, b, c, d, Vector3.UP, true, true)
		var bottom0_y := lerpf(start.y, end.y, t0) - FLOOR_THICKNESS
		var bottom1_y := lerpf(start.y, end.y, t1) - FLOOR_THICKNESS
		var bottom0 := Vector3(start.x, bottom0_y, start.z) \
			+ direction * distance0
		var bottom1 := Vector3(start.x, bottom1_y, start.z) \
			+ direction * distance1
		_append_quad(payload,
			bottom0 - lateral * half_width, a, d,
			bottom1 - lateral * half_width, -lateral, true)
		_append_quad(payload,
			b, bottom0 + lateral * half_width,
			bottom1 + lateral * half_width, c, lateral, true)
		var riser_y := lerpf(start.y, end.y, t0) if rise > 0.0 \
			else lerpf(start.y, end.y, t1)
		var riser_center := center0 if rise > 0.0 else center1
		var low_left := Vector3(riser_center.x, riser_y, riser_center.z) \
			- lateral * half_width
		var low_right := Vector3(riser_center.x, riser_y, riser_center.z) \
			+ lateral * half_width
		var high_left := Vector3(riser_center.x, top_y, riser_center.z) \
			- lateral * half_width
		var high_right := Vector3(riser_center.x, top_y, riser_center.z) \
			+ lateral * half_width
		if not is_equal_approx(riser_y, top_y):
			if rise > 0.0:
				_append_quad(payload, low_left, low_right, high_right,
					high_left, -direction, true)
			else:
				_append_quad(payload, high_left, high_right, low_right,
					low_left, direction, true)
	var bottom_start := start + Vector3.DOWN * FLOOR_THICKNESS
	var bottom_end := end + Vector3.DOWN * FLOOR_THICKNESS
	var underside_normal := -(lateral.cross(bottom_end - bottom_start)).normalized()
	_append_quad(payload,
		bottom_start - lateral * half_width,
		bottom_end - lateral * half_width,
		bottom_end + lateral * half_width,
		bottom_start + lateral * half_width,
		underside_normal, true)


static func _append_side_guards(payload: Dictionary, start: Vector3,
		end: Vector3, lateral: Vector3, owns_start_posts := true,
		wall_boxes: Array[AABB] = [], start_rail_height := GUARD_HEIGHT,
		start_inset := 0.0, half_width := MACRO_SIZE * 0.5) -> void:
	var horizontal_length := Vector2(end.x - start.x,
		end.z - start.z).length()
	var post_intervals := maxi(1, ceili(horizontal_length / POST_SPACING))
	# These generated members are the guard's collision authority. A building
	# kit redraws their visual with its own railing (KitSubstitution) from two
	# facts recorded here: the index range of the guard triangles and each
	# exposed top-rail span with the foot line it stands on.
	var guard_first_index := (payload.indices as PackedInt32Array).size()
	var guard_spans: Array = payload.get("guard_spans", [])
	for side_value: Variant in [-1.0, 1.0]:
		var side := float(side_value)
		var side_offset: Vector3 = lateral * half_width * side
		var inset := ((end-start)*Vector3(1,0,1)).normalized()*start_inset
		var rails: Array[PackedVector3Array] = []
		var upper_rails: Array[PackedVector3Array] = []
		for fraction in [0.52, 1.0]:
			var exposed := _exposed_guard_spans(
				start + side_offset - inset + Vector3.UP * start_rail_height * fraction,
				end + side_offset + Vector3.UP * GUARD_HEIGHT * fraction, wall_boxes)
			rails.append_array(exposed)
			if fraction == 1.0: upper_rails = exposed
		var top_a := start + side_offset - inset + Vector3.UP * start_rail_height
		var top_b := end + side_offset + Vector3.UP * GUARD_HEIGHT
		for rail: PackedVector3Array in upper_rails:
			var feet: Array[Vector3] = []
			for point: Vector3 in rail:
				var s := clampf((point - top_a).dot(top_b - top_a)
					/ maxf((top_b - top_a).length_squared(), 0.000001), 0.0, 1.0)
				feet.append(point + Vector3.DOWN * lerpf(start_rail_height, GUARD_HEIGHT, s))
			guard_spans.append({"top_a": rail[0], "top_b": rail[1],
				"foot_a": feet[0], "foot_b": feet[1], "lateral": lateral})
		for rail: PackedVector3Array in rails:
			_append_beam(payload,rail[0],rail[1],GUARD_BEAM)
		var post_ratios: Array[float] = []
		for post_index in range(0 if owns_start_posts else 1,post_intervals + 1):
			post_ratios.append(float(post_index) / float(post_intervals))
		var regular_count := post_ratios.size()
		var run := (end-start)*Vector3(1,0,1)
		# Clipping can create a new rail end between the original posts. Seat
		# its support on the same flight, then clip it against the same building.
		for rail: PackedVector3Array in upper_rails:
			for tip_index in rail.size():
				var tip := rail[tip_index]
				var ratio := (tip-start-side_offset).dot(run)/maxf(run.length_squared(),0.000001)
				if ratio <= 0.00001 or ratio >= 0.99999: continue
				# The tip lies on whatever clipped it. Under a floor the post
				# stands right below it; against a wall face the post at the tip
				# would be clipped away with the wall, so it is seated just in
				# front of the face on the exposed side instead.
				if not _post_survives(start.lerp(end, ratio) + side_offset, rails, wall_boxes):
					var other := rail[1 - tip_index]
					var toward := signf((other-tip).dot(run))
					ratio += toward * (END_POST_WIDTH*0.5+0.002) / maxf(horizontal_length,0.000001)
				var supported := false
				for existing: float in post_ratios:
					if absf(existing-ratio)*horizontal_length < END_POST_WIDTH:
						supported = true
						break
				if not supported: post_ratios.append(ratio)
		for post_index in post_ratios.size():
			var ratio := post_ratios[post_index]
			var foot: Vector3 = start.lerp(end, ratio) + side_offset
			# A free beam end is housed inside a visibly wider post. Its head
			# stands above the rail instead of ending at the rail centreline.
			var endpoint := ratio == 0.0 or ratio == 1.0 or post_index >= regular_count
			var height := GUARD_HEIGHT + (END_POST_HEADROOM if endpoint else 0.0)
			var width := END_POST_WIDTH if endpoint else GUARD_BEAM
			for post: PackedVector3Array in _exposed_guard_spans(foot,foot+Vector3.UP*height,wall_boxes):
				# A wall can hide the shaft and both rails but leave the post's
				# decorative head exposed. Keep only pieces joined to a rail.
				if _post_meets_rail(post,rails,width):
					_append_beam(payload,post[0],post[1],width)
	var guard_ranges: Array = payload.get("guard_index_ranges", [])
	guard_ranges.append(Vector2i(guard_first_index,
		(payload.indices as PackedInt32Array).size()))
	payload["guard_index_ranges"] = guard_ranges
	payload["guard_spans"] = guard_spans


static func _post_survives(foot: Vector3, rails: Array[PackedVector3Array],
		wall_boxes: Array[AABB]) -> bool:
	for post: PackedVector3Array in _exposed_guard_spans(foot,
			foot + Vector3.UP * (GUARD_HEIGHT + END_POST_HEADROOM), wall_boxes):
		if _post_meets_rail(post, rails, END_POST_WIDTH):
			return true
	return false


static func _post_meets_rail(post: PackedVector3Array,
		rails: Array[PackedVector3Array], width: float) -> bool:
	for rail: PackedVector3Array in rails:
		var closest := Geometry3D.get_closest_points_between_segments(post[0],post[1],rail[0],rail[1])
		if closest[0].distance_to(closest[1]) <= (width+GUARD_BEAM)*.5+0.00001:
			return true
	return false


## Subtract the sealed mass union from each guard member's centre line. This
## leaves guards on exposed spans, including partial walls and parapets, while
## visual and collision geometry retain the same ownership at wall sockets.
static func _exposed_guard_spans(a: Vector3, b: Vector3,
		wall_boxes: Array[AABB]) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	var intervals: Array[Vector2] = [Vector2(0, 1)]
	for box: AABB in wall_boxes:
		var cut := _line_box_interval(a, b, box)
		if cut.x >= cut.y: continue
		var remaining: Array[Vector2] = []
		for span: Vector2 in intervals:
			if cut.y <= span.x or cut.x >= span.y:
				remaining.append(span)
				continue
			if cut.x > span.x: remaining.append(Vector2(span.x, cut.x))
			if cut.y < span.y: remaining.append(Vector2(cut.y, span.y))
		intervals = remaining
		if intervals.is_empty(): return result
	for span: Vector2 in intervals:
		if (span.y - span.x) * a.distance_to(b) < 0.00001: continue
		result.append(PackedVector3Array([a.lerp(b,span.x),a.lerp(b,span.y)]))
	return result


static func _line_box_interval(a: Vector3, b: Vector3, box: AABB) -> Vector2:
	var lo := 0.0
	var hi := 1.0
	var direction := b - a
	for axis in 3:
		if absf(direction[axis]) < 0.000001:
			if a[axis] < box.position[axis] - 0.00001 or a[axis] > box.end[axis] + 0.00001:
				return Vector2.ZERO
			continue
		var t0 := (box.position[axis] - a[axis]) / direction[axis]
		var t1 := (box.end[axis] - a[axis]) / direction[axis]
		lo = maxf(lo, minf(t0, t1))
		hi = minf(hi, maxf(t0, t1))
		if lo >= hi: return Vector2.ZERO
	return Vector2(lo, hi)


static func _append_beam(payload: Dictionary, a: Vector3, b: Vector3,
		thickness: float) -> void:
	var span := b - a
	var z_axis := span.normalized()
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	if x_axis.length_squared() < 0.5:
		x_axis = Vector3.RIGHT
	var y_axis := z_axis.cross(x_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis)
	_append_box(payload, (a + b) * 0.5,
		Vector3(thickness, thickness, span.length()), basis)


static func _append_box(payload: Dictionary, center: Vector3, size: Vector3,
		basis: Basis) -> void:
	var half := size * 0.5
	var points: Array[Vector3] = [
		center + basis * Vector3(-half.x, -half.y, -half.z),
		center + basis * Vector3(half.x, -half.y, -half.z),
		center + basis * Vector3(half.x, half.y, -half.z),
		center + basis * Vector3(-half.x, half.y, -half.z),
		center + basis * Vector3(-half.x, -half.y, half.z),
		center + basis * Vector3(half.x, -half.y, half.z),
		center + basis * Vector3(half.x, half.y, half.z),
		center + basis * Vector3(-half.x, half.y, half.z),
	]
	var faces: Array[Array] = [
		[points[4], points[7], points[6], points[5]],
		[points[1], points[2], points[3], points[0]],
		[points[0], points[3], points[7], points[4]],
		[points[5], points[6], points[2], points[1]],
		[points[3], points[2], points[6], points[7]],
		[points[0], points[4], points[5], points[1]],
	]
	for face: Array in faces:
		var normal := -((face[1] as Vector3) - (face[0] as Vector3)).cross(
			(face[2] as Vector3) - (face[0] as Vector3)).normalized()
		# Box corners already wind clockwise from outside, unlike floor quads.
		# Keep those render fronts and shade outward; collision stays identical.
		_append_quad(payload, face[0] as Vector3, face[1] as Vector3,
			face[2] as Vector3, face[3] as Vector3, normal, true, true, false)


static func _append_quad(payload: Dictionary, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, normal: Vector3,
		include_collision: bool, face_uv := false, reverse_winding := true) -> void:
	var vertices := payload.vertices as PackedVector3Array
	var normals := payload.normals as PackedVector3Array
	var uvs := payload.uvs as PackedVector2Array
	var indices := payload.indices as PackedInt32Array
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	for _index in 4:
		normals.append(normal)
	if face_uv:
		# X/Z projection collapses vertical post and beam-end faces to a line.
		# A metric face basis keeps grain readable on every side and end.
		var u_axis := (b-a).normalized()
		# Texture registration belongs to the unchanged corners, independently
		# of whether their lighting normal points with or against that order.
		var face_plane := (b-a).cross(c-a).normalized()
		var v_axis := face_plane.cross(u_axis).normalized()
		for point: Vector3 in [a,b,c,d]:
			uvs.append(Vector2((point-a).dot(u_axis),(point-a).dot(v_axis))/3.0)
	else:
		uvs.append_array(PackedVector2Array([
			Vector2(a.x, a.z) / 3.0,
			Vector2(b.x, b.z) / 3.0,
			Vector2(c.x, c.z) / 3.0,
			Vector2(d.x, d.z) / 3.0,
		]))
	# Reversed fan, matching PublicRealmSurfacePlan: tops must be front faces
	# when seen from above so lit materials shade them as walk surfaces.
	indices.append_array(PackedInt32Array([
		base, base + 2, base + 1, base, base + 3, base + 2,
	]) if reverse_winding else PackedInt32Array([
		base, base + 1, base + 2, base, base + 2, base + 3,
	]))
	payload["vertices"] = vertices
	payload["normals"] = normals
	payload["uvs"] = uvs
	payload["indices"] = indices
	if include_collision:
		var collision := payload.collision_faces as PackedVector3Array
		collision.append_array(PackedVector3Array([a, b, c, a, c, d]))
		payload["collision_faces"] = collision
