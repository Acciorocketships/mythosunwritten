class_name EnvironmentVisualPiece
extends Resource

## One independently batched piece of an environment visual. Materials stay on
## the mesh surfaces; placement code only composes this local transform.
@export var mesh: Mesh
@export var local_transform: Transform3D = Transform3D.IDENTITY
## Optional asset-level palette material. Most catalogue pieces retain the
## material baked into their mesh; a rare reviewed variant may reuse identical
## geometry/collision while remapping only a known atlas colour family.
@export var material_override: Material
## MultiMesh instance colours occupy the same vertex channel as authored mesh
## colours. Palette-remap materials that need the authored channel may opt out;
## ordinary environment pieces keep the existing tinted-instance behavior.
@export var use_instance_color: bool = true
