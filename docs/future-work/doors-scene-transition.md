# Doors and scene transition

**Goal:** Add the ability to walk through a door (a collision shape on a building). Walking into it loads another scene.

- Add collision shapes to building doors that the player can trigger (area or body detection).
- On overlap/use at door: load another scene (e.g. interior) and transition the player there.
- Consider saving/loading player state and return path (e.g. exit door back to previous scene).
