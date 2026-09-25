class_name DressingHabitatLayer
extends Resource

## One latent ecological field. Sets that name the same channel and scale see
## the same habitat, which correlates canopy, understory, clearings, and edges
## without introducing set ordering or mutable parent/child placement state.
enum Preference { INTERIOR, EDGE, EXTERIOR }

@export var channel: StringName
@export var scale: float = 120.0
@export var preference: Preference = Preference.INTERIOR
@export var coverage: Dictionary = {}
@export_range(0.001, 0.49) var edge_softness: float = 0.08
