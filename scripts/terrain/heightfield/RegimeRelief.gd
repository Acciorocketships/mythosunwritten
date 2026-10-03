class_name RegimeRelief
extends RefCounted

## Archetype recipes (spec 2026-10-02 §5): each turns a region record and a
## world position into relief metres added to the continental base. Noise is
## evaluated in the region's rotated frame with the region's own salt, so two
## regions of one archetype never share a pattern.
## detail=false is the regime's MACRO relief, the part rivers must see: ridge
## spines (two ridged octaves, no gullies), escarpment stairs, valley troughs,
## plateau cells, and the first hummock octave of the gentle archetypes (their
## rounded hills are where headwaters rise). The second hummock octave is
## detail. No isolated knolls, sinkholes, knobs or mounds (owner review
## 2026-10-03: "not a lunar landscape"); structure comes from LandformFeatures.

const ST := TerrainRegimeCatalog.STOREY


static func relief_m(region: Dictionary, p: Vector2, detail: bool = true) -> float:
	var q: Dictionary = region.params
	var s: int = region.salt
	var pr: Vector2 = p.rotated(region.rot)
	match region.archetype:
		&"rolling_downs":
			if not detail:
				return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 1) * q.relief_st * ST
			return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST
		&"ridge_and_pass", &"highland_massif":
			# Their macro shape is the feature layer's ridges and peak clusters;
			# ridged-noise crests are V-shaped and stalled the summit climb.
			if not detail:
				return 0.0
			return _ridges(q, s, pr, 2, detail)
		&"escarpment_country":
			var pw := ReliefPrimitives.warp(pr, s + 1, q.tread_depth_m * 0.5, q.tread_depth_m * 2.0)
			# A warped triangle wave across the region's frame: a constant gradient
			# of one tread rise per tread depth, so terracing yields long parallel
			# cliff bands (`steps` treads up, then down again).
			var period: float = 2.0 * q.steps * q.tread_depth_m
			var u: float = pw.x + ReliefPrimitives.vnoise(pw, s + 3, q.tread_depth_m * 4.0) * q.tread_depth_m
			var stair: float = absf(fposmod(u / period, 1.0) - 0.5) * 2.0 * q.steps * q.tread_rise_st * ST
			if not detail:
				# The same wave rounded (no kink at its crest) for the smooth field.
				return (0.5 + 0.5 * cos(TAU * u / period)) * q.steps * q.tread_rise_st * ST
			# Only the stair is terraced: terracing the whole noisy field broke
			# every gentle slope that crossed a step line into dashed cliffs.
			return ReliefPrimitives.terrace(stair, roundf(q.tread_rise_st) * ST, q.riser_frac) \
				+ ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST
		&"terraced_valleys":
			var axis := Vector2.from_angle(region.rot).orthogonal()
			var rel := ReliefPrimitives.warp(p - region.site, s + 1, 40.0, 300.0)
			var side := maxf(0.0, absf(rel.dot(axis)) - q.valley_half_width_m)
			if not detail:
				return minf(side / q.tread_depth_m, q.treads) * ST
			return minf(side / q.tread_depth_m, q.treads) * ST \
				+ ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST
		&"karst_hollows":
			if not detail:
				return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 1) * q.relief_st * ST
			return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST
		&"tableland":
			var w := ReliefPrimitives.worley(ReliefPrimitives.warp(pr, s + 1, q.channel_m, q.cell_m), s + 7, q.cell_m)
			var interior := smoothstep(q.channel_m * 0.5, q.channel_m, w.y - w.x)
			return interior * lerpf(0.55, 1.0, w.z) * q.rim_st * ST
		&"low_flats":
			if not detail:
				return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 1) * q.relief_st * ST
			return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST
	return 0.0


## Ridged spines, lowered into passes, with downhill gullies on their flanks.
static func _ridges(q: Dictionary, s: int, pr: Vector2, octaves: int, detail: bool) -> float:
	var wl: float = q.ridge_spacing_m * 2.0
	var pw := ReliefPrimitives.warp(pr, s + 1, q.ridge_spacing_m * 0.35, q.ridge_spacing_m * 1.5)
	var height: float = q.ridge_st * ST
	var r := ReliefPrimitives.ridged(pw, s + 2, wl, octaves if detail else 2, 2.0) \
		* ReliefPrimitives.pass_mod(pr, s + 3, q.pass_spacing_m, q.pass_depth)
	if not detail:
		return r * height
	var grad := ReliefPrimitives.ridged_gradient(pw, s + 2, wl, 2.0) * height
	var gate := smoothstep(0.05, 0.25, grad.length())
	return r * height + ReliefPrimitives.gully(pr, s + 4, q.gully_spacing_m, -grad) \
		* q.gully_st * ST * gate


## (step metres, riser fraction) of the regime's storey-aligned terrace, or
## Vector2.ZERO when the archetype does not terrace.
static func terrace_of(region: Dictionary) -> Vector2:
	var q: Dictionary = region.params
	match region.archetype:
		&"terraced_valleys":
			return Vector2(ST, q.riser_frac)
	return Vector2.ZERO
