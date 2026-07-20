class_name EnvironmentVisualPiece
extends Resource

## One independently batched piece of an environment visual. Materials stay on
## the mesh surfaces; placement code only composes this local transform.
@export var mesh: Mesh
@export var local_transform: Transform3D = Transform3D.IDENTITY
