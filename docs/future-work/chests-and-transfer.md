# Chests and inventory transfer

**Goal:** Add chests (inventories in an object, not the player) and the ability to interact with them and move items between chest and player inventory.

- Chest = container object with its own inventory (same or similar backend to player inventory).
- Interaction: when player interacts with a chest, open a UI that shows both player inventory and chest inventory.
- Allow moving items between the two (drag-and-drop or select-and-transfer); persist chest contents when appropriate (e.g. per-instance or per-location).
