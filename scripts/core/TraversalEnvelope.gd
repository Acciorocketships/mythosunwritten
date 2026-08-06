class_name TraversalEnvelope
extends RefCounted

## Canonical resource-free humanoid traversal contract. Structural planners
## validate against these finished-space limits; a scene contract test pins the
## values to the live player capsule and step controller.
const CAPSULE_RADIUS := 0.39746094
const CAPSULE_HEIGHT := 2.244
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
