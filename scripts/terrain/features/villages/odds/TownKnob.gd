class_name TownKnob
extends Resource
## One tunable aesthetic decision. Value at town size 0 (`at_small`) and 1
## (`at_large`) blends linearly; `spread` is how far one town may deviate.
## CHANCE and RANGE_FLOAT draw a float, RANGE_INT draws an integer whose mean
## is the (possibly fractional) centre, WEIGHTS draws per-town option weights
## (each centre weight jittered by +-spread, then normalised). RANGE_INT
## clamps its draw to [clamp_min, clamp_max], which skews the realised mean
## away from the centre when the centre sits near a clamp bound.

enum Kind { CHANCE, RANGE_FLOAT, RANGE_INT, WEIGHTS }

@export var name: StringName
@export var kind: Kind = Kind.CHANCE
@export var at_small := 0.0
@export var at_large := 0.0
@export var spread := 0.0
@export var clamp_min := 0.0
@export var clamp_max := 1.0
@export var options: PackedStringArray = PackedStringArray()
@export var weights_small: PackedFloat32Array = PackedFloat32Array()
@export var weights_large: PackedFloat32Array = PackedFloat32Array()
@export_multiline var notes := ""
