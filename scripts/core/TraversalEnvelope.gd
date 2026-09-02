class_name TraversalEnvelope
extends RefCounted

## Canonical resource-free humanoid traversal contract. Structural planners
## validate against these finished-space limits; a scene contract test pins the
## values to the live player capsule and step controller.
const CAPSULE_RADIUS := 0.39746094
const CAPSULE_HEIGHT := 2.244
## Physics clearance probes expand the live body by this much. Construction
## recipes must reserve the same padded body, otherwise a support can pass the
## logical-cell proof yet still block the finished-space sweep by centimetres.
const CLEARANCE_QUERY_MARGIN := 0.02
## A traversable structural opening is not authored as an exact tangent fit.
## This finite working gap keeps tiny bake/import drift from turning a proved
## passage into a scrape while remaining far below visible module spacing.
const STRUCTURAL_WORKING_CLEARANCE := 0.03
const MIN_APERTURE_WIDTH := 1.0
const MIN_HEADROOM := 2.4
const MAX_FINISHED_STEP := 0.5
const MAX_PLANNED_STEP := 0.48

static func fits_passage(width: float, headroom: float) -> bool:
	return is_finite(width) and is_finite(headroom) \
		and width >= MIN_APERTURE_WIDTH and headroom >= MIN_HEADROOM

static func step_is_legal(height_delta: float, planned: bool = true) -> bool:
	if not is_finite(height_delta):
		return false
	var limit := MAX_PLANNED_STEP if planned else MAX_FINISHED_STEP
	return absf(height_delta) <= limit

static func capsule_diameter() -> float:
	return CAPSULE_RADIUS * 2.0


static func structural_clearance_radius() -> float:
	return CAPSULE_RADIUS + CLEARANCE_QUERY_MARGIN \
		+ STRUCTURAL_WORKING_CLEARANCE


static func clearance_prism(floor_cell: Vector3i, cell_size: float) -> AABB:
	## Continuous finished-space column at one public walk datum. Structural
	## topology may reserve whole construction bands around it, but measured
	## visual/collision envelopes must only be rejected when they enter this real
	## body lane. Keeping the prism here makes planning, volume classification,
	## and the live capsule share one dimensional contract.
	if not is_finite(cell_size) or cell_size <= 0.0:
		return AABB()
	var centre := Vector3(floor_cell) * cell_size
	return AABB(Vector3(centre.x - CAPSULE_RADIUS, centre.y,
		centre.z - CAPSULE_RADIUS), Vector3(capsule_diameter(), MIN_HEADROOM,
		capsule_diameter()))
