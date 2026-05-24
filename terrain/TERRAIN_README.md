## How to Add New Tiles
1. Right-click the .gltf and select New Inherited Scene
2. Click on the new scene that was created and ⌘s save it to the terrain/gltf directory
3. Create a new scene, select 3D Scene, and save it as terrain/scenes/tilename.tscn
4. Drag the visual scene in terrain/gltf onto the root node in the new scene to create an instance as a child.
5. If the object can be collided with, then add a StaticBody3D as a child of the root, and add a CollisionShape3D as a child of that. Set the collision shape.
6. Add a Node3D called "Sockets", and add Marker3D as sockets under it, one of which must be "main". It will be attached to other pieces via the main socket.
7. Add a new function load_tile_name() to TerrainModuleLibrary, and then call that function and add it to terrain_modules in load_terrain_modules().

## Tall tiles (cliffs, ≥4 units)

Tall tiles like the cliff variants follow the same conventions as ground/level tiles, with one extension:
- Origin is at the **top surface** (lateral sockets at local `y=0`).
- `bottom` socket is at local `y=-H` where H is the tile height (e.g., `(0, -4, 0)` for a 4-unit cliff). It attaches to a ground tile at world `y=0` below.
- Use a height-suffixed size tag (e.g., `"24x24x4"`) so adjacency probing uses the correct test piece with sockets at the right height.
- Register a corresponding test piece in `TerrainModuleLibrary.load_test_pieces()` if no existing one matches the height.
