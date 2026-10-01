extends GutTest

## Cliff top (storey 4) at lattice points z <= 0, low ground beyond. On the
## 12 m dual-grid terrain its wall stands on the dual border z = 6 (it stood
## on the old 24 m cell border z = 12); the probes below keep their offsets
## from the wall (WALL_Z).
const WALL_Z := 6.0

class CliffRegion extends RefCounted:
	func storey_at(_x:int,z:int)->int:return 4 if z<=0 else 0
	func surface_height(x:int,z:int)->float:return storey_at(x,z)*4.0

func test_submerged_cliff_cannot_create_a_sharp_wave_amplitude_boundary()->void:
	var st:={"region":CliffRegion.new()}
	var previous:=WaterSkin._swell_scale(st,Vector2(0,WALL_Z),17,INF)
	var jump:=0.0
	for i in range(1,1201):
		var scale:=WaterSkin._swell_scale(st,Vector2(0,WALL_Z+i*.01),17,INF)
		jump=maxf(jump,absf(scale-previous));previous=scale
	assert_lte(jump,.01,"crossing a submerged cliff must not suddenly turn full waves on")
	assert_almost_eq(previous,1.0,.00001,"deep water beyond the bank retains its full wave spectrum")

func test_shallow_covered_cliff_remains_covered_during_the_maximum_trough()->void:
	var st:={"region":CliffRegion.new()}
	for z in [WALL_Z-2.0,WALL_Z-1.0,WALL_Z,WALL_Z+1.0]:
		var scale:=WaterSkin._swell_scale(st,Vector2(0,z),16.2,INF)
		# The covered ground stands at the 16 m cliff top plus SHEET_COVER: the
		# cliff sheet lies on the terrain's 2 m chords (CliffSlopeField.COVER
		# over them, plus the chords' rise over the exact tile surface). The
		# retired native lip lift was the same 0.05 m. The trough must keep
		# SWELL_BED_COVER above that.
		var covered := 16.0 + WaterSkin.SHEET_COVER + WaterSkin.SWELL_BED_COVER
		assert_gte(16.2-WaterSkin.SWELL_TROUGH_BOUND*scale,covered-.00001,
			"a face crossing the higher cliff-top cover keeps its visual cover")

## SHEET_COVER must cover what lies over the exact tile surface at the
## waterline: the cliff sheet's 0.01 m cover over the terrain's 2 m mesh
## chords, plus the chords' own rise over a one-level (1 m) smootherstep step
## across a 2 m-quad diagonal. Derived here independently of WaterSkin.
func test_sheet_cover_bounds_the_sheet_over_one_level_chords()->void:
	var max_curvature:=0.0
	var h:=0.0005
	var t:=h
	while t<1.0-h:
		var d2:=(SlopeProfile.smootherstep(t+h)-2.0*SlopeProfile.smootherstep(t)+SlopeProfile.smootherstep(t-h))/(h*h)
		max_curvature=maxf(max_curvature,absf(d2))
		t+=h
	var diagonal:=2.0*sqrt(2.0)
	var chord_rise:=1.0*max_curvature/(12.0*12.0)*diagonal*diagonal/8.0
	assert_gte(WaterSkin.SHEET_COVER,0.01+chord_rise-0.0001,
		"sheet cover %.3f + chord rise %.3f" % [0.01,chord_rise])
