class_name EnvironmentVisual
extends Resource

## Heavy render/physics asset data. Descriptors refer to this resource by
## string path so loading the catalogue never pulls meshes, materials, or
## shapes into memory.
@export var pieces: Array[EnvironmentVisualPiece] = []
@export var collisions: Array[EnvironmentCollisionPiece] = []
