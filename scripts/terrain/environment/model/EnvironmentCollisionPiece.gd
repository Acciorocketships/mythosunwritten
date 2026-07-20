class_name EnvironmentCollisionPiece
extends Resource

## Heavy, main-thread-only collision data baked beside an environment visual.
## The worker still traffics only in stable asset IDs and placement transforms.
@export var shape: Shape3D
@export var local_transform: Transform3D = Transform3D.IDENTITY
