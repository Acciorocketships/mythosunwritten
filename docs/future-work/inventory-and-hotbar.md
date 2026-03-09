# Inventory system and hotbar

**Goal:** Add an inventory system and a few items, including backend and UI for switching between items. Allow equipping items by switching to them in a hotbar.

- Backend: inventory data structure (list/slot of items), add/remove/stack, persistence if needed.
- A few initial items (e.g. tools, consumables) with basic properties.
- UI: inventory panel and hotbar; selecting a slot in the hotbar equips that item (and updates character/weapon state).
- Hotbar selection should drive “current item” used for use/attack actions.
