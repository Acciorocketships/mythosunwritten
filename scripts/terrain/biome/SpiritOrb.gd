class_name SpiritOrb
extends Node3D

## The light and luminous sprite share one moving parent, including the bob.
var anchor := Vector3.ZERO
var phase := 0.0
var elapsed := 0.0

func _process(dt: float) -> void:
	elapsed += dt
	position = anchor + Vector3(sin(elapsed * 0.23 + phase) * 0.6,
		sin(elapsed * 0.65 + phase) * 0.35, cos(elapsed * 0.19 + phase) * 0.6)
